*****************************************
*       "MC2681"
* Interrupt driven MC2681 device driver
*    (c) 1984 by David C. Wiens,
*       All rights reserved
* Last modified july 5, 1985 12:10 pm
*****************************************
                  IFP1
                    use       defsfile
                  ENDC

*
* Equates
*
BSIZE               equ       128       Size of buffer
MSKCNTR             equ       $7F       Truncates to mod 128
BFULL               equ       BSIZE-1   High water mark (full)
BWAKE               equ       (BSIZE*7)/8 Low water mark at which to waken
*
* Static storage offsets
*
                    org       V.SCF
DART0               rmb       2         Base address of duart chip
MSKART              rmb       3         Interrupt packet
INTMI               rmb       1         Duart receiver interrupt mask
INTMO               rmb       1         Duart transmitter interrupt mask
SAVCHAR             rmb       1         Save area for received character
IPTRH               rmb       1         Input buffer next-in pointer (head)
IPTRT               rmb       1         Input buffer next-out pointer (tail)
ICNT                rmb       1         Input buffer byte count
OPTRH               rmb       1         Output buffer next-in pointer
OPTRT               rmb       1         Output buffer next-out pointer
OCNT                rmb       1         Output buffer byte count
XOFFLG              rmb       1         X-off pause flag (non-zero = paused)
OUTBUF              rmb       BSIZE     Output buffer
INBUF               rmb       BSIZE     Input buffer
MemSize             equ       .

Rev                 set       1
Edition             set       5

*******************
* Header info
*******************
                    mod       ModSize,ModName,Drivr+Objct,ReEnt+Rev,ModEntry,MemSize

                    fcb       $07       Exec/Write/Read
ModName             fcs       'MC2681'
                    fcb       Edition

ModEntry
                    lbra      ARTINIT   Init
                    lbra      ARTINCH   Get character from port
                    lbra      ARTOUTC   Output character
                    lbra      ARTGET    Get status
                    lbra      ARTSET    Set status
                    lbra      ARTCLOS   Close driver

TBAUDR              fcb       $11       110   baud rate codes
                    fcb       $44       300
                    fcb       $55       600
                    fcb       $66       1200
                    fcb       $88       2400
                    fcb       $99       4800
                    fcb       $BB       9600
                    fcb       $CC       38400 (19200 in alternative mode)

*****************************************
* Init port
* In - U static storage
*      Y address of initial device descriptor module
*****************************************
ARTINIT             ldd       V.PORT,U
                    andb      #$F0
                    std       DART0,U
                    lda       #$01
                    ldb       V.PORT+1,U Port b?
                    andb      #$08
                    beq       AI05      .N, port A
                    lsla                .Y, shift left for B
                    lsla
                    lsla
                    lsla
AI05                sta       INTMO,U
                    lsla
                    sta       INTMI,U

                    ldd       V.PORT,U  If port A ($FF20) check ARTLEN
                    cmpd      #$FF20    . for parity/word length
                    bne       AI04
                    lda       ARTLEN
                    bra       AI07
AI04                lda       IT.PAR,Y  Get parity/word length
AI07                pshs      A
                    ldd       V.PORT,U  If port A ($FF20), check ARTBAU for baud rate
                    cmpd      #$FF20
                    bne       AI01
                    lda       ARTBAU
                    cmpa      #$FF      If $FF, code not defined
                    bne       AI03
AI01                lda       IT.BAU,Y  Get baud rate code
                    cmpa      #7        0-7 is valid
                    bls       AI02
                    lda       #7        .N, default to 38400
AI02                leax      <TBAUDR,PCR
                    lda       A,X
AI03                ldy       V.PORT,U
                    sta       1,Y
                    lda       #$10      Reset pointer to MR1X
                    sta       2,Y
                    lda       ,S        Set parity/bits per word
                    bmi       AI06
                    lda       #$13      Default = None/8
AI06                anda      #$1F
                    ora       #$80      Set Rx controls RTS
                    sta       ,Y
                    lda       ,S+       Set stop bits
                    bmi       AI08
                    lda       #$20      Default to 2
AI08                lsra
                    lsra
                    anda      #$08
                    ora       #$17      Set rest of stop bits to complete 1 or 2, and set CTS enable Tx
                    sta       ,Y

