/****************************************************************************
** TTL_74648 - functional (truth-table) testbench                          **
**                                                                         **
** Companion to TTL_7464x_equiv_tb.v (which only checks USE_SYSCLK mode    **
** equivalence). This testbench is the FUNCTIONAL TRUTH TABLE test: real-  **
** time and stored transceiver behaviour, using the DEFAULT parameters     **
** (USE_SYSCLK_AB = USE_SYSCLK_BA = 0, plain posedge CLKAB/CLKBA capture). **
** TTL_74648 is the INVERTING sibling of TTL_74646: outputs are A_OUT_n /  **
** B_OUT_n and every data path is bitwise inverted.                       **
**                                                                         **
** Reference (read from TTL_74648.v lines 118/134):                       **
**   A_OUT_n = OE_n ? 0 : (!DIR) ? (!SBA ? ~B_IN : ~regB) : 0              **
**   B_OUT_n = OE_n ? 0 : ( DIR) ? (!SAB ? ~A_IN : ~regA) : 0              **
** regA captures a_in_n(=A_IN) DIRECTLY on posedge CLKAB (no intermediate  **
** delay register); regB captures b_in_n(=B_IN) directly on posedge CLKBA. **
** This is the STRUCTURAL DIFFERENCE from TTL_74646, which routes A_IN/    **
** B_IN through an extra regX_Delayed hop before the capture register     **
** (see TTL_74646_func_tb.v finding #1). Exercised below with the same    **
** same-instant race probe used for the 646, so the two can be compared.  **
**                                                                         **
** COVERAGE: all 16 states of {DIR,OE_n,SAB,SBA} crossed with 6 data       **
** patterns each on A_IN and B_IN (00,FF,55,AA,5A,A5) = 16*6*6 = 576       **
** real-time-path checks, plus a dedicated stored-mode sequence, the       **
** "other side has no influence" sweep, and the disabled-output-is-zero   **
** check required by the repo's no-z-in-FPGA rule.                        **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp         **
**      TTL_74648_func_tb.v ../TTL_74648.v && vvp tb.vvp                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74648_func_tb;

  reg        sysclk = 0;
  reg [7:0]  A_IN, B_IN;
  reg        CLKAB, CLKBA, DIR, OE_n, SAB, SBA;
  wire [7:0] A_OUT_n, B_OUT_n;

  integer errors = 0;
  integer checks = 0;

  TTL_74648 DUT (
      .sysclk (sysclk),
      .A_IN   (A_IN),
      .B_IN   (B_IN),
      .CLKAB  (CLKAB),
      .CLKBA  (CLKBA),
      .DIR    (DIR),
      .OE_n   (OE_n),
      .SAB    (SAB),
      .SBA    (SBA),
      .A_OUT_n(A_OUT_n),
      .B_OUT_n(B_OUT_n)
  );

  // Shadow model of regA/regB, direct capture (no intermediate hop, matching
  // the 648's a_in_n/b_in_n direct-capture RTL).
  reg [7:0] shadow_regA = 8'h00;
  reg [7:0] shadow_regB = 8'h00;
  always @(posedge CLKAB) shadow_regA <= A_IN;
  always @(posedge CLKBA) shadow_regB <= B_IN;

  function [7:0] ref_a_out_n;
    input [7:0] b_in, regB;
    input dir, oe_n, sba;
    begin
      ref_a_out_n = oe_n ? 8'h00 : (!dir) ? ((!sba) ? ~b_in : ~regB) : 8'h00;
    end
  endfunction

  function [7:0] ref_b_out_n;
    input [7:0] a_in, regA;
    input dir, oe_n, sab;
    begin
      ref_b_out_n = oe_n ? 8'h00 : (dir) ? ((!sab) ? ~a_in : ~regA) : 8'h00;
    end
  endfunction

  task pulse_clkab;
    begin
      CLKAB = 1'b1;
      #1;
      CLKAB = 1'b0;
      #1;
    end
  endtask

  task pulse_clkba;
    begin
      CLKBA = 1'b1;
      #1;
      CLKBA = 1'b0;
      #1;
    end
  endtask

  task check_outputs;
    input [255:0] label;
    reg [7:0] ea, eb;
    begin
      #1;
      ea = ref_a_out_n(B_IN, shadow_regB, DIR, OE_n, SBA);
      eb = ref_b_out_n(A_IN, shadow_regA, DIR, OE_n, SAB);
      checks = checks + 2;
      if (A_OUT_n !== ea) begin
        errors = errors + 1;
        $display("FAIL %0s: A_OUT_n=%02h expected %02h (DIR=%b OE_n=%b SAB=%b SBA=%b A_IN=%02h B_IN=%02h)",
                  label, A_OUT_n, ea, DIR, OE_n, SAB, SBA, A_IN, B_IN);
      end
      if (B_OUT_n !== eb) begin
        errors = errors + 1;
        $display("FAIL %0s: B_OUT_n=%02h expected %02h (DIR=%b OE_n=%b SAB=%b SBA=%b A_IN=%02h B_IN=%02h)",
                  label, B_OUT_n, eb, DIR, OE_n, SAB, SBA, A_IN, B_IN);
      end
    end
  endtask

  integer ictl, ia, ib;
  reg [7:0] apat[0:5];
  reg [7:0] bpat[0:5];

  initial begin
    apat[0] = 8'h00; apat[1] = 8'hFF; apat[2] = 8'h55;
    apat[3] = 8'hAA; apat[4] = 8'h5A; apat[5] = 8'hA5;
    bpat[0] = 8'h00; bpat[1] = 8'hFF; bpat[2] = 8'h55;
    bpat[3] = 8'hAA; bpat[4] = 8'h5A; bpat[5] = 8'hA5;

    $dumpfile("TTL_74648_func_tb.vcd");
    $dumpvars(0, TTL_74648_func_tb);

    A_IN = 8'h00; B_IN = 8'h00;
    CLKAB = 0; CLKBA = 0;
    DIR = 0; OE_n = 0; SAB = 0; SBA = 0;
    #2;

    // ---- short documented sequence first (readable in the VCD) ----------
    DIR = 1; OE_n = 0; SAB = 0; SBA = 0;
    A_IN = 8'h5A; #2;
    pulse_clkab();               // regA <= 5A
    A_IN = 8'hC3;
    SAB = 1; #2;
    DIR = 0; SBA = 0; B_IN = 8'hA5; #2;
    pulse_clkba();                // regB <= A5
    B_IN = 8'h3C; SBA = 1; #2;

    $dumpoff;

    // ---- 1. real-time sweep: 16 control states x 6 x 6 data patterns ----
    for (ictl = 0; ictl < 16; ictl = ictl + 1) begin
      DIR  = ictl[0];
      OE_n = ictl[1];
      SAB  = ictl[2];
      SBA  = ictl[3];
      for (ia = 0; ia < 6; ia = ia + 1) begin
        for (ib = 0; ib < 6; ib = ib + 1) begin
          A_IN = apat[ia];
          B_IN = bpat[ib];
          check_outputs("real-time sweep");
        end
      end
    end

    // ---- 2. stored-mode sequence: A->B direction (DIR=1) -----------------
    DIR = 1; OE_n = 0; SAB = 1; SBA = 0;
    A_IN = 8'h11; #1;
    pulse_clkab();                       // regA <= 11
    check_outputs("stored A->B shows ~captured 11");
    A_IN = 8'h22;
    check_outputs("stored A->B still ~11 (live A_IN ignored)");
    SAB = 0;
    check_outputs("real-time A->B now shows ~live 22");

    // ---- 3. stored-mode sequence: B->A direction (DIR=0) -----------------
    DIR = 0; OE_n = 0; SBA = 1; SAB = 0;
    B_IN = 8'h33; #1;
    pulse_clkba();                       // regB <= 33
    check_outputs("stored B->A shows ~captured 33");
    B_IN = 8'h44;
    check_outputs("stored B->A still ~33 (live B_IN ignored)");
    SBA = 0;
    check_outputs("real-time B->A now shows ~live 44");

    // ---- 4. opposite-side input has NO influence, real-time AND stored ---
    DIR = 1; OE_n = 0; SAB = 0; A_IN = 8'h5A;
    B_IN = 8'h00; #1; checks = checks + 1;
    if (B_OUT_n !== ~8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_RT: B_OUT_n=%02h", B_OUT_n);
    end
    B_IN = 8'hFF; #1; checks = checks + 1;
    if (B_OUT_n !== ~8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_RT_SWEEP: B_OUT_n changed when B_IN swept 00->FF");
    end

    A_IN = 8'h5A; #1;
    pulse_clkab();     // regA <= 5A, known value for the stored-mode check
    A_IN = 8'h5A;
    SAB = 1;
    B_IN = 8'h00; #1; checks = checks + 1;
    if (B_OUT_n !== ~8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_STORED: B_OUT_n=%02h", B_OUT_n);
    end
    B_IN = 8'hFF; #1; checks = checks + 1;
    if (B_OUT_n !== ~8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_STORED_SWEEP: B_OUT_n changed when B_IN swept 00->FF");
    end

    DIR = 0; OE_n = 0; SBA = 0; B_IN = 8'hA5;
    A_IN = 8'h00; #1; checks = checks + 1;
    if (A_OUT_n !== ~8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_RT: A_OUT_n=%02h", A_OUT_n);
    end
    A_IN = 8'hFF; #1; checks = checks + 1;
    if (A_OUT_n !== ~8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_RT_SWEEP: A_OUT_n changed when A_IN swept 00->FF");
    end

    B_IN = 8'hA5; #1;
    pulse_clkba();     // regB <= A5, known value for the stored-mode check
    B_IN = 8'hA5;
    SBA = 1;
    A_IN = 8'h00; #1; checks = checks + 1;
    if (A_OUT_n !== ~8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_STORED: A_OUT_n=%02h", A_OUT_n);
    end
    A_IN = 8'hFF; #1; checks = checks + 1;
    if (A_OUT_n !== ~8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_STORED_SWEEP: A_OUT_n changed when A_IN swept 00->FF");
    end

    // ---- 5. disabled output reads all-zero with nonzero data underneath --
    DIR = 1; SAB = 0; SBA = 0; OE_n = 1; A_IN = 8'hFF; B_IN = 8'hFF;
    #1; checks = checks + 1;
    if (A_OUT_n !== 8'h00 || B_OUT_n !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OE_DISABLE_NONZERO: A_OUT_n=%02h B_OUT_n=%02h with OE_n=1 and FF data present",
                A_OUT_n, B_OUT_n);
    end

    // ---- 6. race probe (informational only): same-instant A_IN change ----
    //         and CLKAB rise. Compare this printout against the 646's -
    //         TTL_74648 has NO regX_Delayed hop, so it may behave
    //         differently under the identical race stimulus.
    DIR = 1; OE_n = 0; SAB = 1;
    A_IN = 8'h10; #1;
    pulse_clkab();                // clean capture: regA <= 10
    A_IN = 8'hAB;
    CLKAB = 1'b1;                 // same #0 instant as the A_IN change above
    #1;
    $display("INFO RACE PROBE: B_OUT_n after same-instant A_IN change + CLKAB rise = %02h (expect ~10=ef if old value wins, ~AB=54 if new value wins)", B_OUT_n);
    CLKAB = 1'b0;
    #1;

    $display("-----------------------------------------------------");
    $display(" TTL_74648 functional testbench");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #100000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
