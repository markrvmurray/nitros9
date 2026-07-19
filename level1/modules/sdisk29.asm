*******************************************
*          "SDISK29"
* Device driver module for floppy disk controller.
*  It is a replacement module for the "ccdisk"
*  module found on a "virgin" coco os-9
*  disk.
* Based on source code for sdisk licensed from
*  D.P. Johnson.
*
* NOTE - default setting enables write precomp
*        on tracks 43 and up if they are dd
*
*    (c) 1984 by David C. Wiens
* Last modified July 30, 1985 4:10 pm
******************************************
DRVCNT              set       4         no. of drive descriptors
LOGNBR              equ       10        number of entries in default log buffer
LOGSIZ              equ       6         size of each log entry

                  IFP1
                    use       defsfile
                  ENDC

*
* new getstat/putstt functions
*
SS.DREAD            equ       128       direct sector read
SS.DWRIT            equ       128       direct sector write
SS.UFREZ            equ       129       unfreeze dd.info
*
* select definitions
*
UNIT0               equ       %00000000 drive zero select value
UNIT1               equ       %01000000 drive one select value
UNIT2               equ       %10000000 drive two select value
UNIT3               equ       %11000000 drive three select value
UNITMSK             equ       UNIT3     unit select bit mask
DDENS               equ       %00100000 density select bit (1=dd)
SIDE                equ       %00010000 side select bit (1=side 1)
PRECOMP             equ       %00001000 write precomp select bit (1=yes)

COCOTYP             equ       $20       it.typ mask re coco ("$20"=coco fmt)
MIZRTYP             equ       $10       it.typ mask re mizar ("$10"=mizar fmt)

*******************************************************
* static storage
*******************************************************
                    org       DRVBEG
                    rmb       DRVMEM*DRVCNT

V.RW                rmb       1         00=read operation, non-zero=write operation
CURTBL              rmb       2         ptr to current drive table
V.SIDE              rmb       1         side select value (0=side 0, non-zero=side 1)
V.DENS              rmb       1         density select value (0=sd, non-zero=dd)
V.STP               rmb       1         double step flag (0=no, non-zero=yes)
V.PRE               rmb       1         write precomp flag (0=no, non-zero=yes)
V.FREZ              rmb       1         freeze dd. info in tables
V.BUFF              rmb       2         write verify buffer addr
V.TEMP              rmb       2         old buffer addr store
V.CNT               rmb       2         sector size (in bytes)
LOGDRV              rmb       1         save field for drive # logged
LOGFUN              rmb       1         save field for function logged
LOGSEC              rmb       2         save field for sector # logged
LOGVFY              rmb       1         save field for verify count logged
                    rmb       2         (reserved for future use)
SECLOG              rmb       (LOGNBR+1)*LOGSIZ log of sectors read/writn/verfyd
Memsize             equ       .

Rev                 set       1
Edition             set       20

***************************************************
*
* header information
*
***************************************************
                    mod       ModSize,ModName,Drivr+Objct,ReEnt+Rev,ModEntry,MemSize

                    fcb       $FF       all capabilities

ModName             fcs       'SDISK29'
                    fcb       Edition

PRETRK              fcb       43        Track # at which to start precomp

                    fcc       'Copyright 1984 D.P. Johnson and David C. Wiens'
                    fcb       C$CR
                    fcc       'All rights reserved'


************************************
* branch table
************************************
ModEntry
                    lbra      INITDSK
                    lbra      READSK
                    lbra      WRTDSK
                    lbra      GETSTAT
                    lbra      PUTSTAT
                    lbra      TERM

************************************
*
* init the driver
* in - y address of device descriptor module
*      u device static storage address
* out - none
* error - cc cs
*         b error code
************************************
INITDSK             clr       V.FREZ,U
                    lbsr      SEC256
                    clr       CURTBL,U
                    leax      SECLOG,U  Init logging
                    stx       BEGLOG    .  "
                    stx       LOGPTR    .  "
                    leax      (LOGNBR*LOGSIZ),X .  "
                    stx       ENDLOG    .  "
                    clr       LOGFUN,U  .  "
                    clr       LOGVFY,U  .  "
                    lbsr      RESET     Reset disk controller
                    ldb       #DRVCNT
                    stb       V.NDRV,U
                    lda       #$FF
                    leax      DRVBEG,U  Point to drive tables
DRVINIT             sta       DD.TOT+1,X Init drive tables
                    sta       V.TRAK,X  Set track nonzero to force restore
                    leax      DRVMEM,X
                    decb
                    bne       DRVINIT

                    ldd       #256      Get memory for write verify buffr
                    pshs      U
                    os9       F$SRqMem
                    tfr       U,X
                    puls      U
                    bcs       INIT9
                    stx       V.BUFF,U
                    clrb
