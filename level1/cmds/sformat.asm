*****************************************
*        "SFORMAT"
* COPYRIGHT 1983 D. P. JOHNSON
*  MODIFIED BY DAVID C. WIENS
* Last modified June 7, 1985 12:55 pm
****************************************
                  IFP1
                    use       defsfile
                  ENDC

***************************************
* STATIC STORAGE
***************************************
                    org       $0000
DEVPATH             rmb       1
PARMPTR             rmb       2         PARAMATER AREA PTR STORE
RFLAG               rmb       1         READY FLAG
NFLAG               rmb       1         DISK NAME GIVEN FLAG
USAVE               rmb       2         TEMP STORE FOR U
TEMP                rmb       2         NUMBER CONVERSION SCRATCH
*FORMAT PARAMETERS
TRACKN              rmb       1         TRK # FOR SECTOR HEADER
SIDEN               rmb       1         SIDE NO. FOR HEADER
SECTORS             rmb       1

*DISK FORMAT PARAMETERS
TPI                 rmb       1         0=48 TPI  2=96 TPI
DENSITY             rmb       1         0=SINGLE 1=DOUBLE
CYLS                rmb       1         # OF CYLINDERS
SIDES               rmb       1         # OF SIDES
INTERLV             rmb       1         INTERLEAVE VALUE
TYPE                rmb       1         $80=COCO 0=STANDARD
TRK0SIZE            rmb       1         SECTORS ON TRACK 0
SECTS               rmb       1         SECTORS/TRACK (OTHER THAN 0)
TN0PTR              rmb       2         TRACK INSERT PTR IN BUFFER
SPTR                rmb       2         PNTR TO START OF SECTOR TAB
SCCSIZ              rmb       2         TOTAL SEC SIZ IN BUF (W/HEADER)

DEVNLN              rmb       1         NAME LENGHT
DEVTPTR             rmb       2         DEVICE TABLE ENTRY PNTR
DRNAM               rmb       6         DEVICE NAME FOR ATTACH
DNLEN               equ       .-DRNAM
DEVNAME             rmb       8         DEVICE NAME BUFFER
NBUF                rmb       5         NUMERIC CONVERSION BUFFER
VSECT               rmb       2         SECTOR BEING VERIFIED
VTRACK              rmb       2         TRACK BEING VERIFIED
VCNT                rmb       1         SECTOR ON CURRENT TRK
GOODCNT             rmb       2         COUNT OF GOOD SECTORS
MINSECS             rmb       2         MIN GOOD SECS AT BEG OF DISK
ILVTAB              rmb       20        INTERLEAVE TABLE
ISIZE               equ       .-ILVTAB
ONEOPTS             rmb       32        PATH 1 OPTIONS
ONEPAU              rmb       1         STORAGE FOR ORIGINAL PAUSE VALUE
DEVOPTS             rmb       32        PATH DESC. OPTIONS
LSN0                rmb       31        IDENTIFICATION SECTOR INFO
DISKNAME            rmb       32
TRKBUF              rmb       6562      (5% OVERFLOW)
BUFEND              equ       .
VBUFFER             rmb       256       VERIFY READ BUFFER
                    rmb       250
DatSize             equ       .

************************************
* HEADER
************************************
TyLg                set       Prgrm+Objct
AtRv                set       ReEnt+rev
Rev                 set       0
Edition             set       27

                    mod       EndFmt,Name,TyLg,AtRv,Start,DatSize

Name                fcs       'sformat'
                    fcb       Edition

                    fcc       '(c) Copyright 1983 D.P.Johnson'
                    fcc       ' and licensed to Sardis Technologies'

*******************************************************
* MESSAGE TABLE
*  format:  fcb message-length
*           fcc /message/
*******************************************************
MSGTAB              fcb       10
                    fcc       / Double/ #0
                    fcb       10
                    fcc       / Single/ #1
                    fcb       9
                    fcc       / Density/ #2
                    fcb       C$CR,11
                    fcc       / Cylinders/ #3
                    fcb       C$CR,7
                    fcc       / sides/ #4
                    fcb       C$CR,18
                    fcc       / Color Computer/ #5
                    fcb       17
SPACE               fcc       / OS-9 Standard/ #6
                    fcb       8
                    fcc       / format/ #7
                    fcb       C$CR,15
                    fcc       / Trk 0 Sectors/ #8
                    fcb       C$CR,15
                    fcc       " Sectors/Track" #9
CRCR                fcb       C$CR,22
                    fcc       /Color Computer Format?/ #10
                    fcb       15
                    fcc       /Double Density?/ #11
                    fcb       13
                    fcc       /Double Sided?/ #12
                    fcb       17
                    fcc       /No. of Cylinders=/ msg #13
                    fcb       1,C$CR    #14
                    fcb       19
                    fcc       /FORMAT PARAMETERS:/ #15
                    fcb       C$CR,17
                    fcc       /Formatting drive / #16
                    fcb       29
                    fcc       /y (yes), n (no), or q (quit)/ #17
                    fcb       C$CR,6
                    fcc       /Ready?/ #18
                    fcb       13
                    fcc       /Volume Name=/ #19
                    fcb       C$CR
                    fcb       18
                    fcc       /Verifying Tracks:/ #20
                    fcb       C$CR
                    fcb       14
                    fcc       / Good Sectors/ #21
                    fcb       C$CR
                    fcb       29
                    fcc       /*** STANDARD DISK FORMAT ***/ #22
                    fcb       C$CR
                    fcb       32
                    fcc       /(C) Copyright 1983 D.P. Johnson/ #23
                    fcb       C$CR
                    fcb       20
                    fcc       /ALL RIGHTS RESERVED/ #24
                    fcb       C$CR
                    fcb       13
                    fcc       /SYNTAX ERROR/ #25
                    fcb       C$CR
                    fcb       29
                    fcc       "use: SFORMAT /devname [opts]" #26
                    fcb       C$CR
                    fcb       26
                    fcc       / opts: S = Single density/ #27
                    fcb       C$CR
                    fcb       26
                    fcc       / D = Double density/ #28
                    fcb       C$CR
                    fcb       17
                    fcc       / R = Ready/ #29
                    fcb       C$CR
                    fcb       18
                    fcc       / 1 = 1 side/ #30
                    fcb       C$CR
                    fcb       19
                    fcc       / 2 = 2 sides/ #31
                    fcb       C$CR
                    fcb       18
                    fcc       / 4 = 48 TPI/ #32
                    fcb       C$CR
                    fcb       28
                    fcc       / O = OS-9 Std. format/ #33
                    fcb       C$CR
                    fcb       19
                    fcc       / "disk name"/ #34
                    fcb       C$CR
                    fcb       26
                    fcc       / 'no. of cylinders'/ #35
                    fcb       C$CR
                    fcb       20
                    fcc       / :Interleave:/ #36
                    fcb       C$CR
                    fcb       17
                    fcc       /Change to 48 tpi?/ #37
                    fcb       19
                    fcc       /System Sector BAD/ #38
                    fcb       C$BELL,C$CR
                    fcb       32
                    fcc       /Licensed to Sardis Technologies/ #39
                    fcb       C$CR

