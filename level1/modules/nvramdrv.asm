**************************************************************************
*
* Copyright (c) 1991, 2019-2022 by David C. Wiens, Langley BC Canada.
*
* Permission to use, copy, modify, and distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*
**************************************************************************

*----------------------------------------------------------------------------
* FILE: nvramdrv.asm
*
* PURPOSE: Device driver module for (Nitr)OS-9 Level 1 for a serial SRAM-Disk
*          and a serial EEPROM-Disk on the NVRAM/RTC board plugged into port B
*          of the ST-2900 FDC board, using the 6522's shift register to emulate
*          a half-duplex SPI port.  Includes matching device descriptors.
*          Also accesses optional Real-Time Clock (RTC) on plug-in module via
*          I$GetStt/I$SetStt calls.
*
* NOTES:
*
*  - The SRAM and EEPROM sections are each divided into (Nitr)OS-9 and FLEX
*    partitions, which have fixed sizes to simplify the software:
*     - OS-9 partitions in test configuration:
*        - SRAM:    first 64KB in 23LCV1024 in U10 @ nCS7 for device S0
*        - EEPROM:  first 64KB in 25CSM04   in U11 @ nCS8 for device F0
*        - EEPROM:  first 64KB in 25LC1024  in U12 @ nCS9 for device E0
*        - RTC:     on RV-3149-C3 eval brd  in U9  @ CS10
*     - OS-9 partitions in final configuration:
*        - SRAM:    4 chips @ 128KB (23LCV1024 in U3..U6 @ nCS0..3) for S0
*        - EEPROM:  1 chip  @ 512KB (25CSM04   in U11 @ nCS8) for E0
*           (or)    1 chip  @ 128KB (25LC1024  in U11 @ nCS8) for E0
*        - RTC:     on RTC-MC-RV3149 module    in U10 @ nCS7
*    The desired configuration is selected in DEFS file st29set(.asm).
*
*  - Some device descriptor fields are not relevant, so are not used by
*    either the device driver or the NVFormat program:  IT.STP, IT.DNS, IT.ILV
*    Some device descriptor fields are not used by the device driver because
*    their values are hard-coded into the driver, but might be used by the
*    NVFormat program, so should have valid values:  IT.CYL, IT.SID, IT.VFY,
*    IT.SCT, IT.T0S
*
*  - Some of the bit fields in IT.TYP/PD.TYP have been redefined -- refer to
*    DEFS file NvramRtcDefs(.asm).
*
*  - I$GetStt/I$SetStt function codes are used to read from and write to one
*    or more registers in the RV-3149-C3 RTC, even though they do not access
*    any disk image.  This avoids the need for a separate driver plus a shared
*    I/O driver.  Note that some RTC registers are in SRAM, while those that
*    are in EEPROM require special procedures for reading or writing (refer
*    to section 4.3 in the RV-3149-C3 Application Manual).
*
*  - NVRAMdrv isn't fully reentrant, so cannot be used by multiple devices.
*    This means all device descriptors using this driver must have the same
*    device controller absolute address, so that IOMan and RBF can use the
*    device's V.BUSY variable to queue requests for this driver when another
*    process is already accessing the driver.  And descriptors for other
*    drivers (DSKdrv, MemDsk, floppy disk, hard drive) must use a different
*    address than NVRAMdrv's.
*
*  - The current version of this driver does not provide for a checksum or
*    CRC for each sector in the serial SRAM or EEPROM chips (except for
*    part of LSN 0).  As a result, it doesn't verify after a sector write,
*    because there is no way to detect any error.  I'm hoping that the
*    serial SRAM and EEPROM chips are reliable enough that this should
*    rarely happen, and then only after many years of use.
*
*  - The first 95 bytes of LSN 0 of each OS-9 partition are protected by a
*    16-bit checksum stored at offset $60, to help catch the all 00h and all
*    FFh values, other fixed patterns or random values from an unformatted
*    volume, and other corruptions of the Volume Identification Sector.
*    If data returned is all $00 or all $FF values, this is likely due to:
*     - selected SPI device not installed on NVRAM/RTC board, so pulldown
*       R2 on NVRAM/RTC generates $00
*     - NVRAM/RTC board not connected, so internal pullup on 6522 port B
*       generates $FF
*
*  - However, the 25CSM04 EEPROM has built-in ECC logic that can correct one
*    incorrectly read bit in each 4 byte group.  Reading its status register
*    provides a flag to indicate whether the most recent read command had any
*    error that was corrected.  You can use the NVStatus program to scan the
*    entire EEPROM, checking each sector for any correctable error.  There is
*    no status flag to indicate that an UNcorrectable error was found.
*
*  - If you want the NVRAM/RTC read/write activity LED to turn on and off,
*    you need to install the new Clock module that uses 100Hz interrupts and
*    checks D.SpiBsy and updates D.SpiLED and turns the NVRAM/RTC LED off when
*    D.SpiLED is decremented to zero.  Select the configuration in DEFS file
*    st29set(.asm).
*
*  - The current version of this driver does not check bit 2 of the 6522/VIA's
*    Interrupt Flag Register to determine when the shift register has read
*    data ready to be read, or has finished a write and is ready for another
*    write.  Instead it just uses a delay with enough of a safety margin (I
*    hope) to guarantee the shift register will be ready before the next read
*    or write.  It might be possible to shorten the current delays slightly,
*    after more research and/or testing, to speed up reads/writes a bit.
*
*  - The I$SetStt/SS.WTrk ($04) write/format track function code is not
*    implemented and is treated as invalid to prevent the disk image from
*    being accidentally reformatted by a floppy disk format program.  The
*    dedicated NVFormat program instead uses the I$SetStt/SS.DWrit function
*    to write all sectors individually.  There is no need to open the path
*    in "raw" mode (e.g., /S0@).  The Volume Identification Sector (LSN 0)
*    should be written first, which also updates the drive table.  Refer to
*    additional notes in nvformat.asm.
*
*  - Does not mask interrupts at any time, for a better multi-tasking experience.
*
*  - Partially based on memdsk.asm, which was originally written March 1991.
*
* Refer to copyright and licensing information at the end of this file.
*
* Initial version created 2021-Dec-13 by David C. Wiens
* Last modified 2022-Feb-20 15:58 PST by David C. Wiens.
*----------------------------------------------------------------------------

                    nam       NVRAMdrv
                    ttl       Device driver and descriptors for serial NVRAM-Disks on ST-2900 NVRAM/RTC.
                    opt       -C        -G D66 W120