INIT9               rts


*********************************
*
* terminate the driver
* in - u device static storage address
* out - none
* error - cc cs
*         b error code
*********************************
TERM                ldu       V.BUFF,U  Return verify buffer memory
                    ldd       #256
                    os9       F$SRTMEM
                    rts

*******************************************************
* read a sector
*  input   u = device static memory addr
*          y = path descriptor addr
*          b = msb of logical sector #
*          x = lsb of logical sector #
* output   sector data returned in the sector buffer
* error    cc cs
*          b error code
*******************************************************
READSK              pshs      X
                    bsr       LOGR
                    lbsr      SELECT
                    bcs       RS90
                    lbsr      LTOP
                    bcs       RS90
                    lda       #$91      retry code
                    bsr       DOREAD
                    bcs       RS90
                    ldx       ,S        sector 0?
                    bne       RS80      .n
                    tst       V.FREZ,U  freeze dd. info?
                    bne       RS80      .y
                    ldx       PD.BUF,Y  .n
                    ldy       CURTBL,U
                    ldb       #DD.SIZ-1
MOVE0               lda       B,X       move sector 0 info to drive table
                    sta       B,Y
                    decb
                    bpl       MOVE0
RS80                clrb
RS90                bsr       LOGENTR
                    puls      X,PC

LOGR                pshs      A
                    lda       #$F1
                    bra       LOGSAV

****************************************
* temporarily save sector numbers
*  read and written
* in - a $f1=read, $f2=write
*      u device static memory addr
*      y path descriptor addr
*      x lsn for r/w, trk/sec for v
* out - all registers unchanged
****************************************
LOGSAV              sta       LOGFUN,U  save function code
                    stx       LOGSEC,U  save sector #
                    lda       PD.DRV,Y  get unit #
                    sta       LOGDRV,U
                    puls      A,PC

*****************************************
* enter disk i/o call into log
* in - cc cs if error
*      b error code
*      u device static memory addr
*      logfun,logdrv,logsec,logvfy as saved by logsav
* out - all registers unchanged
*       logprt advanced
*****************************************
LOGENTR             pshs      CC,B,X,Y
                    bcs       LG10      if carry clear, zero error code
                    clr       1,S
LG10                ldy       LOGPTR
                    cmpy      ENDLOG    log table already full?
                    bhs       LG99      .y
                    ldb       LOGFUN,U  save function code
                    stb       ,Y+
                    clr       LOGFUN,U  clear code re false entries by wrtpsn
                    ldb       1,S       save error code
                    stb       ,Y+
                    ldb       LOGVFY,U  save verify count
                    stb       ,Y+
                    clr       LOGVFY,U
                    ldb       LOGDRV,U  save drive number
                    stb       ,Y+
                    ldx       LOGSEC,U  save lsn or trk/sec
                    stx       ,Y++
                    sty       LOGPTR
LG99                puls      CC,B,X,Y,PC


*****************************************
* read sector with retries
* in - x msb = physical track #, lsb = sector #
*      a retry code
*      u device static memory address
*      y path descriptor address
*      v_side,v_dens,v_stp,v_pre set
*      drive selected
* out - x,y,u unchanged
* error cc cs
*       b error code
*****************************************
DOREAD              pshs      A,X
                    bsr       READSEC   read
                    puls      A,X
                    bcc       DO90      .ok

                    tsta                .errors,  try again?
                    beq       DO90      . n
                    lsra                SHIFT     retry code
                    bcc       DOREAD    . reread without restore
                    pshs      A,X
                    lbsr      HOME      . restore, then reread
                    puls      A,X
                    bcc       DOREAD

DO90                rts


*******************************************************
* read sector
*  (1st drq is after 1st data byte is fully read)
* in x msb=physical track #, lsb=sector #
*    y pd pntr
*    u device static memory address
*    v_side,v_dens,v_stp,v_pre,v_cnt set
*    drive selected
* out u,y unchanged
* error cc cs
*       b error code
*******************************************************
READSEC             lbsr      SEEK
                    lbcs      RETURN
                    lbsr      HLF
                    lbsr      MOTORON
                    clr       V.RW,U
                    pshs      CC,DP,Y,U

                    ldx       V.CNT,U   get sector size
                    ldu       PD.BUF,Y  get buffer address
                    ldy       #32258    time out constant (32258 x 31 = 1 sec)

                    orcc      #INTMASKS
                    ldb       #F.RDSEC  read command
                    lbsr      EXCMD
                    setdp     $FF       <<<<<<<<<
                    ldb       #$FF
                    tfr       B,DP
