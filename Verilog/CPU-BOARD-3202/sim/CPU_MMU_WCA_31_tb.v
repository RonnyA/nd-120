/**************************************************************************
** CPU_MMU_WCA_31 - contract testbench (sheet 31, PPN TO CPN)            **
**                                                                       **
** The whole module is one gated bus assignment:                         **
**     assign PPN_23_10 = WCA_n ? 14'b0 : CPN_23_10;                     **
** so the only things that can be WRONG here are a bit-order slip, a     **
** width slip (13 bits instead of 14), an inverted enable, or a          **
** disabled output that does not settle to ZERO. Inside the FPGA a       **
** disabled driver must drive 0, never z, because PPN is an OR-ed bus    **
** (CPU_15.v line 401 ORs LAPA and MMU PPN together) - a stuck-high or   **
** z-driving disabled path would corrupt the other source.               **
**                                                                       **
** COVERAGE: exhaustive per-bit walk (14 one-hot patterns, 14 one-cold   **
** patterns, all-zero, all-one) x both WCA_n states, plus a randomised   **
** sweep and an explicit "disabled contributes exactly 0" check.         **
** This is a SPECIFICATION test: the intent (enable-gated straight       **
** through, zero when disabled) is stated in the RTL itself.             **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-wca31                 **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_MMU_WCA_31_tb;

  reg  [13:0] CPN_23_10;
  reg         WCA_n;
  wire [13:0] PPN_23_10;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [13:0] expected;

  CPU_MMU_WCA_31 DUT (
      .CPN_23_10(CPN_23_10),
      .WCA_n    (WCA_n),
      .PPN_23_10(PPN_23_10)
  );

  task check;
    input [255:0] name;
    begin
      expected = WCA_n ? 14'b0 : CPN_23_10;
      checks   = checks + 1;
      if (PPN_23_10 !== expected) begin
        errors = errors + 1;
        $display("FAIL %0s: WCA_n=%b CPN=%b -> PPN=%b expected %b",
                 name, WCA_n, CPN_23_10, PPN_23_10, expected);
      end
    end
  endtask

  initial begin
    $dumpfile("CPU_MMU_WCA_31_tb.vcd");
    $dumpvars(0, CPU_MMU_WCA_31_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 200 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #200 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_MMU_WCA_31 (sheet 31) contract testbench");
    $display("=====================================================");

    // ---- 1. one-hot walk, enabled. Catches a bit-order reversal and a
    // ----    dropped bit (a 13-bit slice instead of 14).
    WCA_n = 1'b0;
    for (i = 0; i < 14; i = i + 1) begin
      CPN_23_10 = 14'b1 << i;
      #1;
      check("ONEHOT_EN");
      if (PPN_23_10 !== (14'b1 << i)) begin
        // named message so a reversal is obvious in the log
        $display("        (bit %0d did not appear in place)", i);
      end
    end

    // ---- 2. one-cold walk, enabled. Catches a bit stuck HIGH.
    for (i = 0; i < 14; i = i + 1) begin
      CPN_23_10 = ~(14'b1 << i);
      #1;
      check("ONECOLD_EN");
    end

    // ---- 3. rails
    CPN_23_10 = 14'h0000; #1; check("ZERO_EN");
    CPN_23_10 = 14'h3FFF; #1; check("ONES_EN");

    // ---- 4. THE ONE THAT MATTERS: disabled must contribute exactly 0 on
    // ----    EVERY bit, for every input pattern - PPN is a wired-OR bus.
    WCA_n = 1'b1;
    for (i = 0; i < 14; i = i + 1) begin
      CPN_23_10 = 14'b1 << i;
      #1;
      checks = checks + 1;
      if (PPN_23_10 !== 14'b0) begin
        errors = errors + 1;
        $display("FAIL DISABLED_NOT_ZERO: bit %0d leaked, PPN=%b", i, PPN_23_10);
      end
    end
    CPN_23_10 = 14'h3FFF; #1;
    checks = checks + 1;
    if (PPN_23_10 !== 14'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_ALLONES: PPN=%b must be all zero", PPN_23_10);
    end

    // ---- 5. randomised sweep across both enable states
    for (i = 0; i < 500; i = i + 1) begin
      CPN_23_10 = $random;
      WCA_n     = $random;
      #1;
      check("RANDOM");
    end

    // ---- 6. the enable must actually be the ENABLE, not its inverse:
    // ----    with a non-zero input the two states must DIFFER.
    CPN_23_10 = 14'h2AAA;
    WCA_n = 1'b0; #1;
    checks = checks + 1;
    if (PPN_23_10 !== 14'h2AAA) begin
      errors = errors + 1;
      $display("FAIL ENABLE_POLARITY: WCA_n=0 must pass data, got %h", PPN_23_10);
    end
    WCA_n = 1'b1; #1;
    checks = checks + 1;
    if (PPN_23_10 !== 14'h0000) begin
      errors = errors + 1;
      $display("FAIL ENABLE_POLARITY: WCA_n=1 must block, got %h", PPN_23_10);
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
