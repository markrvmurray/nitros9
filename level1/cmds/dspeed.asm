****************************************
*
*  DISK DRIVE DIAGNOSTIC ROUTINES
*        "DSPEED"
*    (c) 1984 by David C. Wiens
* Affects the clock because interrupts are
*  disabled up to several seconds.
*
* <<< DO NOT RUN IF ANY OTHER TASK IS USING
*  THE DISK DRIVES <<<<
*
* COMMANDS:
*   H - Start drive motors to allow manually
*       timing motor-on hold time
*   D - Measure and display delay between
*       motor-on signal and "ready" signal
*   S d - Display rotational speed of drive "d"
*   Q - Quit and return to OS-9
*
* Last modified June 19, 1985 10:55 pm
****************************************
                  IFP1
                    use       defsfile
                  ENDC

*
* OS-9 EQUATES
*
STDIN               equ       0
STDOUT              equ       1

*
* DATA AREA
*
                    org       0
COUNT               rmb       1
ERFLG               rmb       1
ECHSAV              rmb       1
DRIVE               rmb       1
OPXSAV              rmb       1
SCFOPT              rmb       32
                    rmb       218
DatSiz              equ       .

*********************************
* MODULE HEADER
*********************************
TyLg                set       Prgrm+Objct
AtRv                set       ReEnt+Rev
Rev                 set       1
Edition             set       25
                    mod       EndChk,NamChk,$11,$81,DCheck,DatSiz

NamChk              fcs       'Dspeed'

MSG1                fcc       'ENTER COMMAND - '
                    fcb       C$RPRT
MSG2                fcc       '*NOT READY'
                    fcb       C$RPRT
MSG3                fcc       '*TIME-OUT ERROR'
                    fcb       C$RPRT
MSG4                fcc       '*INVALID NUMBER'
                    fcb       C$RPRT
MSG5                fcc       ' MSEC'
                    fcb       C$RPRT
MSG6                fcc       ' '
                    fcb       C$RPRT
MSG7                fcb       C$BSP,C$BSP,C$BSP,C$BSP,C$BSP,C$BSP,C$RPRT
MSG8                fcb       C$CR,C$LF,C$RPRT

                    setdp     $00       <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
********************************************
*
*   M A I N    L O G I C
*
*******************************************
ERROR               lda       #'?
                    lbsr      OUTCH
                    bcs       DT06

DCheck              leax      <MSG1,PCR
                    lbsr      PSTRNG
                    bcs       DT06
                    lbsr      INCHE     INPUT OPTION CODE
                    bcs       DT06
                    cmpa      #'Q
                    bne       DT10

                    clrb
DT06                os9       F$EXIT

DT10                cmpa      #'S       MOTOR SPEED
                    lbeq      MOTORS
                    cmpa      #'H       MOTOR-ON HOLD
                    lbeq      MOTORH
                    cmpa      #'D       READY DELAY
                    lbeq      MOTORD
                    bra       ERROR
*
* MOTORH/MOTORS/MOTORD ROUTINES RETURN HERE
*
RETURN              bcc       DCHECK
                    leax      <MSG2,PCR
                    cmpb      #F.NOT.RDY
                    beq       DT90
                    leax      <MSG3,PCR
                    cmpb      #F.TIME.OUT
                    beq       DT90
                    leax      <MSG4,PCR
                    cmpb      #F.NUM.ERR
                    beq       DT90
                    cmpb      #$FF
                    beq       ERROR
                    bra       DT06

DT90                lbsr      PSTRNG
                    bcs       DT06
                    bra       DCHECK

*********************************
*
* START DRIVE MOTOR TO TIME DURATION OF "ON"
* IN - NONE
* OUT - A,B UNDEFINED
*       X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (F.NOT.RDY)
*********************************
MOTORH              clrb
                    lda       WDSTAT
                    bmi       MH90      "NOT READY" = OK
                    comb
                    ldb       #F.NOT.RDY
