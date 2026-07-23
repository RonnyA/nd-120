# Tang Nano 20K sdram18 test - OSS toolchain flow (yosys / nextpnr / apicula)
#
# Validates the ND-120 18-bit-word SDRAM controller (../sdram-bridge/sdram18.v)
# on hardware at the SAME 13.5 MHz slow-bring-up clocking as the full ND-120
# build (the exact configuration the deposit bug was localized to).
#
# Requires oss-cad-suite on the PATH:  source ~/oss-cad-suite/environment
#
# Reuses from ../sdram-test: uart_rx/uart_tx, the package + embedded-SDRAM
# pseudo-pin constraints. The PLL is the FULL BUILD's Gowin_rPLL_ND120 with
# TANG_SLOW_BRINGUP defined (one source of truth for the failing clocking).

TOP     = sdram18_test_top
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
BOARD   = tangnano20k

SRCS    = ../src/gowin_rpll_27_54.v \
          ../sdram-bridge/sdram18.v \
          ../sdram-test/src/uart_tx.v \
          ../sdram-test/src/uart_rx.v \
          src/msg_printer18.v \
          src/sdram18_test_top.v

DEFINES = -DTANG_SLOW_BRINGUP

BUILD   = build

all: $(BUILD)/$(TOP).fs

$(BUILD):
	mkdir -p $(BUILD)

# combined constraints: package pins + embedded-SDRAM pseudo-pins (OSS only)
$(BUILD)/oss.cst: ../sdram-test/src/nano20k.cst ../sdram-test/src/sdram_pins_oss.cst | $(BUILD)
	cat ../sdram-test/src/nano20k.cst ../sdram-test/src/sdram_pins_oss.cst > $@

$(BUILD)/$(TOP).json: $(SRCS) | $(BUILD)
	yosys -l $(BUILD)/synth.log -p "read_verilog $(DEFINES) $(SRCS); synth_gowin -top $(TOP) -json $@"

$(BUILD)/$(TOP)_pnr.json: $(BUILD)/$(TOP).json $(BUILD)/oss.cst
	nextpnr-himbaechel --json $(BUILD)/$(TOP).json \
	    --write $(BUILD)/$(TOP)_pnr.json \
	    --device $(DEVICE) \
	    --vopt family=$(FAMILY) \
	    --vopt cst=$(BUILD)/oss.cst

$(BUILD)/$(TOP).fs: $(BUILD)/$(TOP)_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

# volatile load into SRAM (fast iteration; factory flash image untouched)
load: $(BUILD)/$(TOP).fs
	openFPGALoader -b $(BOARD) $<

sim:
	$(MAKE) -C sim test

clean:
	rm -rf $(BUILD)
	$(MAKE) -C sim clean

.PHONY: all load sim clean
