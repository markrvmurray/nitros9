# Sardis Technologies ST-2900 shared build recipe (Level 1, 6809 and 6309).
#
# The ST-2900 boots like the Pico-Thing from two files rather than a track:
#   OS9Kernel = krn krnp2 init_st2900 + a boot block, merged and padded to
#               exactly 3840 bytes so it occupies $F000-$FEFF.  The boot
#               block is boot_st2900, zero padding, then a raw FEXX data
#               block that must end at $FF00 (the ST-2900 boot ROM jumps to
#               a fixed address in it).
#   OS9Boot   = the merged bootfile (ioman, RBF + sdisk29 floppy stack, SCF
#               + MC2681 console, pipes, clock, sysgo1, plus the DriveWire
#               stack on the dw recipes).
#
# Leaf recipes (floppy/, dw/, dd_dw/, *_6309/) set the variant and CPU.
# PORT stays "st2900" for every variant so all sources and the port
# defsfile (which sets Level) resolve to level1/st2900 and level1/modules.

PORT ?= st2900
RECIPE ?= st2900
CPU ?= 6809
MACHINE ?= Sardis Technologies ST-2900
LEVEL = 1
TELNET_PORT ?= 6803
HTTPD_PORT ?= 8803
MODDIR = .mods
include ../../rules.mak
-include recipe.mak

# Assembler search: -I$(L1PD) supplies the port defsfile (Level 1) for
# modules; -I$(L1PD)/defs makes the level1/cmds/defsfile "use ../defsfile"
# chain resolve to it too.  The ST-2900 modules live in level1/modules.
AFLAGS += -I. -I$(L1PD) -I$(L1PD)/defs -I$(L1MD) -I$(L1MD)/kernel
AFLAGS += $(AFLAGS_EXTRA)
LFLAGS += -L$(LIBDIR) -lnet -lst2900 -lalib
LFLAGS += $(LFLAGS_EXTRA)

LIB_NAMES = libst2900.a libnet.a libalib.a

DISTRONAME = NOS9_$(CPU)_L$(LEVEL)
DISTROVER  = $(DISTRONAME)_$(NITROS9VER)_$(RECIPE)

# ---------------------------------------------------------------------------
# Module groups (bare names, built into $(MODDIR))
# ---------------------------------------------------------------------------

SYSMODS = ioman sysgo1
CLOCK   = clock_st2900
CONSOLE = mc2681.dr term_mc2681.dd
PIPE    = pipeman.mn piper.dr pipe.dd

# sdisk29 floppy stack (80-track double-density is the default variant)
FLOPPY  = sdisk29.dr \
          d0_80d.dd d1_80d.dd d2_80d.dd d3_80d.dd \
          sd0_80d.dd sd1_80d.dd sd2_80d.dd sd3_80d.dd
BOOT_DD = ddd0_80d.dd

# DriveWire stack (added by the dw / dd_dw recipes via *_EXTRA)
RBDW      = rbdw.dr dwio_mc2681.sb x0.dd x1.dd x2.dd x3.dd
SCDWV     = scdwv.dr n_scdwv.dd n1_scdwv.dd n2_scdwv.dd n3_scdwv.dd \
            n4_scdwv.dd n5_scdwv.dd n6_scdwv.dd n7_scdwv.dd n8_scdwv.dd \
            n9_scdwv.dd n10_scdwv.dd n11_scdwv.dd n12_scdwv.dd n13_scdwv.dd \
            midi_scdwv.dd
SCDWP     = scdwp.dr p_scdwp.dd

# OS9Boot: default is the floppy bootfile (boot device = ddd0 floppy).
# The DriveWire recipes override BOOTFILE in their recipe.mak (they boot
# from ddx0 and carry the DriveWire stack instead).
BOOTFILE ?= ioman rbf.mn $(FLOPPY) $(BOOT_DD) scf.mn $(CONSOLE) \
            $(PIPE) $(CLOCK) sysgo1

# OS9Kernel parts (boot_block is assembled separately below)
KERNEL   = krn krnp2 init_st2900

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

CMDS = asm attr backup binex build calldbg cmp copy cputype \
       date dcheck debug ded deiniz del deldir devs dir dirsort disasm \
       display dmode dsave dspeed dump echo edit error exbin \
       free help ident iniz irqs link list load login makdir \
       megaread mdir merge mfree padrom park printerr procs prompt pwd pxd \
       nvformat nvstatus \
       rename save setime sformat shell_21 sleep sysgo2 \
       tee tmode touch tsmon unlink verify xmode \
       $(CMDS_EXTRA)

