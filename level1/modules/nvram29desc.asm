**************************************************************************
*
* Copyright (c) 1991, 2019-2022 by David C. Wiens, Langley BC Canada.
*
* Permission to use, copy, modify, and distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*
**************************************************************************

*----------------------------------------------------------------------------
* DEVICE: S0
* PURPOSE: Device descriptor for the SRAM-Disk on the NVRAM/RTC board that
*   uses port B of the 6522/VIA on the ST-2900 FDC board.
*
* NOTES:
*  - Test configuration uses first 64KB (16 cylinders) of one SRAM chip in U10.
*  - Final configuration uses 512KB (128 cylinders) in four SRAM chips in U3..U6.
*  - Refer to driver notes for more information.
*  - If S0 is the only RBF device descriptor, its internal name should be
*    changed from "S0" to "DD", or make a copy of "S0" and rename the copy
*    to "DD".
*----------------------------------------------------------------------------

                  IFP1
                    use       defsfile
                  ENDC

CAP.ALL             equ       DIR.+SHARE.+PEXEC.+PWRIT.+PREAD.+EXEC.+WRITE.+READ.

*--------------------------------------------------------------
* Device descriptor header.
*--------------------------------------------------------------

Rev                 set       0         (0..15)
Edition             set       0         (0..255)
TypLng              set       Devic+Objct
AtrRev              set       ReEnt+Rev

                    mod       S.ModSiz,S.DevNam,TypLng,AtrRev

                    fdb       S.MgrNam  offset to file manager name
                    fdb       S.DrvNam  offset to device driver name

                    fcb       CAP.ALL   capabilities = all

                    fcb       $00       Device physical address (MSB)
                    fdb       $FF4A     .  "      "        "    (LSW) (6522 shift register)

                    fcb       S.EndTbl-*-1 initialization table size

*--------------------------------------------------------------
* Initialization table.
*--------------------------------------------------------------

S.TYPC              set       TYP.NVRM+TYP.SOF+TYPN.SRM

S.DTP               fcb       DT.RBF    device type
S.DRV               fcb       0         drive number
S.STP               fcb       0         step rate (not used)
S.TYP               fcb       S.TYPC    device type = 23LCV1024 (see driver notes)
S.DNS               fcb       0         media density (not used)
S.CYL               fdb       128       number of cylinders (final config)
S.SID               fcb       1         number of sides (always 1)
S.VFY               fcb       1         verify flag (always 1 = don't verify)
S.SCT               fdb       16        default sectors/track (always 16)
S.T0S               fdb       16        default sectors/track zero (always 16)
S.ILV               fcb       0         sector interleave factor (not used)
S.SAS               fcb       4         segment allocation size (final config)
S.EndTbl            equ       *

*--------------------------------------------------------------
* Name strings.
*--------------------------------------------------------------

S.MgrNam            fcs       "RBF"      file manager name
S.DrvNam            fcs       "NVRAMdrv" device driver name
S.DevNam            fcs       "S0"       device descriptor name
                    fcb       Edition   module edition

                    emod
S.ModSiz            equ       *

*----------------------------------------------------------------------------
* DEVICE: E0
* PURPOSE: Device descriptor for the EEPROM-Disk on the NVRAM/RTC board that
*   uses port B of the 6522/VIA on the ST-2900 FDC board.
* NOTES:
*  - Test configuration uses first 64KB (16 cylinders) of one 25LC1024 EEPROM
*    chip in U12.
*  - Final configuration uses 512KB (128 cylinders) in one 25CSM04 EEPROM chip
*    in U11, or 128KB (32 cylinders) in one 25LC1024 EEPROM chip in U11.
*----------------------------------------------------------------------------

*--------------------------------------------------------------
* Device descriptor header.
*--------------------------------------------------------------

Rev                 set       0         (0..15)
Edition             set       0         (0..255)
TypLng              set       Devic+Objct
AtrRev              set       ReEnt+Rev

                    mod       E.ModSiz,E.DevNam,TypLng,AtrRev

                    fdb       E.MgrNam  offset to file manager name
                    fdb       E.DrvNam  offset to device driver name

                    fcb       CAP.ALL   capabilities = all

                    fcb       $00       Device physical address (MSB)
                    fdb       $FF4A     .  "      "        "    (LSW) (6522 shift register)

                    fcb       E.EndTbl-*-1 initialization table size

*--------------------------------------------------------------
* Initialization table.
*--------------------------------------------------------------

E.TYPC              set       TYP.NVRM+TYP.SOF+TYPN.EEP+TYPN.EE4

E.DTP               fcb       DT.RBF    device type
E.DRV               fcb       1         drive number
E.STP               fcb       0         step rate (not used)
E.TYP               fcb       E.TYPC    device type = 25CSM04 (see driver notes)
E.DNS               fcb       0         media density (not used)
E.CYL               fdb       128       number of cylinders (25CSM04 final config)
E.SID               fcb       1         number of sides (always 1)
E.VFY               fcb       1         verify flag (always 1 = don't verify)
E.SCT               fdb       16        default sectors/track (always 16)
E.T0S               fdb       16        default sectors/track zero (always 16)
E.ILV               fcb       0         sector interleave factor (not used)
E.SAS               fcb       4         segment allocation size (final config)
E.EndTbl            equ       *

*--------------------------------------------------------------
* Name strings.
*--------------------------------------------------------------

E.MgrNam            fcs       "RBF"      file manager name
E.DrvNam            fcs       "NVRAMdrv" device driver name
E.DevNam            fcs       "E0"       device descriptor name
                    fcb       Edition   module edition

                    emod
E.ModSiz            equ       *

                    end