*
* wait for first drq signal (check clock while waiting)
*  (loop is mostly 31 cycles, 48 if clock tick)
*
                    ldb       MISTIC    temporarily put mistic onto stack
                    pshs      B
                    ldb       #$02      drq bit mask
READS0              bitb      WDSTAT    (4) check 1793 status for drq
                    bne       READS3    (3) .y, go to sector read loop
                    lda       DUART+5   (4) .n, clock tick?
                    bita      #$08      (2)
                    beq       READS4    (3) .     n
                    bitb      WDSTAT    (4) .     y, but first recheck drq
                    bne       READS3    (3) drq, don't have time to process clock
                    lda       DUART+15  (4) reset timer interrupt flag
                    inc       ,S        (6) incr. missed tick counter
READS4              bitb      WDSTAT    (4) drq?
                    bne       READS3    (3) .y
                    leay      -1,Y      (5) .n, timed out? (1 sec.)
                    bne       READS0    (3) .     n, keep looking
                    lbra      TIMOTR    timeout error
*
* read one sector (loop = 25/32/39)
*
READS2              bitb      WDSTAT    (4) wait for data ready
                    beq       READS2    (3)
READS3              lda       WDDATA    (4) get data byte from controller
                    sta       ,U+       (6) put in buffer
                    leax      -1,X      (5) dec byte count
                    bne       READS2    (3) wait for next byte
                    lbra      FINISR    finished, check for errors

                    setdp     $00       <<<<<<<<<
*******************************************************
* write sector
* wrtdsk
*   in - u device static memory address
*        y path descriptor pointer
*        b msb of lsn
*        x lsb of lsn
* wrtpsn
*   in - u device static memory address
*        y path descriptor pointer
*        x msb=physical track, lsb=sector
*        v.side,v.dens,v.stp,v.pre set
*        drive selected
* output - u,y unchanged
* error - cc cs
*         b error code
*******************************************************
WRTDSK              bsr       LOGW
                    lbsr      SELECT
                    bcs       WS90
                    lbsr      LTOP
                    bcs       WS90

WRTPSN              lda       #$91      retry code
WS10                pshs      A,X
                    bsr       WRITSEC   write sector
                    puls      A,X
                    bcs       WS50      .error
                    tst       PD.VFY,Y  need to verify?
                    bne       WS90      .n
                    lbsr      WRTVFY    .y, do it
                    bcc       WS90

WS50                tsta                ERRORS,   try again?
                    beq       WS90      . n
                    lsra                SHIFT     retry code
                    bcc       WS10      . rewrite, no restore
                    pshs      A,X
                    lbsr      HOME      . restore, then rewrite
                    puls      A,X
                    bcc       WS10

WS90                lbsr      LOGENTR
                    rts

LOGW                pshs      A
                    lda       #$F2
                    lbra      LOGSAV

*******************************************************
* do the actual write
*  (1st drq is after sector id header is read, but approx.
*   700 usec before lost data window)
* input - u device static storage address
*         y path descriptor address
*         x msb=physical track, lsb=sector
*         v.side,v.dens,v.stp,v.pre,v.cnt set
*         drive selected
* output - u,y unchanged
* error - cc cs
*         b error code
*******************************************************
WRITSEC             lbsr      SEEK
                    lbcs      RETURN
                    lbsr      HLF
                    lbsr      MOTORON
                    lda       #$FF
                    sta       V.RW,U
                    pshs      CC,DP,Y,U

                    ldx       V.CNT,U   get sector size
                    ldu       PD.BUF,Y  get buffer address
                    ldy       #41667    time out constant (41667 x 24 = 1 sec)

                    orcc      #INTMASKS
                    lbsr      MOTORON
                    ldb       #F.WRTSEC write command
                    lbsr      EXCMD
                    setdp     $FF       <<<<<<<<<
                    lda       #$FF
                    tfr       A,DP
*
* wait for first drq signal (check clock while waiting)
*  (loop = 24 cycles, 35 if clock tick)
*
                    ldb       #$02      drq bit mask
WRTSD0              bitb      WDSTAT    (4) get 1793 status.  drq?
                    bne       WRTSD3    (3) . yes
                    lda       DUART+5   (4) check duart interrupt flags
                    bita      #$08      (2) clock tick?
                    beq       WRTSD4    (3) .n
                    lda       DUART+15  (4) .y, reset timer interrupt flag
                    inc       MISTIC    (7) incr. missed ticks counter
WRTSD4              leay      -1,Y      (5) timed out?  (1 sec.)
                    bne       WRTSD0    (3) .n, not yet
                    lbra      TIMOTW    .    y, error return