MH90                lbra      RETURN

*****************************************
*
* TIME THE DELAY FROM THE MOTOR-ON SIGNAL
*  TO THE DRIVE-READY SIGNAL
* TIMING IN SOFTWARE LOOP BASED ON
*  EXACTLY 1 MHZ CLOCK.
* IN - NONE
* OUT - A,B,X UNDEFINED
*       Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9, F.NOT.RDY, F.TIME.OUT, F.NUM.ERR)
*****************************************
MOTORD              pshs      CC        DISABLE INTERRUPTS
                    orcc      #IntMasks
                    nop
                    ldb       WDSTAT
                    bpl       MD81      "READY" = NOT READY
                    ldx       #$0000

MD10                ldb       WDSTAT    (5)
                    bpl       MD20      (3) READY, EXIT
                    lda       #195      (2) DELAY TO MAKE LOOP TAKE 1 MSEC
                    lbsr      DELAY     (976)
                    nop       (2)
                    leax      1,X       (5)
                    cmpx      #9999     (4) TIMEOUT?
                    blo       MD10      (3)   N
                    bra       MD82      .     Y

MD20                puls      CC
                    lbsr      BINDEC    CONVERT TO DECIMAL
                    bcs       MD90
                    lda       #C$SPAC
                    lbsr      OUTCH
                    bcs       MD90
                    lbsr      OUT4HX    DISPLAY RESULTS (MSEC)
                    bcs       MD90
                    leax      MSG5,PCR
                    lbsr      PDATA
                    bcs       MD90
                    clrb
                    bra       MD90

MD81                puls      CC
                    comb
                    ldb       #F.NOT.RDY
                    bra       MD90
MD82                puls      CC
                    comb
                    ldb       #F.TIME.OUT

MD90                lbra      RETURN

*************************************
*
* DETERMINE AND DISPLAY THE DRIVE MOTOR SPEED
*  (SOFT SECTORED DISK MUST BE IN SELECTED DRIVE)
* TIMING IN SOFTWARE LOOPS BASED ON
*  EXACTLY 1 MHZ CPU CLOCK
* IN - U STATIC STG PTR
* OUT - A,B,X,Y UNDEFINED
*       U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9, F.NUM.ERR, F.NOT.RDY, F.TIME.OUT)
*************************************
MOTORS              lda       #C$SPAC
                    lbsr      OUTCH
                    lbcs      MS99
                    lbsr      INCHE     GET DRIVE #
                    lbcs      MS99
                    cmpa      #'0
                    lblo      MS81
                    cmpa      #'3
                    lbhi      MS81
                    suba      #'0
                    sta       DRIVE,U
                    leax      MSG6,PCR  POSITION CURSOR
                    lbsr      PDATA
                    lbcs      MS99

                    lda       ARTOPX    SAVE CURRENT DRIVE # SELECTED
                    sta       OPXSAV,U
                    lda       DRIVE,U   SELECT DRIVE
                    asla
                    asla
                    asla
                    asla
                    asla
                    asla
                    ldb       #$C0
                    jsr       [SETOPR]