*--------------------------------------------------------------
* Definitions.
*--------------------------------------------------------------

                  IFP1
                    use       defsfile
                  ENDC

* (Nitr)OS-9 definitions.
*                   ifp1
*                   use   /DD/DEFS/st29set
*                   use   /DD/DEFS/OS9Defs
*                   use   /DD/DEFS/RBFDefs
*                   use   /DD/DEFS/NvramRtcDefs
*                   endc

SS.DWrit            equ       128       direct sector write

CAP.ALL             equ       DIR.+SHARE.+PEXEC.+PWRIT.+PREAD.+EXEC.+WRITE.+READ.

ChkSeed             equ       $719E     checksum accumulator seed value

* Offsets to stack in PutStat/ReadDsk/WritDsk.

sLSN                equ       2         offset from stack pointer to 16-bit LSW of LSN
sBUF                equ       0         offset from stack pointer to 16-bit sector buffer address

*--------------------------------------------------------------
* Configurations.
*--------------------------------------------------------------

* Configuration definitions.

* W.ClkTks = W.10Hz
* W.Ndsk = W.N25CS4
* W.Nrtc = W.Rmodul

* Drive definitions.

DrvCnt              set       2         two drives supported by this driver in final config

*--------------------------------------------------------------
* Driver static storage.
*--------------------------------------------------------------

                    org       DRVBEG
                    rmb       DRVMEM*DrvCnt drive table
DatSiz              equ       .

*--------------------------------------------------------------
* Module header.
*--------------------------------------------------------------

Rev                 set       0         (0..15)
Edition             set       0         (0..255)
TypLng              set       Drivr+Objct
AtrRev              set       ReEnt+Rev

                    mod       ModSiz,ModNam,TypLng,AtrRev
                    fdb       JmpDsk,DatSiz

                    fcb       CAP.ALL   capabilities = all

ModNam              fcs       "NVRAMdrv" device driver module name
                    fcb       Edition   module edition
                    fcb       W.ClkTks+W.Ndsk+W.Nrtc configuration
Copywrit            fcc       "cDCW"

*--------------------------------------------------------------
* Disk driver jump table.
*--------------------------------------------------------------

                    setdp     $00       ??

JmpDsk              equ       *
                    lbra      InizDsk
                    lbra      ReadDsk
                    lbra      WritDsk
                    lbra      GetStat
                    lbra      PutStat
*                   lbra  TermDsk

