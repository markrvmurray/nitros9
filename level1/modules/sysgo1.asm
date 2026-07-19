*----------------------------------------------------------------------------
* SYSGO1.ASM
*
* Two-module replacement for the standard (Nitr)OS-9 SysGo system module:
*   "SysGo1" is a small resident module that replaces the much larger module
*         "SysGo" in the OS9Boot file.
*   "SysGo2" is a transient program in the CMDS directory of the boot drive
*         that displays the sign-on message and runs the "startup" procedure
*         file, functions that are only done during the booting process.
*
* Kernel module OS9p2/KRNp2 sets both default directories (execution and
* data) to the value specified in module init (typically /DD), before using
* F$Chain to execute SysGo1.
*
*----------------------------------------------------------------------------
* Inspiration for the SysGo1/SysGo2 modules thanks to an article in RAINBOW
* magazine (pages 240-243 in the May 1986 issue), and suggestions from Rod
* Brogden, a fellow WCCS computer club member in Vancouver BC.
*
* Last modified 2019-Jun-15 15:33 PDT by DCW.
*----------------------------------------------------------------------------

                    nam       SysGo1
                    ttl       (Nitr)OS-9 system startup module for st-2900 - part 1 of 2

*--------------------------------------------------
* definitions.
*--------------------------------------------------
                  IFP1
                    use       defsfile
                  ENDC

StdOut              equ       1

*--------------------------------------------------
* static storage.
*--------------------------------------------------

                    org       0
DbgCode             rmb       1         temporary storage of debug code
                    rmb       199
DatSiz              equ       .

*--------------------------------------------------
* module header.
*--------------------------------------------------

TyLg                set       Prgrm+Objct
AtRv                set       ReEnt+Rev
Rev                 set       0
Edition             set       2

                    mod       ModLen,ModNam,TyLg,AtRv,ModEntr,DatSiz

ModNam              fcs       "SysGo1"
                    fcb       Edition

*--------------------------------------------------
* strings.
*--------------------------------------------------

SG.Cmds             fcs       "CMDS"    New default execution directory (relative to current)

SG.SysGo            fcs       "SysGo2"
SG.Shell            fcs       "Shell"

SG.Dbg              fcc       "SG1:"    Debug message
SG.DbgSz            equ       *-SG.Dbg

*--------------------------------------------------
* Main logic.
*--------------------------------------------------

ModEntr             equ       *

* Install a dummy signal intercept routine.

                    leax      <Intrcpt,PC
                    os9       F$Icpt

* set process priority.

                    os9       F$ID      Get process id

                    ldb       #128      Default priority (midway between 0 and 255)
                    os9       F$SPrior

* Change default execution directory (was as specified in module init).

                    leax      <SG.Cmds,PC Chx cmds (relative to previous)
                    lda       #EXEC.
                    os9       I$ChgDir
                    lda       #'D       'D' = unable to change default execution directory
                    bsr       DbgMsg

* Run /DD/CMDS/SysGo2.

                    leax      <SG.SysGo,PC

ReStart             lda       #TyLg
                    ldb       #0        No override of data area size
                    ldy       #0        No parameter area
                    os9       F$Fork
                    lda       #'S       'S' = unable to run sysgo2 or shell
                    bsr       DbgMsg

                    os9       F$Wait

* run /dd/cmds/shell, restart it if it ends.

                    leax      <SG.Shell,PC
                    bra       ReStart

*--------------------------------------------------
* Display debug message if error.
* in: a SysGo1 debug code ('D' or 'S')
*     b system error code
*     u,dp bottom of static memory
*     cc c bit set if error, clear if ok
*--------------------------------------------------

DbgMsg              bcc       DbgExit   If no error, exit
                    sta       <DbgCode  Save debug code

                    os9       F$PErr    Display system error code

                    leax      <SG.Dbg,PC Display sysgo1 debug message
                    ldy       #SG.DbgSz
                    lda       #StdOut
                    os9       I$Write

                    leax      <DbgCode,U Display debug code
                    ldy       #1
                    lda       #StdOut
                    os9       I$Write

DbgExit             rts

*--------------------------------------------------
* dummy signal intercept routine.
*--------------------------------------------------

Intrcpt             rti

                    emod
ModLen              equ       *
                    end
