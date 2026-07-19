**************************************************************************
*
* Copyright (c) 2021-2022 by David C. Wiens, Langley BC Canada.
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
* FILES: nvformat.asm / NVFormat
*
* PURPOSE: Format the OS-9 partition in one of the serial NVRAM-Disks on the
*          NVRAM/RTC board connected to port B of the ST-2900 FDC board.
*
* NOTES:
*
*  - Syntax: nvformat </devname> <"volname"> [<'cyl'>]
*     where:  </devname> is device name, must be first parameter, starts with
*                         slash, do not end with '@'
*             <"volname"> is volume name for partition, may contain spaces,
*                          up to 32 characters between " marks, is a required
*                          parameter
*             <'cyl'> is number of cylinders (2..128), defaults to value in
*                      device descriptor if not given here, must be last
*                      parameter if supplied
*
*    Example: nvformat /E0 "NVSRAM-Disk Backup" '24'
*
*  - Limit of 128 cylinders @ 16 sectors/track = 2048 sectors, which allows
*    the Disk Allocation bit Map to fit in exactly one sector with cluster
*    size of 1.  Only four sectors are initially allocated:
*      LSN 0  Volume Identification Sector
*      LSN 1  Disk Allocation bit Map
*      LSN 2  File Descriptor of root directory
*      LSN 3  data of root directory
*
*  - NVFormat doesn't verify after formatting, so any bad sectors won't be
*    removed from the allocation bit map.  Since NVRAMdrv doesn't provide
*    for a checksum or CRC for each sector, reading a sector after writing
*    it can't indicate whether there was any error.  I'm hoping that the
*    serial SRAM and EEPROM chips are reliable enough that this should
*    rarely happen, and then only after many years of use.
*
*  - Why write another format program instead of just supporting the
*    I$SetStt/SS.WTrk function and formatting the entire volume when
*    the SFormat program makes that function call for track 0?  It would
*    add lots of code to the NVRAMdrv driver that is rarely used, so wastes
*    precious memory.  NVFormat does some checking that SFormat doesn't do.
*    SFormat provides some options that are not relevant to NVRAMdrv.
*
*  - I switched to using the I$SetStt/SS.DWrit function instead of using
*    I$Write with raw mode after having lots of problems with it -- refer
*    to ST2900-Notes.txt.
*
* Refer to copyright and licensing information at the end of this file.
*
* Initial version created 2021-Dec-28 by David C. Wiens.
* Last modified 2022-Mar-31 10:29 PDT by David C. Wiens.
*----------------------------------------------------------------------------

                    nam       NVFormat
                    ttl       Format an OS-9 partition in a serial NVRAM-Disk.
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
*                   use   /DD/DEFS/SCFDefs
*                   use   /DD/DEFS/NvramRtcDefs
*                   endc

SS.DWrit            equ       128       direct sector write

CAP.ALL             equ       DIR.+SHARE.+PEXEC.+PWRIT.+PREAD.+EXEC.+WRITE.+READ.

*--------------------------------------------------------------
* Configurations.
*--------------------------------------------------------------

* Configuration definitions.

* W.ClkTks = W.10Hz
* W.Ndsk = W.N25CS4
* W.Nrtc = W.Rmodul

*--------------------------------------------------------------
* Module static storage.
*--------------------------------------------------------------

DevNameL            equ       12        length of DevNameS variable

                    org       0
UserID              rmb       2         user ID
DevPath             rmb       1         path number for device being formatted
DevNameA            rmb       2         address of device name string in parameter line
DevNameR            rmb       DevNameL+2 copy of device name string with @,CR
DevNameS            rmb       DevNameL  copy of device name string with sign bit
DevTablA            rmb       2         address of device table entry
Cyls                rmb       2         number of cylinders to format (2..128)
TotSecs             rmb       2         total number of sectors on media (32..2048)
WritLSN             rmb       2         previous logical sector number where to write
ZeroSupr            rmb       1         3..1 = leading 0 digits to suppress, 0 = print '0'
ZeroSpac            rmb       1         non-zero = replace 0 with space, 0 = don't display
Temp1               rmb       1         temporary 1-byte work area
MsgL                rmb       2         length of string in MsgTxt (1..128)
MsgTxt              rmb       128       message string buffer
SecBufr             rmb       256       sector buffer
                    rmb       200       stack
DatSiz              equ       .

*--------------------------------------------------------------
* Module header.
*--------------------------------------------------------------

Rev                 set       0         (0..15)
Edition             set       0         (0..255)
TypLng              set       Prgrm+Objct
AtrRev              set       ReEnt+Rev

                    mod       ModSiz,ModNam,TypLng,AtrRev
                    fdb       ModEntr,DatSiz

ModNam              fcs       "NVFormat" program module name
                    fcb       Edition   module edition
                    fcb       W.ClkTks+W.Ndsk+W.Nrtc configuration
Copywrit            fcc       "cDCW"

StdIn               set       0
StdOut              set       1

