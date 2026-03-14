include ../port.mak

# Module directory
MD		= ../modules

AFLAGS		+= -I$(LEVEL1)/$(PORT)
AFLAGS		+= -I$(LEVEL1)/modules
ST29FLAGS	= $(AFLAGS) $(FLAGS)

DEPENDS		= ./makefile

KERNEL_PARTS	= $(MD)/krn $(MD)/krnp2 $(MD)/init_st2900 boot_block
BOOT_BLOCK	= $(MD)/boot_st2900 boot_fexx_padding boot_st2900_data	# Order is important!
KERNEL		= kernel_st2900

FLOPPY_40D	= $(MD)/sdisk29.dr \
		$(MD)/d0_40d.dd $(MD)/d1_40d.dd $(MD)/d2_40d.dd $(MD)/d3_40d.dd \
		$(MD)/sd0_40d.dd $(MD)/sd1_40d.dd $(MD)/sd2_40d.dd $(MD)/sd3_40d.dd

FLOPPY_80D	= $(MD)/sdisk29.dr \
		$(MD)/d0_80d.dd $(MD)/d1_80d.dd $(MD)/d2_80d.dd $(MD)/d3_80d.dd \
		$(MD)/sd0_80d.dd $(MD)/sd1_80d.dd $(MD)/sd2_80d.dd $(MD)/sd3_80d.dd

RBDW		= $(MD)/rbdw.dr $(MD)/dwio_mc2681.sb \
		$(MD)/x0.dd $(MD)/x1.dd $(MD)/x2.dd $(MD)/x3.dd

CONSOLE_DRV	= $(MD)/mc2681.dr $(MD)/term_mc2681.dd

SCDWV_NET	= $(MD)/n_scdwv.dd $(MD)/n1_scdwv.dd $(MD)/n2_scdwv.dd \
		$(MD)/n3_scdwv.dd $(MD)/n4_scdwv.dd $(MD)/n5_scdwv.dd \
		$(MD)/n6_scdwv.dd $(MD)/n7_scdwv.dd $(MD)/n8_scdwv.dd \
		$(MD)/n9_scdwv.dd $(MD)/n10_scdwv.dd $(MD)/n11_scdwv.dd \
		$(MD)/n12_scdwv.dd $(MD)/n13_scdwv.dd $(MD)/midi_scdwv.dd

SCDWP		= $(MD)/scdwp.dr $(MD)/p_scdwp.dd

PIPE		= $(MD)/pipeman.mn $(MD)/piper.dr $(MD)/pipe.dd

CLOCK		= $(MD)/clock_st2900

BOOTFILE_ST2900_40DD	= $(MD)/ioman \
		$(MD)/rbf.mn \
		$(FLOPPY_40D) \
		$(MD)/ddd0_40d.dd \
		$(MD)/scf.mn \
		$(CONSOLE_DRV) \
		$(PIPE) \
		$(CLOCK) \
		$(MD)/sysgo1

BOOTFILE_ST2900_80DD	= $(MD)/ioman \
		$(MD)/rbf.mn \
		$(FLOPPY_80D) \
		$(MD)/ddd0_80d.dd \
		$(MD)/scf.mn \
		$(CONSOLE_DRV) \
		$(PIPE) \
		$(CLOCK) \
		$(MD)/sysgo1

BOOTFILE_ST2900_DD_DW	= $(MD)/ioman \
		$(MD)/rbf.mn \
		$(FLOPPY_80D) \
		$(MD)/ddd0_80d.dd \
		$(MD)/scf.mn \
		$(CONSOLE_DRV) \
		$(RBDW) \
		$(MD)/scdwv.dr \
		$(SCDWV_NET) \
		$(SCDWP) \
		$(PIPE) \
		$(CLOCK) \
		$(MD)/sysgo1

BOOTFILE_ST2900_DW	= $(MD)/ioman \
		$(MD)/rbf.mn \
		$(MD)/scf.mn \
		$(CONSOLE_DRV) \
		$(RBDW) \
		$(MD)/ddx0.dd \
		$(FLOPPY_80D) \
		$(MD)/scdwv.dr \
		$(SCDWV_NET) \
		$(SCDWP) \
		$(PIPE) \
		$(CLOCK) \
		$(MD)/sysgo1

BOOTFILES	= bootfile_st2900_40dd bootfile_st2900_80dd bootfile_st2900_dd_dw bootfile_st2900_dw

ALLOBJS		= $(BOOTFILES) $(KERNEL)

# ST-2900 magic: boot module starts at $FDF3, FEXX data ends at $FF00
BOOT_START	= 0xFDF3
FEXX_END	= 0xFF00

all:	$(ALLOBJS)

bootfile_st2900_40dd: $(BOOTFILE_ST2900_40DD) $(DEPENDS)
	$(MERGE) $(BOOTFILE_ST2900_40DD)>$@

bootfile_st2900_80dd: $(BOOTFILE_ST2900_80DD) $(DEPENDS)
	$(MERGE) $(BOOTFILE_ST2900_80DD)>$@

bootfile_st2900_dd_dw: $(BOOTFILE_ST2900_DD_DW) $(DEPENDS)
	$(MERGE) $(BOOTFILE_ST2900_DD_DW)>$@

bootfile_st2900_dw: $(BOOTFILE_ST2900_DW) $(DEPENDS)
	$(MERGE) $(BOOTFILE_ST2900_DW)>$@

# ST-2900 Boot block: boot_st2900 + zero padding + FEXX data
boot_block: $(BOOT_BLOCK)
	$(MERGE) $(BOOT_BLOCK) > $@

# ST-2900 FEXX data block (raw binary at $FEC8)
boot_st2900_data: boot_st2900_data.asm
	$(ASROM) -I$(LEVEL1)/$(PORT) $(ASOUT)$@ $< $(ST29FLAGS)

# ST-2900 Boot/FEXX zero padding (fills gap between boot module end and FEXX data start)
boot_fexx_padding: $(MD)/boot_st2900 boot_st2900_data
	BOOT_LENGTH=$(shell stat -f%z $(MD)/boot_st2900) ;\
	FEXX_LENGTH=$(shell stat -f%z boot_st2900_data) ;\
	BOOT_END=$$(($(BOOT_START)+$${BOOT_LENGTH})) ;\
	FEXX_START=$$(($(FEXX_END)-$${FEXX_LENGTH})) ;\
	PADDING=$$(($${FEXX_START}-$${BOOT_END})) ;\
	dd if=/dev/zero of=$@ bs=1 count=$${PADDING}

# ST-2900 Kernel (padded to exactly 3840 bytes = $F000..$FEFF)
kernel_st2900: $(KERNEL_PARTS) $(DEPENDS)
	$(MERGE) $(KERNEL_PARTS) > $@
	$(PADROM) -b 3840 $@

clean:
	$(RM) $(ALLOBJS) $(BOOT_BLOCK) boot_block
