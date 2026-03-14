                  IFNE    ST2900.D-1
ST2900.D            set       1

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

                    nam       ST2900Defs
                  IFEQ    Level-1
                    ttl       NitrOS-9  System Definitions for the Sardis Technologies ST-2900
                  ELSE
                  IFEQ    Level-2
                    ttl       NitrOS-9  Level 2 System Type Definitions
                  ELSE
                  IFEQ    Level-3
                    ttl       NitrOS-9  Level 3 System Type Definitions
                  ENDC
                  ENDC
                  ENDC

******************************
* Clock Speed Type Definitions
*
OneMHz              equ       1
TwoMHz              equ       2
CPUSpeed            equ       OneMHz

**********************************
* Ticks per second
*
TkPerSec            equ       50

DACRON              equ       $FE00     (2) (indirect)
DACROF              equ       $FE02     (2) (indirect)
DINTON              equ       $FE04     (2) (indirect)
DINTOF              equ       $FE06     (2) (indirect)
DOPCON              equ       $FE08     (2) (indirect)
DOPCOF              equ       $FE0A     (2) (indirect)
SETOPR              equ       $FE0C     (2) (indirect) change DUART's OPX settings

******************
* Device addresses for miscellaneous hardware
*
FDC                 equ       $FF00
WDCMD               equ       FDC
WDSTAT              equ       FDC
WDTRAK              equ       FDC+1
WDSECT              equ       FDC+2
WDDATA              equ       FDC+3

Duart               equ       $FF20     MC2681 DUART base address
MR.D                equ       Duart+0   DUART mode register
SR.D                equ       Duart+1   DUART status register
CSR.D               equ       Duart+1   DUART clock select register
CR.D                equ       Duart+2   DUART command register
TXRX.D              equ       Duart+3   DUART Tx Rx data register
ACR.D               equ       Duart+4   DUART auxiliary control register
IMR.D               equ       Duart+5   DUART interrupt mask register
ISR.D               equ       Duart+5   DUART interrupt status register
CTU.D               equ       Duart+6   DUART Counter/Timer upper value
CTUR.D              equ       Duart+6   DUART Counter/Timer upper preset value
CTL.D               equ       Duart+7   DUART Counter/Timer lower value
CTLR.D              equ       Duart+7   DUART Counter/Timer lower preset value
OPCR.D              equ       Duart+13  DUART output port configuration register
OPRset.D            equ       Duart+14  DUART set output port bits command register
OPRrst.D            equ       Duart+15  DUART reset output port bits command register

VIABase             equ       $FF40     R6522 VIA base address
ORB.V               equ       VIABase+0 VIA output register B
IRB.V               equ       VIABase+0 VIA input register B
DDRB.V              equ       VIABase+2 VIA data direction register B
SR.V                equ       VIABase+10 VIA shift register
ACR.V               equ       VIABase+11 VIA auxiliary control register

**********************************
* NVRAM/RTC board SPI definitions
*
* chip select codes for VIA port B bits 0-3
M.CS00              equ       0         nCS0 SRAM U3
M.CS01              equ       1         nCS1 SRAM U4
M.CS02              equ       2         nCS2 SRAM U5
M.CS03              equ       3         nCS3 SRAM U6
M.CS04              equ       4         nCS4
M.CS05              equ       5         nCS5
M.CS06              equ       6         nCS6
M.CS07              equ       7         nCS7 RTC U10
M.CS08              equ       8         nCS8 EEPROM U11
M.CS09              equ       9         nCS9 EEPROM U12
M.CS10              equ       10        CS10 RTC eval board U9
* VIA port B bit masks
M.DEVS              equ       $0F       chip select mask (nCS0..nCS9)
M.RD                equ       $10       read buffer enable (active low)
M.LED               equ       $20       activity LED (active low)
M.IDLE              equ       $40       SCLK idle state
* SPI command codes
M.WrDat             equ       $02       write data
M.RdDat             equ       $03       read data
M.RdSt              equ       $05       read status register (25CSM04)
M.WrEn              equ       $06       write enable
* VIA shift register ACR mode bits
M.SRin              equ       $08       shift in at system clock / 2
M.SRout             equ       $18       shift out at system clock / 2
M.SR                equ       $1C       shift register mode mask
* NVRAM driver configuration flags (stored in module body)
W.ClkTks            equ       %01000000
W.Ndsk              equ       %00100000
W.Nrtc              equ       %00010000

