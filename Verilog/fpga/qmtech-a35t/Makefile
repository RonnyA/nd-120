# ND-120 on QMTECH XC7A35T - standard board-folder build API (see ../README.md)
#
#   make [TEST=mem-test]   build the test bitstream only (default TEST=mem-test)
#   make load              build + program over JTAG (volatile; Platform Cable USB II)
#   make flash             (not implemented yet - no SPI-flash flow for this board)
#   make sim               run the mem-test iverilog testbench
#   make clean             remove generated bitstreams/reports
#
# There is no full ND-120 build for this board yet (paused side experiment,
# see HANDOFF-qmtech-a35t-bringup.md). TEST selects which stage design to
# build: led-test or mem-test.
# Vivado runs on the Windows host; from WSL this delegates via powershell.exe.
# On Windows: cd <TEST> ; vivado -mode batch -source build.tcl [-tclargs skip_program]

PS   = powershell.exe -NoProfile -ExecutionPolicy Bypass -Command
TEST = mem-test

all:
	cd $(TEST) && $(PS) "vivado -mode batch -source build.tcl -tclargs skip_program"

load:
	cd $(TEST) && $(PS) "vivado -mode batch -source build.tcl"

flash:
	@echo "flash: not implemented for qmtech-a35t yet (JTAG-volatile only; add an .mcs/SPI flow when the full build exists)"; exit 1

sim:
	cd mem-test/sim && iverilog -g2012 -DNO_MMCM -o tb qmtech_mem_test_tb.v \
	    ../qmtech_mem_test_top.v \
	    ../../../basys3/mem-test/msg_printer.v \
	    ../../../basys3/mem-test/uart_tx.v \
	    ../../../../CPU-BOARD-3202/circuit/MEM_RAM_49.v \
	    ../../../../Shared/support/SIP1M9.v && vvp tb

clean:
	rm -f led-test/*.bit led-test/*.rpt mem-test/*.bit mem-test/*.rpt \
	      mem-test/sim/tb mem-test/sim/*.vcd
	rm -rf led-test/.Xil mem-test/.Xil

.PHONY: all load flash sim clean
