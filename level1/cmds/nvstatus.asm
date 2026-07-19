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
* FILES: nvstatus.asm / NVStatus
*
* PURPOSE: Check all the sectors in an OS-9 partition in a 25CSM04 EEPROM on
*          the NVRAM/RTC board connected to port B of the ST-2900 FDC board,
*          for errors that needed correcting by the built-in ECC logic.
*
* NOTES:
*
*  - When the 25CSM04 Read Status Register command is issued after a Read Data
*    command, it indicates whether any data accessed by that Read Data command
*    had any errors that the ECC logic needed to correct.  It can correct one
*    bit for each group of four bytes.
*
* Refer to copyright and licensing information at the end of this file.
*
* Initial version created 2022-Jan-04 by David C. Wiens, with code borrowed
*  from nvwipe77o.asm and nvformat.asm.
* Last modified 2022-Feb-18 22:44 PST by David C. Wiens.
*----------------------------------------------------------------------------

                    nam       NVStatus
                    ttl       Check the OS-9 partition in a 25CSM04 EEPROM for errors.
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

                    org       0
ModAddr             rmb       2         absolute address of device descriptor module
DevPath             rmb       1         path number for device being wiped
TotSecs             rmb       3         total number of sectors on media (32..2048)
LSN                 rmb       2         logical sector number of current sector being processed
ZeroSupr            rmb       1         3..1 = number of leading 0 digits to suppress, 0 = print '0'
ZeroSpac            rmb       1         non-zero = replace 0 with space, zero = don't display space
Temp1               rmb       1         temporary 1-byte work area
EEStatus            rmb       2         25CSM04 EEPROM 16-bit status register value
EEok                rmb       2         number of sectors with no ECC error
EEerror             rmb       2         number of sectors with an ECC error
MsgL                rmb       2         length of MsgTxt string (1..128)
MsgTxt              rmb       128       message string buffer
SecBufr             rmb       256       buffer for one 256-byte sector
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

ModNam              fcs       "NVStatus" program module name
                    fcb       Edition   module edition
                    fcb       W.ClkTks+W.Ndsk+W.Nrtc configuration
Copywrit            fcc       "cDCW"

StdIn               set       0
StdOut              set       1

*--------------------------------------------------------------
* Dummy signal intercept routine.
*--------------------------------------------------------------

Intrcpt             rti

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

* Install dummy signal intercept routine and set process priority.

                    leax      <Intrcpt,PC
                    os9       F$Icpt

                    os9       F$ID      get Process ID and User ID

                    ldb       #128      default priority (midway between 0 and 255)
                    os9       F$SPrior

* Display program name.

                    clr       MsgL+0

                    leax      Msg01,PC  NVStatus - check 25CSM04 EEPROM for errors
                    lbsr      ShowMsg

* Verify device descriptor options, open path to device.

                    bsr       Device
                    bcs       NS99

* Display details, ask user to confirm to proceed.

                    lbsr      AskReady
                    bcs       NS99
                    cmpb      #E$PrcAbt user requested abort?
                    beq       NS90      .Y, exit

* Perform the status checking process, report results.

                    lbsr      ChkStat
                    bcs       NS99

* Exit.

NS90                clrb
                    bra       NS99

NS93                ldb       #E$BNam

NS99                os9       F$Exit

*--------------------------------------------------------------
* Device and driver strings.
*--------------------------------------------------------------

ModulNam            fcs       "E0 "
PathName            fcc       "/E0@"
                    fcb       C$CR

DrvrNam             fcs       "NVRAMdrv"
DrvrNamL            equ       *-DrvrNam

*--------------------------------------------------------------
* FUNCTION: Device
* PURPOSE: Verify the device exists, that it uses the correct
*   device driver, and the descriptor has the correct settings,
*   then open a path to it in "raw" mode.
*
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  always 0
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

Device              pshs      Y,X,A

* Link to device descriptor memory module.

                    pshs      U
                    lda       #Devic+Objct
                    leax      <ModulNam,PC
                    os9       F$Link
                    tfr       U,Y       module header absolute address
                    stu       ModAddr
                    puls      U
                    lbcs      DV99      .module not found

* Verify device driver name in device descriptor is correct.

                    ldd       M$PDev,Y
                    leay      D,Y
                    leax      <DrvrNam,PC
                    ldb       #DrvrNamL
                    os9       F$CmpNam  do the strings match?
                    bcs       DV93      .N

* Verify other device descriptor fields are correct.

                    ldx       ModAddr

                    lda       M$DTyp+(PD.TYP-PD.DTP),X verify IT.TYP (device type)
                    anda      #TYP.NVRM+TYPN.EEP+TYPN.EE4 is 25CSM04 EEPROM?
                    cmpa      #TYP.NVRM+TYPN.EEP+TYPN.EE4
                    bne       DV91      .N, error

                    ldd       M$DTyp+(PD.CYL-PD.DTP),X verify IT.CYL (cylinders)
                    cmpd      #16
                    beq       DV20
                    cmpd      #128
                    bne       DV95

