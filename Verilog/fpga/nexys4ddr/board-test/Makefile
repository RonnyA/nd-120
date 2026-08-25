# Nexys 4 DDR board check - same build API as the board folders
#
#   make        build the bitstream + JTAG-program
#   make build  build only (no board needed)
#   make clean  remove build outputs

VIVADO ?= F:\\AMDDesignTools\\2026.1\\Vivado\\bin\\vivado.bat
CMD     = cmd.exe /c

all:
	$(CMD) "$(VIVADO)" -mode batch -source build.tcl

build:
	$(CMD) "$(VIVADO)" -mode batch -source build.tcl -tclargs -noburn

clean:
	rm -f board_test.bit util.rpt timing.rpt vivado*.jou vivado*.log
	rm -rf .Xil

.PHONY: all build clean
