*****************************************
*   "Clock" module for ST-2900 system
* NitrOS-9 clock using MC2681 DUART timer
*    (c) 1984 by David C. Wiens
* Last modified June 19, 1985 9:00 pm
*****************************************
                    nam       Clock
                    ttl       NitrOS-9 System Clock

                  IFP1
                    use       defsfile
                  ENDC


****************************************
* header and constants
****************************************
TPS                 equ       50        Ticks per second

TyLg                set       Systm+Objct
AtRv                set       ReEnt+Rev
Rev                 set       1
Edition             set       3

                    mod       ModLen,Name,TyLg,AtRv,Entry,0

Name                fcs       "Clock"
                    fcb       Edition

* DUART counter/timer constant = crystal / 16 / ticks per second
* 3.6864 MHz / 16 = 230400 Hz; 230400 / 50 = 4608
Divide              fdb       4608      Time constant for DUART clock timer (50 hz)
*
* packet to define f$time svc
*
TIMSVC              fcb       F$Time
                    fdb       GetTime-*-2 offset to handler
                    fcb       $80
*
* table of days per month
*
Month               fcb       0
                    fcb       31,28,31,30
                    fcb       31,30,31,31
                    fcb       30,31,30,31

*****************************************
* clock initialization
*****************************************
Entry               pshs      CC,DP
                    clra
                    tfr       A,DP

                    setdp     $00

                    orcc      #IntMasks
                    lda       #TPS      Init ticks per second (must be >= 5)
                    sta       <D.TSec
                    sta       <D.TicK
                    lda       #1        Init ticks per time slice
                    sta       <D.TSlice
                    sta       <D.Slice
                    clr       MISTIC    Init missed ticks counter

                    leax      <ClkSrv,PCR
                    stx       D.IRQ

                    lda       #$70      Set timer to count using 3.6864 mhz
                    jsr       [DACRON]  . crystal clock /16

                    ldd       <Divide,PCR load timer constant
                    std       Duart+6
                    lda       Duart+14  Restart timer
                    lda       Duart+15  Reset timer interrupt flag

                    lda       #$08      Enable timer interrupt
                    jsr       [DINTON]
                    puls      CC        Unmask interrupts

                    leay      <TIMSVC,PCR Add F$Time svc
                    os9       F$SSVC
                    puls      DP,PC     Restore dp

*******************************************
* clock interrupt service routine
*******************************************
ClkSrv              lda       Duart+5   Get Duart interrupt flags
                    anda      ARTINT    Mask
                    bita      #$08      Mid timer generate interrupt?
                    bne       C10       .y
                    jmp       [D.SvcIRQ] .n
C10                 lda       Duart+15  Reset timer interrupt flag

                    clra
                    tfr       A,DP

                    setdp     $00

                    ldb       MISTIC    Get number of missed ticks
                    clr       MISTIC    Reset missed tick counter
                    incb

C20                 cmpb      D.Tsec    Apply mistic to d_sec until mistic < d_tsec
                    blo       C25
                    inc       D.Sec
                    subb      D.TSec
                    bne       C20

C25                 cmpb      D.Tick    MISTIC < D_Tick?
                    bhs       C30       .n
                    negb                .y,       D.Tick = D_Tick - MISTIC
                    addb      D.Tick
                    stb       D.Tick
                    bra       C40

C30                 subb      D.Tick
                    negb
                    addb      D.Tsec
                    stb       D.Tick
                    inc       D.Sec

C40                 lda       D.Sec     Normalize seconds
                    cmpa      #59
                    bls       C95
                    suba      #60
                    sta       D.Sec

                    inc       D.Min     Increment and normalize minutes
                    lda       D.Min
                    cmpa      #59
                    bls       C95
                    clr       D.Min

                    inc       D.Hour    Increment and normalize hour
                    lda       D.Hour
                    cmpa      #23
                    bls       C95
                    clr       D.Hour

                    inc       D.Day     Increment and normalize day of month
                    leax      Month,PCR
                    lda       D.Month
                    ldb       A,X       Get days-in-this-month
                    cmpa      #2        February?
                    bne       C50       .n
                    lda       D.Year    Year = 00?
                    beq       C50       .y
                    bita      #$03      Leap year?
                    bne       C50       .n
                    incb                .y,       Increment days-in-this-month
C50                 cmpb      D.Day
                    bhs       C95
                    lda       #1
                    sta       D.Day

                    inc       D.Month   Increment and normalize month
                    lda       D.Month
                    cmpa      #12
                    bls       C95
                    lda       #1
                    sta       D.Month

                    inc       D.Year    Increment year

C95                 jmp       [D.Clock]

****************************************
* f$time svc code
****************************************
GetTime             ldx       R$X,U
                    ldd       D.Min     Move min/sec
                    std       4,X
                    ldd       D.Day     Move day/hour
                    std       2,X
                    ldd       D.Year    Move year/month
                    std       ,X
                    clrb                Clear     carry
                    rts

                    emod
ModLen              equ       *
                    end

