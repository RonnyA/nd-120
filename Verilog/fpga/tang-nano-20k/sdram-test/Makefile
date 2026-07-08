# Tang Nano 20K SDRAM test - OSS toolchain flow (yosys / nextpnr / apicula)
#
# Requires oss-cad-suite on the PATH:  source ~/oss-cad-suite/environment
# The Gowin EDA flow uses sdram_test.gprj instead (see README.md).
#
# Key OSS-flow detail (learned from Seyviour/sdram-tang-nano-20k-os-example):
# the embedded SDRAM "magic" ports are NOT auto-connected by nextpnr the way
# Gowin EDA does it - they must be pinned to internal pseudo-pins. That pin
# list lives in src/sdram_pins_oss.cst and is appended to the package-pin CST
# below.

TOP     = sdram_test_top
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
BOARD   = tangnano20k

SRCS    = src/gowin_rpll/gowin_rpll.v \
          src/sdram.v \
          src/uart_tx.v \
          src/uart_rx.v \
          src/msg_printer.v \
          src/sdram_test_top.v

BUILD   = build

all: $(BUILD)/$(TOP).fs

$(BUILD):
	mkdir -p $(BUILD)

# combined constraints: package pins + embedded-SDRAM pseudo-pins (OSS only)
$(BUILD)/oss.cst: src/nano20k.cst src/sdram_pins_oss.cst | $(BUILD)
	cat src/nano20k.cst src/sdram_pins_oss.cst > $@

$(BUILD)/$(TOP).json: $(SRCS) | $(BUILD)
	yosys -l $(BUILD)/synth.log -p "read_verilog $(SRCS); synth_gowin -top $(TOP) -json $@"

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

# persistent: writes the config flash (REPLACES the factory LiteX image -
# restore it from sipeed/TangNano-20K-example if you want it back)
flash: $(BUILD)/$(TOP).fs
	openFPGALoader -b $(BOARD) -f $<

sim:
	$(MAKE) -C sim

clean:
	rm -rf $(BUILD)
	$(MAKE) -C sim clean

.PHONY: all load flash sim clean