# ---------------------------------------------------------------------------
# Build products
# ---------------------------------------------------------------------------

OS9FORMAT_CMD ?= $(OS9FORMAT_DS80)
STARTUP ?= $(L1PD)/startup
DSKIMAGE ?= $(DISTROVER).dsk

# ST-2900 boot geometry: boot module loads at $FDF3, the FEXX data block
# must end at $FF00, and the whole OS9Kernel is padded to 3840 bytes so it
# spans $F000-$FEFF.
BOOT_START = 0xFDF3
FEXX_END   = 0xFF00
KERNEL_PAD = 3840

all: libs kernel_st2900 $(DSKIMAGE)

include ../../libs.mak

# ---- descriptor / driver rules that need non-default flags ----------------

SSDD35 = -DCyls=35 -DSides=1 -DSectTrk=18 -DSectTrk0=18 -DInterlv=4 -DSAS=8 -DDensity=1
DSDD40 = -DCyls=40 -DSides=2 -DSectTrk=18 -DSectTrk0=18 -DInterlv=4 -DSAS=8 -DDensity=1
DSDD80 = -DCyls=80 -DSides=2 -DSectTrk=18 -DSectTrk0=18 -DInterlv=4 -DSAS=8 -DDensity=1 -DD35
DSSD40 = -DCyls=40 -DSides=2 -DSectTrk=10 -DSectTrk0=10 -DInterlv=4 -DSAS=8 -DDensity=0
DSSD80 = -DCyls=80 -DSides=2 -DSectTrk=10 -DSectTrk0=10 -DInterlv=4 -DSAS=8 -DDensity=0 -DD35

$(MODDIR)/ddd0_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=0 -DDD=1
$(MODDIR)/d0_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=0
$(MODDIR)/d1_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=1
$(MODDIR)/d2_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=2
$(MODDIR)/d3_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSDD80) -DDNum=3
$(MODDIR)/sd0_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=0
$(MODDIR)/sd1_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=1
$(MODDIR)/sd2_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=2
$(MODDIR)/sd3_80d.dd: sdisk29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) $(DSSD80) -DDNum=3

$(MODDIR)/term_mc2681.dd: term_mc2681.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS)
$(MODDIR)/nvram29desc.dd: nvram29desc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS)

# DriveWire subroutine module (38400 baud via the MC2681 second port)
$(MODDIR)/dwio_mc2681.sb: dwio.asm dwread.asm dwwrite.asm dwinit.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DMC2681=1

# DriveWire RBF descriptors
$(MODDIR)/ddx0.dd: dwdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDD=1 -DDNum=0
$(MODDIR)/x0.dd: dwdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=0
$(MODDIR)/x1.dd: dwdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=1
$(MODDIR)/x2.dd: dwdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=2
$(MODDIR)/x3.dd: dwdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DDNum=3

# DriveWire SCF virtual channels
$(MODDIR)/term_scdwv.dt: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=0
$(MODDIR)/n_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=255
$(MODDIR)/n1_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=1
$(MODDIR)/n2_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=2
$(MODDIR)/n3_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=3
$(MODDIR)/n4_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=4
$(MODDIR)/n5_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=5
$(MODDIR)/n6_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=6
$(MODDIR)/n7_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=7
$(MODDIR)/n8_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=8
$(MODDIR)/n9_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=9
$(MODDIR)/n10_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=10
$(MODDIR)/n11_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=11
$(MODDIR)/n12_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=12
$(MODDIR)/n13_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=13
$(MODDIR)/midi_scdwv.dd: scdwvdesc.asm | $(MODDIR)
	$(AS) $< $(ASOUT)$@ $(AFLAGS) -DAddr=14

# ---- command rules that need non-default flags ---------------------------

$(MODDIR)/tmode: xmode.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DTMODE=1
$(MODDIR)/xmode: xmode.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DXMODE=1
$(MODDIR)/pwd: pd.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DPWD=1
$(MODDIR)/pxd: pd.asm | $(MODDIR)
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DPXD=1

# ---- OS9Boot, boot block, OS9Kernel --------------------------------------

bootfile: $(addprefix $(MODDIR)/,$(BOOTFILE))
	$(MERGE) $(addprefix $(MODDIR)/,$(BOOTFILE)) >$@