*--------------------------------------------------------------
* FUNCTION: ModEntr
* PURPOSE: Entry point and main logic of program.
*
* IN: X,SP  address of beginning of parameter string
*     Y  address of end of parameter string
*     U,DP  address of process static storage
*     D  size of parameter area
* OUT: B  exit code, 0 = OK, non-zero = error
*      ??? undefined
*--------------------------------------------------------------

ModEntr             equ       *

* Install dummy signal intercept routine.

                    pshs      Y,X

                    leax      >Intrcpt,PC
                    os9       F$Icpt

* Set process priority.

                    os9       F$ID      get Process ID and User ID
                    sty       UserID

                    ldb       #128      default priority (midway between 0 and 255)
                    os9       F$SPrior

* Display program name.

                    clr       MsgL+0

                    leax      Msg01,PC  NVFormat - format NVRAM-Disk partition
                    lbsr      ShowMsg

                    puls      X,Y

* Extract device name from parameter line.

                    bsr       DevcName
                    bcs       NF99

* Open path to device, using "raw" mode.

                    pshs      X
                    lda       #WRITE.   open device for write-only
                    leax      DevNameR,U
                    os9       I$Open
                    puls      X
                    bcs       NF99

                    sta       DevPath   save path number

* Copy device options section of path descriptor to DD.OPT in LSN 0 buffer.

                    clra
                    lbsr      InizBufr  clear sector buffer for LSN 0

                    lbsr      DevOpts
                    bcs       NF99

* Get volume name from parameter line.

                    lbsr      VolName
                    bcs       NF99

* Get number of cylinders (optional) from parameter line.

                    lbsr      NumCyls
                    bcs       NF99

* Perform the formatting process.

                    lbsr      AskReady  display details, ask user to confirm to proceed
                    bcs       NF99
                    cmpb      #E$PrcAbt user requested abort?
                    beq       NF90      .Y, exit

                    lbsr      WritVID   build and write Volume Identification Sector (LSN 0)
                    bcs       NF99

                    lbsr      WritDAM   build and write Disk Allocation bit Map sector (LSN 1)
                    bcs       NF99

                    lbsr      WritRoot  build and write root directory FD and data sectors
                    bcs       NF99

                    lbsr      WritFree  zero all other (free) sectors
                    bcs       NF99

                    leax      Msg13,PC  formatting complete
                    lbsr      ShowMsg

* Exit.

NF90                clrb
                    bra       NF99
NF93                ldb       #E$BNam
NF99                os9       F$Exit

*--------------------------------------------------------------
* FUNCTION: DevcName
* PURPOSE: Extract the device name string from the parameter
*   line, verify this device exists and that it uses the correct
*   device driver.
*
* NOTES:
*
*  - Three different versions of the device name are needed.
*    DevNameA is used to store the address of the name string
*    in the parameter line (pointing to the '/' character).
*    The string is copied from the parameter line into DevNameS
*    and modified there, and into DevNameR and modified there:
*      parameter line:  "S0 "   - used by F$Link and I$Attach
*      DevNameR:       "/S0@CR" - used by I$Open
*      DevNameS:       "/S0" (sign bit) - used by ShowMsg
*
*  - The string in the parameter line must have a leading '/'
*    character, must be no more than 12 characters, and must not
*    have a trailing '@' character.
*
* IN: X  points to next character in parameter line to process
*     U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      X  incremented past last character of device name
* ERROR: CC.C  1 = error
*        B  error code
*        X  undefined
*--------------------------------------------------------------

DevcName            pshs      Y,B,A

* Find beginning of device name in parameter line.

                    lbsr      SkipSpac  skip leading spaces, CR found?
                    lbeq      DN95      .Y, error, no parameter found
                    cmpa      #PDELIM   starts with a '/'?
                    lbne      DN95      .N, error, first parameter must start with '/'

                    stx       DevNameA  .Y, save address of start of device name string

* Copy device name string from parameter line to variable DevNameS.

                    leay      DevNameS,U
                    ldb       #DevNameL loop count = length of DevNameS variable
DN20                lda       ,X+       get next character from parameter line
                    cmpa      #C$SPAC   space delimiter character?
                    beq       DN25      .Y, but don't copy, done
                    cmpa      #PENTIR   '@' raw mode character?
                    beq       DN95      .Y, not valid
                    cmpa      #C$CR     end-of-line delimiter character?
                    beq       DN95      .Y, not valid, only space allowed here
                    tstb                is DevNameS variable already full?
                    beq       DN95      .Y, error, device name too long
                    sta       ,Y+       .N, save in DevNameS
                    decb                decr. empty slots available in DevNameS
                    bra       DN20      process next character

DN25                leax      -1,X      back up to first delimiter character

                    lda       -1,Y      set sign bit of last character in DevNameS for use by ShowMsg
                    ora       #Sign
                    sta       -1,Y

* Copy device name string from parameter line to variable DevNameR.

                    pshs      X

                    ldx       DevNameA
                    leay      DevNameR,U
DN30                lda       ,X+       get next character from parameter line
                    cmpa      #C$SPAC   space delimiter character?
                    beq       DN35      .Y, but don't copy, done
                    sta       ,Y+       .N, save in DevNameR
                    bra       DN30

