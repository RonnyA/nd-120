/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_INTR_IRSRC testbench                                              **
**                                                                       **
** Verification of the interrupt-source OR plane (drawing page 76):      **
** the 16 hardware interrupt request lines IREQ_15_0_N, formed from the  **
** microcode-driven FIDBO bus (gated by EMPIDN) merged with the ten      **
** hard-wired sources.                                                   **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_IRSRC.v). Nothing was  **
** taken from ND documentation, and in particular NO assumption was made **
** about which hardware source "should" sit on which level - the map     **
** below is a straight per-gate transcription, so it catches a source    **
** wired to the wrong IREQ bit only in the sense that a future edit      **
** would have to change both this file and the RTL.                      **
**                                                                       **
** Transcribed model. Every NOR_GATE here has BubblesMask=2'b11, i.e.    **
** result = ~(~i1 | ~i2) = i1 & i2, an AND of two active-low terms.      **
**   g(k)      = ~( FIDBO_15_0[k] & ~EMPIDN )      (NAND, active low)    **
**   IREQ_n[15] = g(15) & BINT15N                                        **
**   IREQ_n[14] = g(14)                    <- no hardware source         **
**   IREQ_n[13] = g(13) & POWFAILN                                       **
**   IREQ_n[12] = g(12) & MORN                                           **
**   IREQ_n[11] = g(11) & PARERRN                                        **
**   IREQ_n[10] = g(10) & IOXERRN                                        **
**   IREQ_n[9]  = g(9)                     <- no hardware source         **
**   IREQ_n[8]  = g(8)  & ~Z               <- Z is ACTIVE HIGH, unique   **
**   IREQ_n[7..4] = g(7..4)                <- no hardware source         **
**   IREQ_n[3]  = g(3)  & BINT13N                                        **
**   IREQ_n[2]  = g(2)  & BINT12N                                        **
**   IREQ_n[1]  = g(1)  & BINT11N                                        **
**   IREQ_n[0]  = g(0)  & BINT10N                                        **
** CHARACTERISED, not judged: there is no BINT14N input at all, and the  **
** BINTxxN names do not line up with the bit numbers they land on        **
** (BINT10N -> bit 0, BINT11N -> bit 1, BINT12N -> bit 2,                **
**  BINT13N -> bit 3, BINT15N -> bit 15). Recorded as read.              **
**                                                                       **
** Test plan:                                                            **
**   1. all-idle baseline: IREQ_15_0_N must read FFFF                    **
**   2. walking-one and walking-zero on FIDBO_15_0 with EMPIDN=0 and     **
**      EMPIDN=1 (64 vectors) - per-bit FIDBO wiring and the EMPID gate  **
**   3. one hardware source asserted at a time, all ten of them, with    **
**      FIDBO idle - proves each source reaches exactly one IREQ bit     **
**      and disturbs no other bit                                        **
**   4. EXHAUSTIVE over all 1024 hardware-source combinations, run with  **
**      FIDBO=0000/EMPIDN=1, FIDBO=0000/EMPIDN=0 and FIDBO=FFFF/EMPIDN=0 **
**   5. 1024 fixed-seed LFSR vectors with everything random              **
** The full 16-bit bus is compared on every vector.                      **
**                                                                       **
** Purely combinational - no flip-flop, no `ifdef FPGA_FF_MODE anywhere  **
** in this module. The Makefile target test-intr-irsrc builds it both    **
** ways anyway and both must print PASS.                                 **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_INTR/sim && make test-intr-irsrc         **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_INTR_IRSRC_tb;

  reg         BINT10N = 1;
  reg         BINT11N = 1;
  reg         BINT12N = 1;
  reg         BINT13N = 1;
  reg         BINT15N = 1;
  reg         EMPIDN = 1;
  reg  [15:0] FIDBO_15_0 = 0;
  reg         IOXERRN = 1;
  reg         MORN = 1;
  reg         PARERRN = 1;
  reg         POWFAILN = 1;
  reg         Z = 0;

  wire [15:0] IREQ_15_0_N;

  integer errors = 0;
  integer checks = 0;
  integer i, e;
  reg [31:0] lfsr;

  CGA_INTR_IRSRC dut (
      .BINT10N    (BINT10N),
      .BINT11N    (BINT11N),
      .BINT12N    (BINT12N),
      .BINT13N    (BINT13N),
      .BINT15N    (BINT15N),
      .EMPIDN     (EMPIDN),
      .FIDBO_15_0 (FIDBO_15_0),
      .IOXERRN    (IOXERRN),
      .MORN       (MORN),
      .PARERRN    (PARERRN),
      .POWFAILN   (POWFAILN),
      .Z          (Z),
      .IREQ_15_0_N(IREQ_15_0_N)
  );

  initial begin
    $dumpfile("CGA_INTR_IRSRC_tb.vcd");
    $dumpvars(0, CGA_INTR_IRSRC_tb);
  end

  // ext[9:0] packing used by the exhaustive sweep and by set_ext():
  //   0 BINT10N  1 BINT11N  2 BINT12N  3 BINT13N  4 BINT15N
  //   5 POWFAILN 6 MORN     7 PARERRN  8 IOXERRN  9 Z (ACTIVE HIGH)
  localparam [9:0] EXT_IDLE = 10'b0_1_1_1_1_1_1_1_1_1;

  task set_ext(input [9:0] x);
    begin
      BINT10N  = x[0];
      BINT11N  = x[1];
      BINT12N  = x[2];
      BINT13N  = x[3];
      BINT15N  = x[4];
      POWFAILN = x[5];
      MORN     = x[6];
      PARERRN  = x[7];
      IOXERRN  = x[8];
      Z        = x[9];
    end
  endtask

  function [15:0] model(input [15:0] fidbo, input empidn, input [9:0] x);
    reg [15:0] g;
    integer k;
    begin
      for (k = 0; k < 16; k = k + 1) g[k] = ~(fidbo[k] & ~empidn);
      model[15] = g[15] & x[4];   // BINT15N
      model[14] = g[14];
      model[13] = g[13] & x[5];   // POWFAILN
      model[12] = g[12] & x[6];   // MORN
      model[11] = g[11] & x[7];   // PARERRN
      model[10] = g[10] & x[8];   // IOXERRN
      model[9]  = g[9];
      model[8]  = g[8]  & ~x[9];  // Z, active high
      model[7]  = g[7];
      model[6]  = g[6];
      model[5]  = g[5];
      model[4]  = g[4];
      model[3]  = g[3]  & x[3];   // BINT13N
      model[2]  = g[2]  & x[2];   // BINT12N
      model[1]  = g[1]  & x[1];   // BINT11N
      model[0]  = g[0]  & x[0];   // BINT10N
    end
  endfunction

  task vec(input [15:0] fidbo, input empidn, input [9:0] x, input [255:0] name);
    reg [15:0] exp;
    begin
      FIDBO_15_0 = fidbo;
      EMPIDN     = empidn;
      set_ext(x);
      #2;
      exp = model(fidbo, empidn, x);
      checks = checks + 1;
      if (IREQ_15_0_N !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h exp %04h (FIDBO=%04h EMPIDN=%b ext=%b)",
                 name, IREQ_15_0_N, exp, fidbo, empidn, x);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_INTR_IRSRC_tb: built with FPGA_FF_MODE (must not matter here)");
`else
    $display("CGA_INTR_IRSRC_tb: default build mode");
