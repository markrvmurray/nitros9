*-----------------------------------------------------------*
* BOOT_DATA.ASM
*
* "Boot" is the system boot module for both OS-9/6809 Level 1
* and NitrOS-9/6809 Level 1, or (Nitr)OS-9 for short, running
* on the ST-2900.  It is called when the kernel can't find the
* IOMan module during startup, i.e., before the OS9Boot file,
* which contains IOMan, has been processed.
*
* ST-MON 2.04 in the ST-2900 reads the OS9Boot file from disk
* into a temporary buffer at $2000..$7FFF ($2000..$9FFF for a
* future revision) before calling the (Nitr)OS-9 kernel.  The
* Boot module uses an OS call to reserve system memory for the
* OS9Boot file, then copies the file from the temporary buffer
* into the final location.
*
* In order to allow larger OS9Boot files, where the source and
* destination copies might overlap somewhat, Boot starts copying
* from the end and works toward the beginning.  OS9Boot files
* of up to 32767 bytes (32KB-1) are supported.
*
* Memory is allocated in 256-byte chunks, but the OS9Boot file
* is the exact size required to contain its modules, so doesn't
* have any filler.  As a result the upper 256 bytes of the
* allocated area usually contains some undefined garbage values,
* but these are ignored by the kernel when searching for valid
* modules since it is given the exact size of the OS9Boot file.
*
* The FEXX page contains data and code to support (Nitr)OS-9
* running on the ST-2900.  It resides in RAM at $FDF3..$FEFF.
* The FEXX page contains:
*  - Boot module (now occupies what was formerly unused space
*    in the FEXX page)
*  - vector table to access the DUART subroutines
*  - subroutines to access various DUART registers
*  - variables for DUART subroutines, floppy disk driver, and
*    Boot module
*  - interrupt jump table
*
* The FEXX page (with Boot module) must be located at the very
* end of the OS9Kernel file.
*
* Note that unlike the CoCo versions, there is no REL module,
* and the Boot module doesn't read the OS9Boot file from disk.
* This is because most of the functionality of the REL and Boot
* modules in the boot track (track 34) in the CoCo versions of
* (Nitr)OS-9 is handled by ST-MON 2.04.  Both the kernel (from
* the OS9Kernel file, not track 34) and OS9Boot are read into
* buffers in RAM by ST-MON 2.04, and the kernel has already
* been moved into its correct location at $F000-$FEFF, before
* control is passed to the kernel.
*
* First version written by David C. Wiens in 1985, revised to
* support larger OS9Boot files in 1991-Mar, then merged with
* the FEXX page in 2019-Jun.
* Last modified by David C. Wiens 2019-Jun-25 16:30 PDT
*-----------------------------------------------------------*

                    nam       Boot
                    ttl       FEXX page for (Nitr)OS-9 on the ST-2900.

                    opt       -C        G D66 W120

*--------------------------------------------------
* Definitions.
*--------------------------------------------------
FEXXBlock           equ       1
                  IFP1
                    use       defsfile
                  ENDC

*--------------------------------------------------
* Variables used by the DUART subroutines, the floppy
*  disk driver, and the Boot module.
*
* ST-MON initializes these variables during the boot
*  process before jumping to the kernel:
*   - ARTLEN: bits 4..0 from DUART's MR1A register,
*             bits 7..5 = '101' = 2 stop bits
*   - BDRIVE,DBLSTP,ARTBAU,ARTACR,ARTINT,ARTOPC,ARTOPX,
*     BTADDR,BTSIZE,BOOTFL:
*      from ST-MON's corresponding variables
*   - OFFSET
* SDISK29 initializes these variables during driver
*  initialization:  BEGLOG, LOGPTR, ENDLOG
* CLOCK clears this variable during its initialization:
*  MISTIC
* Variable SECSIZ is initialized to 256 here, but
*  may need to be manually set to the desired value
*  before each use.  Refer to section 19.0 of the
*  ST-2900 OS-9 Conversion User Manual.
*--------------------------------------------------

                    org       $FEC8
FEXXVars            equ       *         (must be $FEC8)

SECSIZ              fdb       256       default sector size for direct read/write (128/256/512/1024)
BEGLOG              fdb       0         address of start of SDISK29's disk I/O log (6 bytes/entry)
LOGPTR              fdb       0         address of next available entry in SDISK29's disk I/O log
ENDLOG              fdb       0         address of end+1 of SDISK29's disk I/O log
OFFSET              fdb       0         offset between $AXXX and $FXXX addresses of relocated ST-MON
                    fcb       0         (reserved)
MISTIC              fcb       0         number of missed clock ticks (0..n)
BDRIVE              fcb       0         drive to boot from (0..3)
DBLSTP              fcb       0         boot drive double-stepping flag (non-zero = yes)
                    fdb       0         (reserved)
ARTBAU              fcb       0         DUART port A baud rate code at boot time
ARTLEN              fcb       0         DUART port A data/parity/stop bits code at boot time
ARTACR              fcb       0         current contents of DUART's ACR register
ARTINT              fcb       0         current contents of DUART's IMR register
ARTOPC              fcb       0         current contents of DUART's OPCR register
ARTOPX              fcb       0         current values of DUART's OP7..OP0 lines
                    fdb       0         (reserved)
                    fdb       0         (reserved)
BTADDR              fdb       0         address of OS9Boot file buffer
BTSIZE              fdb       0         size of OS9Boot file (bytes)
BOOTFL              fcb       0         Boot module flag, non-zero = already called

*--------------------------------------------------
* Interrupt jump table used by ST-MON and (Nitr)OS-9.
* The six interrupt vectors (not including RESET) in
* EPROM at $FFF2-$FFFD point to these jump instructions
* in RAM at $FEE7-$FEFE, which in turn use (Nitr)OS-9
* interrupt vectors in Direct Page of RAM at $002C-$0037
* which contain the address of the (Nitr)OS-9 Interrupt
* Service Routine for each type of interrupt.
*--------------------------------------------------

IntVects            equ       *         (must be $FEE7)

VSWI3               jmp       [D.SWI3]
VSWI2               jmp       [D.SWI2]
VFIRQ               jmp       [D.FIRQ]
VIRQ                jmp       [D.IRQ]
VSWI                jmp       [D.SWI]
VNMI                jmp       [D.NMI]
Guard               fcb       0         (reserved - do not use)

FEXXend             equ       *         (must be $FF00)

                    end