DN35                lda       #PENTIR   add '@' character for raw mode for use by I$Open
                    sta       ,Y+
                    lda       C$CR      add CR delimiter
                    sta       ,Y+

                    puls      X

* Attach device to system to allocate its static storage and initialize it.

                    pshs      U,X
                    clra                access mode = use device capabilities
                    ldx       DevNameA  get address of name string in parameter line
                    leax      1,X       skip past leading '/'
                    os9       I$Attach
                    stu       DevTablA  save address of device table entry
                    puls      X,U
                    bcs       DN97

* Verify device driver name is correct.

                    pshs      X
                    ldx       DevTablA  get address of device table entry
                    ldx       V$DRIV,X  get address of device driver module
                    ldd       M$Name,X  calculate address of module name in device driver
                    leay      D,X
                    leax      DrvrNam,PC address of expected driver name
                    ldb       #DrvrNamL
                    os9       F$CmpNam  do the strings match?
                    puls      X
                    bcc       DN90      .Y, OK

                    leax      Msg16,PC  .N, wrong device driver name
                    lbsr      ShowMsg
                    bra       DN95

* Return.

DN90                clrb                CC.C = 0 = OK
                    bra       DN99

DN95                ldb       #E$BNam
DN97                stb       1,S
                    comb                CC.C = 1 = error

DN99                puls      A,B,Y,PC

DrvrNam             fcs       "NVRAMdrv"
DrvrNamL            equ       *-DrvrNam

*--------------------------------------------------------------
* FUNCTION: VolName
* PURPOSE: Extract the volume name string from the parameter
*   line and copy it to DD.NAM in the sector buffer for LSN 0.
*
* NOTES:
*  - Before calling this function the sector buffer must be
*    cleared to all 00h values except for the DD.OPT field.
*  - The name string must be enclosed in " characters.  This
*    allows the string to contain embedded space characters.
*  - The string between the " characters must not be longer than
*    32 characters.
*
* IN: X  points to next character in parameter line to process
*     U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      X  incremented past trailing " characer
* ERROR: CC.C  1 = error
*        B  error code
*        X  undefined
*--------------------------------------------------------------

VolName             pshs      Y,B,A

VolNamL             set       SecBufr+DD.NAM-1 temporary field sharing DD.DAT

* Skip leading spaces.

                    lbsr      SkipSpac  skip leading spaces, CR found?
                    beq       VN95      .Y, error, end-of-line, no volume name parameter
                    cmpa      #'"       starts with " character?
                    bne       VN95      .N, error, second parameter must start with "

* Copy string.

                    clr       VolNamL   clear volume name string length to 0
                    ldb       #32       loop count = DD.NAM field length
                    leax      1,X       point past leading " character
                    leay      SecBufr+DD.NAM,U
VN20                lda       ,X+       get next character from parameter line
                    cmpa      #'"       trailing " found?
                    beq       VN30      .Y, done
                    tstb                .N, 32 characters already processed?
                    beq       VN95      . Y, error, name too long
                    sta       ,Y+       . N, save in DD.NAM
                    inc       VolNamL
                    decb                decr. characters left to copy
                    bra       VN20

* Set sign bit on last character.

VN30                lda       -1,Y
                    ora       #Sign
                    sta       -1,Y

* Return.

                    clrb                CC.C = 0 = OK
                    bra       VN99

VN95                ldb       #E$BNam
                    stb       1,S
                    comb                CC.C = 1 = error

VN99                puls      A,B,Y,PC

*--------------------------------------------------------------
* FUNCTION: NumCyls
* PURPOSE: Extract the optional number of cylinders value from
*   the parameter line as a decimal number.
*
* NOTES:
*  - Before calling this function you must open a path to the
*    device being formatted, clear the sector buffer to all 00h
*    values, and call the DevOpts and VolName functions.
*  - The cylinder string must be enclosed in ' characters and
*    contain only numeric digits, leading zeros are allowed,
*    the value should be 2..128, but not more than the device
*    descriptor value.
*  - If this parameter is omitted, the IT.CYL value in the device
*    descriptor is used.
*
* IN: X  points to next character in parameter line to process
*     U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      X  incremented past trailing ' characer
* ERROR: CC.C  1 = error
*        B  error code
*        X  undefined
*--------------------------------------------------------------

NumCyls             pshs      Y,B,A

* Set default value to device descriptor value.

                    ldd       SecBufr+DD.OPT+PD.CYL-PD.OPT
                    std       Cyls

* Skip leading spaces.

                    lbsr      SkipSpac  skip leading spaces, found CR?
                    bne       NC10      .N
                    ldd       Cyls      .Y, end-of-line, no cylinders parameter, use default
                    bra       NC32
NC10                cmpa      #''       does third parameter start with ' character?
                    bne       NC95      .N, error

* Extract and convert numeric string.

                    clrb                initialize 8-bit cylinder accumulator to 0
                    leax      1,X       point past leading ' character