*--------------------------------------------------------------
* FUNCTION: TermDsk
* PURPOSE: Terminate the NVRAM-Disk device driver.
*
* IN: U  address of device static storage
*     DP  $00 ??
* OUT: CC.C  0 = OK
*--------------------------------------------------------------

TermDsk             andcc     #^Carry
                    rts

*--------------------------------------------------------------
* FUNCTION: InizDsk
* PURPOSE: Initialize port B of the 6522/VIA on the ST-2900 FDC
*   board, and initialize the NVRAM-Disk device driver.
*
* NOTES:
*
*  - 6522/VIA port B default levels are (CS10 negated in RTC
*    test/eval config), LED off, read buffer disabled, SCLK
*    forced low, chip selects nCS0..nCS9 negated.
*
*  - InizDsk does not need to initialize D.SpiLED or D.SpiBsy
*    because the first thing the OS9p1 kernel module does when
*    it is called at boot time is to clear the entire direct page
*    to all $00 values:
*      D.SpiLED  0 = idle value of down-counter
*      D.SpiBsy  0 = SPI port is "not busy", so Clock module may
*                 access IRB/ORB
*
* IN: U  address of device static storage
*     Y  address of device descriptor module
*     DP  $00 ??
* OUT: CC.C  0 = OK
*--------------------------------------------------------------

InizDsk             pshs      X,B,A

* Initialize 6522/VIA port B.

                    ldb       #M.CS10!M.LED!M.RD!M.DEVS set output levels to defaults
                    stb       ORB.V
                    ldb       #$FF      configure PB7..PB0 as outputs
                    stb       DDRB.V

                    lbsr      SHFTdis   disable 6522 shift register

* Initialize number of drives supported by this device.

                    ldb       #DrvCnt
                    stb       V.NDRV,U

* Initialize DD.TOT for each drive to prevent E$EOF or E$Sect errors.

                    lda       #$01
                    leax      DRVBEG,U
ID20                sta       DD.TOT+1,X
                    leax      DRVMEM,X
                    decb
                    bne       ID20

* Return.

                    clrb
                    puls      A,B,X,PC

*--------------------------------------------------------------
* FUNCTION: PutStat
* PURPOSE: Handle various I$SetStt service requests.
*
* NOTES:
*
*  - SS.Reset ($03) - restore to track 0 - is not implemented,
*    but is ignored without any error returned.
*
*  - SS.WTrk ($04) - write/format track - is not implemented,
*    and is treated as invalid.
*
*  - SS.DWrit bypasses regular RBF processing to directly write
*    to any sector, even if the device was not opened in "raw"
*    mode (e.g., /S0@).
*
*  - SS.RtcWr writes to one or more registers in the RV-3149-C3
*    RTC chip.  The I/O control structure consists of a 1-byte
*    command code, 1 byte number of registers to write (1..8),
*    and an 8-byte data buffer containing the data to write.
*
*  - Register usage by calling program:
*
*      SS.DWrit - direct sector write:
*        IN: A  path number
*            B  function code $80
*            X  16-bit LSN (0..2047)
*            Y  address of 256-byte user sector buffer
*        OUT: CC.C  0 = OK
*        ERROR: CC.C  1 = error
*               B  error code
*
*      SS.RtcWr - write to RTC register(s):
*        IN: A  path number
*            B  function code $D9
*            X  address of data buffer in I/O control struct
*        OUT: CC.C  always 0 = OK
*
* IN: U  address of device static storage
*     Y  address of path descriptor
*       PD.RGS,Y  address of caller's register stack:
*         R$B  I$SetStt function code
*         (other registers depend on function code, see notes)
*     DP  $00 ??
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

PutStat             pshs      Y,X,B,A   (stack must be same as in GetStat and WritDsk)

* Get I$SetStt function code.

                    ldx       PD.RGS,Y  address of caller's register stack
                    ldb       R$B,X     Set Status function code

* Restore to track zero.

                    cmpb      #SS.Reset code = restore to track zero?
                    beq       PSok      .Y, not implemented, ignore

* Direct sector write.  (Stack must be same as in WritDsk at WD10.)

                    cmpb      #SS.DWrit code = direct sector write?
                    bne       PS29      .N, try other codes

                    ldd       R$X,X     .Y, save 16-bit LSN on stack (sLSN)
                    pshs      D
                    ldd       R$Y,X     save address of user sector buffer on stack (sBUF)
                    pshs      D

                    clrb                extend 16-bit LSN to 24-bit LSN

                    lbra      WD10      use WritDsk to perform write

PS29                equ       *