*
* write one sector (loop = 25/32/39)
*
WRTSD2              bitb      WDSTAT    (4) ready for next byte?
                    beq       WRTSD2    (3) .n, keep watching
WRTSD3              lda       ,U+       (6) get data byte
                    sta       WDDATA    (4) send to controller
                    leax      -1,X      (5) byte count
                    bne       WRTSD2    (3) wait for next byte
                    bra       FINISW    done, clean up

                    setdp     $00       <<<<<<<<<
*******************************************************
* format command write
*  (drq is issued immediately after write-track command
*   is issued, so missed clock ticks can only be guessed.)
* in - u static storage address
*      y path descriptor pointer
*      x msb=physical track, lsb=01
*      v.side,v.dens,v.stp,v.pre set
*      drive selected
* out - u,y unchanged
* error - cc cs
*         b error code
*******************************************************
FMTWRT              lbsr      SEEK
                    lbcs      RETURN
                    lbsr      HLF
                    lbsr      MOTORON
                    lda       #$FF
                    sta       V.RW,U
                    ldx       PD.RGS,Y  get buffer address
                    ldx       R$X,X
                    pshs      CC,DP,Y,U
                    orcc      #INTMASKS mask out interrupts
                    lbsr      MOTORON
                    ldy       #0        time out constant (65536 x 15 = .983 sec.)
                    inc       MISTIC    assume 3 lost clock ticks
                    inc       MISTIC
                    inc       MISTIC
                    ldb       #F.WRTTRK issue cmd to wd1791
                    lbsr      EXCMD
                    setdp     $FF       <<<<<<<<<<<
                    ldb       #$FF
                    tfr       B,DP
*
* wait for first drq (loop = 15 cycles)
*
                    lda       ,X+       prefetch data byte
                    ldb       #$02      drq bit mask
FMTSD0              bitb      WDSTAT    (4) data request on?
                    bne       FMTSD1    (3) . yes
                    leay      -1,Y      (5) see if timed out waiting  (983 msec.)
                    bne       FMTSD0    (3) .no, look again
                    bra       TIMOTW    timed out
*
* write one full track
*
FMTSD1              sta       WDDATA    (4) loop = 19/33
                    lda       ,X+       (6) prefetch data byte
FMTSD2              ldb       WDSTAT    (4)
                    bitb      #$02      (2) drq?
                    bne       FMTSD1    (3) .y
                    bitb      #$01      (2) busy?
                    bne       FMTSD2    (3) .y
                    bra       FINISW

                    setdp     $00       <<<<<<<<<
*******************************************************
* complete the read-sector/write-sector/write-track
*  processing by waiting until command is completed,
*  then check for errors.
*******************************************************
FINISW              puls      CC,DP,Y,U
                    ldb       #17       delay 1 msec. after write
FN05                lbsr      SDELAY
                    decb
                    bne       FN05
                    bra       FN10

FINISR              puls      B
                    stb       MISTIC
                    puls      CC,DP,Y,U

FN10                bsr       DBL
                    lbsr      BUSYW
                    bitb      #$FC      any errors?
                    beq       NOERRS    .n
                    bitb      #$04      lost data error?
                    beq       FN20
                    tst       V.RW,U
                    bne       WRTERR
                    bra       READERR
FN20                lda       #E$NOTRDY
                    bitb      #$80      drive not ready?
                    bne       ERROR
                    lda       #E$WP
                    bitb      #$40      write protected?
                    bne       ERROR
                    bitb      #$20      write fault?
                    bne       WRTERR
                    bitb      #$10      rnf error?
                    bne       SEEKERR
                    lda       #E$CRC
                    bitb      #$08      crc error?
                    bne       ERROR

NOERRS              clrb
                    rts

ERROR               comb                set       carry
                    tfr       A,B       put error code in b
RETURN              rts

TIMOTW              puls      CC,DP,Y,U
                    lbsr      RESET
                    bsr       DBL
WRTERR              comb
                    ldb       #E$WRITE  write error
                    rts

TIMOTR              puls      B
                    stb       MISTIC
                    puls      CC,DP,Y,U
                    lbsr      RESET
                    bsr       DBL
READERR             comb
                    ldb       #E$READ   read error
                    rts

TYPERR              comb
                    ldb       #E$BTYP   wrong type - incompatible media
                    rts

SEEKERR             comb
                    ldb       #E$SEEK   seek to non-existant sector
                    rts

SECTERR             comb
                    ldb       #E$SECT   sector number is out of range
                    rts


