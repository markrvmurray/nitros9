*************************************************
*                                               *
*       /Term                                   *
*                                               *
*************************************************
                    nam       Term
                    ttl       mc2681 Device Descriptor

                  IFP1
                    use       defsfile
                  ENDC

TyLg                set       Devic+Objct
AtRv                set       ReEnt+Rev
Rev                 set       1

                    mod       ModLen,ModName,TyLg,AtRv,MgrName,DrvName

                    fcb       UPDAT.    Mode byte
                    fcb       HW.Page   Extended controller address
                    fdb       Duart     .  "      "        "    (lsb)

                    fcb       InitSiz-*-1 initialization table size
*
* initialization table
*
                    fcb       0         Device type (0 = scf)
                    fcb       0         Case (0 = upper/lower case)
                    fcb       1         Backspace output (01 = bse/spce/bse)
                    fcb       0         Delete output (0 = bse over entire line)
                    fcb       1         Echo flag (1 = echo)
                    fcb       1         Auto line-feed (01 = yes)
                    fcb       0         Number of end-of-line nulls
                    fcb       1         End-of-page pause flag (1 = yes)
                    fcb       24        Lines per page
                    fcb       $08       Keyboard backspace character (ctl h)
                    fcb       $18       Keyboard delete-line character (ctl x)
                    fcb       $0D       End-of-record character (cr)
                    fcb       $1B       Keyboard end-of-file character (escape/ctl [)
                    fcb       $04       Keyboard reprint-current-line charac (ctl d)
                    fcb       $01       Keyboard duplicate-prev-line charac (ctl a)
                    fcb       $17       Keyboard "pause" character (ctl w)
                    fcb       $03       Keyboard "interrupt" character (ctl c)
                    fcb       $11       Keyboard "quit" character (ctl q)
                    fcb       $08       Backspace output character
                    fcb       $07       Line overflow character (bell)
                    fcb       $B3       Device initialization value (8/N/2)
                    fcb       7         Baud rate (7 = 38400 baud)
                    fdb       ModName   Offset to name of attached device
                    fcb       $00       X-on character (not defined)
                    fcb       $00       X-off character (not defined)
                    fdb       0         (reserved for expansion)
InitSiz             equ       *
*
* name strings
*
                    IFDEF     TNum      From makefile
                  IFEQ    TNum
ModName             fcs       'T0'
                    ENDIF
                  IFEQ    TNum-1
ModName             fcs       'T1'
                    ENDIF
                  ELSE
ModName             fcs       'TERM'    Module name
                    ENDIF

MgrName             fcs       'SCF'     File manager name
DrvName             fcs       'MC2681'  Device driver name

                    emod
ModLen              equ       *
                    end