MS01                pshs      CC        DISABLE INTERRUPTS
                    orcc      #IntMasks
                    lbsr      READY     WAIT UNTIL MOTORS UP TO SPEED
                    lbvs      MS82
                    lda       WDSTAT    DISK CONTROLLER READY?
                    bita      #$01
                    lbne      MS82      .N, STILL BUSY

                    lda       WDTRAK    ISSUE SEEK TO LOAD HEAD
                    sta       WDDATA    (WILL STAY LOADED UNTIL 15
                    lda       #4        INDEX PULSES REC'D)
                    lbsr      DELAY
                    lda       #$18+$03
                    sta       WDCMD
                    ldx       #12500    DELAY 100 MSEC FOR THE HEAD TO SETTLE
MS06                leax      -1,X      (5)
                    bne       MS06      (3)
*
* WAIT FOR BEGINNING OF INDEX PULSE
*
                    ldx       #0        WAIT FOR END OF INDEX PULSE
MS10                lda       WDSTAT
                    bita      #$02      END?
                    beq       MS20      .Y
                    leax      1,X       .N
                    cmpx      #740      20 MSEC. EXCEEDED?
                    lbeq      MS83
                    bra       MS10

MS20                ldx       #0        WAIT FOR START OF INDEX PULSE
MS25                lda       WDSTAT
                    bita      #$02      START?
                    bne       MS30      .Y
                    leax      1,X       .N
                    cmpx      #11111    300 MSEC. EXCEEDED?
                    lbeq      MS83
                    bra       MS25
*
* TIME HOW LONG UNTIL THE BEGINNING OF THE NEXT
*  INDEX PULSE, IN 66.666 USEC. INCREMENTS
*
MS30                ldx       #0        WAIT FOR END OF INDEX PULSE
MS35                lda       WDSTAT    (5)
                    bita      #$02      (2) END?
                    beq       MS40      (3)  Y
                    lda       #6        (2)  N, STRETCH LOOP TO 66 USEC.
                    lbsr      DELAY     (31)
                    leax      1,X       (5)
                    cmpx      #1000     (4) 66 MSEC EXCEEDED YET?
                    lbeq      MS83      (5/6) (LBEQ)
                    brn       *         (3)
                    brn       *         (3)
                    bra       MS35      (3)

MS40                lda       WDSTAT    (5)WAIT FOR START OF INDEX PULSE
                    bita      #$02      (2)
                    bne       MS50      (3)
                    lda       #7        (2) STRETCH LOOP TO 67 USEC.
                    lbsr      DELAY     (36)
                    leax      1,X       (5)
                    cmpx      #5000     (4) 330 MSEC EXCEEDED YET?
                    lbeq      MS83      (5/6) (LBEQ)
                    nop       (2)
                    brn       *         (3)

                    lda       WDSTAT
                    bita      #$02
                    bne       MS50
                    lda       #7        STRETCH LOOP TO 66 USEC.
                    lbsr      DELAY
                    leax      1,X
                    cmpx      #5000     330 MSEC EXCEEDED YET?
                    lbeq      MS83      (LBEQ)
                    nop
                    nop

                    lda       WDSTAT
                    bita      #$02
                    bne       MS50
                    lda       #7        STRETCH LOOP TO 67 USEC.
                    lbsr      DELAY
                    leax      1,X
                    cmpx      #5000     330 MSEC EXCEEDED YET?
                    lbeq      MS83      (LBEQ)
                    nop
                    bra       MS40
*
* CONVERT DURATION TO RPM X 10 AND DISPLAY.
*  REPEAT UNTIL ANY CHARACTER KEYED.
*
MS50                puls      CC
                    bsr       DSPRPM
                    bcs       MS99
                    lbsr      INCHEK    ABORT?
                    bcc       MS60      .Y
                    cmpb      #$F6
                    lbeq      MS01      .N
                    orcc      #Carry    .N, ERROR
                    bra       MS99
MS60                lbsr      INCHN     DISCARD ABORT CHARAC
                    bcs       MS99
                    clrb
                    bra       MS99

MS81                comb
                    ldb       #F.NUM.ERR
                    bra       MS99
MS82                puls      CC
                    comb
                    ldb       #F.NOT.RDY
                    bra       MS99
MS83                puls      CC
                    comb
                    ldb       #F.TIME.OUT

MS99                equ       *
                    pshs      CC,B

                    ldx       #12500    DELAY 100 MSEC.
MS99A               leax      -1,X      (5)
                    bne       MS99A     (3)

                    lda       #$D0      ABORT SEEK
                    sta       WDCMD
                    lda       #200      DELAY 1 MSEC
                    lbsr      DELAY
                    lda       WDTRAK    ISSUE DUMMY SEEK TO UNLOAD HEAD
                    sta       WDDATA
                    lda       #10
                    lbsr      DELAY
                    lda       #$10+$03
                    sta       WDCMD
                    lda       #200      DELAY 1 MSEC.
                    lbsr      DELAY
                    lda       #$D0      ABORT SEEK
                    sta       WDCMD
                    lda       #200      DELAY 1 MSEC
                    lbsr      DELAY

                    lda       OPXSAV,U  RESTORE DRIVE SELECT
                    ldb       #$C0
                    jsr       [SETOPR]

                    puls      CC,B
                    lbra      RETURN

*****************************************
*
* DISPLAY RPM  ( XXX.X)
* (9,000,000 / COUNT) = (RPM * 10)
*   3 BYTES    2 BYTS   2 BYTS
* COUNT = .1 REV PER 60,000 MSEC, OR 66.67 USEC PER COUNT
*
* IN - X COUNT
* OUT - A,B,X,Y UNDEFINED
*       U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9, F.NUM.ERR)
******************************************
DSPRPM              ldb       #$89      PUSH CONSTANT VALUE 9001501
                    ldy       #$5A1D    . ONTO STACK
                    pshs      B,Y
                    pshs      X
                    ldx       #0000

