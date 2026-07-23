/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_VECGEN_PTY  (vector generator, schematic p.83)                                  **
**                                                                                               **
** DUT contract: splits MIREQ_15_0_N (active-LOW requests) into two priority encoders:            **
**   HI encoder <- MIREQ[15:8]  ->  HIVEC = index 0..7 of highest active-low bit in 15:8, HIDET   **
**   LO encoder <- MIREQ[7:0]   ->  LOVEC = index 0..7 of highest active-low bit in 7:0,  LODET   **
**   (encoder index 0 == the low end of its own byte: HIVEC=0 => MIREQ[8], HIVEC=7 => MIREQ[15]).  **
**                                                                                               **
** Self-checking: golden priority-encode computed INDEPENDENTLY in the tb. Covers all-none,       **
** HI-only, LO-only, both-halves, exhaustive per-byte single-bit walks, priority (multiple bits   **
** active - highest wins), plus a randomized soak. Prints "TB_RESULT: PASS/FAIL".                  **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_pty \                                                             **
**     -y Shared/logisim -y Shared/support -y Shared/ndlib \                                      **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_PTY.v \                                  **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_PTY_PTYENC.v \                           **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_VECGEN_PTY_tb.v && vvp /tmp/tb_pty                  **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_PTY_tb;

  reg  [15:0] MIREQ_15_0_N;
  wire        HIDET, LODET;
  wire [2:0]  HIVEC, LOVEC;

  CGA_INTR_CNTLR_VECGEN_PTY dut (
      .MIREQ_15_0_N(MIREQ_15_0_N),
      .HIDET(HIDET),
      .HIVEC(HIVEC),
      .LODET(LODET),
      .LOVEC(LOVEC)
  );

  // Independent 8-bit priority-encode golden: {det, vec[2:0]}, highest active-low wins.
  function [3:0] enc8;
    input [7:0] rn;
    integer i;
    reg        det;
    reg  [2:0] vec;
    begin
      det = 1'b0; vec = 3'b000;
      for (i = 7; i >= 0; i = i - 1)
        if (rn[i] == 1'b0 && det == 1'b0) begin det = 1'b1; vec = i[2:0]; end
      enc8 = {det, vec};
    end
  endfunction

  integer errors = 0;
  integer checks = 0;

  task do_check(input [127:0] label);
    reg [3:0] ghi, glo;
    begin
      #1;
      ghi = enc8(MIREQ_15_0_N[15:8]);
      glo = enc8(MIREQ_15_0_N[7:0]);
      checks = checks + 1;
      if (HIDET !== ghi[3] || HIVEC !== ghi[2:0] ||
          LODET !== glo[3] || LOVEC !== glo[2:0]) begin
        errors = errors + 1;
        $display("FAIL %0s MIREQ=%b: HIDET e=%b g=%b HIVEC e=%0d g=%0d | LODET e=%b g=%b LOVEC e=%0d g=%0d",
                 label, MIREQ_15_0_N,
                 ghi[3], HIDET, ghi[2:0], HIVEC,
                 glo[3], LODET, glo[2:0], LOVEC);
      end
    end
  endtask

  integer k;
  initial begin
    // 1) no requests (all inactive = all 1)
    MIREQ_15_0_N = 16'hFFFF;                    do_check("none");

    // 2) exhaustive single-bit-active walk over all 16 bits (bit low = active)
    for (k = 0; k < 16; k = k + 1) begin
      MIREQ_15_0_N = ~(16'h0001 << k);          do_check("single-bit");
    end

    // 3) HI-only (some bit in 15:8 active, LO all inactive)
    MIREQ_15_0_N = 16'hFFFF & ~(16'h1 << 8);    do_check("hi-only b8");
    MIREQ_15_0_N = 16'hFFFF & ~(16'h1 << 15);   do_check("hi-only b15");

    // 4) LO-only
    MIREQ_15_0_N = 16'hFFFF & ~(16'h1 << 0);    do_check("lo-only b0");
    MIREQ_15_0_N = 16'hFFFF & ~(16'h1 << 7);    do_check("lo-only b7");

    // 5) both halves active simultaneously - encoders independent
    MIREQ_15_0_N = ~16'b0000_1000_0001_0000;    do_check("both b11+b4");
    MIREQ_15_0_N = ~16'b1000_0000_0000_0001;    do_check("both b15+b0");

    // 6) priority: multiple bits active in a half - highest index must win
    MIREQ_15_0_N = ~16'b1010_1010_0101_0101;    do_check("multi mix");
    MIREQ_15_0_N = ~16'b1111_1111_1111_1111;    do_check("all active");
    MIREQ_15_0_N = ~16'b0011_0011_1100_1100;    do_check("multi mix2");

    // 7) randomized soak over full 16-bit space
    for (k = 0; k < 500; k = k + 1) begin
      MIREQ_15_0_N = $random;                    do_check("soak");
    end

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