*******************************************************
* track format tables
*******************************************************
*SINGLE DENSITY STANDARD FORMAT
                    fdb       296       SECTOR SIZE IN TRACKBUF
SS                  fcb       39,$FF    TRACK HEADER
                    fcb       1,$FF     make table same length as DD
                    fcb       6,$0
                    fcb       1,$FC     INDEX MARK
                    fcb       12,$FF

                    fcb       5,0       SECTOR REPEATS n TIMES
                    fcb       1,0       BALANCE TABLE LENGTH
                    fcb       1,$FE
                    fcb       4,1       (TRK,SIDE,SECT,LEN)
                    fcb       1,$F7     CRC BYTES
                    fcb       10,$FF
                    fcb       6,0
                    fcb       1,$FB     DATA ADDRESS MARK
                    fcb       0,$E5     (256 DATA BYTES)
                    fcb       1,$F7     (2 CRC BYTES)
                    fcb       8,$FF
                    fcb       2,$FF     TABLE LENGTH EQUILIZER
*
*
*DOUBLE DENSITY STANDARD FORMAT
*
                    fdb       338       SECTOR FORMAT LEN
DD                  fcb       80,$4E
                    fcb       12,0
                    fcb       3,$F6     (MICROWARE USES $F5)
                    fcb       1,$FC     INDEX MARK
                    fcb       32,$4E

                    fcb       12,0      SECTOR REPEAT STARTS HERE
                    fcb       3,$F5
                    fcb       1,$FE
                    fcb       4,1       (TRK,SIDE,SECT,BYTCNT)
                    fcb       1,$F7     2 CRC BYTES
                    fcb       22,$4E
                    fcb       12,0
                    fcb       3,$F5
                    fcb       1,$FB
                    fcb       0,$E5     (256 DATA BYTES)
                    fcb       1,$F7
                    fcb       22,$4E
*
*
* COCO DOUBLE DENSITY FORMAT
*
                    fdb       336       FORMAT SECTOR SIZE
COCODD              fcb       32,$4E
                    fcb       12,0
                    fcb       3,$F6     (MICROWARE USES $F5)
                    fcb       1,$FC
                    fcb       32,$4E

                    fcb       8,0       SECTOR REPEAT STARTS HERE
                    fcb       3,$F5
                    fcb       1,$FE
                    fcb       4,1       (TRK,SIDE,SECT,LEN)
                    fcb       1,$F7
                    fcb       22,$4E
                    fcb       12,0
                    fcb       3,$F5
                    fcb       1,$FB
                    fcb       0,$E5     (256 DATA BYTES)
                    fcb       1,$F7
                    fcb       24,$4E
*
*
*

Start               pshs      U         SAVE REG
                    clrb                CNT
CLRSTAT             clr       ,U+
                    decb
                    bne       CLRSTAT   CLEAR STATIC STORAGE
                    puls      U         RESTORE
                    stu       USAVE     SAVE FOR LATER

* PICK UP DEVICE NAME FROM PARAMETER AREA
START2              lda       ,X+       SKIP SPACES
                    cmpa      #'        .
                    beq       START2
                    cmpa      #'/
                    bne       SYNTAX    PRINT SYNTAX WANTED AND EXIT
                    sta       DEVNAME
                    os9       F$PRSNAM  PARSE THE NAME
                    bcs       SYNTAX    IF ERROR
                    stb       DEVNLN    SAVE LENGTH OF NAME
                    inc       DEVNLN    FIX TO INCLUDE "/"
                    leay      DEVNAME+1,U POINT TO DESTINATION
MOVNAME             lda       ,X+
                    sta       -1-DNLEN,Y
                    sta       ,Y+
                    decb
                    bne       MOVNAME   MOVE THE NAME
                    lda       #'@
                    ldb       #C$CR
                    std       ,Y        FINISH DEVICE PATH NAME
                    stb       -1-DNLEN,Y
                    stx       PARMPTR   SAVE PARMETER POINTER

*
*SIGN ON MESSAGE
*
                    lbsr      PMSG
                    fcb       22
                    lbsr      PMSG
                    fcb       23
                    lbsr      PMSG
                    fcb       24
                    lbsr      PMSG
                    fcb       39
                    lbsr      PMSG
                    fcb       14

                    clra                USE       DEVICE CAPABILITIES
                    leax      DRNAM,U
                    os9       I$ATTACH
                    lbcs      ZABORT    ERROR EXIT
                    stu       DEVTPTR   SAVE TABLE ENTRY ADDRESS
                    ldu       USAVE     RESTORE STATIC STORE PTR

*
* GET PATH 1 OPTIONS AND TURN PAUSE OFF
*
                    lda       #1
                    clrb                SS.OPT
                    leax      ONEOPTS,U SAVE OPTS HERE
                    os9       I$GETSTT  GET PATH ONE OPTIONS
                    lbcs      ZABORT
                    ldb       PD.PAU-PD.OPT,X GET OLD PAUSE VALUE
                    stb       ONEPAU    SAVE IT
                    clr       PD.PAU-PD.OPT,X SHUT OFF PAUSE
                    clrb                SS.OPT
                    os9       I$SETSTT
                    bcs       ABORT

                    leax      DEVNAME,U POINT TO NAME
                    lda       #WRITE.
                    os9       I$OPEN
                    bcc       DEVOK
