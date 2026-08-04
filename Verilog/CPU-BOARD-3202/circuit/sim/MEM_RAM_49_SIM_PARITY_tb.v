/**************************************************************************
** tb_mem_ram_parity - unit testbench for MEM_RAM_49_SIM parity behaviour  **
**                                                                        **
** Proves the parity contract that defeats the ECCR / parity-error       **
** override (why TPE classifies memory as Mpm5, not Local):              **
**   - Correct-parity round-trip: CORR_n stays 1 (no error), data intact. **
**   - BAD-parity write then read: parity is REGENERATED on read, the bad **
**     bit is DISCARDED, CORR_n stays 1 (fault absorbed).                 **
**                                                                        **
** POLICY 3-AUG-2026 (docs/nd120-parity-analysis.md section 6b): parity   **
** is computed, never stored, in EVERY build. This tb used to assert a    **
** divergence - stored parity without ND_SDRAM_PACK16, regenerated with   **
** it. That divergence is gone by decision. Both builds are still run, so **
** the gate now proves the define does NOT change parity semantics.       **
**                                                                        **
** Build/run BOTH modes - they must agree:                               **
**   iverilog -g2012            -o tb.p0 tb_mem_ram_parity.v MEM_RAM_49_SIM.v && vvp tb.p0
**   iverilog -g2012 -DND_SDRAM_PACK16 -o tb.p1 tb_mem_ram_parity.v MEM_RAM_49_SIM.v && vvp tb.p1
**                                                                        **
** MEM_RAM_49_SIM timing (from the module): row0 latched on posedge       **
** (RAS & BANK0); the word is written/read on posedge (CAS & BANK0) with  **
** RAS still high; MWRITE50_n=0 writes DD_17_0_IN, =1 reads. DD_17_0_OUT  **
** and CORR_n are combinational, valid while (CAS & BANK0 & MWRITE50_n).  **
** idx = {row0[9:0], AA_9_0[9:0]} - row from the RAS phase, column from   **
** the CAS phase, so both strobes must present the right AA.              **
***************************************************************************/
`timescale 1ns / 1ps

module tb_mem_ram_parity;

  // DUT ports
  reg         sysclk = 0, sys_rst_n = 1;
  reg  [9:0]  AA_9_0 = 0;
  reg         BANK0 = 0, BANK1 = 0, BANK2 = 0;
  reg         CAS = 0, RAS = 0;
  reg         MWRITE50_n = 1;          // 1 = read, 0 = write
  reg  [17:0] DD_17_0_IN = 0;
  wire [17:0] DD_17_0_OUT;
  wire        CORR_n;

  integer errors = 0;

  MEM_RAM_49_SIM dut (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .AA_9_0(AA_9_0), .BANK0(BANK0), .BANK1(BANK1), .BANK2(BANK2),
      .CAS(CAS), .RAS(RAS), .MWRITE50_n(MWRITE50_n),
      .DD_17_0_IN(DD_17_0_IN), .DD_17_0_OUT(DD_17_0_OUT), .CORR_n(CORR_n)
  );

  // Odd-parity helper for a byte (AM29833A convention used by the model)
  function automatic bit odd_par(input [7:0] d);
    odd_par = ~(^d);
  endfunction

  // Build an 18-bit word: {par_hi, hi[7:0], par_lo, lo[7:0]}
  function automatic [17:0] mkword(input [7:0] hi, input [7:0] lo,
                                   input bit phi, input bit plo);
    mkword = {phi, hi, plo, lo};
  endfunction

  // --- one RAS/CAS write of `word` to {row,col} ------------------------
  task automatic ram_write(input [9:0] row, input [9:0] col, input [17:0] word);
    begin
      BANK0 = 1; RAS = 0; CAS = 0; MWRITE50_n = 1; #2;
      AA_9_0 = row;         RAS = 1; #2;      // latch row0 on posedge RAS
      AA_9_0 = col; MWRITE50_n = 0; DD_17_0_IN = word; #1;
      CAS = 1; #2;                            // posedge CAS + RAS -> write
      CAS = 0; #1; RAS = 0; MWRITE50_n = 1; #2;
    end
  endtask

  // --- one RAS/CAS read of {row,col}; returns data + CORR_n ------------
  task automatic ram_read(input [9:0] row, input [9:0] col,
                          output [17:0] data, output corr_n);
    begin
      BANK0 = 1; RAS = 0; CAS = 0; MWRITE50_n = 1; #2;
      AA_9_0 = row; RAS = 1; #2;              // latch row0
      AA_9_0 = col; MWRITE50_n = 1; #1;
      CAS = 1; #2;                            // posedge CAS -> q0 <= stored
      data   = DD_17_0_OUT;                   // combinational while CAS & read
      corr_n = CORR_n;
      CAS = 0; #1; RAS = 0; #2;
    end
  endtask

  task automatic check(input cond, input string name);
    begin
      if (cond) $display("  PASS: %0s", name);
      else begin $display("  FAIL: %0s", name); errors = errors + 1; end
    end
  endtask

  reg [17:0] rd;
  reg        corr;
  reg [17:0] w_good, w_badlo, w_badhi;

  initial begin
`ifdef ND_SDRAM_PACK16
    $display("=== tb_mem_ram_parity  (build: ND_SDRAM_PACK16 defined) ===");
