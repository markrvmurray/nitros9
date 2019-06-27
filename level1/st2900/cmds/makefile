include ../port.mak

vpath %.as $(LEVEL1)/cmds
vpath %.asm $(LEVEL1)/cmds:$(3RDPARTY)/packages/basic09

DEPENDS		= ./makefile

AFLAGS          += --includedir=$(3RDPARTY)/packages/basic09
AFLAGS          += -I.
LFLAGS          += -L $(NITROS9DIR)/lib -lnet -lst2900 -lalib

BASIC09FILES	= basic09.asm runb.asm inkey.asm syscall.asm
CMDS		= asm attr backup binex build calldbg cmp copy cputype \
		date dcheck debug ded deiniz del deldir devs dir dirsort disasm \
		display dmode dsave dspeed dump echo edit error exbin \
		free help ident iniz irqs link list load login makdir \
		megaread mdir merge mfree padrom park printerr procs prompt pwd pxd \
		rename save setime sformat shellplus shell_21 sleep sysgo2 \
		tee tmode touch tsmon unlink verify xmode

CMDS_D2		= basic09 runb inkey syscall copy del echo sformat \
		merge prompt tmode

CMDS_DW		= format inetd telnet dw httpd

SUBS		= inkey syscall
ALLOBJS		= $(CMDS) $(CMDS_D2) $(CMDS_DW) $(SUBS)

all:	$(ALLOBJS)

pwd:	pd.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DPWD=1

xmode:	xmode.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DXMODE=1

tmode:	xmode.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DTMODE=1

pxd:	pd.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@ -DPXD=1
	
clean:
	$(RM) $(ALLOBJS)

identify:
	$(IDENT_SHORT) $(ALLOBJS)

showobjs:
	@$(ECHO) $(CMDS)

showobjs_d2:
	@$(ECHO) $(CMDS_D2)

showobjs_dw:
	@$(ECHO) $(sort $(CMDS) $(CMDS_DW))

showallobjs:
	@$(ECHO) $(ALLOBJS)