ABORT               lbra      XABORT
SYNTAX              lbsr      SYNPRT    PRINT SYNTAX MESSAGE
                    clrb
                    os9       F$EXIT

DEVOK               sta       DEVPATH   PATH TO DEVICE

                    ldb       #SS.OPT
                    leax      DEVOPTS,U GET PATH OPTIONS
                    os9       I$GETSTT
                    bcs       ABORT

* initialize disk format parameters
                    lda       DEVOPTS-PD.OPT+PD.DNS,U GET DENSITY INFO
                    tfr       A,B       SAVE COPY IN B
                    anda      #1        MASK OFF TPI BIT
                    sta       DENSITY
                    andb      #2        MASK TPI BIT
                    stb       TPI
                    lda       DEVOPTS-PD.OPT+PD.TYP,U GET TYPE BYTE
                    tfr       A,B       COPY TO B
                    anda      #%10000001 MASK 8" AND HARD DISK BITS
                    lbne      TYPERR    error .. wrong device type
                    andb      #%00100000
                    stb       TYPE      SAVE DISK TYPE BIT
                    ldd       DEVOPTS-PD.OPT+PD.CYL+1,U GET CYLS AND SIDES
                    std       CYLS      SAVE CYLS AND SIDES
                    ldd       DEVOPTS-PD.OPT+PD.SCT,U get sectors per track
                    stb       SECTS     SAVE
                    ldd       DEVOPTS-PD.OPT+PD.T0S,U trk 0 sectors
                    stb       TRK0SIZE  save
                    ldb       DEVOPTS-PD.OPT+PD.ILV,U get interleave value
                    stb       INTERLV   SAVE IT
                    bra       SCAN      CONTINUE

* CONVERT TO UPPER CASE
MAKEUP              cmpa      #$60
                    bls       ISUP
                    suba      #$20
ISUP                rts

*
* SCAN REST OF PARAMTER AREA FOR OPTIONS
*
SCAN                ldx       PARMPTR   POINT TO PARAM AREA
GETP                lda       ,X+
                    bsr       MAKEUP    MAKE IT UPPER CASE
                    cmpa      #C$CR     CR?
                    lbeq      DISP      END OF LINE

                    ldb       #1        SET UP FOR FLAG STORE
                    tst       TYPE      IS IT COCO TYPE?
                    bne       SCAN1     YES.. DISALLOW SING DENS
                    cmpa      #'S       SINGLE DENS?
                    bne       SCAN1
                    clr       DENSITY   SET FOR SINGLE DENSITY
                    lda       #10       SET DEFAULT SECS/TRK FOR SD
                    sta       TRK0SIZE
                    sta       SECTS
                    bra       GETP

SCAN1               cmpa      #'D       DOUBLE DENSITY?
                    bne       SCAN2
                    stb       DENSITY   SET FOR DOUBLE DENSITY
                    bra       GETP

SCAN2               cmpa      #'R       READY?
                    bne       SCAN5
                    stb       RFLAG     SET READY FLAG
                    bra       GETP

SCAN3               cmpa      #'C       COCO?
                    bne       SCAN4
                    lda       #$20
                    sta       TYPE      SET TYPE AS COCO
                    stb       DENSITY   SET FOR DD
                    lda       #18       SET DEFAULT SECS/TRK
                    sta       TRK0SIZE
                    sta       SECTS
                    bra       GETP

SCAN4               cmpa      #'O       OS9 STANDARD?
                    bne       SCAN5
                    clr       TYPE      SET AS STANDARD
                    bra       GETP

SCAN5               cmpa      #'1
                    bne       SCAN6
                    stb       SIDES     SET AS 1 SIDE
                    bra       GETP

SCAN6               cmpa      #'2
                    bne       SCAN6.5
                    cmpb      DEVOPTS-PD.OPT+PD.SID
                    lbeq      TYPERR    IS ASKING FOR 2 SIDES ON 1 SIDE DRIVE
                    incb
                    stb       SIDES     SET AS 2 SIDES
                    bra       GETP

SCAN6.5             cmpa      #'4       48 TPI?
                    bne       SCAN7
                    clr       TPI
                    bra       GOGETP

SCAN7               cmpa      #''       TRACKS ?
                    bne       SCAN8
                    lbsr      GETDEC    GET VALUE
                    lbcs      SYNABORT
                    cmpd      DEVOPTS-PD.OPT+PD.CYL OUT OF RANGE?
                    lbhi      TYPERR    IF TOO HI
                    stb       CYLS
                    lda       ,X+       TERMINATION CHAR
                    cmpa      #''
                    lbne      SYNABORT
                    bra       GOGETP

* PICK UP DISK NAME
SCAN8               cmpa      #'"
                    bne       SCAN9
                    inc       NFLAG     FLAG NAME GIVEN
                    leay      DISKNAME,U
                    ldb       #32       MAX LENGTH
SCN8.1              lda       ,X+       GET NAME CHAR
                    cmpa      #'"       END?
                    bne       SCN8.3
SCN8.2              lda       ,-Y       SET HI BIT OF LAST CHAR
                    ora       #$80
                    sta       ,Y
GOGETP              lbra      GETP

SCN8.3              cmpa      #C$CR
                    lbeq      SYNABORT  ERROR
                    sta       ,Y+       SAVE CHAR
                    decb                COUNT     DOWN
                    bne       SCN8.1
SCN8.4              lda       ,X+       FORCE END
                    cmpa      #'"
                    beq       SCN8.2
                    cmpa      #C$CR
                    beq       SCN8.2
                    bra       SCN8.4

SCAN9               cmpa      #':       INTERLEAVE VALUE
                    bne       GOGETP
                    lbsr      GETDEC
                    stb       INTERLV   NEW INTERLEAVE VALUE
                    lda       ,X+       TERMINATION CHAR
                    cmpa      #':
                    lbne      SYNABORT
                    bra       GOGETP

* DISPLAY CURRENT FORMAT PARAMETERS:
DISP                bsr       PMSGJ
                    fcb       15
                    bsr       PMSGJ
                    fcb       14        PRINT CR
                    tst       DENSITY
                    bne       DISP2     DOUBLE
                    bsr       PMSGJ
                    fcb       1         SINGLE
                    bra       DISP3
DISP2               bsr       PMSGJ
                    fcb       0