* Write to one or more registers in the RV-3149-C3 RTC.

                    cmpb      #SS.RtcWr code = write to RTC registers?
                    bne       PS39      .N, try other codes

                    ldx       R$X,X     address of data buffer in I/O control struct

                    lbsr      WritRtc   write to RTC registers

                    bra       PSok

PS39                equ       *

* Return.

PSunksvc            ldb       #E$UnkSvc unknown/unimplemented function code
                    bra       PSerr

PSok                clrb                CC.C = 0 = OK
                    bra       PS99

PSerr               stb       1,S       store error code
                    comb                CC.C = 1 = error

PS99                puls      A,B,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: GetStat
* PURPOSE: Handle various I$GetStt service requests.
*
* NOTES:
*
*  - SS.Stat4 returns the 16-bit 25CSM04 EEPROM status register
*    contents, where bit 6 is the ECC status:
*      1 = error found and corrected in previous read sequence
*      0 = no error found in previous read sequence
*    It is only available if a 25CSM04 EEPROM is installed.
*
*  - SS.RtcRd reads from one or more registers in the RV-3149-C3
*    RTC chip.  The I/O control structure consists of a 1-byte
*    command code, 1 byte number of registers to read (1..8),
*    and an 8-byte data buffer where data read is to be stored.
*
*  - Register usage by calling program:
*
*      SS.Stat4 - read 25CSM04 EEPROM status register:
*        IN: A  path number
*            B  function code $D8
*            X  address of 2-byte user status register buffer
*        OUT: CC.C  always 0 = OK
*
*      SS.RtcRd - read from RTC register(s):
*        IN: A  path number
*            B  function code $DA
*            X  address of data buffer in I/O control struct
*        OUT: CC.C  always 0 = OK
*
* IN: U  address of device static storage
*     Y  address of path descriptor
*       PD.RGS,Y  address of caller's register stack
*         R$B  I$GetStt function code
*         (other registers depend on function code, see notes)
*     DP  $00 ??
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

GetStat             pshs      Y,X,B,A   (stack must be same as in PutStat)

* Get I$GetStt function code.

                    ldx       PD.RGS,Y  address of caller's register stack
                    ldb       R$B,X     Get Status function code

* Read 25CSM04 EEPROM status register.

                    cmpb      #SS.Stat4 code = read 25CSM04 status register?
                    bne       GS29      .N, try other codes

                    ldb       #E$BTyp   .Y, return code = wrong type of device for this function code
                    lda       PD.TYP,Y  is device a 25CSM04 EEPROM?
                    anda      #TYP.NVRM!TYP.SOF!TYPN.EEP!TYPN.EE4
                    cmpa      #TYP.NVRM!TYP.SOF!TYPN.EEP!TYPN.EE4
                    bne       PSerr     .N, this function not supported for other devices

                    ldy       R$X,X     .Y, get address of status register buffer
                    lbsr      ReadStat  read 16-bit status register in 25CSM04 to buffer

                    bra       PSok

GS29                equ       *

* Read from one or more registers in the RV-3149-C3 RTC.

                    cmpb      #SS.RtcRd code = read from RTC registers?
                    bne       GS39      .N, try other codes

                    ldy       R$X,X     address of data buffer in I/O control struct

                    lbsr      ReadRtc   write to RTC registers

                    bra       PSok

GS39                equ       *

                    bra       PSunksvc  unknown/unimplemented function code

*--------------------------------------------------------------
* FUNCTION: LtoP  (Logical to Physical)
* PURPOSE: Check if drive number and LSN are valid, calculate
*   address of drive table entry, convert drive number and 24-bit
*   LSN to an SPI chip select code and 16-bit chip LSN.
*
* NOTES:
*  - MSB of DD.TOT must also be zero, but is not checked.
*
* IN: U  address of device static storage
*     Y  address of path descriptor
*     B  MSB of 24-bit LSN to read or write
*     sLSN,S  LSW of 24-bit LSN to read or write (at sLSN+2,S in LtoP)
*     DP  $00 ??
* OUT: CC.C  0 = OK
*      X  address of entry in drive table
*      A,B  undefined
* ERROR: CC.C  1 = error
*        B  error code
*        A,X  undefined
*--------------------------------------------------------------

LtoP                equ       *

* Validate drive number and MSB of 24-bit LSN.

                    lda       PD.DRV,Y  get drive number
                    cmpa      #DrvCnt   is it valid?
                    bhs       LP95      .N, out of range

                    tstb                is MSB of 24-bit LSN zero?
                    bne       LP93      .N, out of range