***************************************
* temporarily change value in trkreg from physical
*  to logical track number
* in - u static memory address
*      y path descr. ptr
*      v.stp
* out - cc undefined, all others unchanged
***************************************
HLF                 pshs      CC,A
                    lda       >WDTRAK
                    tst       V.STP,U
                    beq       HL30
                    lsra
HL30                bra       DB60

***************************************
* change value in trkreg from logical track #
*  back into physical track number
* in - u static memory address
*      y path descr. ptr
*      v.stp
* out - all registers unchanged
***************************************
DBL                 pshs      CC,A
                    lda       >WDTRAK
                    tst       V.STP,U
                    beq       DB60
                    lsla

DB60                sta       >WDTRAK
                    lbsr      SDELAY
                    puls      CC,A,PC


*******************************************************
* read sector just written to verify
* in - u device static memory address
*      y path descriptor pointer
*      x msb=physical track, lsb=sector
*      v.side,v.dens,v.stp,v.pre set
*      drive selected
* out - a,x,y,u unchanged
* error - cc cs
*         b error code
*******************************************************
WRTVFY              inc       LOGVFY,U
                    pshs      X,A
                    ldx       PD.BUF,Y  temporarily point to verify buffer
                    pshs      X
                    ldx       V.BUFF,U
                    stx       PD.BUF,Y
                    ldx       3,S
                    lbsr      READSEC   read sector
                    puls      X
                    stx       PD.BUF,Y  reset buffer pointer
                    bcs       VFYDONE
                    lda       #64       count = 64 (64x4=256)
                    pshs      U,Y,A
                    ldy       V.BUFF,U
                    tfr       X,U
VFYCMP              ldx       ,U        (5) loop = 33 cycles x 64 = 2.1 msec
                    cmpx      ,Y        (6)
                    bne       VFYERR    (3)
                    leau      4,U       (5)
                    leay      4,Y       (5) compare every 2nd 2-byte word
                    dec       ,S        (6)
                    bne       VFYCMP    (3)
                    bra       VFYOK
VFYERR              coma                set       carry
                    ldb       #E$WRITE
VFYOK               puls      A,Y,U
VFYDONE             puls      A,X,PC

*******************************************************
* seek to desired track, then select density/side/precomp
*  and sector
* input - u device static memory address
*         y path descriptor pointer
*         x msb=physical track, lsb=sector
*         v.side,v.dens,v.stp,v.pre set
*         drive selected
* output - y,u unchanged
*          a,b,x undefined
* error - cc cs
*         b error code
*******************************************************
SEEK                tfr       X,D
                    pshs      B
                    ldx       CURTBL,U
                    lbsr      RESET
*
* seek to proper track
*
                    cmpa      V.TRAK,X  new same as old?
                    beq       TRAKSET   yes..skip seek
                    sta       V.TRAK,X  old:=new
                    sta       WDDATA    put new track in data reg
                    ldb       #F.SEEK   seek command (load head/no verify)
                    eorb      PD.STP,Y  mask in step rate
                    lbsr      EXCMDW
                    lda       #30       30 msec. head settle delay
                    lbsr      DLY1K
                    bitb      #$10      seek error?
                    beq       TRAKSET
                    comb
                    ldb       #E$SEEK   seek error
                    bra       SK90

TRAKSET             clra
* test side
                    tst       V.SIDE,U
                    bne       SK50
                    ora       #SIDE
* test density
SK50                tst       V.DENS,U
                    bne       SK60
                    ora       #DDENS
* test write precomp
SK60                tst       V.PRE,U
                    bne       SK70
                    ora       #PRECOMP
* select side/density/precomp
SK70                ldb       #SIDE+DDENS+PRECOMP
                    jsr       [SETOPR]

                    ldb       ,S        select sector
                    stb       WDSECT
                    lbsr      SDELAY
                    lbsr      SDELAY
                    clrb
SK90                puls      A,PC

*******************************************************
* convert logical sector # to physical track and sector
*  and set v.side,v.dens,v.stp,v.pre
* input - u device memory address
*         y path descriptor pointer
*         b msb logical sect #
*         x lsb logical sect #
*         dblstp,bdrive,pretrk
*         drive selected
* output - x msb=physical track, lsb=physic sector
*          u,y unchanged
*          a,b undefined
*          v.side,v.dens,v.stp,v.pre set
* error: cc cs
*        b error code
*******************************************************
LTOP                tstb
                    lbne      SECTERR   sector number too hi
                    clr       V.SIDE,U
                    clr       V.DENS,U
                    clr       V.STP,U
                    clr       V.PRE,U
                    tfr       X,D
                    ldx       CURTBL,U
                    cmpd      #0000
                    beq       PHYS7     no translation needed
                    cmpd      DD.TOT+1,X out of bounds?
                    lbhs      SECTERR   .yes

                    tst       DBLSTP    check for 96 tpi flag for
                    beq       PHYS0     . non-configured device descriptor
                    pshs      A
                    lda       BDRIVE
                    cmpa      PD.DRV,Y  (only for boot drive)
                    bne       LT05
                    lda       PD.DNS,Y
                    ora       #$02
                    sta       PD.DNS,Y
