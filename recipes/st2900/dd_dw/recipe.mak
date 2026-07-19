# ST-2900 floppy-boot recipe that also carries the DriveWire stack.
RECIPE = st2900_dd_dw
OS9FORMAT_CMD = $(OS9FORMAT_DW)
CMDS_EXTRA = format inetd telnet dw httpd
BOOTFILE = ioman rbf.mn $(FLOPPY) $(BOOT_DD) scf.mn $(CONSOLE) $(RBDW) \
           $(SCDWV) $(SCDWP) $(PIPE) $(CLOCK) sysgo1