* Calculate entry in drive table for this drive.

                    ldb       #DRVMEM   calculate address of entry in drive table
                    mul
                    leax      DRVBEG,U
                    leax      D,X

* Validate LSN vs. DD.TOT for selected drive in drive table.

                    ldd       sLSN+2,S  get LSW of 24-bit LSN from Reg X on stack, is valid?
                    beq       LP30      .Y, LSN 0 is always valid
                    cmpd      DD.TOT+1,X
                    bhs       LP93      .N, out of range

LP30                stb       D.SpiLSN+1 .Y, save LSB of 16-bit chip LSN

* Determine chip select code and MSB of chip LSN for SRAM.

                    ldb       PD.TYP,Y  is this for a 23LCV1024 SRAM device?
                    bitb      #TYPN.EEP
                    bne       LP50      .N, EEPROM

                    ldb       #M.CS00   .Y, load chip select code of first SRAM chip in U3
LP40                bita      #%11111110 is MSB of LSN a 0 or 1 (offset < 128KB)?
                    beq       LP60      .Y, chip select code and chip LSN ready
                    suba      #2        .N, subtract $0200 from LSN (128KB from address)
                    incb                incr. chip select code by 1
                    bra       LP40

* Determine chip select code and MSB of chip LSN for EEPROM.

LP50                ldb       #M.CS08   use nCS8 for 25CSM04 or 25LC1024 EEPROM in U11

LP60                stb       D.SpiSel  save chip select code
                    sta       D.SpiLSN+0 save adjusted MSB of 16-bit chip LSN

* Return.

                    clrb                CC.C = 0 = OK
                    bra       LP99

LP93                ldb       #^E$Sect
                    bra       LP97

LP95                ldb       #^E$Unit
LP97                comb                CC.C = 1 = error

LP99                rts

*--------------------------------------------------------------
* FUNCTION: ReadDsk
* PURPOSE: Read 256 bytes of data from the specified location in
*   the specified NVRAM-Disk into the path descriptor's sector
*   buffer.  If LSN 0, also update the drive table entry and
*   verify the Volume Identification Sector checksum.
*
* IN: U  address of device static storage
*     Y  address of path descriptor
*     B  MSB of 24-bit LSN to read (must be zero)
*     X  LSW of 24-bit LSN to read (0..2047)
*     DP  $00 ??
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

ReadDsk             equ       *

* Save registers on stack - must be same as in WritDsk.
* Any changes also require modifying LtoP.

                    pshs      Y,X,B,A   save incoming registers
                    pshs      X         save LSW of 24-bit LSN on stack (sLSN)
                    ldx       PD.BUF,Y  save address of path sector buffer on stack (sBUF)
                    pshs      X

* Check if drive number and LSN are valid, calculate
* drive table address and SPI chip select and chip LSN.

                    bsr       LtoP
                    bcs       RD95

* Read sector data from NVRAM-Disk.

                    ldy       sBUF,S    address of path sector buffer
                    lbsr      ReadSect

* If LSN 0, copy part of Volume Identification Sector to drive table entry.

                    ldd       sLSN,S    is LSN 0?
                    bne       RD90      .N

                    bsr       CopyVIS

* If LSN 0, verify Volume Identification Sector checksum.

                    bsr       CalcChk

                    cmpx      1,Y       checksum matches DD.CHK (offset $60)?
                    beq       RD90      .Y, OK

* Return.

                    ldb       #E$Read   .N, error
                    bra       RD95

RD90                clrb                CC.C = 0 = no error
                    bra       RD99

RD95                stb       1+4,S     store error code
                    comb                CC.C = 1 = error

RD99                leas      4,S
                    puls      A,B,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: CopyVIS
* PURPOSE: Copy part of Volume Identification Sector to drive
*   table entry.
* NOTES: Only done for LSN 0, for both reads and writes.
* IN: X  address of drive table entry for current drive
*     Y  address of path sector buffer or user sector buffer
* OUT: CC.C,A,B  undefined
*--------------------------------------------------------------

CopyVIS             equ       *

                    ldb       #DD.SIZ-1 loop count = size of area to copy
CV20                lda       B,Y
                    sta       B,X
                    decb
                    bpl       CV20

                    rts

*--------------------------------------------------------------
* FUNCTION: CalcChk
* PURPOSE: Calculate Volume Identification Sector checksum.
* NOTES: Only done for LSN 0, for both reads and writes.
* IN: Y  address of path sector buffer or user sector buffer
* OUT: X  16-bit checksum
*      Y  points to DD.FIL in sector buffer
*      CC.C,A,B  undefined
*--------------------------------------------------------------