DISP3               bsr       PMSGJ
                    fcb       2
                    ldb       CYLS      # OF CYLINDERS
                    lbsr      PDECIMAL
                    bsr       PMSGJ
                    fcb       3
                    ldb       SIDES
                    lbsr      PDECIMAL
                    bsr       PMSGJ
                    fcb       4         SIDES
                    tst       TYPE
                    beq       DISP4
                    bsr       PMSGJ
                    fcb       5         COLOR COMPUTER
                    bra       DISP5
DISP4               bsr       PMSGJ
                    fcb       6         OS-9 STANDARD
DISP5               bsr       PMSGJ
                    fcb       7         FORMAT
                    ldb       TRK0SIZE
                    lbsr      PDECIMAL
                    bsr       PMSGJ
                    fcb       8         TRK 0 SECTORS
                    ldb       SECTS
                    lbsr      PDECIMAL
                    bsr       PMSGJ
                    fcb       9         SECTORS/TRACK
DISP6               bsr       PMSGJ
                    fcb       14        PRINT CR
                    bsr       PMSGJ
                    fcb       16        FORMATTING DRIVE
                    ldb       DEVNLN
                    clra
                    tfr       D,Y
                    leax      DEVNAME,U
                    lda       #1
                    os9       I$WRITLN  DRIVE NAME
                    lbcs      ABORT
                    bsr       PMSGJ
                    fcb       14        CR

                    tst       RFLAG     READY TO FORMAT?
                    lbne      FORMAT    YES

                    bsr       PMSGJ
                    fcb       17        YES NO QUIT?
                    bsr       PMSGJ
                    fcb       18        READY?
                    lbsr      YESNO     GET ANSWER
                    lbeq      FORMAT    IF READY
                    cmpa      #'Q       QUIT?
                    lbeq      EXIT
                    cmpa      #'N       NO?
                    bne       DISP6     NONE OF THE ABOVE
                    bra       DISP7

PMSGJ               bra       PMSG

* ASK OPERATOR FOR NEW PARAMETERS
DISP7               bra       ASK2
                    bsr       PMSG      COLOR COMPUTER FORMAT?
                    fcb       10
                    clr       TYPE      SET FOR STANDARD TYPE
                    lbsr      YESNO
                    bne       ASK2

                    lda       #$20
                    sta       TYPE      SET COCO TYPE
                    lda       #18       SET DEFAULT SECOTRS/TRACK
                    sta       TRK0SIZE
                    sta       SECTS
                    lda       #1        SET FOR DOUBLE DENSITY
                    sta       DENSITY
                    bra       ASK3      SKIP DENSITY QUESTION

ASK2                tst       TYPE      IS IT A COCO TYPE?
                    bne       ASK3      YES.. SKIP DENSITY QUESTION
                    lda       #10       SET FOR 10 SECTORS/TRACK
                    sta       TRK0SIZE
                    sta       SECTS
                    bsr       PMSG
                    fcb       11        GET DENSITY
                    clr       DENSITY   SET FOR SINGLE
                    bsr       YESNO     GET ANSWER
                    bne       ASK3      IF SINGLE
                    inc       DENSITY   SET FOR DOUBLE
                    lda       #16
                    sta       SECTS     SET SECTORS/TRACK FOR DD

ASK3                tst       TPI       IS THIS A 40 TRK DRIVE?
                    beq       ASK3.5    YES
                    bsr       PMSG      NO..ASK IF CHANGE TO 48TPI
                    fcb       37
                    bsr       YESNO     GET REPLY
                    bne       ASK3.5
                    clr       TPI       SET FOR 48 TPI

ASK3.5              lda       DEVOPTS-PD.OPT+PD.SID DRIVE SIDES
                    cmpa      #1        IS DRIVE SINGLE SIDED?
                    beq       ASK4      YES.. SKIP THIS OPTION
                    bsr       PMSG      GET SIDES
                    fcb       12
                    lda       #1
                    sta       SIDES     SET FOR 1 SIDE
                    bsr       YESNO     GET ANSWER
                    bne       ASK4      IS SINGLE
                    inc       SIDES     SET FOR DOUBLE SIDED

ASK4                bsr       PMSG      GET CYLINDERS
                    fcb       13
                    ldy       #80
                    leax      TRKBUF,U
                    clra
                    os9       I$READLN  GET ANSWER
                    lbcs      ABORT
                    lbsr      GETDEC    GET NUMBER
                    bcs       ASK4      IF NO NUMBER GIVEN
                    cmpd      DEVOPTS-PD.OPT+PD.CYL TOO HI?
                    bhi       ASK4      ASK AGAIN
                    stb       CYLS
                    bsr       PMSG
                    fcb       14        PRINT CR
                    lbra      DISP      RE DISPLAY PARAMETERS

*******************************************************
* PRINT MESSAGE FROM TABLE
* CALL AS BSR PMSG
*         FCB MSG-NUMBER
*******************************************************
PMSG                puls      X         GET PARAM ADDR
                    lda       ,X+       GET MSG #
                    pshs      X         FIX RETURN ADR
                    leax      MSGTAB,PCR
PMSG1               tsta                AT        DESIRED MSG?
                    beq       PMSG2     YES
                    ldb       ,X+       GET MSG LENGTH
                    abx                 POINT     TO NEXT MSG
                    deca                COUNT     TO DESIRED ONE
                    bra       PMSG1
PMSG2               ldb       ,X+       GET MSG LEN
                    clra
                    tfr       D,Y       SET LENGTH OF WRITE
                    lda       #1        PATH #
                    os9       I$WRITLN
                    lbcs      ABORT
                    rts

*******************************************************
* GET INPUT CHAR AND TEST FOR YES ANSWER
* BEQ TRUE ON Y INPUT
*******************************************************
YESNO               clr       ,-S       MAKE STACK SPACE
                    tfr       S,X       POINT TO IT
                    ldy       #1
                    clra                PATH
                    os9       I$READ    GET CHAR
                    lbcs      ABORT
                    bsr       PMSG
                    fcb       14        CR
                    puls      A         GET CHAR
                    anda      #$7F      strip high order bit
                    lbsr      MAKEUP    FORCE UPPER CASE
                    cmpa      #'Y
                    rts