NC20                lda       ,X+       get next character from parameter line
                    cmpa      #''       trailing ' found?
                    beq       NC30      .Y, done
                    cmpa      #'0       .N, is valid ASCII numeric digit 0..9?
                    blo       NC95      . N, error
                    cmpa      #'9
                    bhi       NC95      . N, error
                    suba      #'0       . Y, convert ASCII character to numeric value
                    pshs      A
                    lda       #10       multiply accumulator by 10 to shift previous digit left
                    mul
                    tsta                result fits into 8 bits?
                    bne       NC93      .N, overflow error
                    addb      ,S+       .Y, add value of next digit, result fits into 8 bits?
                    bcs       NC95      . N, overflow error
                    bra       NC20      . Y, process next character

* Check if value is within valid limits.

NC30                clra                convert 8-bit cylinder value to 16-bit
NC32                cmpd      #2        is value 2..128?
                    blo       NC95      .N, too small
                    cmpd      #128
                    bhi       NC95      .N, too large
                    cmpd      Cyls      is value less than or equal to device descriptor?
                    bhi       NC95      .N, larger, not allowed
                    std       Cyls      .Y, replace default

* Convert cylinders to total sectors (32..2048).

                    lda       #16
                    mul
                    std       SecBufr+DD.TOT+1
                    std       TotSecs

* Return.

                    clrb                CC.C = 0 = OK
                    bra       NC99

NC93                leas      1,S
NC95                ldb       #E$BNam
                    stb       1,S
                    comb                CC.C = 1 = error

NC99                puls      A,B,Y,PC

*--------------------------------------------------------------
* FUNCTION: DevOpts
* PURPOSE: Copy device options section of path descriptor to
*   DD.OPT in LSN 0 buffer.  Verify some of the values.
* NOTES:
*  - Before calling this function you must open a path to the
*    device being formatted, and clear the sector buffer to
*    all 00h values.
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------
*
DevOpts             pshs      X,B,A

* Copy device options section of path descriptor.

                    lda       DevPath
                    ldb       #SS.Opt   function code = get option section
                    leax      SecBufr+DD.OPT,U
                    os9       I$GetStt
                    bcs       DO95

* Check several device options for valid values.

                    lda       SecBufr+DD.OPT+PD.SID-PD.OPT number of sides should be 1
                    cmpa      #1
                    bne       DO70

                    ldd       SecBufr+DD.OPT+PD.SCT-PD.OPT sectors/track should be 16
                    cmpd      #16
                    bne       DO70

                    ldd       SecBufr+DD.OPT+PD.T0S-PD.OPT sectors/track0 should be 16
                    cmpd      #16
                    beq       DO90

DO70                leax      Msg15,PC  invalid device descriptor values
                    bsr       ShowMsg

                    ldb       #^E$BTyp
                    comb                CC.C = 1 - error
                    bra       DO95

* Return.

DO90                clrb                CC.C = 0 = OK
                    bra       DO99
DO95                stb       1,S
DO99                puls      A,B,X,PC

*--------------------------------------------------------------
* FUNCTION: InizBufr
* PURPOSE: Set all 256 bytes of sector buffer to specified value.
* IN: A  value to write to each byte
*     U,DP  address of process static storage
* OUT: CC.C/.Z  undefined
*--------------------------------------------------------------

InizBufr            pshs      X,B

                    clrb                loop count = 256 bytes
                    leax      SecBufr,U
ZB10                sta       ,X+
                    decb
                    bne       ZB10

                    puls      B,X,PC

*--------------------------------------------------------------
* FUNCTION: SkipSpac
* PURPOSE: Skip past space characters in parameter line, check
*   if at end-of-line.
* IN: X  points to next character in parameter line to process
*     U,DP  address of process static storage
* OUT: CC.Z  1/EQ = at end of line (CR character)
*            0/NE = other non-space character found
*      X  incremented to point to first non-space character
*      A  first non-space character found
*--------------------------------------------------------------

SkipSpac            equ       *

SS10                lda       ,X+       get next character from parameter line
                    cmpa      #C$SPAC   space?
                    beq       SS10      .Y, skip it
                    leax      -1,X      .N, back up to first non-space character
                    cmpa      #C$CR     end-of-line?

                    rts

*--------------------------------------------------------------
* FUNCTION: ShowMsg
* PURPOSE: Write the specified string to the console.
* NOTES:
*  - String must have sign bit set in last character.
*  - String length must not exceed size of MsgTxt buffer.
* IN: X  address of string
*     U,DP  address of process static storage
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

ShowMsg             pshs      Y,X,A

* Copy string to display buffer.

                    clr       MsgL+1
                    leay      MsgTxt,U
SM20                lda       0,X
                    anda      #^Sign    clear sign bit of character
                    sta       ,Y+
                    inc       MsgL+1
                    tst       ,X+       did character have sign bit set?
                    bpl       SM20      .N, not end of string, process next character

* Display buffer contents.

                    lda       #StdOut
                    leax      MsgTxt,U
                    ldy       MsgL
                    os9       I$Write

                    puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: AskReady