CalcChk             equ       *

                    ldx       #ChkSeed  checksum accumulator seed
                    lda       #DD.FIL   loop count = start of DD.TOT to end of DD.OPT
CC20                ldb       ,Y+
                    abx
                    deca                all bytes processed?
                    bne       CC20      .N, process next

                    rts

*--------------------------------------------------------------
* FUNCTION: WritDsk
* PURPOSE: Write 256 bytes data from the path descriptor's sector
*   buffer into the specified NVRAM-Disk at the specified location.
*   If LSN 0, update the Volume Identification Sector checksum
*   before writing, and also update the drive table entry.
*
* IN: U  address of device static storage
*     Y  address of path descriptor
*     B  MSB of 24-bit LSN to write (must be zero)
*     X  LSW of 24-bit LSN to write (0..2047)
*     DP  $00 ??
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

WritDsk             equ       *

* Save registers on stack - must be same as in ReadDsk and
* PutStat/SS.DWrit.  Any changes also require modifying LtoP.

                    pshs      Y,X,B,A   save incoming registers
                    pshs      X         save LSW of 24-bit LSN on stack (sLSN)
                    ldx       PD.BUF,Y  save address of path sector buffer on stack (sBUF)
                    pshs      X

WD10                equ       *         PutStat enters here for I$SetStt/SS.DWrit

* Check if drive number and LSN are valid, calculate
* drive table address and SPI chip select and chip LSN.

                    lbsr      LtoP
                    bcs       WD95

* If LSN 0, copy part of Volume Identification Sector to drive table entry.

                    ldd       sLSN,S    is LSN 0?
                    bne       WD40      .N, skip

                    pshs      Y

                    ldy       sBUF+2,S  address of path/user sector buffer
                    bsr       CopyVIS

* If LSN 0, calculate new Volume Identification Sector checksum.

                    bsr       CalcChk
                    stx       1,Y       store new checksum in DD.CHK (offset $60)

                    puls      Y

* If write to EEPROM, set write-enable latch.

WD40                lda       PD.TYP,Y  is this an EEPROM device?
                    bita      #TYPN.EEP
                    beq       WD50      .N, SRAM

                    lbsr      WritEnbl  .Y, set write enable latch

* Write sector data to NVRAM-Disk.

WD50                ldx       sBUF,S    address of path/user sector buffer
                    lbsr      WritSect

* If write to EEPROM, wait until write completed.

                    lda       PD.TYP,Y  is this an EEPROM device?
                    bita      #TYPN.EEP
                    beq       WD90      .N, SRAM, done

                    ldd       #6100/7   .Y, delay 6.1 msec. with spin loop
WD70                subd      #1        (4)
                    bne       WD70      (3)

* Return.

WD90                clrb                CC.C = 0 = no error
                    bra       WD99

WD95                stb       1+4,S     store error code

WD99                leas      4,S
                    puls      A,B,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: ReadRtc
* PURPOSE: Read 1..8 bytes from the RV-3149-C3 RTC chip.
* NOTES:
*  - Multi-byte reads must not cross a page boundary.
*  - Refer to notes in GetStat for details of I/O control struct.
* IN: Y  address of data buffer in RTC I/O control structure
*     DP  $00 ??
* OUT: A,B,CC.C  undefined
*--------------------------------------------------------------

ReadRtc             pshs      Y,A       (stack must be same as in ReadSect)

                    lda       #M.CS07   chip select nCS7 for U10
                    sta       D.SpiSel

                    lda       -2,Y      get command code from I/O control struct
                    lbsr      StartCmd

                    lda       -1,Y      get loop count from I/O control struct
                    sta       0,S       save on stack
                    cmpa      #1        more than one byte?
                    bhi       RS20      .Y, 2..8, use ReadSect to process rest of command

                    lbsr      SHFTin    .N, only 1, switch shift register to input mode

                    andb      #^M.RD    enable read buffer
                    stb       ORB.V

                    lda       SR.V      dummy read to initiate shift in of first byte
                    lbsr      Delay20   (20)

                    bra       RS60      use ReadSect to process rest of command

*--------------------------------------------------------------
* FUNCTION: ReadStat
* PURPOSE: Read the 16-bit status register in a 25CSM04 SPI
*   EEPROM in U11.
*
* NOTES:
*  - Is not available if 25LC1024 EEPROM installed instead of
*    25CSM04.
*
* IN: Y  address of status data buffer
*     DP  $00 ??
* OUT: A  always 0
*      B,CC.C  undefined
*--------------------------------------------------------------