* PRINT VALUE OF NUMBER IN B-REG
PDECIMAL            clra
                    leax      NBUF,U    TEMP STORAGE
                    ldy       #4        ZERO SUPPRESS CNT
                    bsr       CONVERT   CONVERT TO ASCI
                    leax      NBUF+2,U  WRITE LAST 3 DIGITS
                    ldy       #3        3 DIGITS MAX
                    lda       #1        PATH
                    os9       I$WRITLN  WRITE IT
                    lbcs      ABORT
                    rts

*******************************************************
* CONVERT   (USE CONVERT)
*******************************************************
TABDEC              fdb       10000
                    fdb       1000
                    fdb       100
                    fdb       10
                    fdb       1

CONVERT             pshs      Y
                    pshs      A,B,X
                    lda       #'0
                    ldb       #5
CV10                stb       4,S
CV20                sta       ,X+
                    decb
                    bne       CV20
                    puls      A,B,X
                    pshs      A,B,X
                    leay      <TABDEC,PCR
CV30                subd      ,Y
                    blo       CV40
                    inc       ,X
                    bra       CV30
CV40                addd      ,Y++
                    leax      1,X
                    dec       4,S
                    bne       CV30
                    puls      A,B,X
                    puls      Y
                    pshs      Y
                    tst       1,S
                    beq       CV80
                    lda       #'0
                    ldb       #'        .
CV60                cmpa      ,X
                    bne       CV80
                    stb       ,X+
                    dec       1,S
                    bne       CV60
CV80                leas      2,S
                    rts

*******************************************************
* RETURN DECIMAL VALUE IN B-REG
*******************************************************
GETDEC              pshs      Y
                    leay      TEMP,U
                    bsr       GETDN
                    puls      Y,PC

*******************************************************
*   GETDN       (USE GETDN)
*******************************************************
GETDN               clrb
                    clra
                    std       ,Y
GD10                lda       ,X+
                    cmpa      #'        .
                    beq       GD10
                    cmpa      #'0
                    blo       GD70
                    cmpa      #'9
                    bhi       GD70
                    suba      #'0
                    sta       1,Y
GD20                ldb       ,X+
                    cmpb      #'0
                    blo       GD80
                    cmpb      #'9
                    bhi       GD80
                    subb      #'0
                    clra
                    pshs      A,B
                    lda       1,Y
                    ldb       #10
                    mul
                    pshs      A,B
GD40                lda       ,Y
                    ldb       #10
                    mul
                    tfr       B,A
                    clrb
                    addd      ,S++
                    addd      ,S++
                    std       ,Y
                    bra       GD20
GD70                comb
                    bra       GD90
GD80                clrb
GD90                leax      -1,X
                    ldd       ,Y
                    rts

*******************************************************
* format the disk according to parameters in table
*******************************************************
FORMAT              lda       DEVPATH
                    ldb       #SS.RESET RESTORE DRIVE
                    os9       I$SETSTT
                    lda       DENSITY
                    pshs      A         SAVE DENSITY
                    tst       TYPE      COCO?
                    beq       FRMT1     IF NOT

* DO TRACK 0 FOR COCO
                    leax      COCODD,PCR POINT TO FORMAT PARAMS TABLE
FRMT0               lda       TRK0SIZE  GET TRACK SIZE
                    lbsr      MAKTRK    BUILD THE TRACK TABLE
                    clra
                    clrb                TRACK     AND SIDE NOS.
                    lbsr      FMTTRK    FORMAT TRK0 SIDE 0
                    puls      A         RESTORE DENSITY SETTING
                    sta       DENSITY
                    bra       FRMT2     NOW DO REMAINING TRACKS

* STANDARD FORMAT ALWAYS DO SING DENS ON TRK 0
FRMT1               leax      SS,PCR    POINT TO SS TABLE
                    clr       DENSITY
                    bra       FRMT0     FORMAT TRK0 SIDE 0 SINGLE DENS.

*
* NOW DO FOR REMAINING TRACKS
*
FRMT2               leax      COCODD,PCR POINT OT COCO FORMAT TABLE
                    tst       TYPE
                    bne       FRMT3     IF COCO TYPE DISK
                    leax      SS,PCR    SET FOR SINGLE DENS
                    tst       DENSITY
                    beq       FRMT3     IF SINGLE
                    leax      DD,PCR    SET FOR DD
                    lda       SECTS     HOW MANY SECTS/TRK?
                    cmpa      #16
                    bls       FRMT3     16 OR LESS USE NORMAL DD
                    leax      COCODD,PCR ELSE USE COCO DD

FRMT3               lda       SECTS     GET NUMBER OF SECTORS
                    lbsr      MAKTRK    BUILD THE TRACK TABLE
                    bra       FRMT5     START WITH SIDE 1 TRK 0 IF DS

FRMT4               lda       TRACKN
                    inca
                    cmpa      CYLS      DONE?
                    beq       FRMT7     YES.. GO VERIFY
                    clrb                SIDE      0
                    lbsr      FMTTRK    FORMAT THE TRACK
FRMT5               lda       SIDES     HOW MANY SIDES?
                    cmpa      #2
                    bne       FRMT4     DO NEXT TRACK
                    lda       TRACKN    SAME TRACK
                    ldb       #1        OTHER SIDE
                    lbsr      FMTTRK
                    bra       FRMT4

*
* FORMAT VERIFY HERE
*
* FILL IN LSN0 VALUES
FRMT7               lda       SECTS     SECTORS/TRK
                    sta       LSN0+DD.TKS
                    sta       LSN0+DD.SPT+1
                    ldd       LSN0+DD.TOT+1 TOTAL SECTORS ON MEDIA
                    addd      #7        CALC BYTES IN BIT MAP
                    lsra                DIVIDE    BY 8
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    std       LSN0+DD.MAP SAVE MAP BYTES
                    subd      #1        A= MAP SECTORS -1
                    pshs      A
                    ldb       #2        ALLOCATE LSN0 AND 1 MAP SECTOR
                    addb      ,S+       ADD ANY OTHER MAP SECTORS
                    stb       LSN0+DD.DIR+2 = ROOT DIR SECTOR
                    ldb       #1        SET 1 SECTOR CLUSTERS
                    stb       LSN0+DD.BIT+1
