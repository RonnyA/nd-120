/****************************************************************************
** TTL_74646 - functional (truth-table) testbench                          **
**                                                                         **
** Companion to TTL_7464x_equiv_tb.v (which only checks USE_SYSCLK mode    **
** equivalence). This testbench is the FUNCTIONAL TRUTH TABLE test: real-  **
** time and stored transceiver behaviour, using the DEFAULT parameters     **
** (USE_SYSCLK_AB = USE_SYSCLK_BA = 0, plain posedge CLKAB/CLKBA capture). **
**                                                                         **
** Reference (read from TTL_74646.v lines 148/164, non-inverting part):    **
**   A_OUT = OE_n ? 0 : (!DIR) ? (!SBA ? B_IN : regB) : 0                  **
**   B_OUT = OE_n ? 0 : ( DIR) ? (!SAB ? A_IN : regA) : 0                  **
** regA captures on posedge CLKAB, regB captures on posedge CLKBA - both   **
** through an intermediate "regX_Delayed" combinational pass-through       **
** register (see RTL comment at lines 83-98).                             **
**                                                                         **
** COVERAGE: all 16 states of {DIR,OE_n,SAB,SBA} crossed with 6 data       **
** patterns each on A_IN and B_IN (00,FF,55,AA,5A,A5) = 16*6*6 = 576       **
** real-time-path checks, plus a dedicated stored-mode sequence (clock in  **
** a value, change the live input, prove SAB/SBA=1 shows the OLD value and **
** SAB/SBA=0 shows the NEW live value) repeated for both directions, plus  **
** the "other side has no influence" sweep and the disabled-output-is-zero **
** check required by the repo's no-z-in-FPGA rule.                        **
**                                                                         **
** RTL OBSERVATIONS (reported, not asserted as bugs - see job report):     **
**  1. TTL_74646 pushes A_IN/B_IN through an extra always@(A_IN)/          **
**     always@(B_IN,SBA) combinational register (regA_Delayed/             **
**     regB_Delayed) before the capture register. TTL_74648 (sibling part) **
**     captures A_IN/B_IN directly. Both settle to the same value with no  **
**     simulation-time delay in non-race stimulus (verified below); a      **
**     same-instant race between changing A_IN and pulsing CLKAB is        **
**     exercised separately and the observed (not asserted-correct)        **
**     result is printed for the record.                                  **
**  2. TTL_74646's `always@(B_IN, SBA)` lists SBA in its sensitivity list  **
**     even though only B_IN is assigned - this can only re-schedule the   **
**     same value, so it is a redundant sensitivity entry, not a           **
**     functional bug. Exercised below by toggling SBA alone and           **
**     confirming regB_Delayed (and hence B_OUT once captured) does not    **
**     change value.                                                      **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && iverilog -g2012 -o tb.vvp         **
**      TTL_74646_func_tb.v ../TTL_74646.v && vvp tb.vvp                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                             **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74646_func_tb;

  reg        sysclk = 0;
  reg [7:0]  A_IN, B_IN;
  reg        CLKAB, CLKBA, DIR, OE_n, SAB, SBA;
  wire [7:0] A_OUT, B_OUT;

  integer errors = 0;
  integer checks = 0;

  TTL_74646 DUT (
      .sysclk(sysclk),
      .A_IN  (A_IN),
      .B_IN  (B_IN),
      .CLKAB (CLKAB),
      .CLKBA (CLKBA),
      .DIR   (DIR),
      .OE_n  (OE_n),
      .SAB   (SAB),
      .SBA   (SBA),
      .A_OUT (A_OUT),
      .B_OUT (B_OUT)
  );

  // Shadow model of regA/regB (non-race capture: value present just before
  // the clock edge, no delta-cycle games) -- matches the RTL when A_IN/B_IN
  // are stable across the pulse, which is how every check below drives it.
  reg [7:0] shadow_regA = 8'h00;
  reg [7:0] shadow_regB = 8'h00;
  always @(posedge CLKAB) shadow_regA <= A_IN;
  always @(posedge CLKBA) shadow_regB <= B_IN;

  function [7:0] ref_a_out;
    input [7:0] b_in, regB;
    input dir, oe_n, sba;
    begin
      ref_a_out = oe_n ? 8'h00 : (!dir) ? ((!sba) ? b_in : regB) : 8'h00;
    end
  endfunction

  function [7:0] ref_b_out;
    input [7:0] a_in, regA;
    input dir, oe_n, sab;
    begin
      ref_b_out = oe_n ? 8'h00 : (dir) ? ((!sab) ? a_in : regA) : 8'h00;
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
      ea = ref_a_out(B_IN, shadow_regB, DIR, OE_n, SBA);
      eb = ref_b_out(A_IN, shadow_regA, DIR, OE_n, SAB);
      checks = checks + 2;
      if (A_OUT !== ea) begin
        errors = errors + 1;
        $display("FAIL %0s: A_OUT=%02h expected %02h (DIR=%b OE_n=%b SAB=%b SBA=%b A_IN=%02h B_IN=%02h)",
                  label, A_OUT, ea, DIR, OE_n, SAB, SBA, A_IN, B_IN);
      end
      if (B_OUT !== eb) begin
        errors = errors + 1;
        $display("FAIL %0s: B_OUT=%02h expected %02h (DIR=%b OE_n=%b SAB=%b SBA=%b A_IN=%02h B_IN=%02h)",
                  label, B_OUT, eb, DIR, OE_n, SAB, SBA, A_IN, B_IN);
      end
    end
  endtask

  integer ictl, ia, ib;
  reg [7:0] apat[0:5];
  reg [7:0] bpat[0:5];
  integer di;

  initial begin
    apat[0] = 8'h00; apat[1] = 8'hFF; apat[2] = 8'h55;
    apat[3] = 8'hAA; apat[4] = 8'h5A; apat[5] = 8'hA5;
    bpat[0] = 8'h00; bpat[1] = 8'hFF; bpat[2] = 8'h55;
    bpat[3] = 8'hAA; bpat[4] = 8'h5A; bpat[5] = 8'hA5;

    $dumpfile("TTL_74646_func_tb.vcd");
    $dumpvars(0, TTL_74646_func_tb);

    A_IN = 8'h00; B_IN = 8'h00;
    CLKAB = 0; CLKBA = 0;
    DIR = 0; OE_n = 0; SAB = 0; SBA = 0;
    #2;

    // ---- short documented sequence first (readable in the VCD) ----------
    DIR = 1; OE_n = 0; SAB = 0; SBA = 0;
    A_IN = 8'h5A; #2;
    pulse_clkab();               // regA <= 5A
    A_IN = 8'hC3;                // live A changes after capture
    SAB = 1; #2;                 // stored path now selected
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
    A_IN = 8'h11;
    #1;                                   // settle before the clock edge -
                                           // avoids the regA_Delayed race
                                           // (see finding #1 in the header)
    pulse_clkab();                       // regA <= 11
    check_outputs("stored A->B shows captured 11");
    A_IN = 8'h22;                        // live change after capture
    check_outputs("stored A->B still 11 (live A_IN ignored)");
    SAB = 0;
    check_outputs("real-time A->B now shows live 22");

    // ---- 3. stored-mode sequence: B->A direction (DIR=0) -----------------
    DIR = 0; OE_n = 0; SBA = 1; SAB = 0;
    B_IN = 8'h33;
    #1;                                   // settle before the clock edge
    pulse_clkba();                       // regB <= 33
    check_outputs("stored B->A shows captured 33");
    B_IN = 8'h44;
    check_outputs("stored B->A still 33 (live B_IN ignored)");
    SBA = 0;
    check_outputs("real-time B->A now shows live 44");

    // ---- 4. THE CHECK THAT MATTERS MOST: opposite-side input has NO ------
    //         influence on the driven output, real-time AND stored, both
    //         directions.
    DIR = 1; OE_n = 0; SAB = 0; A_IN = 8'h5A;
    B_IN = 8'h00; #1; checks = checks + 1;
    if (B_OUT !== 8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_RT: B_OUT=%02h", B_OUT);
    end
    B_IN = 8'hFF; #1; checks = checks + 1;
    if (B_OUT !== 8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_RT_SWEEP: B_OUT changed when B_IN swept 00->FF");
    end

    A_IN = 8'h5A; #1;
    pulse_clkab();     // regA <= 5A, so the stored-mode check below is
                        // checking THIS known value, not a leftover
    A_IN = 8'h5A;       // keep the live line consistent too
    SAB = 1;
    B_IN = 8'h00; #1; checks = checks + 1;
    if (B_OUT !== 8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_STORED: B_OUT=%02h", B_OUT);
    end
    B_IN = 8'hFF; #1; checks = checks + 1;
    if (B_OUT !== 8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_NOINFL_STORED_SWEEP: B_OUT changed when B_IN swept 00->FF");
    end

    DIR = 0; OE_n = 0; SBA = 0; B_IN = 8'hA5;
    A_IN = 8'h00; #1; checks = checks + 1;
    if (A_OUT !== 8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_RT: A_OUT=%02h", A_OUT);
    end
    A_IN = 8'hFF; #1; checks = checks + 1;
    if (A_OUT !== 8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_RT_SWEEP: A_OUT changed when A_IN swept 00->FF");
    end

    B_IN = 8'hA5; #1;
    pulse_clkba();     // regB <= A5, known value for the stored-mode check
    B_IN = 8'hA5;
    SBA = 1;
    A_IN = 8'h00; #1; checks = checks + 1;
    if (A_OUT !== 8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_STORED: A_OUT=%02h", A_OUT);
    end
    A_IN = 8'hFF; #1; checks = checks + 1;
    if (A_OUT !== 8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_NOINFL_STORED_SWEEP: A_OUT changed when A_IN swept 00->FF");
    end

    // ---- 5. disabled output reads all-zero with nonzero data underneath --
    DIR = 1; SAB = 0; SBA = 0; OE_n = 1; A_IN = 8'hFF; B_IN = 8'hFF;
    #1; checks = checks + 1;
    if (A_OUT !== 8'h00 || B_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL OE_DISABLE_NONZERO: A_OUT=%02h B_OUT=%02h with OE_n=1 and FF data present",
                A_OUT, B_OUT);
    end

    // ---- 6. redundant-sensitivity-list check: toggling SBA alone with a --
    //         stable B_IN must not change regB_Delayed's captured value.
    DIR = 0; OE_n = 0; SBA = 1; B_IN = 8'h77;
    #1;
    pulse_clkba();
    check_outputs("pre SBA-toggle capture 77");
    SBA = 0; #1; SBA = 1; #1;    // toggle SBA with B_IN held constant
    check_outputs("post SBA-toggle, regB unaffected");

    // ---- 7. race probe (informational only, not a pass/fail check): -----
    //         change A_IN and pulse CLKAB in the same simulation instant.
    DIR = 1; OE_n = 0; SAB = 1;   // DIR=1 routes regA out onto B_OUT
    A_IN = 8'h10;
    #1;
    pulse_clkab();                // clean capture: regA <= 10
    A_IN = 8'hAB;
    CLKAB = 1'b1;             // same #0 instant as the A_IN change above
    #1;
    $display("INFO RACE PROBE: B_OUT after same-instant A_IN change + CLKAB rise = %02h (old regA=10, new A_IN=AB)", B_OUT);
    CLKAB = 1'b0;
    #1;

    $display("-----------------------------------------------------");
    $display(" TTL_74646 functional testbench");
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