* PURPOSE: Display formatting details, then ask user whether or
*   not to proceed with formatting.
*
* NOTES:
*  - Several fields in the sector buffer must already have valid
*    before calling AskReady:  DD.TOT, DD.NAM, DD.OPT
*  - The Cyls field must already have a valid value.
*
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  0 = proceed, E$PrcAbt = abort
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

AskReady            pshs      Y,X,B,A

                    clr       ZeroSpac  display numbers left justified

* Display formatting parameters being used.

                    leax      Msg02,PC  format parameters header
                    bsr       ShowMsg

                    leax      Msg03,PC  device name
                    bsr       ShowMsg
                    leax      DevNameS,U device name string
                    bsr       ShowMsg

                    leax      Msg18,PC  device type
                    bsr       ShowMsg
                    lda       SecBufr+DD.OPT+PD.TYP-PD.OPT
                    bita      #TYPN.EEP EEPROM?
                    bne       AR20      .Y
                    leax      Msg19,PC  .N, 23LCV1024 SRAM
                    bra       AR29
AR20                bita      #TYPN.EE4 25CSM04?
                    bne       AR22      .Y
                    leax      Msg20,PC  .N, 25LC1024 EEPROM
                    bra       AR29
AR22                leax      Msg21,PC  25CSM04 EEPROM
AR29                bsr       ShowMsg

                    leax      Msg17,PC  driver
                    bsr       ShowMsg
                    leax      DrvrNam,PC driver name string
                    bsr       ShowMsg

                    leax      Msg04,PC  volume name
                    bsr       ShowMsg
                    leax      SecBufr+DD.NAM,U volume name string
                    bsr       ShowMsg

                    leax      Msg05,PC  cylinders
                    bsr       ShowMsg
                    ldd       Cyls      number of cylinders (2..128)
                    lbsr      ShowDec4

                    leax      Msg06,PC  sides
                    lbsr      ShowMsg

                    leax      Msg07,PC  sectors/track
                    lbsr      ShowMsg

                    leax      Msg08,PC  total sectors
                    lbsr      ShowMsg
                    ldd       SecBufr+DD.TOT+1 total sectors (32..2048)
                    lbsr      ShowDec4

                    leax      Msg09,PC  capacity
                    lbsr      ShowMsg
                    ldb       Cyls+1    calculate capacity in KB (8..512)
                    lda       #4
                    mul
                    lbsr      ShowDec4
                    leax      Msg10,PC  KB
                    lbsr      ShowMsg

* Prompt user for response, get response, validate.

AR60                leax      Msg11,PC  proceed to format device? Y/N/Q
                    lbsr      ShowMsg

                    lda       #StdIn    input response character from user
                    leax      Temp1,U
                    ldy       #1
                    os9       I$Read
                    bcs       AR99

                    lda       Temp1
                    anda      #$5F      convert to uppercase

                    cmpa      #'N
                    beq       AR95      .abort
                    cmpa      #'Q
                    beq       AR95      .abort
                    cmpa      #'Y
                    bne       AR60      .invalid response, repeat prompt

                    leax      Msg12,PC  formatting ...
                    lbsr      ShowMsg

* Return.

                    clrb                return code = proceed
                    bra       AR97

AR95                leax      Msg14,PC  formatting aborted
                    lbsr      ShowMsg
                    ldb       #E$PrcAbt return code = abort
AR97                stb       1,S
                    clrb                CC.C = 0 = OK

AR99                puls      A,B,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: WritVID
* PURPOSE: Finish building the Volume Identification Sector,
*   write it to LSN 0, then read it back to update the drive
*   table in the driver.
*
* NOTES:
*
*  - The device must already be open for raw writes, and the
*    file position must already be at the beginning of LSN 0.
*
*  - Before calling WritVID the TotSecs variable must already
*    have a valid value, the sector buffer cleared to all 00h
*    values, and these fields in the sector buffer must already
*    have valid values:  DD.TOT, DD.NAM, DD.OPT
*
*  - Limit of 128 cylinders @ 16 sectors/track = 2048 sectors =
*    2048 bits = 256 bytes, which allows the Disk Allocation bit
*    Map to fit in one sector with cluster size = 1.
*
*  - F$Time writes 6 bytes into a 5-byte field, so overwrites
*    the first character of the volume name, which is why we
*    need to save/restore that character.
*
*  - Since the NVRAM/RTC board doesn't have removeable media,
*    having a truly random value in DD.DSK isn't as important.
*
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  undefined
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

WritVID             pshs      Y,X,A

* Fill in DD.TKS, DD.SPT, DD.ATT, DD.OWN fields.

                    ldd       #16       always 16 sectors/track for serial NVRAM-Disks
                    stb       SecBufr+DD.TKS
                    std       SecBufr+DD.SPT

                    lda       #CAP.ALL  disk capability attributes = all
                    sta       SecBufr+DD.ATT

                    ldd       UserID
                    std       SecBufr+DD.OWN

