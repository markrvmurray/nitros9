*----------------------------------------------------------------------------
* INIT.ASM - NitrOS-9 Initialization Module.
* Operating system initialization values.
* Cleaned up and modified for Sardis Technologies ST-2900 NitrOS-9 Level 1.
* This module is currently only defined for NitrOS-9/6809 Level 1, not for
* OS-9/6809 Level 1.
* Last modified 2019-Jun-15 14:56 PDT by DCW.
*----------------------------------------------------------------------------

                    nam       Init
                    ttl       NitrOS-9 initialization module for st-2900
                    opt       -C        G D66 W120

*--------------------------------------------------
* Definitions.
*--------------------------------------------------

* (Nitr)OS-9 definitions.
                  IFP1
                    use       defsfile
                  ENDC

* Init module header definitions.
TypLng              set       Systm+0
AtrRev              set       ReEnt+Rev
Rev                 set       0         (0..15)
Edition             set       1         (0..255)

*--------------------------------------------------
* Module header.
*--------------------------------------------------
* Usually, the last two words here would be the module entry
* address and the dynamic data size requirement. Neither value is
* needed for this module so they are pressed into service to show
* MaxMem and PollCnt. For example:
* $00FD,$F204 means
* MaxMem = $00FDF2
* PollCnt = $04

                    mod       ModSiz,ModNam,TypLng,AtrRev,$00FD,$F204

*--------------------------------------------------
* Initialization table.
*--------------------------------------------------

* The first three entries are hacked into the last two words of the above 'mod'
*                   fcb       $00       Upper address limit for end-of-ram search
*                   fdb       $FDF2
*                   fcb       4         # entries in irq polling table
                    fcb       16        # entries in system device table

                    fdb       DefProg   Offset to execution module string
                    fdb       DefDir    Offset to default directories string
                    fdb       DefCons   Offset to default console device string
                    fdb       DefBoot   Offset to boot module string

                    fcb       $01       Write protect flag (?)

                    fcb       Level     OS level
                    fcb       NOS9VER   OS version
                    fcb       NOS9MAJ   OS major revision
                    fcb       NOS9MIN   OS minor revision

                    fcb       Proc6809+CRCOn Feature byte #1
                    fcb       $00       Feature byte #2

                    fdb       OSStr     Offset to operating system string
                    fdb       InstStr   Offset to installation string

                    fcb       0,0,0,0   Reserved

*--------------------------------------------------
* Strings.
*--------------------------------------------------

ModNam              fcs       "Init"    module name
                    fcb       Edition   module edition

DefProg             fcs       "SysGo1"  first module to be executed after startup
DefDir              fcs       "/DD"     initial default directories (execution and data)
DefCons             fcs       "/Term"   initial standard path
DefBoot             fcs       "Boot"    bootstrap module name

* Operating system name and version.
OSStr               fcc       "NitrOS-9/6809 Level "
                    fcb       '0+Level
                    fcc       " v"
                    fcb       '0+NOS9VER
                    fcb       '.
                    fcb       '0+NOS9MAJ
                    fcb       '.
                    fcb       '0+NOS9MIN
                    fcb       0

* Hardware installation platform.
InstStr             fcc       "Sardis Technologies ST-2900"
                    fcb       0

                    emod
ModSiz              equ       *
                    end