ReadStat            lda       #2-1      loop count = 1 byte
                    pshs      Y,A       (stack must be same as in ReadSect)

                    lda       #M.CS08
                    sta       D.SpiSel

                    lda       #M.RdSt   command code = Read Status
                    bsr       StartCmd

                    bra       RS20      use ReadSect to process rest of command

*--------------------------------------------------------------
* FUNCTION: ReadSect
* PURPOSE: Read one 256-byte sector from an SPI memory device.
*
* IN: Y  address of sector data buffer
*     DP  $00 ??
*       D.SpiSel  8-bit SPI chip select code (0..9 for nCS0..9)
*       D.SpiLSN  16-bit SPI LSN (within selected device)
* OUT: A  always 0
*      B,CC.C  undefined
*--------------------------------------------------------------

ReadSect            lda       #256-1    loop count = 255 bytes
                    pshs      Y,A

                    lda       #M.RdDat  command code = Read Data
                    bsr       CmdAddr

RS20                lbsr      SHFTin    switch shift register to input mode

                    andb      #^M.RD    enable read buffer
                    stb       ORB.V

                    lda       SR.V      dummy read to initiate shift in of first byte
                    bsr       Delay20   (18)

RS50                lda       SR.V      (5) 255 x 24 = 6120 cycles = 333333 bps average
                    sta       ,Y+       (6)
                    nop       (2)
                    nop       (2)
                    dec       0,S       (6)
                    bne       RS50      (3)

RS60                bsr       EndRead   read last byte from shift register
                    sta       ,Y+

                    puls      A,Y,PC

*--------------------------------------------------------------
* FUNCTION: WritRtc
* PURPOSE: Write 1..8 bytes to the RV-3149-C3 RTC chip.
* NOTES:
*  - Multi-byte writes to SRAM pages must not cross a page boundary.
*  - Writes to EEPROM pages must be done 1 byte at a time, and
*    follow the procedure in section 4.3 of the Application Manual.
*  - Refer to notes in PutStat for details of I/O control struct.
* IN: X  address of data buffer in RTC I/O control structure
*     DP  $00 ??
* OUT: A  always 0
*      B,CC.C  undefined
*--------------------------------------------------------------

WritRtc             lda       -1,X      get loop count from I/O control struct
                    pshs      X,A       (stack must be same as in WritSect)

                    lda       #M.CS07   chip select nCS7 for U10
                    sta       D.SpiSel

                    lda       -2,X      get command code from I/O control struct
                    bsr       StartCmd

                    bra       WS50      use WritSect to process rest of command

*--------------------------------------------------------------
* FUNCTION: WritSect
* PURPOSE: Write one 256-byte sector to an SPI memory device.
*
* NOTES:
*  - If the write is to an EEPROM, its write enable latch must
*    have been set immediately before calling this routine.
*
* IN: X  address of sector data buffer
*     DP  $00 ??
*       D.SpiSel  8-bit SPI chip select code (0..9 for nCS0..9)
*       D.SpiLSN  16-bit SPI LSN (within selected device)
* OUT: A  always 0
*      B,CC.C  undefined
*--------------------------------------------------------------

WritSect            clra                loop count = 256 bytes
                    pshs      X,A

                    lda       #M.WrDat  command code = Write Data
                    bsr       CmdAddr

WS50                lda       ,X+       (6) 256 x 24 = 6144 cycles = 333333 bps average
                    sta       SR.V      (5)
                    nop       (2)
                    nop       (2)
                    dec       0,S       (6)
                    bne       WS50      (3)

                    puls      A,X

                    bra       EndCmd

*--------------------------------------------------------------
* FUNCTION: WritEnbl
* PURPOSE: Set the Write Enable latch in an SPI EEPROM device.
*
* IN: DP  $00 ??
*       D.SpiSel  8-bit SPI chip select code (0..9 for nCS0..9)
* OUT: A,B,CC.C  undefined
*--------------------------------------------------------------

WritEnbl            equ       *

                    lda       #M.WrEn   command code = Write Enable
                    bsr       StartCmd

                    bra       EndCmd

*--------------------------------------------------------------
* FUNCTION: CmdAddr
* PURPOSE: Write the 8-bit command code and 24-bit address to
*   an SPI memory device.
*
* IN: A  8-bit SPI command code
*     DP  $00 ??
*       D.SpiSel  8-bit SPI chip select code (0..9 for nCS0..9)
*       D.SpiLSN  16-bit SPI LSN (within selected device)
* OUT: B  current VIA ORB value
*      A,CC.C  undefined
*--------------------------------------------------------------