* Fill in DD.MAP, DD.BIT, DD.DIR fields.

                    ldd       TotSecs   number of bits = total number of sectors on media
                    addd      #7        round up to nearest 8 boundary
                    lsra                divide by 8 (8 bits/byte)
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    std       SecBufr+DD.MAP number of bytes used in allocation map

                    lda       #1        1 sector/cluster
                    sta       SecBufr+DD.BIT+1

                    ldb       #2        root directory FD sector is LSN 2 (map only uses LSN 1)
                    stb       SecBufr+DD.DIR+2

* Get date/time of creation of volume.

                    lda       SecBufr+DD.NAM+0 save first character of volume name

                    leax      SecBufr+DD.DAT,U date/time of creation (YMDhms)
                    os9       F$Time
                    bcs       WS99

                    sta       SecBufr+DD.NAM+0 restore first character of volume name

* Fill in DD.DSK field with pseudo-random number.

                    ldd       SecBufr+DD.DAT+1
                    addd      SecBufr+DD.DAT+3
                    addd      SecBufr+DD.TOT+1
                    addd      SecBufr+DD.NAM+0
                    std       SecBufr+DD.DSK

* Write Volume Identification Sector data to LSN 0.
* This also updates drive table entry.

                    ldd       #0-1
                    std       WritLSN

                    bsr       WritBufr

WS99                puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: WritDAM
* PURPOSE: Build the Disk Allocation bit Map in the sector buffer,
*   then write it to LSN 1.
*
* NOTES:
*  - The file position must already be at the beginning of LSN 1.
*  - Limit of 128 cylinders @ 16 sectors/track = 2048 sectors =
*    2048 bits = 256 bytes, which allows the Disk Allocation bit
*    Map to fit in one sector with cluster size = 1.
*  - Since each cylinder has exactly 16 sectors, those 16 bits
*    in the bit map are exactly 2 bytes on byte boundaries, so
*    we can update the map without using F$DelBit and F$AllBit.
*  - Root directory assumed to be created with only 1 data sector.
*
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  always 0
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

WritDAM             pshs      X,A

* Initialize entire bit map buffer to allocated/non-existent.

                    lda       #$FF
                    lbsr      InizBufr

* Clear bits for all sectors present on media.

                    ldb       Cyls+1    loop count = number of cylinders
                    leax      SecBufr+0,U start at LSN 0
WD20                clr       ,X+       16 bits (sectors) per cylinder
                    clr       ,X+
                    decb                all cylinders processed?
                    bne       WD20      .N, process next

* Set bits for sectors allocated to VID, DAM, root directory FD and data.

                    lda       SecBufr+0 LSN 0..7
                    ora       #$F0      LSN 0..3
                    sta       SecBufr+0

* Write sector buffer containing bit map to LSN 1.

                    bsr       WritBufr

                    puls      A,X,PC

*--------------------------------------------------------------
* FUNCTION: WritBufr
* PURPOSE: Write the 256-byte sector buffer to disk at the
*   specified LSN, and increment the LSN.
* NOTES: Uses IRSetStt/SS.DWrit Direct Sector Write.
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

WritBufr            pshs      Y,X,B,A

* Write the buffer contents to the device using a direct sector write.

                    lda       DevPath
                    ldb       #SS.DWrit
                    ldx       WritLSN   get previous LSN
                    leax      1,X
                    stx       WritLSN   save new/current LSN
                    leay      SecBufr,U
                    os9       I$SetStt
                    bcc       WB99

                    stb       1,S
WB99                puls      A,B,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: WritRoot
* PURPOSE: Build the root directory File Descriptor in the sector
*   buffer, write it to LSN 2, then build the root directory data
*   in the sector buffer, write it to LSN 3.
* NOTES: The root directory is only allocated 1 data sector.
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  undefined
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

WritRoot            pshs      Y,X,A

* ----- Build and write root directory FD sector.

                    clra
                    lbsr      InizBufr

* Fill in FD.DAT, FD.LNK, FD.Creat.

                    leax      SecBufr+FD.DAT,U date/time last modified (YMDhms)
                    os9       F$Time
                    bcs       WR99

                    lda       #1        link count = 1
                    sta       SecBufr+FD.LNK

                    lda       SecBufr+FD.DAT+0 copy YMD from date modified to date created
                    sta       SecBufr+FD.Creat+0
                    ldd       SecBufr+FD.DAT+1
                    std       SecBufr+FD.Creat+1

* Fill in FD.ATT, FD.OWN. FD.SIZ.

                    lda       #CAP.ALL-SHARE.
                    sta       SecBufr+FD.ATT

                    ldd       UserID
                    std       SecBufr+FD.OWN

                    lda       #DIR.SZ*2
                    sta       SecBufr+FD.SIZ+3

* Fill in FD.SEG for first (and only) segment.

                    lda       #3        LSN 3
                    sta       SecBufr+FD.SEG+FDSL.A+2
                    lda       #1        1 data sector
                    sta       SecBufr+FD.SEG+FDSL.B+1

* Write FD sector to LSN 2.

                    bsr       WritBufr
                    bcs       WR99

* ----- Build and write root directory data sector.

                    clra
                    lbsr      InizBufr

