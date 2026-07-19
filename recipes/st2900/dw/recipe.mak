# ST-2900 DriveWire-boot recipe: boots OS9Boot from a DriveWire server
# (boot device ddx0), MC2681 second port as the DW transport at 38400 baud.
RECIPE = st2900_dw
OS9FORMAT_CMD = $(OS9FORMAT_DW)
CMDS_EXTRA = format inetd telnet dw httpd
BOOTFILE = ioman rbf.mn scf.mn $(CONSOLE) $(RBDW) ddx0.dd $(FLOPPY) \
           $(SCDWV) $(SCDWP) $(PIPE) $(CLOCK) sysgo1