AI15                lda       1,Y       Flush fifo
                    bita      #$01
                    beq       AI20
                    lda       3,Y
                    bra       AI15
AI20                lda       #$40      Reset error status
                    sta       2,Y
                    clr       V.ERR,U

                    clr       MSKART,U  Flip byte = 0
                    lda       INTMI,U
                    ora       INTMO,U
                    sta       MSKART+1,U Mask byte
                    ldd       V.PORT,U  If port A ($FF20) set higher priority
                    cmpd      #$FF20
                    bne       AI30
                    lda       #200
                    bra       AI35
AI30                lda       #100
AI35                sta       MSKART+2,U Priority

                    ldd       DART0,U
                    addd      #5
                    leax      MSKART,U
                    leay      DIRQ,PCR
                    os9       F$IRQ     Add to IRQ polling table
                    bcs       AI90

                    pshs      CC
                    orcc      #IRQMask
                    clr       IPTRH,U   Clear pointers and counts
                    clr       IPTRT,U
                    clr       OPTRH,U
                    clr       OPTRT,U
                    clr       ICNT,U
                    clr       OCNT,U
                    clr       XOFFLG,U
                    lda       INTMI,U   Enable receive interrupt
                    jsr       [DINTON]
                    puls      CC
AI90                rts

*****************************************
* Input character from port
* In - U static storage
*      Y path descriptor
* Out - A character recd
*****************************************
ARTINCH             orcc      #IRQMask
                    tst       ICNT,U    Buffer has character waiting?
                    bne       AN50      .y

                    bsr       SLEEP
                    beq       ARTINCH   No signal waiting
                    coma                Return    return-signal as error
                    rts

AN50                leax      INBUF,U
                    ldb       IPTRT,U
                    lda       B,X       Get character
                    incb
                    andb      #MSKCNTR
                    stb       IPTRT,U
                    dec       ICNT,U
                    clrb

                    ldb       V.ERR,U   Errors?
                    beq       AN60      .n
                    stb       PD.ERR,Y  .y
                    clr       V.ERR,U
                    comb
                    ldb       #E$Read
AN60                andcc     #^IRQMask
                    rts

****************************************
* Output character to port
*  (make as efficient as possible)
* In - A character to write
*      U static storage
*      Y path descriptor
****************************************
ARTOUTC             orcc      #IRQMask
                    ldb       OCNT,U    Any space left in transmit buffer?
                    cmpb      #BFULL
                    blo       AO50      .Y

                    bsr       SLEEP
                    beq       ARTOUTC   No signal waiting
                    coma                Return    return-signal as error
                    rts

AO50                leax      OUTBUF,U
                    ldb       OPTRH,U
                    sta       B,X       Store character
                    incb
                    andb      #MSKCNTR
                    stb       OPTRH,U
                    inc       OCNT,U
                    tst       XOFFLG,U  Xoff pause in effect?
                    bne       AO70      .y
                    lda       INTMO,U   Buffer being filled, so
                    jsr       [DINTON]  .  re-enable interrupt
AO70                andcc     #^(Carry+IRQMask) .  and clear carry
                    rts

*
* Sleep until buffer ready
*
SLEEP               ldb       V.BUSY,U  .N
                    stb       V.WAKE,U
                    andcc     #^IRQMask

                    ldx       #0
                    os9       F$SLEEP   Sleep indefinitely

                    ldx       >D.PROC
                    ldb       P$Signal,X Signal waiting?
                    rts

****************************************
* Interrupt handler routine
*  (make as efficient as possible)
* In - A contents of status register of port
*         (after flipping and masking bits)
*      U static storage address
****************************************
DIRQ                ldy       V.PORT,U
                    anda      ARTINT
                    bita      INTMO,U
                    bne       DIRQO
                    bita      INTMI,U
                    bne       DIRQI
                    orcc      #Carry    Interrupt not caused by this device
                    rts
*
* Output interrupt handler routine
*  (make as efficient as possible)
* In - U static storage address
*      Y address of port A or B
*
DIRQO               leax      OUTBUF,U
                    ldb       OPTRT,U
                    lda       B,X       get character from buffer
                    sta       3,Y       send to transmitter
                    incb                ADJUST    pointer
                    andb      #MSKCNTR
                    stb       OPTRT,U
                    dec       OCNT,U    Tx buffer now empty?
                    beq       DO60      .Y
                    ldb       OCNT,U    .N, reached wakeup level?
                    cmpb      #BWAKE
                    lbeq      WAKE      .Y
                    clrb                .N
                    rts
