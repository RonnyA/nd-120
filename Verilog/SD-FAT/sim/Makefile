# Unit testbenches for the SD-FAT library
# (repo convention: sim/ next to the modules it tests)
#
# test         - all library unit tests (used by the global test registry)
# test-writer  - sd_writer (CMD24 single-sector write) against the
#                behavioral card model
#
# The board-level system tests (menu, reader, dump, copy, block update)
# live in Verilog/fpga/tang-nano-20k/sd-fat-test/sim/.

IVERILOG = iverilog
VVP      = vvp

WRITER_SRCS = ../circuit/sd_writer.v \
              sd_card_model.v \
              sd_writer_tb.v

all: test

test: test-writer

writer_test.img:
	dd if=/dev/zero of=$@ bs=1024 count=64 status=none

sd_writer_tb.vvp: $(WRITER_SRCS)
	$(IVERILOG) -g2005 -o $@ $(WRITER_SRCS)

test-writer: sd_writer_tb.vvp writer_test.img
	$(VVP) sd_writer_tb.vvp | tee writer_out.log
	@grep -q "TB_RESULT: PASS" writer_out.log

clean:
	rm -f *.vvp *.log writer_test.img

.PHONY: all test test-writer clean
