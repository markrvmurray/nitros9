*----------------------------------------------------------------------------
* SYSGO2.ASM
*
* Two-module replacement for the standard (Nitr)OS-9 SysGo system module:
*   "SysGo1" is a small resident module that replaces the much larger module
*         "SysGo" in the OS9Boot file.
*   "SysGo2" is a transient program in the CMDS directory of the boot drive
*         that displays the sign-on message and runs the "startup" procedure
*         file, functions that are only done during the booting process.
*
* Inspiration for the SysGo1/SysGo2 modules thanks to an article in RAINBOW
* magazine (pages 240-243 in the May 1986 issue), and suggestions from Rod
* Brogden, a fellow WCCS computer club member in Vancouver BC.
*
* Last modified 2019-Jun-15 16:48 PDT by DCW.
*----------------------------------------------------------------------------

                    nam       SysGo
                    ttl       (Nitr)OS-9 system startup module for ST-2900 - part 2 of 2
                    opt       -C        G D66 W120

* (Nitr)OS-9 definitions.
                  IFP1
                    use       defsfile
                  ENDC
StdOut.             set       1

*--------------------------------------------------
* Static storage.
*--------------------------------------------------

                    org       0
SGD.Init            rmb       2         Absolute address of module Init linked into local memory
                    rmb       198
DatSiz              equ       .

*--------------------------------------------------
* Module header.
*--------------------------------------------------
TyLg                set       Prgrm+Objct
AtRv                set       ReEnt+Rev
Rev                 set       0
Edition             set       2

                    mod       ModLen,ModNam,TyLg,AtRv,ModEntr,DatSiz

ModNam              fcs       "SysGo2"
                    fcb       Edition

*--------------------------------------------------
* Strings.
*--------------------------------------------------

SG.Init             fcs       "Init"

SG.Shell            fcs       "Shell"
SG.Start            fcc       "startup -p" -p inhibits shell prompt and messages
                    fcb       C$CR
SG.StarE            equ       *

SG.Msg1             fcb       C$CR,C$LF
                    fcc       "*******************************************"
                    fcb       C$CR,C$LF
                    fcc       "* (C) 2014 the NitrOS-9 Project"
                    fcb       C$CR,C$LF
                    fcc       "* http://www.nitros9.org"
                    fcb       C$CR,C$LF
                    fcc       "*"
                    fcb       C$CR,C$LF
                    fcc       "* Welcome to "
SG.Msg1s            equ       *-SG.Msg1

SG.Msg3             fcb       C$CR,C$LF
                    fcc       "* on the "
SG.Msg3s            equ       *-SG.Msg3

SG.Msg5             fcb       C$CR,C$LF
                    fcc       "*******************************************"
                    fcb       C$CR,C$LF
SG.Msg5s            equ       *-SG.Msg5

SG.Err1             fcb       C$CR,C$LF
                    fcc       "SysGo2: Unable to link to module Init."
                    fcb       C$CR,C$LF
SG.Err1s            equ       *-SG.Err1

SG.Err2             fcb       C$CR,C$LF
                    fcc       "SysGo2: Unable to run 'startup' procedure."
                    fcb       C$CR,C$LF
SG.Err2s            equ       *-SG.Err2

*--------------------------------------------------
* Main logic.
*--------------------------------------------------

                    setdp     $00

* Install dummy signal intercept routine.

ModEntr             leax      >Intrcpt,PC
                    os9       F$Icpt

* Set process priority.

                    os9       F$ID

                    ldb       #128      Default priority (midway between 0 and 255)
                    os9       F$SPrior

* Link to module Init.

                    leax      >SG.Init,PC
                    lda       #Systm+0
                    os9       F$Link
                    bcc       SG.OK

                    os9       F$PErr    Display system error code

                    leax      >SG.Err1,PC Display sysgo2 error message
                    ldy       #SG.Err1s
                    lda       #StdOut.
                    os9       I$Write
                    bra       SG.Exit

SG.OK               stu       <SGD.Init

* Display part 1 of welcome message.

                    leax      >SG.Msg1,PC
                    ldy       #SG.Msg1s
                    lda       #StdOut.
                    os9       I$Write

* Display part 2 of welcome message -- OS name.

                    ldu       <SGD.Init
                    ldd       OSName,U  Get address of os name string in Init module
                    leax      D,U
                    bsr       StrLen
                    tfr       D,Y
                    lda       #StdOut.
                    os9       I$Write

* Display part 3 of welcome message.

                    leax      >SG.Msg3,PC
                    ldy       #SG.Msg3s
                    lda       #StdOut.
                    os9       I$Write

* Display part 4 of welcome message -- installation name.

                    ldu       <SGD.Init
                    ldd       InstallName,U Get address of installation name string in Init module
                    leax      D,U
                    bsr       StrLen
                    tfr       D,Y
                    lda       #StdOut.
                    os9       I$Write

* Display part 5 of welcome message.

                    leax      >SG.Msg5,PC
                    ldy       #SG.Msg5s
                    lda       #StdOut.
                    os9       I$Write

* Call shell to run startup procedure file.

                    leax      >SG.Shell,PC
                    leau      >SG.Start,PC
                    ldy       #(SG.StarE-SG.Start) Parameter area size
                    lda       #TyLg
                    ldb       #0        No override of data area size
                    os9       F$Fork
                    bcs       SG.RunEr  Error, display message

                    os9       F$Wait    Wait for procedure file to finish executing
                    bra       SG.Exit

* Display error/debug messages.

SG.RunEr            os9       F$PErr    Display system error code

                    leax      >SG.Err2,PC Display sysgo2 error message
                    ldy       #SG.Err2s
                    lda       #StdOut.
                    os9       I$Write

* Exit to free up resources.

SG.Exit             os9       F$Exit

*--------------------------------------------------
* StrLen
* Determine the length of a null-terminated string.
* IN: X address of string
* OUT: D length of string (not incl. null)
*--------------------------------------------------

StrLen              pshs      X
                    ldd       #-1
SL10                addd      #1
                    tst       ,X+
                    bne       SL10
                    puls      X,PC

*--------------------------------------------------
* Dummy signal intercept routine.
*--------------------------------------------------

Intrcpt             rti

                    emod
ModLen              equ       *
                    end