LT05                puls      A

PHYS0               subd      PD.T0S,Y  - track 0 side 0 sector cnt
                    bcc       PHYS1     want past first side of track 0
                    addd      PD.T0S,Y  add back to get sector no.
                    bra       PHYS7
PHYS1               pshs      B         save reg
                    ldb       DD.FMT,X  check for double sided
                    lsrb                SHIFT     side bit to carry
                    puls      B
                    bcc       PHYS4A    if single sided

*double sided disk
                    pshs      B
                    ldb       PD.SID,Y  double sided drive?
                    cmpb      #1
                    puls      B
                    lbls      TYPERR    btyp error
                    clr       ,-S       clear logical track number accumulator
PHYS2               com       V.SIDE,U  flip sides
                    bne       PHYS3     if change from side 0 to 1
                    inc       ,S        else inc logical track
PHYS3               subd      DD.SPT,X  subtract a track full
                    bcc       PHYS2     do until less than track full
                    bra       PHYS5

* single side disk
PHYS4A              clr       ,-S       clear logical track number accumulator
PHYS4B              inc       ,S        inc track no.
                    subd      DD.SPT,X  minus track full
                    bcc       PHYS4B

* now set for proper density
PHYS5               addd      DD.SPT,X  restore sect0r #
                    lda       DD.FMT,X  get side/density byte
                    bita      #%00000010 single density?
                    beq       PHYS6     yes
                    com       V.DENS,U  save ddens select value
PHYS6               puls      A         get logical track value just computed

PHYS7               pshs      A         save logical track value
PHYS7A              lda       DD.FMT,X  get media format
                    lsra                shift     to match pd.dns
                    bita      #$02      96 tpi?
                    beq       PHYS7B    .n
                    eora      PD.DNS,Y  .y, is drive also 96 tpi?
                    bita      #$02
                    beq       PHYS7C    .y
                    puls      A         .n, error
                    lbra      TYPERR
PHYS7B              eora      PD.DNS,Y  is drive also 48 tpi?
                    bita      #$02
                    beq       PHYS7C    .y
                    com       V.STP,U   .n, need to double step
                    asl       ,S        logical trk #  * 2 = physical trk #
PHYS7C              lda       PD.CYL+1,Y
                    cmpa      ,S        valid physical trk # ?
                    bhi       PHYS7D
                    puls      A
                    lbra      SEEKERR
PHYS7D              lda       PD.TYP,Y  get device type
                    bita      #MIZRTYP  mizar format?
                    bne       PHYS7E    .y
                    bita      #COCOTYP  color computer format?
                    beq       PHYS8     no.. use standard os9 format
                    incb                adjust    physical sector # for coco
PHYS7E              lda       #$FF
                    sta       V.DENS,U  force double density for all tracks
PHYS8               puls      A         restore physical track no.
                    tfr       D,X
                    cmpa      PRETRK,PCR write precomp if trk >= pretrk and dd
                    blo       PHYS9
                    tst       V.DENS,U
                    beq       PHYS9
                    inc       V.PRE,U
PHYS9               clrb
                    rts

*******************************************************
* select drive
* input - u device static memory address
*         y path descriptor pointer
* output:  curtbl,u = current drive table ptr
*          x,y,u unchanged
*          b unchanged if no error
*          a undefined
* error - cc cs
*         b error code
*******************************************************
SELECT              tst       >WDSTAT   turn motors on
                    lda       PD.DRV,Y  get unit number
                    cmpa      #DRVCNT   in range?
                    bhs       SE80      .n
                    pshs      X,B,A
                    leax      DRVBEG,U
                    ldb       #DRVMEM
                    mul
                    leax      D,X       new drive table addr
                    cmpx      CURTBL,U  drive change?
                    beq       NOCHNG

                    stx       CURTBL,U  yes
                    lda       V.TRAK,X  restore track # for this drive
                    sta       WDTRAK
                    sta       WDDATA
                    ldb       #$10      dummy seek to reset hld flag
                    lbsr      EXCMD
                    lda       #1
                    lbsr      DLY1K
                    lbsr      RESET     cancel dummy seek
                    lda       ,S
                    lsra                PHYSICALLY select drive
                    rora
                    rora
                    ldb       #UNITMSK
                    jsr       [SETOPR]