`endif

    // 1. idle baseline - nothing requesting, every bit must be inactive high
    vec(16'h0000, 1'b1, EXT_IDLE, "idle EMPIDN=1");
    checks = checks + 1;
    if (IREQ_15_0_N !== 16'hFFFF) begin
      errors = errors + 1;
      $display("FAIL idle baseline: IREQ=%04h expected FFFF", IREQ_15_0_N);
    end
    vec(16'hFFFF, 1'b1, EXT_IDLE, "FIDBO=FFFF but EMPID off");
    checks = checks + 1;
    if (IREQ_15_0_N !== 16'hFFFF) begin
      errors = errors + 1;
      $display("FAIL EMPID gate: IREQ=%04h expected FFFF with EMPIDN=1", IREQ_15_0_N);
    end

    // 2. walking one / walking zero on FIDBO, both EMPIDN phases
    for (i = 0; i < 16; i = i + 1) begin
      vec(16'h0001 << i, 1'b0, EXT_IDLE, "walk1 FIDBO EMPID on");
      vec(16'h0001 << i, 1'b1, EXT_IDLE, "walk1 FIDBO EMPID off");
      vec(~(16'h0001 << i), 1'b0, EXT_IDLE, "walk0 FIDBO EMPID on");
      vec(~(16'h0001 << i), 1'b1, EXT_IDLE, "walk0 FIDBO EMPID off");
    end

    // 3. one hardware source at a time (bits 0..8 are active low, bit 9 high)
    for (i = 0; i < 10; i = i + 1) begin
      vec(16'h0000, 1'b1, EXT_IDLE ^ (10'd1 << i), "single source, EMPID off");
      vec(16'h0000, 1'b0, EXT_IDLE ^ (10'd1 << i), "single source, EMPID on");
    end

    // 4. exhaustive over all 1024 hardware-source combinations
    for (e = 0; e < 1024; e = e + 1) begin
      vec(16'h0000, 1'b1, e[9:0], "exh ext, FIDBO idle");
      vec(16'h0000, 1'b0, e[9:0], "exh ext, EMPID on");
      vec(16'hFFFF, 1'b0, e[9:0], "exh ext, FIDBO all ones");
    end

    // 5. pseudo-random soak
    lfsr = 32'h0BADCAFE;
    for (i = 0; i < 1024; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      vec(lfsr[19:4], lfsr[20], lfsr[30:21], "lfsr");
    end

    // vectors = 2 + 64 + 20 + 3072 + 1024 = 4182 ; plus 2 baseline checks
    if (errors == 0 && checks == 4184) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 4184 checks)", checks, errors);
    if (errors == 0 && checks == 4184) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