DR10                ldd       3,S       SUBTRACT DIVISOR FROM DIVIDEND
                    subd      ,S        . UNTIL DIVIDEND IS NEGATIVE
                    std       3,S
                    lda       2,S
                    sbca      #00
                    sta       2,S
                    bcs       DR30
                    leax      1,X       ACCUMULATE QUOTIENT IN REG X
                    bra       DR10

DR30                leas      5,S
                    lbsr      BINDEC    CONVERT TO BCD
                    bcs       DR90
                    pshs      X         DISPLAY AS XXX.X
                    leax      MSG7,PCR  . BACKSPACE OVER PREV DISPLAY
                    lbsr      PDATA
                    bcs       DR89
                    ldx       ,S
                    lbsr      OUT4HX    . OUTPUT ALL 4 DIGITS
                    bcs       DR89
                    lda       #C$BSP    . OVERWRITE LAST DIGIT WITH PERIOD
                    lbsr      OUTCH
                    bcs       DR89
                    lda       #'.
                    lbsr      OUTCH
                    bcs       DR89
                    lsl       1,S       . GET TENTHS DIGIT
                    lsl       1,S
                    lsl       1,S
                    lsl       1,S
                    lda       1,S
                    lbsr      OUT2HX
                    bcs       DR89
                    lda       #C$BSP    . OVERWRITE DUMMY DIGIT
                    lbsr      OUTCH
                    bcs       DR89
                    lda       #C$SPAC
                    lbsr      OUTCH
                    bcs       DR89

                    ldb       #100      WAIT 100 MSEC. TO ALLOW DATA TO BE TRANSMITTED
DR60                lda       #198      (2)
                    lbsr      DELAY     (991)
                    decb                (2)
                    bne       DR60      (3)
                    clrb
DR89                leas      2,S
DR90                rts

*****************************
* CHECK IF DRIVE READY
*
* IN -  NONE
* OUT - VC = READY
*       VS = NOT READY AFTER WAITING 5 SECONDS
*       REG A DESTROYED, REG B HAS 1793 STATUS CODE
*       X,Y,U UNCHANGED
*****************************
READY               pshs      X
                    ldx       #0000

RY10                ldb       WDSTAT
                    bmi       RY20
                    ldb       WDSTAT    TEST TWICE IN CASE OF GLITCH
                    bpl       RY80
RY20                lda       #196
                    lbsr      DELAY
                    leax      1,X
                    cmpx      #5000     LOOPED FOR 5 SECONDS ALREADY?
                    blo       RY10      .N

                    orcc      #TwosOvfl .Y, TIMEOUT
                    bra       RY90

RY80                andcc     #^TwosOvfl
RY90                puls      X,PC

