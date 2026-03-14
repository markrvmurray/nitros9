include ../port.mak

vpath %.asm $(LEVEL1)/modules

AFLAGS		+= -I$(LEVEL1)/$(PORT)
AFLAGS		+= -I$(LEVEL1)/modules

DEPENDS		= ./makefile

SYSMODS		= ioman sysgo1
CLOCKS		= clock_st2900 clock2_dw

RBF		= rbf.mn \
		sdisk29.dr \
		rbdw.dr dwio_mc2681.sb \
		ddd0_35s.dd  d0_35s.dd  d1_35s.dd  d2_35s.dd  d3_35s.dd \
		ddd0_40d.dd  d0_40d.dd  d1_40d.dd  d2_40d.dd  d3_40d.dd \
			    sd0_40d.dd sd1_40d.dd sd2_40d.dd sd3_40d.dd \
		ddd0_80d.dd  d0_80d.dd  d1_80d.dd  d2_80d.dd  d3_80d.dd \
			    sd0_80d.dd sd1_80d.dd sd2_80d.dd sd3_80d.dd \
		ddx0.dd x0.dd x1.dd x2.dd x3.dd

SCF		= scf.mn \
		mc2681.dr \
		term_mc2681.dd \
		scdwp.dr p_scdwp.dd \
		scdwv.dr term_scdwv.dt n_scdwv.dd n1_scdwv.dd n2_scdwv.dd \
		n3_scdwv.dd n4_scdwv.dd n5_scdwv.dd n6_scdwv.dd n7_scdwv.dd \
		n8_scdwv.dd n9_scdwv.dd n10_scdwv.dd n11_scdwv.dd n12_scdwv.dd \
		n13_scdwv.dd midi_scdwv.dd

PIPE		= pipeman.mn \
		piper.dr \
		pipe.dd

KERNEL		= krn krnp2 init_st2900 boot_st2900

ALLOBJS		= $(KERNEL) $(SYSMODS) $(CLOCKS) $(RBF) $(SCF) $(PIPE)

all:	$(ALLOBJS)

# Kernel
krn krnp2:
	$(CD) kernel; make $@
	$(CP) kernel/$@ .

# Floppy descriptors
SSDD35		= -DCyls=35 -DSides=1 -DSectTrk=18 -DSectTrk0=18 \
		-DInterlv=4 -DSAS=8 -DDensity=1
DSDD40		= -DCyls=40 -DSides=2 -DSectTrk=18 -DSectTrk0=18 \
		-DInterlv=4 -DSAS=8 -DDensity=1
DSDD80		= -DCyls=80 -DSides=2 -DSectTrk=18 -DSectTrk0=18 \
		-DInterlv=4 -DSAS=8 -DDensity=1 -DD35
DSSD40		= -DCyls=40 -DSides=2 -DSectTrk=10 -DSectTrk0=10 \
		-DInterlv=4 -DSAS=8 -DDensity=0
DSSD80		= -DCyls=80 -DSides=2 -DSectTrk=10 -DSectTrk0=10 \
		-DInterlv=4 -DSAS=8 -DDensity=0 -DD35

ddd0_35s.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(SSDD35) -DDNum=0 -DDD=1

d0_35s.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(SSDD35) -DDNum=0

d1_35s.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(SSDD35) -DDNum=1

d2_35s.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(SSDD35) -DDNum=2

d3_35s.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(SSDD35) -DDNum=3

ddd0_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD40) -DDNum=0 -DDD=1

d0_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD40) -DDNum=0

d1_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD40) -DDNum=1

d2_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD40) -DDNum=2

d3_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD40) -DDNum=3

sd0_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD40) -DDNum=0

sd1_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD40) -DDNum=1

sd2_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD40) -DDNum=2

sd3_40d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD40) -DDNum=3

ddd0_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=0 -DDD=1

d0_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=0

d1_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=1

d2_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=2

d3_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=3

sd0_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=0

sd1_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=1

sd2_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=2

sd3_80d.dd: sdisk29desc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=3

# DriveWire 3 RBF descriptors
ddx0.dd: dwdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDD=1 -DDNum=0

x0.dd: dwdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=0

x1.dd: dwdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=1

x2.dd: dwdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=2

x3.dd: dwdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=3

# MC2681 SCF descriptors
term_mc2681.dd: term_mc2681.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS)

t1_mc2681.dd: term_mc2681.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DTNum=1

# DriveWire subroutine module (38400 baud via MC2681 port B)
dwio_mc2681.sb: dwio.asm dwread.asm dwwrite.asm dwinit.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DMC2681=1

# DriveWire 3 SCF descriptors
term_scdwv.dt: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=0

n_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=255

n1_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=1

n2_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=2

n3_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=3

n4_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=4

n5_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=5

n6_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=6

n7_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=7

n8_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=8

n9_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=9

n10_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=10

n11_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=11

n12_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=12

n13_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=13

midi_scdwv.dd: scdwvdesc.asm
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=14

# Clocks
clock_st2900: clock_st2900.asm
	$(AS) $(AFLAGS) $(ASOUT)$@ $<

clean:
	$(CD) kernel; make $@
	$(RM) $(ALLOBJS) *.list *.map

showobjs:
	@$(ECHO) $(ALLOBJS)

showkernel:
	@$(ECHO) $(KERNEL)

showsysmods:
	@$(ECHO) $(SYSMODS)

showclocks:
	@$(ECHO) $(CLOCKS)

showrbf:
	@$(ECHO) $(RBF)

showscf:
	@$(ECHO) $(SCF)

showpipe:
	@$(ECHO) $(PIPE)

identify:
	$(IDENT_SHORT) $(ALLOBJS)