DO60                lda       INTMO,U   .Y, disable TxRdy interrupts
                    jsr       [DINTOF]
                    lbra      WAKE
*
* Input interrupt handler routine
* In - U static storage address
*      Y address of port A or B
*
DIRQI               lda       1,Y       Get error status
                    anda      #$F0
                    ora       V.ERR,U   Update cumulative errors
                    sta       V.ERR,U
                    lda       #$40      Reset overrun error status bit
                    sta       2,Y
                    lda       3,Y       Get character from receiver
                    sta       SAVCHAR,U

                    anda      #$7F
                    beq       DI40      Pass nulls thru
                    cmpa      V.XON,U   Xon characterter?
                    beq       DI80      .Y
                    cmpa      V.XOFF,U  Xoff characterter?
                    beq       DI85      .Y

DI40                lda       SAVCHAR,U Store characterter into buffer
                    leax      INBUF,U
                    ldb       IPTRH,U
                    sta       B,X
                    lda       ICNT,U
                    cmpa      #BFULL    Buffer was already full?
                    blo       DI50
                    lda       V.ERR,U   .Y, overrun error
                    ora       #$10
                    sta       V.ERR,U
                    bra       DI60      Don't adjust buffer count/pointer

DI50                inca                ADJUST    Buffer count and pointer
                    sta       ICNT,U
                    incb
                    andb      #MSKCNTR
                    stb       IPTRH,U

DI60                lda       SAVCHAR,U
                    anda      #$7F
                    beq       WAKE      Pass nulls thru
                    cmpa      V.PCHR,U  Pause character?
                    bne       DI65      .N
                    ldx       V.DEV2,U  Get address of output device
                    beq       WAKE      .None
                    sta       V.PAUS,X  Request pause
                    bra       WAKE
DI65                ldb       #S$Intrpt (Interrupt signal)
                    cmpa      V.INTR,U  Keyboard interrupt?
                    beq       DI70      .y
                    ldb       #S$Abort  (Abort signal)
                    cmpa      V.QUIT,U  Keyboard abort?
                    bne       WAKE      .n
DI70                lda       V.LPRC,U
                    bra       WI50

DI80                clr       XOFFLG,U  Process xon characterter
                    tst       OCNT,U
                    beq       WK95
                    lda       INTMO,U
                    jsr       [DINTON]
                    bra       WK95

DI85                lda       #$FF      Process xoff characterter
                    sta       XOFFLG,U
                    lda       INTMO,U
                    jsr       [DINTOF]
                    bra       WK95

WAKE                ldb       #S$WAKE   Wakeup signal
                    lda       V.WAKE,U  Get process id
WI50                beq       WK90      .None, return
                    os9       F$Send    Send signal
WK90                clr       V.WAKE,U
WK95                andcc     #^Carry
                    rts

****************************************
* Get/Set status
* In - U static storage address
****************************************
ARTGET              cmpa      #SS.READY Status check?
                    bne       AG60      .N
                    tst       ICNT,U    Data avail?
                    bne       AG90      .Y
                    comb                .N
                    ldb       #E$NotRdy
                    rts
AG60                cmpa      #SS.EOF
                    bne       AS80
AG90                clrb
                    rts

ARTSET              equ       *
AS80                comb
                    ldb       #E$UNKSVC
                    rts

***************************************
* Deactivate this device driver
* In - U static storage address
***************************************
ARTCLOS             ldx       >D.PROC
                    lda       P$ID,X
                    sta       V.BUSY,U
                    sta       V.LPRC,U
                    orcc      #IRQMask
                    tst       OCNT,U
                    beq       AT50
                    lbsr      SLEEP
                    beq       ARTCLOS   No signal waiting
                    coma                Return    return-signal as error
                    rts

AT50                lda       INTMI,U   Disable both interrupts
                    ora       INTMO,U
                    jsr       [DINTOF]
                    andcc     #^IRQMask
                    ldx       #0        Remove device from polling table
                    os9       F$IRQ
                    rts

                    emod
ModSize             equ       *