* Fill in anonymous name for parent directory.

                    ldd       #$2EAE    name is ".."
                    std       SecBufr+(DIR.SZ*0)+DIR.NM+0
                    lda       #2        LSN 2
                    sta       SecBufr+(DIR.SZ*0)+DIR.FD+2

* Fill in anonymous name for self.

                    lda       #$AE      name is "."
                    sta       SecBufr+(DIR.SZ*1)+DIR.NM+0
                    lda       #2        LSN 2
                    sta       SecBufr+(DIR.SZ*1)+DIR.FD+2

* Write data sector to LSN 3.

                    bsr       WritBufr

WR99                puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: WritFree
* PURPOSE: Write zeros to all other (free) sectors.
* NOTES:
*  - In test configuration writes the LSN to the first byte of
*    each of the 252 free sectors for verification purposes.
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  undefined
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

WritFree            pshs      Y,X,A

* Initialize.

                    ldd       TotSecs   loop count is number of sectors to write
                    subd      #4        LSN 0..3 already written
                    pshs      D

                    clra                all bytes in free sectors have 00h values
                    lbsr      InizBufr

* Loop to write all sectors.

WF20                bsr       WritBufr
                    bcs       WF99

                    ldd       0,S       all sectors written?
                    subd      #1
                    std       0,S
                    bne       WF20      .N, write next

* Return.

                    clrb
WF99                leas      2,S
                    puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: ShowDec4
* PURPOSE: Write an unsigned 16-bit binary value to the console
*   as a 4-digit decimal number, with leading zeros suppressed.
* NOTES:
*  - ZeroSpace determines whether to align the numbers to the
*    left or right (leading zeros discarded vs. replaced with
*    spaces).
*  - If the value is greater than 9999, the most significant
*    digit will not be displayed (will be truncated to least
*    significant 4 digits).
* IN: D  unsigned 16-bit binary value to display (0..9999)
*     U,DP  address of process static storage
* OUT: CC.C  undefined
*--------------------------------------------------------------

ShowDec4            pshs      X,B,A

* Convert 16-bit binary value to 6-digit packed BCD value.

                    bsr       BINBCD6

* Display 4-digit packed BCD value to console.

                    bsr       ShowBCD4

                    puls      A,B,X,PC

*--------------------------------------------------------------
* FUNCTION: ShowBCD4
* PURPOSE: Write an unsigned 4-digit packed BCD number to the
*   console, with leading zeros suppressed.
* NOTES:
*  - ZeroSpace determines whether to align the numbers to the
*    left or right (leading zeros discarded vs. replaced with
*    spaces).
*  - Any error returned by I$Write is ignored.
* IN: X  unsigned 4-digit packed BCD number (0000..9999)
*     U,DP  address of process static storage
* OUT: A,B,CC.C  undefined
*--------------------------------------------------------------

ShowBCD4            equ       *

                    lda       #3        number of leading zero digits to suppress (3 of 4)
                    sta       ZeroSupr

                    tfr       X,D

                    bsr       ShowBCD2  process upper byte

                    tfr       B,A       process lower byte

* Display two BCD digits from Reg A.

ShowBCD2            pshs      A

                    lsra                process upper nybble
                    lsra
                    lsra
                    lsra
                    bsr       ShowBCD1

                    puls      A         process lower nybble
                    anda      #$0F

* Display one BCD digit from Reg A (upper 4 bits must be 0).

ShowBCD1            pshs      Y,X,B

                    tst       ZeroSupr  is '0' digit suppression still enabled?
                    beq       SB22      .N, print digit
                    dec       ZeroSupr  .Y, decrement number of '0' digits to suppress
                    tsta                is value to display zero?
                    bne       SB20      .N, print digit, disable suppression
                    tst       ZeroSpac  .Y, replace zero with space (right justify)?
                    beq       SB99      . N, don't display
                    lda       #C$SPAC   . Y, display space
                    bra       SB24
SB20                clr       ZeroSupr  disable suppression
SB22                adda      #'0       convert binary value to ASCII character
SB24                sta       Temp1

                    lda       #StdOut   write one ASCII digit to console
                    leax      Temp1,U
                    ldy       #1
                    os9       I$Write

SB99                puls      B,X,Y,PC

*--------------------------------------------------------------
* Dummy signal intercept routine.
*--------------------------------------------------------------

Intrcpt             rti

* Include functions from source code libraries.

MathCvrt            set       %10000000000 BINBCD6
*        use   /DD/SRCLIB/mathcvrt.asm

LibBegin            set       *         start of generated code from mathcvrt.asm

*------------------------------------------------------------------------
* FUNCTION: BINBCD6
* PURPOSE: Convert an unsigned 16-bit binary number into an unsigned
*   6-digit BCD decimal number.
*
* NOTES:
*  - Uses an algorithm that does not use a table (like that found in the
*    6800 Cookbook), but processes each BCD digit separately to compare
*    to 5 and add 3 then shift left, as found in:
*      https://my.eng.utah.edu/~nmcdonal/Tutorials/BCDTutorial/BCDConversion.html
*  - Refer to copyright and licensing information in mathcvrt.asm.
*
* IN: D  unsigned 16-bit binary number (0..65535, big-endian)
* OUT: B:X  unsigned 6-digit packed BCD result (0..065535, big-endian)
*      A,CC.C  undefined
*------------------------------------------------------------------------

