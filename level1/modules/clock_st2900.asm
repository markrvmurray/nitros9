*****************************************
*   "Clock" module for ST-2900 system
* Running Radio Shack Coco version of OS-9
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
TPS                 EQU       10        Ticks per second

TyLg                set       Systm+Objct
AtRv                set       ReEnt+Rev
Rev                 set       1
Edition             set       3

                    mod       ModLen,Name,TyLg,AtRv,Entry,0

Name                fcs       "Clock"
                    fcb       Edition

Divide              FDB       11520     Time constant for DUART clock timer (10 hz)
*
* packet to define f$time svc
*
TIMSVC              FCB       F$Time
                    FDB       GetTime-*-2 offset to handler
                    FCB       $80
*
* table of days per month
*
Month               FCB       0
                    FCB       31,28,31,30
                    FCB       31,30,31,31
                    FCB       30,31,30,31

*****************************************
* clock initialization
*****************************************
Entry               PSHS      CC,DP
                    CLRA
                    TFR       A,DP

                    SETDP     $00

                    ORCC      #IntMasks
                    LDA       #TPS      Init ticks per second (must be >= 5)
                    STA       <D.TSec
                    STA       <D.TicK
                    LDA       #1        Init ticks per time slice
                    STA       <D.TSlice
                    STA       <D.Slice
                    CLR       MISTIC    Init missed ticks counter

                    LEAX      <ClkSrv,PCR
                    STX       D.IRQ

                    LDA       #$70      Set timer to count using 3.6864 mhz
                    JSR       [DACRON]  . crystal clock /16

                    LDD       <Divide,PCR /11520 = 10 hz
                    STD       Duart+6
                    LDA       Duart+14  Restart timer
                    LDA       Duart+15  Reset timer interrupt flag

                    LDA       #$08      Enable timer interrupt
                    JSR       [DINTON]
                    PULS      CC        Unmask interrupts

                    LEAY      <TIMSVC,PCR Add F$Time svc
                    OS9       F$SSVC
                    PULS      DP,PC     Restore dp

*******************************************
* clock interrupt service routine
*******************************************
ClkSrv              LDA       Duart+5   Get Duart interrupt flags
                    ANDA      ARTINT    Mask
                    BITA      #$08      Mid timer generate interrupt?
                    BNE       C10       .y
                    JMP       [D.SvcIRQ] .n
C10                 LDA       Duart+15  Reset timer interrupt flag

                    CLRA
                    TFR       A,DP

                    SETDP     $00

                    LDB       MISTIC    Get number of missed ticks
                    CLR       MISTIC    Reset missed tick counter
                    INCB

C20                 CMPB      D.Tsec    Apply mistic to d_sec until mistic < d_tsec
                    BLO       C25
                    INC       D.Sec
                    SUBB      D.TSec
                    BNE       C20

C25                 CMPB      D.Tick    MISTIC < D_Tick?
                    BHS       C30       .n
                    NEGB      .y,       D.Tick = D_Tick - MISTIC
                    ADDB      D.Tick
                    STB       D.Tick
                    BRA       C40

C30                 SUBB      D.Tick
                    NEGB
                    ADDB      D.Tsec
                    STB       D.Tick
                    INC       D.Sec

C40                 LDA       D.Sec     Normalize seconds
                    CMPA      #59
                    BLS       C95
                    SUBA      #60
                    STA       D.Sec

                    INC       D.Min     Increment and normalize minutes
                    LDA       D.Min
                    CMPA      #59
                    BLS       C95
                    CLR       D.Min

                    INC       D.Hour    Increment and normalize hour
                    LDA       D.Hour
                    CMPA      #23
                    BLS       C95
                    CLR       D.Hour

                    INC       D.Day     Increment and normalize day of month
                    LEAX      Month,PCR
                    LDA       D.Month
                    LDB       A,X       Get days-in-this-month
                    CMPA      #2        February?
                    BNE       C50       .n
                    LDA       D.Year    Year = 00?
                    BEQ       C50       .y
                    BITA      #$03      Leap year?
                    BNE       C50       .n
                    INCB      .y,       Increment days-in-this-month
C50                 CMPB      D.Day
                    BHS       C95
                    LDA       #1
                    STA       D.Day

                    INC       D.Month   Increment and normalize month
                    LDA       D.Month
                    CMPA      #12
                    BLS       C95
                    LDA       #1
                    STA       D.Month

                    INC       D.Year    Increment year

C95                 JMP       [D.Clock]

****************************************
* f$time svc code
****************************************
GetTime             LDX       R$X,U
                    LDD       D.Min     Move min/sec
                    STD       4,X
                    LDD       D.Day     Move day/hour
                    STD       2,X
                    LDD       D.Year    Move year/month
                    STD       ,X
                    CLRB      Clear     carry
                    RTS

                    emod
ModLen              equ       *
                    end

