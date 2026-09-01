# iverilog testbench for the ND-120 sheet-49 SDRAM backend
# (reuses the behavioral SDRAM model from ../../sdram-test/sim/)
#
# Four compiles of the SAME tb source:
#   test               legacy 18-bit word-per-location (stored parity)
#   test-pack16        ND_SDRAM_PACK16: 2 ND words per 32-bit location,
#                      DQM lane-masked writes, computed parity
#   test-pack16-part   pack16 with a reduced CPU partition (CPU_PART_ROWS=1024
#                      = 2 MB): partition boundary + absent-row semantics
#   test-storage-port  pack16 + ND_STORAGE_PORT: nd_storage device port
#                      (32-bit locations in the upper chip half) concurrent
#                      with the CPU protocol replay - N+4 deadline held,
#                      device data intact, CPU partition unreachable

IVERILOG = iverilog
VVP      = vvp

SRCS = ../MEM_RAM_49_SDRAM.v \
       ../sdram18.v \
       ../../sdram-test/sim/sdram_model.v \
       mem_ram_49_sdram_tb.v

#   test-dq16          pack16 + ND_SDRAM_DQ16 (the MiSTer's 16-bit module):
#                      one ND word per 16-bit location, refresh every 7 us -
#                      the same protocol replay and checks as test-pack16

all: test test-pack16 test-pack16-part test-storage-port test-dq16

mem_ram_49_sdram_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

mem_ram_49_sdram_pack16_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -DND_SDRAM_PACK16 -o $@ $(SRCS)

mem_ram_49_sdram_pack16_part_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -DND_SDRAM_PACK16 -DTB_PART_ROWS=1024 -o $@ $(SRCS)

test: mem_ram_49_sdram_tb.vvp
	$(VVP) mem_ram_49_sdram_tb.vvp | tee sim_out.log
	@grep -q "TB_RESULT: PASS" sim_out.log

test-pack16: mem_ram_49_sdram_pack16_tb.vvp
	$(VVP) mem_ram_49_sdram_pack16_tb.vvp | tee sim_pack16.log
	@grep -q "TB_RESULT: PASS" sim_pack16.log

test-pack16-part: mem_ram_49_sdram_pack16_part_tb.vvp
	$(VVP) mem_ram_49_sdram_pack16_part_tb.vvp | tee sim_pack16_part.log
	@grep -q "TB_RESULT: PASS" sim_pack16_part.log

mem_ram_49_sdram_storage_port_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -DND_SDRAM_PACK16 -DND_STORAGE_PORT -o $@ $(SRCS)

test-storage-port: mem_ram_49_sdram_storage_port_tb.vvp
	$(VVP) mem_ram_49_sdram_storage_port_tb.vvp | tee sim_storage_port.log
	@grep -q "TB_RESULT: PASS" sim_storage_port.log

mem_ram_49_sdram_dq16_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -DND_SDRAM_PACK16 -DND_SDRAM_DQ16 -DND_SDRAM_REFRESH_US=7 -o $@ $(SRCS)

test-dq16: mem_ram_49_sdram_dq16_tb.vvp
	$(VVP) mem_ram_49_sdram_dq16_tb.vvp | tee sim_dq16.log
	@grep -q "TB_RESULT: PASS" sim_dq16.log

clean:
	rm -f mem_ram_49_sdram_tb.vvp mem_ram_49_sdram_pack16_tb.vvp mem_ram_49_sdram_dq16_tb.vvp sim_dq16.log \
	      mem_ram_49_sdram_pack16_part_tb.vvp \
	      mem_ram_49_sdram_storage_port_tb.vvp \
	      sim_out.log sim_pack16.log sim_pack16_part.log sim_storage_port.log

.PHONY: all test test-pack16 test-pack16-part test-storage-port test-dq16 clean