* CALCULATE .FMT BYTE
                    lda       TPI       GET TRACK PER INCH BIT
                    ora       DENSITY   ADD DENSITY BIT
                    asla                SHIFT
                    ldb       SIDES     ADD IN SIDES BIT
                    cmpb      #2
                    bne       LSNF1     IF SINGLE SIDED
                    inca                ADD       IN DOUBLE SIDED BIT
LSNF1               sta       LSN0+DD.FMT STORE FORMAT BYTE
                    lda       DISKNAME  SAVE DISKNAME BYTE FOR TIME GET
                    leax      LSN0+DD.DAT,U WHERE TO PUT DATE
                    os9       F$TIME
                    sta       DISKNAME  RESTORE NAME BYTE
                    tst       NFLAG     DO WE HAVE THE NAME?
                    bne       LSNF2     YES
                    lbsr      PMSG      NO.. PROMPT FOR IT
                    fcb       19
                    leax      DISKNAME,U
                    ldy       #32       MAX LENGTH
                    clra                PATH      NO.
                    os9       I$READLN
                    lbcs      ABORT
                    tfr       Y,D       FIND LAST BYTE
DNAM1               decb                CALC      OFFSET
                    lda       B,X
                    tstb                EMPTY     LINE?
                    beq       DNAM2
                    cmpa      #C$CR     CR?
                    beq       DNAM1     CHOP IT OFF
DNAM2               ora       #$80      SET BIT 7
                    sta       B,X
LSNF2               lda       #$FF      DISK ATTRIBUTES
                    sta       LSN0+DD.ATT
* CALCULATE SEMI RANDOM VALUE FOR DD.DSK
                    ldd       LSN0+DD.DAT+1
                    addd      LSN0+DD.DAT+3 USE TIME
                    pshs      D         ROLL IT AROUND
                    ldb       LSN0+DD.DAT+4 USE SECONDS AS CNTR
                    leax      DISKNAME,U
DSK1                lda       ,S
                    eora      B,X
                    sta       ,S
                    rola
                    rol       1,S
                    rol       ,S
                    decb
                    bne       DSK1
                    puls      D         .DSK VALUE
                    addd      DENSITY   MUTILATE IT SOME MORE
                    subd      TYPE
                    addd      USAVE
                    subd      PARMPTR
                    std       LSN0+DD.DSK SAVE IT
*CLEAR TRKBUF
                    leax      TRKBUF,U
                    ldy       #$1000
LSNF3               clr       ,X+
                    leay      -1,Y      CNT DOWN
                    bne       LSNF3

                    lda       DEVPATH
                    ldb       #SS.RESET
                    os9       I$SETSTT  RESTORE DRIVE
                    ldy       #256
                    leax      LSN0,U    WRITE FIRST PART OF LSN0
                    os9       I$WRITE
                    lbcs      ABORT

*******************************************************
* SET UP SECTOR ALLOCATION MAP
*******************************************************
                    ldd       LSN0+DD.MAP
                    inca                NUMBER    OF MAP SECTORS
                    clrb                D=        NUMBER OF BYTES IN MAP SECTORS
                    tfr       D,Y
                    leax      TRKBUF,U  FILL WITH FF'S
                    lda       #$FF
FILLFF              sta       ,X+
                    leay      -1,Y
                    bne       FILLFF
                    ldy       LSN0+DD.TOT+1 NUMBER OF MEDIA SECTORS
                    leax      TRKBUF,U  ALLOCATION MAP
                    clra                BEGINNING BIT
                    clrb
                    os9       F$DELBIT  DEALLOCATE ALL SECTORS
                    ldb       LSN0+DD.MAP NUMBER OF MAP SECTORS IN EXCESS OF 1
                    addb      #2        ADD FOR LSN0 AND MAP SECT 0
                    addb      DEVOPTS-PD.OPT+PD.SAS ALLOCATE 1 SEG FOR DIR
                    std       MINSECS   SAVE THIS USEFUL INFO FOR VERIFY
                    tfr       D,Y       BIT CNT
                    clra
                    clrb
                    os9       F$ALLBIT  ALLOCATE FOR USED SECTORS

*
* CLOSE DEVICE AND REOPEN AS READ
*
                    lda       DEVPATH
                    os9       I$CLOSE
                    bcc       REOP
XABOR               lbra      XABORT    ERROR RELAY JUMP

REOP                leax      DEVNAME,U
                    lda       #READ.
                    os9       I$OPEN
                    bcs       XABOR
                    sta       DEVPATH
                    leax      VBUFFER,U READ 2 SECTORS TO FORCE
                    ldy       #256      LSN0 PARAM READ
                    os9       I$READ
                    bcs       XABOR
                    os9       I$READ
                    bcs       XABOR
*
* CLOSE DEVICE AND RE-OPEN IN UPDATE MODE
*
                    lda       DEVPATH
                    os9       I$CLOSE
                    bcs       XABOR
                    leax      DEVNAME,U
                    lda       #UPDAT.
                    os9       I$OPEN
                    bcs       XABOR
                    sta       DEVPATH

*******************************************************
* VERIFY SECTORS AND MAP OUT ANY BADS
*******************************************************
                    ldd       LSN0+DD.TOT+1 MEDIA SECTOR CNT
                    std       GOODCNT   ASSUME ALL GOOD UNTIL PROVEN GUILTY

* SEEK LSN0
                    lda       DEVPATH
                    ldx       #0
                    tfr       X,U
                    os9       I$SEEK
                    ldu       USAVE     RESTORE U
                    lbcs      VABORT

                    lbsr      PMSG      PRINT VERIFY MSG
                    fcb       20

VERFY0              ldd       VSECT     NEXT SECTOR TO VERIFY
                    cmpd      LSN0+DD.TOT+1 DONE?
                    lbeq      VERFY4    IF SO
                    tst       VCNT      START OF NEW TRACK?
                    bne       VERFY1    NO

                    ldy       #1        YES
                    leax      CRCR,PCR  SEND A CR
                    lda       #1
                    os9       I$WRITE
                    bcs       VABORT
                    ldb       VTRACK+1
                    lbsr      PDECIMAL  PRINT THE TRACK NUMBER
                    leax      SPACE,PCR AND A SPACE
                    ldy       #1
                    lda       #1
                    os9       I$WRITLN
                    bcs       VABORT