`else
    $display("=== tb_mem_ram_parity  (build: ND_SDRAM_PACK16 NOT defined) ===");
`endif

    // ---- Test 1: correct-parity round-trip: data intact, no error ----
    w_good = mkword(8'hAA, 8'h55, odd_par(8'hAA), odd_par(8'h55));
    ram_write(10'd0, 10'd5, w_good);
    ram_read (10'd0, 10'd5, rd, corr);
    check(rd[7:0]  == 8'h55, "T1 read-back low data == 0x55");
    check(rd[16:9] == 8'hAA, "T1 read-back high data == 0xAA");
    check(corr === 1'b1,     "T1 CORR_n == 1 (no parity error on good word)");

    // ---- Test 2: BAD low-byte parity written, then read --------------
    // flip the low parity bit (store even parity where odd is required)
    w_badlo = mkword(8'hAA, 8'h55, odd_par(8'hAA), ~odd_par(8'h55));
    ram_write(10'd0, 10'd6, w_badlo);
    ram_read (10'd0, 10'd6, rd, corr);
    check(rd[7:0]  == 8'h55, "T2 read-back low data still == 0x55");
    // Policy 3-AUG-2026: parity is regenerated on read in EVERY build, so the
    // bad stored bit is discarded and CORR_n stays 1. Identical in both modes -
    // ND_SDRAM_PACK16 must NOT change parity semantics any more, and building
    // this tb both ways is what proves it.
    check(corr === 1'b1,     "T2 CORR_n == 1 (bad parity absorbed, per policy)");
    check(rd[8]  == odd_par(8'h55),
                             "T2 read parity is REGENERATED, stored bad bit gone");

    // ---- Test 3: BAD high-byte parity ---------------------------------
    w_badhi = mkword(8'hAA, 8'h55, ~odd_par(8'hAA), odd_par(8'h55));
    ram_write(10'd0, 10'd7, w_badhi);
    ram_read (10'd0, 10'd7, rd, corr);
    check(corr === 1'b1,     "T3 CORR_n == 1 (bad HIGH parity also absorbed)");
    check(rd[17] == odd_par(8'hAA),
                             "T3 high read parity is REGENERATED");

    // ---- Test 4: a good word at a different address is unaffected -----
    ram_write(10'd3, 10'd9, mkword(8'h0F, 8'hF0, odd_par(8'h0F), odd_par(8'hF0)));
    ram_read (10'd3, 10'd9, rd, corr);
    check(rd[7:0] == 8'hF0 && rd[16:9] == 8'h0F, "T4 second address data intact");
    check(corr === 1'b1,                         "T4 CORR_n == 1 (good word, no error)");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d checks failed)", errors);
    $finish;
  end

endmodule