NOCHNG              puls      X,B,A
                    clra
                    bra       SE90

SE80                comb
                    ldb       #E$UNIT

SE90                rts


*************************************************
* reset v.cnt to sector size of 256 bytes
* in - u static storage address
* out - cc,a,b undefined
*       x,y,u unchanged
*************************************************
SEC256              ldd       #256
                    std       V.CNT,U
                    rts


*******************************************************
* get status
* input u static storage addr
*       y path descriptor ptr
* output - various
* error - cc cs
*         b error code
*******************************************************
GETSTAT             ldx       PD.RGS,Y
                    ldb       R$B,X     get function code
                    cmpb      #SS.DREAD direct read?
                    beq       DREAD     .y
                    comb                .N,       unknown command
                    ldb       #E$UNKSVC
                    rts


*******************************************************
* getstt: ss.dread direct sector read
* putstt: ss.dwrit direct sector write
* input   u = static storage addr
*         y = path desc. ptr
*         x = pointer to register stack
*           r$u = (msb) logical track no.,
*                 (lsb) physical sector no.
*           r$x = buffer address
*           r$y  bit 0 = side (0 or 1)
*                bit 1 = media density (0=single  1=double)
*                bit 2 = media tpi (0= 48,  1= 96 )
*                bit 3 = (not used)
*                bits 4 - 7 = most significant 4 bits of
*                              12 bit sector size
*                bits 8-15 = least significant 8 bits of
*                             12 bit sector size
*
* getstt output : buffer contains sector read from disk
* putstt output : contents of buffer written to disk
* output - u,y unchanged
* error - cc cs
*         b error code
*******************************************************
DWRITE              bsr       DCOMMON
                    bcs       DFINISH
                    lbsr      WRTPSN
                    bra       DFINISH

DREAD               bsr       DCOMMON   do common section
                    bcs       DFINISH
                    lda       #$91      retry code
                    lbsr      DOREAD    skip sector 0 read section

DFINISH             pshs      B,CC      save error status code
                    ldd       V.TEMP,U  restore original buffer address
                    std       PD.BUF,Y
                    bsr       SEC256    reset sector length to 256
                    puls      B,CC,PC   return with status

*********************
* direct read/write common section
* in - u device static memory address
*      y path descriptor pointer
*      x pointer to register stack
* out - x msb=physical track, lsb=sector
*       u,y unchanged
*       a,b undefined
*       v.side,v.dens,v.stp,v.pre,v.cnt set
* error cc cs
*       b error code
*********************
DCOMMON             ldd       PD.BUF,Y  save buffer address
                    std       V.TEMP,U
                    ldd       R$X,X     get new buffer address
                    std       PD.BUF,Y  stick it into pd
                    ldd       R$Y,X     extract sector length count
                    exg       A,B
                    lsra
                    lsra
                    lsra
                    lsra
                    cmpd      #0000     if zero, use default sector size
                    bne       DC60
                    ldd       SECSIZ
DC60                std       V.CNT,U
                    lbsr      SELECT
                    bcs       DC90
                    ldx       R$U,X     get track/sector
                    bsr       SETSDP
DC90                rts


*******************************************************
* set status
*  u = static storage addr
*  y = path descriptor ptr
*******************************************************
PUTSTAT             ldx       PD.RGS,Y
                    ldb       R$B,X     get function code
                    cmpb      #SS.RESET restore to track zero?
                    lbeq      RESTORE
                    cmpb      #SS.WTRK  write track?
                    beq       WRTTRK
                    cmpb      #SS.FRZ   freeze?
                    beq       FREEZE
                    cmpb      #SS.UFREZ unfreeze?
                    beq       UNFREEZ
                    cmpb      #SS.DWRIT direct sector write?
                    beq       DWRITE
                    comb
                    ldb       #E$UNKSVC
                    rts

***********************
* freeze/unfreeze
* in - u static storage addr
***********************
UNFREEZ             clra                UNFREEZE
                    bra       FREEZ2

FREEZE              lda       #$FF      freeze dd. info in drive storage
FREEZ2              sta       V.FREZ,U
                    clrb
                    rts


*******************************************************
* format a track
* input  u = static storage addr
*        y = path desc. ptr
*        x = pointer to register stack
*          r$x = address of track buffer
*          r$u = logical track number
*          r$y = side/density (dd.fmt byte)
*******************************************************
WRTTRK              lbsr      SELECT    update curtbl,u
                    bcs       WT90      if error
                    ldb       R$Y+1,X   get side/dens info
                    ldx       R$U,X     get track #
                    pshs      X
                    ldx       CURTBL,U
                    stb       DD.FMT,X  save in drive table
                    puls      A,B       convert to track/sector
                    lda       #01
                    exg       A,B
                    tfr       D,X
                    bsr       SETSDP
                    bcs       WT90
                    lbsr      FMTWRT    go finish the format