* DO THE VERIFY READ NOW
VERFY1              leax      VBUFFER,U
                    ldy       #256
                    lda       DEVPATH
                    os9       I$READ    READ VSECT FROM DISK
                    bcc       VERFY2    IF OK

*BAD SECTOR.. MAP IT OUT
                    ldd       VSECT     BAD SECT #
                    cmpd      MINSECS   IS IT A CRITICAL ONE?
                    blo       BADDISK   IF SO
                    ldy       #1        ONE BIT
                    leax      TRKBUF,U
                    os9       F$ALLBIT  MAP OUT
                    ldd       GOODCNT   DEC CNT OF GOODS
                    subd      #1
                    std       GOODCNT

*SEEK TO NEXT SECTOR
                    clrb
                    pshs      B
                    ldd       VSECT
                    addd      #1
                    pshs      D
                    clrb
                    pshs      B
                    puls      X,U       NEW FILE POSITION
                    lda       DEVPATH
                    os9       I$SEEK
                    ldu       USAVE
                    bcs       VABORT

VERFY2              ldd       VSECT     BUMP SECTOR NUMBER
                    addd      #1
                    std       VSECT
                    inc       VCNT      AND SECTOR CNT ON CURRENT TRK
                    ldb       TRK0SIZE
                    clra
                    cmpd      VSECT     STILL ON TRK 0?
                    bhs       VERFY3    YES
                    ldb       SECTS     NO.. GET SIZE OF OTHER TRKS
VERFY3              cmpb      VCNT      NEW TRACK?
                    bne       V0JUMP
                    clr       VCNT
                    inc       VTRACK+1
V0JUMP              lbra      VERFY0

BADDISK             lbsr      PMSG      BAD SYS SECTOR MESSAGE
                    fcb       38
                    ldb       #1        UNCONDITIONAL ABORT
VABORT              lbra      XABORT

*******************************************************
* DONE WITH VERIFY PRINT GOOD SECTORS
*******************************************************
VERFY4              lbsr      PMSG      PRINT CR
                    fcb       14
                    ldd       GOODCNT   CONVERT CNT TO DECIMAL
                    leax      NBUF,U
                    ldy       #4        Z SUPPRESS CNT
                    lbsr      CONVERT
                    leax      NBUF,U
                    ldy       #5
                    lda       #1
                    os9       I$WRITLN  PRINT GOODCNT
                    bcs       VABORT
                    lbsr      PMSG
                    fcb       21

*
* SEEK TO LSN 1
                    ldx       #0
                    ldu       #$100
                    lda       DEVPATH
                    os9       I$SEEK
                    ldu       USAVE
                    bcs       VABORT
*
* BUILD ROOT DIR IN TRKBUF
*
                    leax      TRKBUF,U
                    lda       LSN0+DD.DIR+2 ROOT DIR SECT NO.
                    deca
                    clrb
                    leax      D,X       PNT TO ROOT DIR IN TRKBUF

                    lda       #$BF
                    sta       FD.ATT,X
                    ldd       LSN0+DD.DAT MOVE DATE
                    std       FD.DAT,X
                    std       FD.CREAT,X
                    ldd       LSN0+DD.DAT+2
                    std       FD.DAT+2,X
                    sta       FD.CREAT+2,X
                    lda       LSN0+DD.DAT+4
                    sta       FD.DAT+4,X
                    lda       #$40      ROOT DIR SIZE
                    sta       FD.SIZ+3,X
                    ldb       LSN0+DD.DIR+2 ROOT DIR SECT NO.
                    stb       $100+31,X SET UP FOR ..
                    stb       $120+31,X AND .
                    incb
                    stb       FD.SEG+2,X SET UP SEG IN FDS
                    ldb       DEVOPTS-PD.OPT+PD.SAS GET SEG ALLOC SIZE
                    decb                BUG       HERE IF PD.SAS < 2
                    stb       FD.SEG+4,X
                    ldd       #$2EAE
                    std       $100,X    ..
                    stb       $120,X    .
*
* WRITE THE STUFF TO DISK
*
                    lda       MINSECS+1
                    deca                NUMBER    OF SECS TO WRITE
                    clrb
                    tfr       D,Y       # OF BYTES
                    leax      TRKBUF,U
                    lda       DEVPATH
                    os9       I$WRITE
                    bcs       XABORT

*******************************************************
* ALL DONE
*******************************************************

EXIT                ldu       DEVTPTR   PTR TO TABLE ENTRY
                    os9       I$DETACH
SABORT              clrb
XABORT              pshs      CC,B      SAVE ERROR CODE
                    ldb       ONEPAU    RESET PAUSE VALUE
                    ldu       USAVE     RESTORE U
                    leax      ONEOPTS,U
                    stb       PD.PAU-PD.OPT,X
                    lda       #1        PATH NO.
                    clrb                SS.OPT
                    os9       I$SETSTT  RESET PAUSE VALUE
                    puls      B,CC      RESTORE ERROR CODE
ZABORT              os9       F$EXIT    EXIT PROGRAM

*
*FORMAT A TRACK (A=TRACK B=SIDE)
*
FMTTRK              bsr       SETTS     SET THE TRACK AND SECT NOS. IN TABLE
                    pshs      U         SAVE REG
                    clra
                    ldb       DENSITY
                    orb       TPI       ADD IN TPI DENSITY
                    aslb
                    orb       SIDEN     SET SIDE AN DENSITY
                    tfr       D,Y
                    ldb       TRACKN
                    pshs      D         SET UP TRACK NO.
                    leax      TRKBUF,U
                    puls      U
                    lda       DEVPATH
                    ldb       #SS.WTRK
                    os9       I$SETSTT  FORMAT A TRACK
                    bcc       FMTRK9
ABORT2              bra       XABORT    ON ERROR
FMTRK9              ldd       LSN0+DD.TOT+1 UPDATE SECTOR CNT
                    addb      SECTORS
                    adca      #0
                    std       LSN0+DD.TOT+1
                    puls      U,PC

*
*  A= TRACK
* B= SIDE
* sets track and side nos. into sector headers in trkbuf
*
SETTS               std       TRACKN    SAVE VALUES
                    ldb       SECTORS   COUNT OF SECTORS THIS TRACK
                    pshs      B
                    ldx       TN0PTR    PNT INTO TRKBUF
