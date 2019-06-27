                  IFNE    ST2900.D-1
ST2900.D            SET       1

********************************************************************
* ST2900Defs - NitrOS-9 System Definitions for the Sardis ST-2900
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*          2019/06/23  Mark R V Murray
* Created new ST2900 file

                    NAM       ST2900Defs
                  IFEQ    Level-1
                    TTL       NitrOS-9  System Definitions for the Sardis Technologies ST-2900
                  ELSE
                  IFEQ    Level-2
                    TTL       NitrOS-9  Level 2 System Type Definitions
                  ELSE
                  IFEQ    Level-3
                    TTL       NitrOS-9  Level 3 System Type Definitions
                  ENDC
                  ENDC
                  ENDC

******************************
* Clock Speed Type Definitions
*
OneMHz              EQU       1
TwoMHz              EQU       2
CPUSpeed            EQU       OneMHz

**********************************
* Ticks per second
*
TkPerSec            EQU       10

DACRON              EQU       $FE00     (2) (indirect)
DACROF              EQU       $FE02     (2) (indirect)
DINTON              EQU       $FE04     (2) (indirect)
DINTOF              EQU       $FE06     (2) (indirect)
DOPCON              EQU       $FE08     (2) (indirect)
DOPCOF              EQU       $FE0A     (2) (indirect)
SETOPR              EQU       $FE0C     (2) (indirect) change DUART's OPX settings

******************
* Device addresses for miscellaneous hardware
*
FDC                 EQU       $FF00
WDCMD               EQU       FDC
WDSTAT              EQU       FDC
WDTRAK              EQU       FDC+1
WDSECT              EQU       FDC+2
WDDATA              EQU       FDC+3

Duart               EQU       $FF20     MC2681 DUART base address
MR.D                EQU       Duart+0   DUART mode register
SR.D                EQU       Duart+1   DUART status register
CSR.D               EQU       Duart+1   DUART clock select register
CR.D                EQU       Duart+2   DUART command register
TXRX.D              EQU       Duart+3   DUART Tx Rx data register
ACR.D               EQU       Duart+4   DUART auxiliary control register
IMR.D               EQU       Duart+5   DUART interrupt mask register
ISR.D               EQU       Duart+5   DUART interrupt status register
CTU.D               EQU       Duart+6   DUART Counter/Timer upper value
CTUR.D              EQU       Duart+6   DUART Counter/Timer upper preset value
CTL.D               EQU       Duart+7   DUART Counter/Timer lower value
CTLR.D              EQU       Duart+7   DUART Counter/Timer lower preset value
OPCR.D              EQU       Duart+13  DUART output port configuration register
OPRset.D            EQU       Duart+14  DUART set output port bits command register
OPRrst.D            EQU       Duart+15  DUART reset output port bits command register

VIABase             EQU       $FF40     R6522 VIA base address

                  IFEQ    FEXXBlock
SECSIZ              EQU       $FEC8     (2) Default sector size for direct r/w
BEGLOG              EQU       $FECA     (2) Pointer to beginning of log
LOGPTR              EQU       $FECC     (2) Pointer to next avail. entry in log
ENDLOG              EQU       $FECE     (2) Pointer to end of log + 1
OFF_AF              EQU       $FED0     (2) Offset between $AXXX and $FXXX addresses of relocated ST-MON
*                        (1) reserved
MISTIC              EQU       $FED3     (1) Counter re missed clock ticks
BDRIVE              EQU       $FED4     (1) Drive # booted from
DBLSTP              EQU       $FED5     (1) Double-step boot drive
*                        (2) reserved
ARTBAU              EQU       $FED8     (1) Holds DUART's write-only baud rate data
ARTLEN              EQU       $FED9     (1) Code re data/parity/stop bits for port a
ARTACR              EQU       $FEDA     (1) Current contents of DUART's ACR register
ARTINT              EQU       $FEDB     (1) Current contents of DUART's IMR register
ARTOPC              EQU       $FEDC     (1) Current contents of DUART's OPCR register
ARTOPX              EQU       $FEDD     (1) Current contents of DUART's OPX register
*                        (2) reserved
*                        (2) reserved
BTADDR              EQU       $FEE2     (2) Address of OS9Boot file buffer
BTSIZE              EQU       $FEE4     (2) Size of OS9Boot file (bytes)
BOOTFL              EQU       $FEE6     (1) Boot module flag, non-zero = already called
                  ENDC

*
* WD1791 commands
*
F.REST              EQU       $0B       restore cmd
F.STEPIN            EQU       $4B       stepin
F.SEEK              EQU       $1B       seek track cmd
F.RDSEC             EQU       $80       read sector
F.WRTSEC            EQU       $A0       write sector
F.WRTTRK            EQU       $F0       write track
F.TYPE1             EQU       $D0       force interrupt

F.NUM.ERR           EQU       $71       numeric error
F.NOT.RDY           EQU       $72       not-ready error
F.TIME.OUT          EQU       $73       time-out error

                  IFEQ    Level-1

********************************
* Boot defs for NitrOS-9 Level 1
*
* These defs are not strictly for 'Boot', but are for booting the
* system.
*
Bt.Start            EQU       $F000     Start address of the kernel file in memory
Bt.Size             EQU       $0F00     Size of kernel file

                  ELSE

******************************************
* Boot defs for NitrOS-9 Level 2 and above
*
* These defs are not strictly for 'Boot', but are for booting the
* system.
*
Bt.Start            EQU       $ED00     Start address of the boot file in memory

                  ENDC

                  IFEQ    Level-1

*************************************************
*
* NitrOS-9 Level 1 Section
*
*************************************************

HW.Page             SET       $FF       Device descriptor hardware page

                  ENDC
                  ENDC