WT90                rts

***************************************************
* set side/density/double-stepping/precomp flags
*  as per explicit command
* in - u static storage address
*      y path descriptor pointer
*      x logical track / physical sector
*      pretrk
* out - u,y unchanged
*       a,b undefined
*       x physical track / physical sector
*       v.side,v.dens,v.stp,v.pre set
* error - cc cs
*         b error code
**************************************************
SETSDP              pshs      X
                    ldx       PD.RGS,Y
                    ldb       R$Y+1,X   get fmt byte

                    clra
                    bitb      #$01      side zero?
                    beq       ST02      .y
                    coma                .N
ST02                sta       V.SIDE,U

                    clra
                    bitb      #$02      single density?
                    beq       ST04      .y
                    coma                .N
ST04                sta       V.DENS,U

                    clra
                    lsrb                SHIFT     fmt to match pd.dns
                    bitb      #$02      96 tpi?
                    beq       ST06      .n
                    eorb      PD.DNS,Y  .y, drive 96 tpi?
                    bitb      #$02
                    beq       ST08      .y
                    leas      2,S       .n
                    lbra      TYPERR
ST06                eorb      PD.DNS,Y  drive 48 tpi?
                    bitb      #$02
                    beq       ST08      .y
                    coma                .N, double step
                    asl       ,S        logical*2 = physical track
ST08                sta       V.STP,U
                    puls      X
                    tfr       X,D

                    cmpa      PD.CYL+1,Y valid track number?
                    lbhs      SEEKERR   .n
                    clrb
                    cmpa      PRETRK,PCR precomp this track?
                    blo       ST10      .n
                    tst       V.DENS,U
                    beq       ST10
                    incb                .Y
ST10                stb       V.PRE,U

                    clrb
                    rts


*******************************************************
* restore drive to track 0
*
*  input:  (y) = path descriptor pntr
*          (u) = static storage addr
* output - x,y,u unchanged
*          a,b undefined
* error - cc cs
*         b error code
*******************************************************
RESTORE             lbsr      SELECT    select the drive
                    bcs       RE90      if error


HOME                bsr       RESET
                    ldb       #F.REST   restore
                    eorb      PD.STP,Y
                    bsr       EXCMDW
                    lda       #5        step in 5 times
STEPIN              pshs      A
                    ldb       #F.STEPIN
                    eorb      PD.STP,Y  step rate value
                    bsr       EXCMDW
                    puls      A
                    deca
                    bne       STEPIN
                    lda       #30       delay for head settle
                    bsr       DLY1K
                    ldb       #F.REST   restore again
                    eorb      PD.STP,Y
                    bsr       EXCMDW
                    lda       #30       wait for head to settle
                    bsr       DLY1K
                    ldx       CURTBL,U
                    clr       V.TRAK,X
RE90                rts

************************************
* reset the floppy disk controller chip
* in - none
* out - b 1793 status word
*       cc undefined
*       a,x,y,u unchanged
***********************************
RESET               ldb       #F.TYPE1  force interrupt

******************************
* execute floppy disk command
*  and wait until done
******************************
EXCMDW              bsr       EXCMD

BUSYW               ldb       WDSTAT
                    bitb      #$01
                    bne       BUSYW
                    rts

EXCMD               stb       WDCMD

*************************
* delay approx. 56 cycles
* in - none
* out - all registers unchanged
**************************
SDELAY              lbsr      SDELY2
SDELY2              lbsr      SDELY3
SDELY3              nop
                    rts

********************************
* delay approx. 1 - 255 msec.
* in - a number of msec. desired delay
* out - a,cc undefined
*       b,x,y,u unchanged
********************************
DLY1K               pshs      B
DY40                ldb       #1000/5
DY50                decb                (2)
                    bne       DY50      (3)
                    deca
                    bne       DY40
                    puls      B,PC

*******************************************************
* ensure that drive motor is on
* (allow motor on delay if starting from a stop)
* in - none
* out - a,b,x,y,u unchanged
*       cc undefined
*******************************************************
MOTORON             pshs      X,B,A
                    ldx       #65535
MTR1                tst       >WDSTAT   (7) loop = 29
                    bpl       MTR2      (3)
                    mul                 (11)
                    leax      -1,X      (5)
                    bne       MTR1      (3)
                    bra       MTR3      timeout after 2 seconds
MTR2                tst       >WDSTAT
                    bmi       MTR1
MTR3                puls      A,B,X,PC


                    emod
ModSize             equ       *

