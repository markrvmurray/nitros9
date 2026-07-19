********************************************************************
*
* D0/Dn/DD descriptors for ST-2900
*
********************************************************************
                    nam       sdisk29desc
                    ttl       sdisk29 Device Descriptor Template

                  IFP1
                    use       defsfile
                  ENDC

TyLg                set       Devic+Objct
atrv                set       ReEnt+Rev
Rev                 set       1

                    ifndef    DNum
DNum                set       0
                  ENDC
                  IFNE    D35
Type                set       TYP.CCF+TYP.3
                  ELSE
Type                set       TYP.CCF+TYP.5
                  ENDC
                    ifndef    Density
Density             set       DNS.MFM
                  ENDC
Step                set       STP.12ms
                    ifndef    Cyls
Cyls                set       40
                  ENDC
                    ifndef    Sides
Sides               set       1
                  ENDC
Verify              set       0
                    ifndef    SectTrk
SectTrk             set       18
                  ENDC
                    ifndef    SectTrk0
SectTrk0            set       18
                  ENDC
                    ifndef    Interlv
Interlv             set       4
                  ENDC
                    ifndef    SAS
SAS                 set       8
                  ENDC

                    mod       ModSiz,ModName,tylg,atrv,MgrName,DrvName

                    fcb       DIR.!SHARE.!PEXEC.!PWRIT.!PREAD.!EXEC.!UPDAT.
                    fcb       HW.Page
                    fdb       FDC
                    fcb       InitSiz-*-1
                    fcb       DT.RBF    Device type:0=SCF,1=RBF,2=PIPE,3=SCF
                    fcb       DNum      Drive number
                    fcb       Step      Step rate
                    fcb       Type      Drive device type
                    fcb       Density   Media density:0=single,1=double
                    fdb       Cyls      Number of cylinders (tracks)
                    fcb       Sides     Number of sides
                    fcb       Verify    Verify disk writes:0=on
                    fdb       SectTrk   # of sectors per track
                    fdb       SectTrk0  # of sectors per track (track 0)
                    fcb       Interlv   Sector interleave factor
                    fcb       SAS       Minimum size of sector allocation
InitSiz             equ       *

                  IFNE    DD
ModName             fcs       /DD/
                  ELSE
ModName             fcb       'D,'0+DNum+$80
                  ENDC
                    fcb       $FF       Reserved for name expansion
MgrName             fcs       'RBF'
DrvName             fcs       'SDISK29'

                    emod
ModSiz              equ       *
                    end