DV20                lda       M$DTyp+(PD.SID-PD.DTP),X verify IT.SID (sides)
                    cmpa      #1
                    bne       DV95

                    ldd       M$DTyp+(PD.SCT-PD.DTP),X verify IT.SCT (sectors/track)
                    cmpd      #16
                    bne       DV95

                    ldd       M$DTyp+(PD.T0S-PD.DTP),X verify IT.T0S (sectors/track 0)
                    cmpd      #16
                    bne       DV95

* Open device in "raw" mode.

                    lda       #READ.    open device for read-only
                    leax      <PathName,PC
                    os9       I$Open
                    bcs       DV99

                    sta       DevPath   save path number

* Read DD.TOT from LSN 0 into variable TotSecs and validate.

                    leax      TotSecs,U
                    ldy       #3
                    os9       I$Read
                    bcs       DV99

                    tst       TotSecs+0
                    bne       DV89
                    ldd       TotSecs+1
                    cmpd      #128*16
                    bhi       DV89

* Seek back to file position 0.

                    clra
                    clrb
                    tfr       D,X
                    pshs      U
                    tfr       D,U
                    lda       DevPath
                    os9       I$Seek
                    puls      U
                    bcs       DV99

* Display error messages, return.

                    clrb
                    bra       DV99

DV89                leax      Msg16,PC  DD.TOT too large
                    bsr       ShowMsg
                    ldb       #^E$Sect
                    bra       DV97

DV91                leax      Msg11,PC  not 25CSM04 EEPROM
                    bra       DV96

DV93                leax      Msg10,PC  wrong device driver name
                    bsr       ShowMsg
                    ldb       #^E$BNam
                    bra       DV97

DV95                leax      Msg09,PC  invalid device descriptor value
DV96                bsr       ShowMsg
                    ldb       #^E$BTyp
DV97                comb

DV99                puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: ShowMsg
* PURPOSE: Write the specified string to the console.
*
* NOTES:
*  - String must have sign bit set in last character.
*  - String length must not exceed size of MsgTxt buffer.
*
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
                    bpl       SM20      .N, not end of string, process next

* Display buffer contents.

                    lda       #StdOut
                    leax      MsgTxt,U
                    ldy       MsgL
                    os9       I$Write

                    puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: AskReady
* PURPOSE: Display status checking details, then ask user whether
*   or not to proceed with checking status.
*
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  0 = proceed, E$PrcAbt = abort
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

AskReady            pshs      Y,X,B,A

                    clr       ZeroSpac  display numbers left justified

* Display status checking parameters being used.

                    leax      Msg02,PC  status checking parameters header
                    bsr       ShowMsg

                    leax      Msg03,PC  device name
                    bsr       ShowMsg
                    leax      ModulNam,PC device module name string
                    bsr       ShowMsg

                    leax      Msg04,PC  total sectors
                    bsr       ShowMsg
                    ldd       TotSecs+1 total sectors (32..2048)
                    lbsr      ShowDec4

* Prompt user for response, get response, validate.

AR60                leax      Msg05,PC  proceed to check status of device? Y/N/Q
                    bsr       ShowMsg

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

                    leax      Msg06,PC  checking status ...
                    bsr       ShowMsg

* Return.

                    clrb                error code = proceed
                    bra       AR97

AR95                leax      Msg08,PC  status checking aborted
                    bsr       ShowMsg
                    ldb       #E$PrcAbt error code = abort
AR97                stb       1,S
                    clrb                CC.C = 0

AR99                puls      A,B,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: ChkStat
* PURPOSE: Read each sector in the partition, checking the EEPROM
*   ECC status after each read.
*
* IN: U,DP  address of process static storage
* OUT: CC.C  0 = OK
*      B  always 0
* ERROR: CC.C  1 = error
*        B  error code
*--------------------------------------------------------------

ChkStat             pshs      Y,X,A

* Initialize.

                    clra                clear starting LSN and status count accumulators
                    clrb
                    std       LSN
                    std       EEok
                    std       EEerror

                    ldd       TotSecs+1 count is number of sectors to read/check
                    pshs      D

* Loop to read data and status for each sector in partition.

CS20                equ       *

* Read next sector.

                    lda       DevPath
                    leax      SecBufr,U
                    ldy       #256
                    os9       I$Read
                    bcs       CS97

                    cmpy      #256
                    beq       CS30
                    ldb       #^E$Read
                    comb
                    bra       CS97

* Read ECC status of sector just read.

CS30                lda       DevPath
                    ldb       #SS.Stat4 function code = read 25CSM04 status register
                    leax      EEStatus,U
                    os9       I$GetStt
                    bcs       CS97