********************************
*
* CONVERT BINARY NUMBER TO DECIMAL (BCD)
*
* IN - REG X HAS BINARY NUMBER
*      U POINTS TO STATIC STORAGE
* OUT - REG X HAS 4 DIGIT BCD NUMBER
*       B UNDEFINED
*       A,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (F.NUM.ERR)
**********************************
BINDEC              pshs      A,Y
                    lda       #16
                    sta       COUNT,U
*
* PUSH A 2 BYTE BCD NUMBER (ZERO OR VALUE OF
*  THAT BIT) ONTO STACK FOR EACH OF THE 16 BITS
*
                    tfr       X,D
                    leax      <WGHTB,PCR
                    tsta
                    bra       BN20
BN10                lslb
                    rola
BN20                bmi       BN30
                    leax      2,X
                    ldy       #$0000
                    bra       BN40
BN30                ldy       ,X++
BN40                pshs      Y
                    dec       COUNT,U
                    bne       BN10
*
* ADD UP THE VALUES OF THE 16 BCD NUMBERS
*  ON THE STACK
*
                    clr       ERFLG,U
                    ldy       #16
                    clra
                    clrb
BN60                exg       A,B
                    adda      1,S
                    daa
                    exg       A,B
                    adca      ,S
                    daa
                    bcc       BN70
                    inc       ERFLG,U
BN70                leas      2,S
                    leay      -1,Y
                    bne       BN60

                    tfr       D,X
                    clrb
                    tst       ERFLG,U
                    beq       BN90
                    comb
                    ldb       #F.NUM.ERR
BN90                puls      A,Y,PC

WGHTB               fdb       $A999
                    fdb       $A999
                    fdb       $8192
                    fdb       $4096
                    fdb       $2048
                    fdb       $1024
                    fdb       $0512
                    fdb       $0256
                    fdb       $0128
                    fdb       $0064
                    fdb       $0032
                    fdb       $0016
                    fdb       $0008
                    fdb       $0004
                    fdb       $0002
                    fdb       $0001

***************************************
* OUTPUT ONE CHARACTER TO CONSOLE
* IN - A CHARAC TO SEND
* OUT - B UNDEFINED
*       A,X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
***************************************
OUTCH               pshs      A,X,Y
                    lda       #STDOUT
                    leax      ,S
                    ldy       #1
                    os9       I$WRITE
                    puls      A,X,Y,PC

**************************************
* OUTPUT ONE HEXADECIMAL CHARACTER
* IN - A LOWER 4 BITS HAS HEX VALUE
* OUT - A,B UNDEFINED
*       X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
**************************************
OUT1HX              anda      #$0F
                    adda      #$30
                    cmpa      #$39
                    ble       OT150
                    adda      #$07
OT150               bsr       OUTCH
                    rts

**************************************
* OUTPUT 2 HEXADECIMAL DIGITS
* IN - A 2 DIGIT HEX VALUE
* OUT - B UNDEFINED
*       A,X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
*************************************
OUT2HX              pshs      A
                    lsra
                    lsra
                    lsra
                    lsra
                    bsr       OUT1HX
                    bcs       OT290
                    lda       ,S
                    anda      #$0F
                    bsr       OUT1HX
OT290               puls      A,PC

************************************
* OUTPUT A 4 DIGIT HEXADECIMAL VALUE
* IN - X 4 DIGIT HEX VALUE
* OUT - A,B UNDEFINED
*       X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
************************************
OUT4HX              pshs      X
                    lda       ,S
                    bsr       OUT2HX
                    bcs       OT490
                    lda       1,S
                    bsr       OUT2HX
OT490               puls      X,PC

********************************
* OUTPUT STRING WITHOUT CR/LF
* IN - X ADDRESS OF STRING
* OUT - A,B,X UNDEFINED
*       Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
********************************
PDATA               lda       ,X+
                    cmpa      #C$RPRT
                    beq       PD80
                    bsr       OUTCH
                    bcs       PD90
                    bra       PDATA