# FEXX data block: raw binary that ends at $FF00
boot_st2900_data: $(L1PD)/bootfiles/boot_st2900_data.asm | $(MODDIR)
	$(ASROM) -I$(L1PD) $(ASOUT)$@ $< $(AFLAGS)

# Zero padding between the boot module end and the FEXX data start
boot_fexx_padding: $(MODDIR)/boot_st2900 boot_st2900_data
	BOOT_LENGTH=$$(stat -f%z $(MODDIR)/boot_st2900) ;\
	FEXX_LENGTH=$$(stat -f%z boot_st2900_data) ;\
	BOOT_END=$$(($(BOOT_START)+$${BOOT_LENGTH})) ;\
	FEXX_START=$$(($(FEXX_END)-$${FEXX_LENGTH})) ;\
	PADDING=$$(($${FEXX_START}-$${BOOT_END})) ;\
	dd if=/dev/zero of=$@ bs=1 count=$${PADDING} 2>/dev/null

boot_block: $(MODDIR)/boot_st2900 boot_fexx_padding boot_st2900_data
	$(MERGE) $(MODDIR)/boot_st2900 boot_fexx_padding boot_st2900_data >$@

# OS9Kernel: krn krnp2 init_st2900 + boot block, padded to $F000-$FEFF
kernel_st2900: $(addprefix $(MODDIR)/,$(KERNEL)) boot_block
	$(MERGE) $(addprefix $(MODDIR)/,$(KERNEL)) boot_block >$@
	$(PADROM) -b $(KERNEL_PAD) $@

# ---- disk image ----------------------------------------------------------

$(DSKIMAGE): bootfile kernel_st2900 helpmsg \
             $(addprefix $(MODDIR)/,$(CMDS))
	$(RM) $@
	$(OS9FORMAT_CMD) -q $@ -n"NitrOS-9/$(CPU) Level $(LEVEL)"
	$(OS9COPY) kernel_st2900 $@,OS9Kernel
	$(OS9ATTR_EXEC) $@,OS9Kernel
	$(OS9COPY) bootfile $@,OS9Boot
	$(MAKDIR) $@,CMDS
	$(OS9COPY) $(addprefix $(MODDIR)/,$(CMDS)) $@,CMDS
	$(OS9ATTR_EXEC) $(foreach f,$(CMDS),$@,CMDS/$(f))
	$(OS9RENAME) $@,CMDS/shell_21 shell
	$(MAKDIR) $@,SYS
	$(CPL) $(SYS_TEXT_FILES) $@,SYS
	$(OS9ATTR_TEXT) $(foreach f,$(notdir $(SYS_TEXT_FILES)),$@,SYS/$(f))
	$(CPL) $(STARTUP) $@,startup
	$(OS9ATTR_TEXT) $@,startup

# ---- system support files ------------------------------------------------

HELPFILES = asm.hp attr.hp backup.hp binex.hp build.hp chd.hp chx.hp cmp.hp \
            config.hp copy.hp cputype.hp date.hp dcheck.hp debug.hp ded.hp \
            deiniz.hp del.hp deldir.hp devs.hp dir.hp dirsort.hp disasm.hp \
            display.hp dmode.hp dsave.hp dump.hp echo.hp edit.hp error.hp \
            ex.hp exbin.hp sformat.hp free.hp help.hp ident.hp iniz.hp \
            inkey.hp irqs.hp kill.hp link.hp list.hp load.hp login.hp \
            makdir.hp mdir.hp megaread.hp merge.hp minted.hp mpi.hp mfree.hp \
            padrom.hp park.hp procs.hp prompt.hp pwd.hp pxd.hp rename.hp \
            save.hp setime.hp setpr.hp shell.hp sleep.hp tee.hp tmode.hp \
            touch.hp tsmon.hp tuneport.hp unlink.hp verify.hp xmode.hp

SYS_TEXT_FILES = $(L1D)/sys/errmsg $(L1D)/sys/motd $(L1D)/sys/password \
                 $(L1D)/sys/inetd.conf helpmsg

vpath %.hp $(L1D)/sys

helpmsg: $(HELPFILES)
	$(MERGE) $^ > $@

clean:
	$(RM) *.list *.map bootfile kernel_st2900 boot_block boot_fexx_padding
	$(RM) boot_st2900_data *.dsk buildinfo helpmsg
	-rm -rf $(OBJDIR) $(LIBDIR) $(MODDIR)

.PHONY: all clean libs bootfile
