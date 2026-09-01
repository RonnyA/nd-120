# ND-120 on MiSTer (DE10-Nano / MiSTer Pi) - standard board-folder build API
# (see ../README.md). Full flow notes: docs/02-building.md
#
#   make            build the .rbf with Quartus 17.0.2 inside Docker
#   make gui        print the command for a native/GUI Quartus compile
#   make check      report what the toolchain loop needs and whether it is there
#   make clean      remove Quartus temporary + output dirs
#   make load       (not wired yet) send the core to a MiSTer over the network
#
# WHY DOCKER: MiSTer standardizes on Quartus Prime Lite *17.0.2* exactly -
# newer Quartus breaks the project files and buys nothing on Cyclone V. The
# community image raetro/quartus:17.0 carries that version, so nothing has to
# be installed on the host. Run it from WSL (Linux paths, docker socket).

SHELL := /bin/bash
.DELETE_ON_ERROR:

PROJECT   ?= nd120
QIMAGE    ?= raetro/quartus:17.0
RBF        = output_files/$(PROJECT).rbf

# MiSTer network name/address for 'make load' (default is the stock hostname)
MISTER    ?= root@MiSTer.local

.PHONY: all build font microcode wcs gui check clean load flash

all: build

# The terminal font, copied next to the project so $$readmemh finds it whatever
# path rule Quartus uses. See the note in nd120.qsf - this is the second half
# of that belt-and-braces.
FONT_SRC = ../../Terminals/font/font8x16.hex

font: font8x16.hex

font8x16.hex: $(FONT_SRC)
	cp $< $@

# Microcode PROM (build 2, 31-AUG-2026): CPU_CS_PROM_19.v's $readmemh, same
# belt-and-braces as the font - a SEARCH_PATH in nd120.qsf AND a copy here,
# because which rule Quartus actually uses has not been proven. Canonical
# source lives next to CPU_CS_PROM_19.v itself; Basys3's vivado_build.tcl
# copies the same two files into ITS project dir for the same reason.
MICROCODE_SRC = ../../CPU-BOARD-3202/circuit/AM27256_45132L.hex ../../CPU-BOARD-3202/circuit/AM27256_45133L.hex

microcode: AM27256_45132L.hex AM27256_45133L.hex

AM27256_45132L.hex: ../../CPU-BOARD-3202/circuit/AM27256_45132L.hex
	cp $< $@

AM27256_45133L.hex: ../../CPU-BOARD-3202/circuit/AM27256_45133L.hex
	cp $< $@

# files.qip pulls in ../../Terminals/rtl/*.v - paths outside this folder. A
# container that only mounts this directory as /build cannot see them (they
# resolve to a nonexistent /Terminals and Quartus reports the modules as
# undefined entities, not as a missing-file error against the real path,
# which is what made this confusing the first time). So the mount has to be
# the whole Verilog/ tree, at the same relative depth this project expects.
VERILOG_ROOT := $(realpath ../..)

# WCS microcode preload (SKIP_WCS_LOAD): this board reads the 32 wcs_*.hex
# images straight in via $readmemh, the same as Nexys/Tang. The `make wcs`
# MIF conversion that used to sit here fed the altsyncram megafunction arm,
# deleted 01-SEP-2026 together with tools/wcs_hex_to_mif.py.

build: font microcode
	docker run --rm -v "$(VERILOG_ROOT)":/build -w /build/fpga/mister $(QIMAGE) \
		quartus_sh --flow compile $(PROJECT).qpf
	@ls -l $(RBF)

# The GUI is still needed for two things: generating the PLL IP (rtl/pll) and
# running SignalTap. Everything else is the container flow above.
gui:
	@echo "Native Quartus 17.0.2: open $(PROJECT).qpf and press Start Compilation."
	@echo "Needed for: PLL IP regeneration (rtl/pll*) and SignalTap."

check:
	@echo "== docker =="; docker version --format '{{.Server.Version}}' 2>&1 | head -1
	@echo "== image  =="; docker image inspect $(QIMAGE) >/dev/null 2>&1 \
		&& echo "$(QIMAGE) present" || echo "$(QIMAGE) NOT pulled - run: docker pull $(QIMAGE)"
	@echo "== project =="; test -f $(PROJECT).qpf && echo "$(PROJECT).qpf ok" || echo "MISSING $(PROJECT).qpf"
	@test -d sys && echo "sys/ framework present" || echo "MISSING sys/"
	@echo "== terminal =="; test -f $(FONT_SRC) && echo "font present" || echo "MISSING $(FONT_SRC)"
	@test -f ../../Terminals/rtl/terminal_top.v && echo "terminal core present" 		|| echo "MISSING ../../Terminals/rtl - the console will not build"
	@echo "== microcode =="; for f in $(MICROCODE_SRC); do test -f $$f && echo "$$f present" || echo "MISSING $$f - the WCS will load empty microcode"; done
	@echo "== wcs preload =="; n=$$(ls $(WCS_SRC)/wcs_*.hex 2>/dev/null | grep -v wcs_image | wc -l); \
		test "$$n" = "32" && echo "32 WCS images present" \
		|| echo "EXPECTED 32 WCS images in $(WCS_SRC), found $$n - the CPU will run blank microcode"
	@test -f ../../ND120_CORE.v && echo "ND120_CORE.v present" || echo "MISSING ../../ND120_CORE.v - the CPU will not build"

# scp the core to the MiSTer's SD card. The core is picked up from the menu
# after a rescan; see docs/03-deploy-and-test.md for hot-load alternatives.
load: $(RBF)
	scp $(RBF) $(MISTER):/media/fat/_Computer/ND120.rbf

flash: load

clean:
	rm -rf db incremental_db output_files simulation greybox_tmp hc_output \
	       hps_isw_handoff .qsys_edit build_id.v