PD80                clrb
PD90                rts

**************************************
* OUTPUT CR/LF, THEN STRING
* IN - X ADDRESS OF STRING
* OUT - A,B,X UNDEFINED
*       Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
**************************************
PSTRNG              pshs      X
                    leax      MSG8,PCR
                    bsr       PDATA
                    puls      X
                    bcs       PS90
                    bsr       PDATA
PS90                rts

**************************************
* CHECK KEYBOARD PORT FOR DATA AVAILABLE
* IN - NONE
* OUT - CC CC IF READY
*       B ZERO
*       A,X,Y,U UNCHANGED
* ERROR - CC CS
*         B OS-9 ERROR CODE ($F6=NOT-READY, ETC.)
**************************************
INCHEK              pshs      A
                    lda       #STDIN
                    ldb       #SS.READY
                    os9       I$GETSTT
                    puls      A,PC

*****************************
*
* INPUT CHARACTER, CONVERT TO UPPER CASE,
*  AND ECHO IF DISPLAYABLE
* IN - U STATIC STG PTR
* OUT - A CHARACTER REC'D
*       B UNDEFINED
*       X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9, $FF=NON-DISPLAYABLE)
******************************
INCHE               bsr       INCHN
                    bcs       IN90
                    anda      #$7F
                    cmpa      #$20
                    blo       IN80
                    cmpa      #$7F
                    bhs       IN80
                    cmpa      #'a
                    blo       IN70
                    cmpa      #'z
                    bhi       IN70
                    anda      #$5F
IN70                bsr       OUTCH
IN90                rts

IN80                clrb
                    comb
                    rts

**************************************
* INPUT CHARACTER FROM KEYBOARD - NO ECHO
* IN - U STATIC STORAGE POINTER
* OUT - A CHARAC REC'D
*       B UNDEFINED
*       X,Y,U UNCHANGED
* ERROR - CC CS
*         B ERROR CODE (OS-9)
**************************************
INCHN               pshs      A,X,Y
*
* DISABLE ECHO
*
                    lda       #STDIN    GET OPTION PACKET
                    ldb       #SS.OPT
                    leax      SCFOPT,U
                    os9       I$GETSTT
                    bcs       IC90

                    lda       SCFOPT+4,U SAVE, THEN CLEAR ECHO FLAG
                    sta       ECHSAV,U
                    clr       SCFOPT+4,U

                    lda       #STDIN    RE-WRITE OPTION PACKET
                    ldb       #SS.OPT
                    leax      SCFOPT,U
                    os9       I$SETSTT
                    bcs       IC90
*
* INPUT CHARACTER WITHOUT ECHO
*
                    lda       #STDIN    GET CHARACTER
                    leax      ,S
                    ldy       #1
                    os9       I$READ
                    bcs       IC90
*
* RESTORE ECHO FLAG
*
                    lda       #STDIN    GET OPTION PACKET
                    ldb       #SS.OPT
                    leax      SCFOPT,U
                    os9       I$GETSTT
                    bcs       IC90

                    lda       ECHSAV,U  RESTORE ECHO FLAG
                    sta       SCFOPT+4,U

                    lda       #STDIN    RE-WRITE OPTION PACKET
                    ldb       #SS.OPT
                    leax      SCFOPT,U
                    os9       I$SETSTT
                    bcs       IC90

IC90                puls      A,X,Y,PC

****************************************
*
* DELAY FOR 20 TO 1275 MICROSECONDS (INCL. JSR AND RTS)
*
* IN - A NUMBER OF MICROSECONDS DIVIDED BY 5
* OUT - A UNDEFINED
*       B,X,Y,U UNCHANGED
*****************************************
DELAY               suba      #3        (2)
DLY                 deca                (2)
                    bne       DLY       (3)
                    rts                 (5)

                    emod
EndChk              equ       *
