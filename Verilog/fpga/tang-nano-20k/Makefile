# ND-120 on Tang Nano 20K - standard board-folder build API (see ../README.md)
#
#   make            build the full ND-120 bitstream (Gowin EDA gw_sh on the Windows host)
#   make load       program over JTAG into SRAM (volatile; openFPGALoader from WSL, usbipd-attached)
#   make flash      write the config flash (persistent; REPLACES the factory LiteX image)
#   make sim        run the iverilog testbenches (sdram-bridge + sdram-test)
#   make clean      remove the build/ output
#
# On Windows, call .\gowin_build.ps1 directly (it also copies the WCS preload
# hex from Code/Microcode/wcs/ and checks for EX3988 = empty control store).
# The standalone sdram-test/ has its own Makefile with the same targets
# (OSS yosys/nextpnr flow, Linux-native).

PS = powershell.exe -NoProfile -ExecutionPolicy Bypass -File
FS = build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.fs

all:
	$(PS) gowin_build.ps1

load:
	@test -f $(FS) || { echo "No bitstream at $(FS) - run 'make' first"; exit 1; }
	openFPGALoader -b tangnano20k $(FS)

flash:
	@test -f $(FS) || { echo "No bitstream at $(FS) - run 'make' first"; exit 1; }
	openFPGALoader -b tangnano20k -f $(FS)

sim:
	$(MAKE) -C sdram-bridge/sim test
	$(MAKE) -C sdram-test/sim test

clean:
	rm -rf build
	$(MAKE) -C sdram-bridge/sim clean
	$(MAKE) -C sdram-test/sim clean

.PHONY: all load flash sim clean