CmdAddr             equ       *

                    bsr       StartCmd

                    lda       D.SpiLSN+0 MSB of 16-bit chip LSN
                    sta       SR.V
                    bsr       Delay16   (14)

                    lda       D.SpiLSN+1 LSB of 16-bit chip LSN
                    sta       SR.V
                    bsr       Delay16   (14)

                    clra                lower 8 bits of address always 0 (sector boundary)
                    sta       SR.V

                    bra       Delay20   (14)

*--------------------------------------------------------------
* FUNCTION: StartCmd
* PURPOSE: Start an SPI read or write command sequence.  Also
*   turn on SPI activity LED if enabled.
*
* IN: A  8-bit SPI command code
*     DP  $00 ??
*       D.SpiSel  8-bit SPI chip select code (0..9 for nCS0..9,
*                  or $8F for CS10)
* OUT: B  current VIA ORB value
*      CC.C  undefined
*--------------------------------------------------------------

StartCmd            equ       *

                    bsr       SHFTout   enable shift register for output

                    ldb       IRB.V     read current VIA ORB value

                    andb      #^M.DEVS  assert specified nCS
                    orb       D.SpiSel
                    orb       #M.IDLE   release SCLK
                    stb       ORB.V

                    sta       SR.V      send command code to SPI device

                    bra       Delay20   (14)

*--------------------------------------------------------------
* FUNCTION: EndCmd
* PURPOSE: End an SPI command sequence.
*
* NOTES:
*  - Reg B is considered undefined at exit because VIA ORB may
*    not be accessed by NVRAMdrv after D.SpiBsy is cleared, as
*    the Clock module updates it
*
* IN: B  current VIA ORB value
* OUT: B,CC.C  undefined
*--------------------------------------------------------------

EndCmd              equ       *

                    andb      #^M.IDLE  force SCLK low
                    stb       ORB.V
                    orb       #M.DEVS   negate all chip selects (nCS0..9)
                    stb       ORB.V

                    bra       SHFTdis   disable shift register

*--------------------------------------------------------------
* FUNCTION: EndRead
* PURPOSE: End an SPI read command sequence.
*
* IN: B  current VIA ORB value
* OUT: A  last data value read from SRAM or EEPROM or RTC
*      B,CC.C  undefined
*--------------------------------------------------------------

EndRead             equ       *

                    orb       #M.RD     disable read buffer

                    bsr       EndCmd

                    lda       SR.V      read last data value from shift register

                    rts

*--------------------------------------------------------------
* FUNCTIONS: Delay14/Delay16/Delay18/Delay20
* PURPOSE: Delay 14..20 cycles to allow data to finish shifting
*   in/out of the 6522's 8-bit shift register before processsing
*   the next byte.
*
* NOTES:
*  - The delay values in the names include the calling LBSR (9
*    cycles).
*
* IN: (none)
* OUT: (none)
*--------------------------------------------------------------

Delay20             nop       (2)
Delay18             nop       (2)
Delay16             nop       (2)
Delay14             rts                 (5)

*--------------------------------------------------------------
* FUNCTION: SHFTin
* PURPOSE: Configure 6522 Shift Register to shift in at 1/2
*   system clock rate.
*
* IN: (none)
* OUT: CC.C  undefined
*--------------------------------------------------------------

SHFTin              pshs      A

                    lda       ACR.V
                    anda      #^M.SR
                    ora       #M.SRin

                    bra       SH50

*--------------------------------------------------------------
* FUNCTION: SHFTout
* PURPOSE: Configure 6522 Shift Register to shift out at 1/2
*   system clock rate.
*
* IN: (none)
* OUT: CC.C  undefined
*--------------------------------------------------------------

SHFTout             pshs      A

                    lda       ACR.V
                    anda      #^M.SR
                    ora       #M.SRout

                    bra       SH50

*--------------------------------------------------------------
* FUNCTION: SHFTdis
* PURPOSE: Disable 6522 Shift Register.
*
* IN: (none)
* OUT: CC.C  undefined
*--------------------------------------------------------------

SHFTdis             pshs      A

                    lda       ACR.V
                    anda      #^M.SR
*                   ora   #M.SRdis
SH50                sta       ACR.V

                    puls      A,PC


                    emod
ModSiz              equ       *

                    end