**********************************
* NVRAM device type bits for IT.TYP/PD.TYP
* (redefine unused bits in the standard RBF type byte)
*
TYP.NVRM            equ       %10000000 NVRAM device (vs floppy/hard)
TYPN.SRM            equ       %00000000 23LCV1024 SRAM
TYPN.EEP            equ       %00000100 EEPROM device
TYPN.EE4            equ       %00001000 25CSM04 (with ECC)

**********************************
* NVRAM GetStat/SetStat function codes
*
SS.Stat4            equ       $D8       read 25CSM04 EEPROM status register
SS.RtcWr            equ       $D9       write to RTC register(s)
SS.RtcRd            equ       $DA       read from RTC register(s)

**********************************
* NVRAM direct page variables
* (allocated in unused direct page space)
*
D.SpiSel            equ       $E0       (1) current SPI chip select code
D.SpiLSN            equ       $E1       (2) current SPI chip LSN
D.SpiLED            equ       $E3       (1) LED down-counter
D.SpiBsy            equ       $E4       (1) SPI busy flag

**********************************
* LSN 0 Volume Identification Sector offsets for NVRAM checksum
*
DD.FIL              equ       $5F       end of DD.NAM+DD.OPT area
DD.CHK              equ       $60       16-bit VIS checksum

                  IFEQ    FEXXBlock
SECSIZ              equ       $FEC8     (2) Default sector size for direct r/w
BEGLOG              equ       $FECA     (2) Pointer to beginning of log
LOGPTR              equ       $FECC     (2) Pointer to next avail. entry in log
ENDLOG              equ       $FECE     (2) Pointer to end of log + 1
OFF_AF              equ       $FED0     (2) Offset between $AXXX and $FXXX addresses of relocated ST-MON
*                        (1) reserved
MISTIC              equ       $FED3     (1) Counter re missed clock ticks
BDRIVE              equ       $FED4     (1) Drive # booted from
DBLSTP              equ       $FED5     (1) Double-step boot drive
*                        (2) reserved
ARTBAU              equ       $FED8     (1) Holds DUART's write-only baud rate data
ARTLEN              equ       $FED9     (1) Code re data/parity/stop bits for port a
ARTACR              equ       $FEDA     (1) Current contents of DUART's ACR register
ARTINT              equ       $FEDB     (1) Current contents of DUART's IMR register
ARTOPC              equ       $FEDC     (1) Current contents of DUART's OPCR register
ARTOPX              equ       $FEDD     (1) Current contents of DUART's OPX register
*                        (2) reserved
*                        (2) reserved
BTADDR              equ       $FEE2     (2) Address of OS9Boot file buffer
BTSIZE              equ       $FEE4     (2) Size of OS9Boot file (bytes)
BOOTFL              equ       $FEE6     (1) Boot module flag, non-zero = already called
                  ENDC

*
* WD1791 commands
*
F.REST              equ       $0B       restore cmd
F.STEPIN            equ       $4B       stepin
F.SEEK              equ       $1B       seek track cmd
F.RDSEC             equ       $80       read sector
F.WRTSEC            equ       $A0       write sector
F.WRTTRK            equ       $F0       write track
F.TYPE1             equ       $D0       force interrupt

F.NUM.ERR           equ       $71       numeric error
F.NOT.RDY           equ       $72       not-ready error
F.TIME.OUT          equ       $73       time-out error

                  IFEQ    Level-1

********************************
* Boot defs for NitrOS-9 Level 1
*
* These defs are not strictly for 'Boot', but are for booting the
* system.
*
Bt.Start            equ       $F000     Start address of the kernel file in memory
Bt.Size             equ       $0F00     Size of kernel file

                  ELSE

******************************************
* Boot defs for NitrOS-9 Level 2 and above
*
* These defs are not strictly for 'Boot', but are for booting the
* system.
*
Bt.Start            equ       $ED00     Start address of the boot file in memory

                  ENDC

                  IFEQ    Level-1

*************************************************
*
* NitrOS-9 Level 1 Section
*
*************************************************

HW.Page             set       $FF       Device descriptor hardware page

                  ENDC
                  ENDC