BINBCD6             equ       *

* Initialize.

                    leas      -5,S      allocate room for bit and byte counts and BCD result
                    pshs      D         push binary input value

BIN                 set       0         16-bit binary number, offset (0..1) from Reg S
BIT                 set       2         loop counter for bit shifts, offset (2) from Reg S
BYT                 set       3         loop counter for BCD bytes, offset (3) from Reg S
BCD                 set       4         6-digit BCD number, offset (4..6) from Reg S

                    clra                clear BCD number accumulator to 0
                    clrb
                    sta       BCD+0,S
                    std       BCD+1,S

* Loop to process each binary bit.

                    lda       #16       count of binary bits to process
                    sta       BIT,S

CVB210              equ       *

* Loop to process each BCD digit.

                    leax      BCD+2+1,S start with LSB of BCD number

                    lda       #6/2      count of BCD bytes to process
                    sta       BYT,S

CVB220              equ       *

                    lda       ,-X       get next BCD byte (2 digits)

                    tfr       A,B       is lower digit in byte >= 5?
                    andb      #$0F
                    cmpb      #$05
                    blo       CVB230    .N
                    adda      #$03      .Y, add 3

CVB230              tfr       A,B       is upper digit in byte >= 5?
                    andb      #$F0
                    cmpb      #$50
                    blo       CVB240    .N
                    adda      #$30      .Y, add 3

CVB240              sta       0,X       save processed BCD byte (2 digits)

                    dec       BYT,S     all BCD bytes processed this cycle?
                    bne       CVB220    .N, process next BCD byte

                    asl       BIN+1,S   .Y, shift BIN left 1 bit position (and into BCD lsb)
                    rol       BIN+0,S
                    rol       BCD+2,S   shift BCD left 1 bit position
                    rol       BCD+1,S
                    rol       BCD+0,S

                    dec       BIT,S     all bit shifts processed?
                    bne       CVB210    .N, process next bit cycle

* Done, exit.

CVB299              leas      4,S       discard binary input and bit and byte counters
                    puls      B,X,PC    pull BCD result, return

LibSize             set       *-LibBegin size of generated code from mathcvrt.asm

*--------------------------------------------------------------
* Message strings.
*
* NOTES:
*  - The last character of each message string must have its
*    sign bit set, as required by the ShowMsg function.
*--------------------------------------------------------------

Msg01               fcb       C$CR,C$LF
                    fcc       "NVFormat - Format NVRAM-Disk partition."
                    fcb       C$CR,C$LF+Sign

Msg02               fcb       C$CR,C$LF
                    fcs       "Formatting parameters:"

Msg03               fcb       C$CR,C$LF
                    fcs       " device:        "

Msg04               fcb       C$CR,C$LF
                    fcs       " volume name:   "

Msg05               fcb       C$CR,C$LF
                    fcs       " cylinders:     "

Msg06               fcb       C$CR,C$LF
                    fcs       " sides:         1"

Msg07               fcb       C$CR,C$LF
                    fcs       " sectors/track: 16"

Msg08               fcb       C$CR,C$LF
                    fcs       " total sectors: "

Msg09               fcb       C$CR,C$LF
                    fcs       " capacity:      "

Msg10               fcs       "KB"

Msg11               fcb       C$CR,C$LF,C$CR,C$LF
                    fcc       "Proceed to format device?"
                    fcb       C$CR,C$LF
                    fcs       " Y (yes), N (no), Q (quit): "

Msg12               fcb       C$CR,C$LF,C$CR,C$LF
                    fcs       "formatting ... "

Msg13               fcb       C$CR,C$LF
                    fcc       "Formatting completed."
                    fcb       C$CR,C$LF+Sign

Msg14               fcb       C$CR,C$LF
                    fcc       "Formatting aborted."
                    fcb       C$CR,C$LF+Sign

Msg15               fcb       C$CR,C$LF
                    fcc       "Device descriptor has invalid values"
                    fcb       C$CR,C$LF
                    fcc       " for IT.SID or IT.SCT or IT.T0S."
                    fcb       C$CR,C$LF
                    fcc       " Specify a valid NVRAM/RTC device."
                    fcb       C$CR,C$LF+Sign

Msg16               fcb       C$CR,C$LF
                    fcc       "Device driver name for specified device isn't 'NVRAMdrv'."
                    fcb       C$CR,C$LF+Sign

Msg17               fcb       C$CR,C$LF
                    fcs       " driver:        "

Msg18               fcb       C$CR,C$LF
                    fcs       " type:          "

Msg19               fcs       "23LCV1024 SRAM"

Msg20               fcs       "25LC1024 EEPROM"

Msg21               fcs       "25CSM04 EEPROM"

                    emod
ModSiz              equ       *

                    end
