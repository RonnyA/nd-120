# ND-120 on Nexys 4 DDR / Nexys A7-100T - standard board-folder build API
# (see ../README.md)
#
#   make              build the bitstream + JTAG-program (Vivado on the Windows host)
#   make build        build only (no board needed)
#   make load         same as 'make' - JTAG is the only programming path here
#   make CLK=33       build at 33.333 MHz instead of the default 16.667 MHz
#   make clean        remove build outputs
#
# Vivado path: the same install the Basys3 flow uses; override with
#   make VIVADO="D:\Xilinx\...\vivado.bat"
# From a Windows shell, run the tcl directly instead:
#   vivado -mode batch -source build.tcl [-tclargs -noburn clk=33 -skipwcs]

VIVADO ?= F:\\AMDDesignTools\\2026.1\\Vivado\\bin\\vivado.bat
CMD     = cmd.exe /c
CLK    ?= 16
ARGS    = clk=$(CLK)

all:
	$(CMD) "$(VIVADO)" -mode batch -source build.tcl -tclargs $(ARGS)

build:
	$(CMD) "$(VIVADO)" -mode batch -source build.tcl -tclargs $(ARGS) -noburn

load: all

clean:
	rm -f nd120_nexys4ddr.bit util.rpt timing.rpt \
	      AM27256_45132L.hex AM27256_45133L.hex wcs_*.hex \
	      vivado*.jou vivado*.log
	rm -rf .Xil

.PHONY: all build load clean