* Update totals based on received status.

                    lda       EEStatus+1 get second byte of status register
                    bita      #$40      is ECS bit set?
                    bne       CS40      .Y, one or more errors required correcting

                    ldd       EEok      .N, no errors
                    addd      #1
                    std       EEok
                    bra       CS45

CS40                ldd       EEerror
                    addd      #1
                    std       EEerror

                    ldd       LSN       display LSN of sector that had error(s)
                    bsr       ShowDec4
                    leax      Msg18,PC  display 2 spaces for gap between LSN values
                    lbsr      ShowMsg

* All sectors checked?

CS45                ldd       LSN       increment LSN
                    addd      #1
                    std       LSN

                    ldd       0,S       all sectors checked?
                    subd      #1
                    std       0,S
                    bne       CS20      .N, check next

* Display results of checking.

                    inc       ZeroSpac  display numbers right-justified

                    leax      Msg07,PC  status checking complete
                    lbsr      ShowMsg

                    leax      Msg12,PC  sector status summary
                    lbsr      ShowMsg

                    leax      Msg13,PC  number of sectors OK
                    lbsr      ShowMsg
                    ldd       EEok
                    bsr       ShowDec4

                    leax      Msg14,PC  number of sectors with errors
                    lbsr      ShowMsg
                    ldd       EEerror
                    bsr       ShowDec4

                    leax      Msg17,PC  CR/LF
                    lbsr      ShowMsg

* Return.

                    clrb
CS97                leas      2,S
                    puls      A,X,Y,PC

*--------------------------------------------------------------
* FUNCTION: ShowDec4
* PURPOSE: Write an unsigned 16-bit binary value to the console
*   as a 4-digit decimal number, with leading zeros suppressed
*   or replaced with space characters.
*
* NOTES:
*  - ZeroSpace determines whether to align the numbers to the
*    left or right.
*  - If the value is greater than 9999, the most significant
*    digit will not be displayed (will be truncated to least
*    significant 4 digits).
*
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
*   console, with leading zeros suppressed or replaced with
*   space characters.
*
* NOTES:
*  - ZeroSpace determines whether to align the numbers to the
*    left or right.
*  - Any error returned by I$Write is ignored.
*
* IN: X  unsigned 4-digit packed BCD number (0000..9999)
*     U,DP  address of process static storage
* OUT: A,B,CC.C  undefined
*--------------------------------------------------------------

ShowBCD4            equ       *

                    lda       #3        number of leading zero digits to suppress
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
                    fcc       "NVStatus - Check ECC status of 25CSM04 EEPROM contents."
                    fcb       C$CR,C$LF+Sign

Msg02               fcb       C$CR,C$LF
                    fcs       "Status parameters:"

Msg03               fcb       C$CR,C$LF
                    fcs       " device:        "

Msg04               fcb       C$CR,C$LF
                    fcs       " total sectors: "

Msg05               fcb       C$CR,C$LF,C$CR,C$LF
                    fcc       "Proceed to check status of device?"
                    fcb       C$CR,C$LF
                    fcs       " Y (yes), N (no), Q (quit): "

Msg06               fcb       C$CR,C$LF,C$CR,C$LF
                    fcs       "checking status ...   "

Msg07               fcb       C$CR,C$LF
                    fcs       "Status checking completed."

Msg08               fcb       C$CR,C$LF
                    fcc       "Status checking aborted."
                    fcb       C$CR,C$LF+Sign

Msg09               fcb       C$CR,C$LF
                    fcc       "Device descriptor has invalid value for"
                    fcb       C$CR,C$LF
                    fcc       " IT.CYL or IT.SID or IT.SCT or IT.T0S."
                    fcb       C$CR,C$LF+Sign

Msg10               fcb       C$CR,C$LF
                    fcc       "Device driver name for specified device isn't 'NVRAMdrv'."
                    fcb       C$CR,C$LF+Sign

Msg11               fcb       C$CR,C$LF
                    fcc       "Device descriptor IT.TYP isn't for 25CSM04 EEPROM."
                    fcb       C$CR,C$LF+Sign

Msg12               fcb       C$CR,C$LF
                    fcs       "Sector status summary:"

Msg13               fcb       C$CR,C$LF
                    fcs       "     OK: "

Msg14               fcb       C$CR,C$LF
                    fcs       " errors: "

Msg15               fcb       C$CR,C$LF
                    fcc       "Not supported when 'W.Ndsk set W.N25LC1' in st29set."
                    fcb       C$CR,C$LF+Sign

Msg16               fcb       C$CR,C$LF
                    fcc       "DD.TOT in LSN 0 is too large."
                    fcb       C$CR,C$LF+Sign

Msg17               fcb       C$CR,C$LF+Sign

Msg18               fcs       "  "

                    emod
ModSiz              equ       *

                    end
