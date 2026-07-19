*-----------------------------------------------------------*
* BOOT.ASM
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
                    ttl       Boot      module and FEXX page for (Nitr)OS-9 on the ST-2900.

                    opt       -C        G D66 W120

*--------------------------------------------------
* Definitions.
*--------------------------------------------------

                  IFP1
                    use       defsfile
                  ENDC

BtOfst              equ       $FDF3     location of Boot module in memory

*--------------------------------------------------
* Boot module header.
*--------------------------------------------------

TypLng              set       Systm+Objct
AtrRev              set       ReEnt+Rev
Rev                 set       0         (0..15)
Edition             set       3         (0..255)
BtDatSz             set       0         no static storage used, stack is system stack

BtBeg               equ       *+BtOfst  (must be $FDF3)

                    mod       BtSiz,BtName,TypLng,AtrRev,BtEntry,BtDatSz

*--------------------------------------------------
* Address vector table for DUART subroutines.  It
* contains the addresses of the seven routines.  Use
* JSR [$FExx] to call the desired routine.  This
* allows the routines to change in size or location
* without affecting the calling software.
*--------------------------------------------------

FEXXbeg             equ       *+BtOfst  (must be $FE00)

                    fdb       xDACRON+BtOfst
                    fdb       xDACROF+BtOfst
                    fdb       xDINTON+BtOfst
                    fdb       xDINTOF+BtOfst
                    fdb       xDOPCON+BtOfst
                    fdb       xDOPCOF+BtOfst
                    fdb       xSETOPR+BtOfst

*--------------------------------------------------
* Boot module code.
* Requests a block of system memory large enough to
* contain the OS9Boot file, then copies OS9Boot from
* a temporary buffer into this block, starting from
* the end and working backwards.
* This routine is called using JSR, not F$Fork.
* Inputs: BOOTFL, BTADDR, BTSIZE
* Outputs: X boot file starting address in RAM
*          D boot file size (bytes)
*          U,Y undefined
* Error: CC C bit set
*        B  error code
*--------------------------------------------------

BtName              fcs       "Boot"
                    fcb       Edition

BtEntry             tst       >BOOTFL   Boot previously called?
                    bne       BT80      .Y, error
                    inc       >BOOTFL   .N, set flag to indicate "called"

                    ldd       >BTSIZE   Size of memory block to allocate
                    os9       F$SRqMem  Request block of system memory (from top of RAM)
                    bcs       BT90

                    pshs      U         Save start of boot file (new location)
                    ldd       >BTSIZE   Actual size of boot file
                    ldx       >BTADDR   Start of boot file (old location)
                    leax      D,X       Calculate end of boot file (old location)
                    leau      D,U       Calculate end of boot file (new location)
                    tfr       D,Y       Iniz down counter to size of boot file

BT10                lda       ,-X       Get byte to move from old location
                    clr       ,X        Zero it out in old location
                    sta       ,-U       Save into new location
                    leay      -1,Y      All data moved?
                    bne       BT10      .N, move next byte

                    clrb                return    Code = OK
                    puls      X         Return boot file starting address in memory
                    ldd       >BTSIZE   Return boot file size (actual, in bytes)
                    bra       BT90

BT80                comb                error     If Boot called a second time
                    ldb       E$NEMod   Error = "non existant module"
BT90                rts                 return    To caller in kernel

*--------------------------------------------------
* DACRON/DACROF
* Update the 2681 DUART 'ACR' write-only register,
* setting individual bits on or off.
* IN: A the bits to be affected are 1's, others are 0's
* OUT: A new ACR contents
*      CC,B,X,Y,U,S unchanged
*--------------------------------------------------

DACRON.L            equ       *+BtOfst

xDACRON             pshs      CC
                    orcc      #IntMasks Disable interrupts
                    nop
                    ora       >ARTACR   Set specified bits
                    bra       DA50

DACROF.L            equ       *+BtOfst

xDACROF             pshs      CC
                    orcc      #IntMasks Disable interrupts
                    coma
                    anda      >ARTACR   Clear specified bits

DA50                sta       >ARTACR   Update variable and DUART register
                    sta       >ACR.D
                    puls      CC,PC     Restore interrupts, return to caller

*--------------------------------------------------
* DINTON/DINTOF
* Enable/disable individual interrupt sources from
* the 2681 DUART by updating write-only register 'IMR'.
* IN: A the bits to be affected are 1's, others are 0's
* OUT: A new ARTINT contents
*      CC,B,X,Y,U,S unchanged
*--------------------------------------------------

DINTON.L            equ       *+BtOfst

xDINTON             pshs      CC
                    orcc      #IntMasks disable processor interrupts
                    nop
                    ora       >ARTINT   set specified bits
                    bra       DI50

DINTOF.L            equ       *+BtOfst

xDINTOF             pshs      CC
                    orcc      #IntMasks disable processor interrupts
                    coma
                    anda      >ARTINT   clear specified bits

DI50                sta       >ARTINT   update variable and DUART register
                    sta       >IMR.D
                    puls      CC,PC     restore interrupts, return to caller

*--------------------------------------------------
* DOPCON/DOPCOF
* Update the 2681 DUART 'OPCR' write-only register,
* setting individual bits on or off.
* IN: A the bits to be affected are 1's, others are 0's
* OUT: A new OPCR contents
*      CC,B,X,Y,U,S unchanged
*--------------------------------------------------

DOPCON.L            equ       *+BtOfst

xDOPCON             pshs      CC
                    orcc      #IntMasks Disable interrupts
                    nop
                    ora       >ARTOPC   Set specified bits
                    bra       DO50

DOPCOF.L            equ       *+BtOfst

xDOPCOF             pshs      CC
                    orcc      #IntMasks Disable interrupts
                    coma
                    anda      >ARTOPC   Clear specified bits

DO50                sta       >ARTOPC   Update variable and DUART register
                    sta       >OPCR.D
                    puls      CC,PC     Restore interrupts, return to caller

*--------------------------------------------------
* SETOPR
* Set DUART output lines OP7..OP0 via register 'OPR'.
* IN: A value to set output lines to (complement of OPR)
*     B mask re which bits are to be affected
* OUT: A undefined
*      CC,B,X,Y,U,S unchanged
*--------------------------------------------------

SETOPR.L            equ       *+BtOfst

xSETOPR             pshs      CC,A,B
                    orcc      #IntMasks Disable interrupts
                    anda      2,S
                    sta       1,S
                    comb
                    andb      >ARTOPX
                    orb       1,S
                    stb       >ARTOPX
                    eora      2,S
                    ldb       1,S
                    std       >OPRset.D Update DUART OPR register via set/reset registers
                    puls      CC,A,B,PC Restore interrupts, return to caller

*--------------------------------------------------
* End of Boot module.
*--------------------------------------------------

                    emod
BtSiz               equ       *
                    end