SETTS1              ldd       TRACKN
                    std       ,X
                    tfr       X,D
                    addd      SCCSIZ    ADD OFFSET TO NEXT HEADER
                    tfr       D,X
                    dec       ,S        COUNT DOWN SECTORS
                    bne       SETTS1
                    puls      B,PC
*******************************************************

*******************************************************
* FILL TRKBUF WITH DATA TO FORMAT TRACK
* INPUT X = TRACK TABLE PTR
*       A = # OF SECTORS
* OUPUT: TRKBUF CONTAINS PATTERN FOR FORMAT
*******************************************************
MAKTRK              sta       SECTORS   SAVE NUMBER OF SECTS IN TRACK
                    ldb       INTERLV   GET INTERLEAVE #
                    lbsr      SETI      CALC INTERLEAVE TABLE
                    leay      TRKBUF,U  PNT TO BUFFER
                    clrb
                    pshs      D,X       SAVE SECTOR CNT AND PNTR
                    ldd       -2,X      GET FORMAT SECT LEN
                    std       SCCSIZ    SAVE IT
                    ldb       #5        TABLE ENTRY CNT
                    bsr       FILLBUF   FILL IN INDEX HEADER
                    stx       SPTR      SAVE TABLE PTR
                    ldb       #3
                    bsr       FILLBUF   FILL IN BEG OF 1ST SECTOR
                    sty       TN0PTR    SAVE PNTR FOR HEADER INSERTION
                    ldb       #9        DO REST OF SECTOR
                    bsr       FILLBUF
                    ldb       ,S        GET NUMBER OF SECTORS THIS TRK
                    decb                ADJUST    FOR 1 WE JUST DID
                    pshs      B         STACK CNT
MAKE1               ldx       SPTR      GET FORMAT TABLE PTR
                    ldb       #12       TABLE ELEMENT CNT
                    bsr       FILLBUF
                    dec       ,S        COUNT OF SECTORS
                    bne       MAKE1
                    leas      1,S       CLEAN STACK

                    leax      BUFEND,U  CALC REMAINING BUF SPACE
                    tfr       X,D
                    pshs      Y         CURRENT BUF PTR
                    subd      ,S
                    std       ,S
                    ldx       4,S       TRK TABLE PTR
                    lda       1,X       GET FILL BYTE
                    puls      X
MAKE2               sta       ,Y+       FILL TO END OF TRACK TABLE
                    leax      -1,X      CNT DOWN
                    bne       MAKE2

* FILL IN SECTOR NOS. FROM INTERLEAVE TABLE
                    ldy       TN0PTR
                    leax      ILVTAB,U  INTERLEAVE TABLE PTR
                    ldb       1,S       GET FIRST SECTOR NO. OFFSET
MAKE3               lda       B,X       PICK UP SECTOR NO. FROM TABLE
                    tst       TYPE      CHECK DISK TYPE
                    beq       MAKE4     IF STANDARD
                    inca                ADJUST    SECTOR NO. FOR COCO
MAKE4               sta       2,Y       PUT IT IN SECTOR HEADER
                    incb                NEXT      OFFSET TO TABLE
                    stb       1,S
                    tfr       Y,D
                    addd      SCCSIZ    POINT TO NEXT HEADER IN TRKBUF
                    tfr       D,Y       PUT PTR BACK
                    ldb       1,S       SEE IF DONE
                    cmpb      ,S
                    bne       MAKE3
                    puls      D,X,PC

*
* X= TABLE PNTR   B=ENTRY CNT
* FILLS TRKBUF WITH FORMAT BYTES
*
FILLBUF             pshs      B         SAVE CNT
FILL1               ldd       ,X++      A=CNT B=VALUE
FILL2               stb       ,Y+
                    deca
                    bne       FILL2
                    dec       ,S        ANOTHER ENTRY?
                    bne       FILL1     YES
                    puls      B,PC
*******************************************************

*******************************************************
* CALCULATE SECTOR INTERLEAVE
* INPUT: A = # OF SECTORS
*        B = INTERLEAVE VALUE
* OUTPUT: ILVTAB FILLED WITH INTERLEAVE PATTERN
*  (UNUSED SECTORS = $FF
*******************************************************
SETI                pshs      D,X       SAVE REGS
* 0,S = SECTORS/TRAK  1,S = INTERLEAVE
                    leax      ILVTAB,U  INTERLEAVE TABLE PTR
                    lda       #$FF
                    ldb       #ISIZE
SETI1               sta       ,X+       INIT TABLE
                    decb
                    bne       SETI1
                    leax      ILVTAB,U  FIX PTR
                    clra                SECTOR    # TO PUT IN TABLE
                    clrb                TABLE     OFFSET
                    bra       SETI3
SETI2               incb                POSTION   TAKEN.. TRY NEXT
SETI3               cmpb      ,S        PAST END OF TRACK?
                    bcs       SETI4     NO
                    subb      ,S        YES.. WRAP AROUND
SETI4               tst       B,X       TABLE POSITION TAKEN?
                    bpl       SETI2     YES.. TRY NEXT
                    sta       B,X       NO..STORE SECTOR NUMBER IN TABLE
                    inca                NEXT      SECTOR NUMBER
                    cmpa      ,S        DONE?
                    beq       SETI9     YES
                    addb      1,S       NO..ADD INTERLEAVE VALUE TO OFFSET
                    bra       SETI3
SETI9               puls      D,X,PC
*******************************************************

TYPERR              ldb       #E$BTYP
                    os9       F$EXIT    TYPE MISMATCH ERROR

SYNABORT            bsr       SYNPRT
                    lbra      SABORT

PM                  lbra      PMSG      GO PRINT MESSAGE
*
* PRINT SYNTAX
*
SYNPRT              bsr       PM
                    fcb       25
                    bsr       PM
                    fcb       26
                    bsr       PM
                    fcb       27
                    bsr       PM
                    fcb       28
                    bsr       PM
                    fcb       29
                    bsr       PM
                    fcb       30
                    bsr       PM
                    fcb       31
                    bsr       PM
                    fcb       32
* BSR PM
* FCB 33
                    bsr       PM
                    fcb       34
                    bsr       PM
                    fcb       35
                    bsr       PM
                    fcb       36
                    rts

                    fdb       $02C4     reserve for serial no.

                    emod
EndFmt              equ       *
                    end
