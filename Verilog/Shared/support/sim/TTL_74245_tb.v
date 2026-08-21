/****************************************************************************
** TTL_74245 - exhaustive functional testbench                             **
**                                                                         **
** The 74245 is an octal bus transceiver. This testbench exists because the **
** module was CHANGED on 20-AUG-2026 to remove a shared helper wire, and    **
** the whole point of that change was that it must be FUNCTIONALLY          **
** IDENTICAL while being structurally different.                           **
**                                                                         **
** WHAT CHANGED AND WHY                                                     **
**   Before:                                                                **
**       wire [7:0] internalBus = DIR ? A : B;                              **
**       assign B_OUT = (!OE_n && DIR)  ? internalBus : 8'b0;               **
**       assign A_OUT = (!OE_n && !DIR) ? internalBus : 8'b0;               **
**   After:                                                                 **
**       assign B_OUT = (!OE_n && DIR)  ? A : 8'b0;                         **
**       assign A_OUT = (!OE_n && !DIR) ? B : 8'b0;                         **
**                                                                          **
**   Identical truth table - when DIR is 1 the helper WAS A, and when DIR   **
**   is 0 it WAS B - but the old form created the structural edge           **
**   B -> internalBus -> B_OUT. On the FIDB bus, where the far end feeds    **
**   back, that edge closed a COMBINATIONAL LOOP. Measured with Vivado      **
**   2025.2.1 on xc7a100t: 59 "[Synth 8-295] found timing loop" warnings,   **
**   and the worst reported path ran 181 logic levels / 94.4 ns of which    **
**   83.6 ns was the tool walking ~14 laps around the loop.                 **
**                                                                          **
** COVERAGE: every one of the 4 x 256 x 256 = 262,144 input combinations is **
** checked against a reference model - this module is small enough that     **
** EXHAUSTIVE means exhaustive, with no sampling and no argument about      **
** whether the corner cases were hit.                                       **
**                                                                          **
** THE REPO RULE THIS ALSO GUARDS: inside the FPGA a disabled output drives **
** ZERO, never z, because the buses are OR-ed together. Tested explicitly.  **
**                                                                          **
** Run: cd Verilog/Shared/support/sim && make test-74245                    **
**                                                                          **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74245_tb;

  reg  [7:0] A, B;
  reg        DIR, OE_n;
  wire [7:0] A_OUT, B_OUT;

  integer errors = 0;
  integer checks = 0;

  TTL_74245 DUT (
      .A    (A),
      .A_OUT(A_OUT),
      .B    (B),
      .B_OUT(B_OUT),
      .DIR  (DIR),
      .OE_n (OE_n)
  );

  // ---- reference model: the datasheet function, with the repo's
  // ---- zero-when-disabled convention instead of high-Z
  function [7:0] ref_b_out;
    input [7:0] a;
    input       dir, oe_n;
    begin
      ref_b_out = (oe_n == 1'b0 && dir == 1'b1) ? a : 8'b0;
    end
  endfunction

  function [7:0] ref_a_out;
    input [7:0] b;
    input       dir, oe_n;
    begin
      ref_a_out = (oe_n == 1'b0 && dir == 1'b0) ? b : 8'b0;
    end
  endfunction

  integer ia, ib, idir, ioe;
  reg [7:0] eb, ea;

  initial begin
    $display("=====================================================");
    $display(" TTL_74245 exhaustive functional testbench");
    $display(" (all 262,144 input combinations)");
    $display("=====================================================");

    for (idir = 0; idir < 2; idir = idir + 1) begin
      for (ioe = 0; ioe < 2; ioe = ioe + 1) begin
        for (ia = 0; ia < 256; ia = ia + 1) begin
          for (ib = 0; ib < 256; ib = ib + 1) begin
            DIR  = idir[0];
            OE_n = ioe[0];
            A    = ia[7:0];
            B    = ib[7:0];
            #1;
            eb = ref_b_out(A, DIR, OE_n);
            ea = ref_a_out(B, DIR, OE_n);
            checks = checks + 2;
            if (B_OUT !== eb) begin
              errors = errors + 1;
              if (errors < 10)
                $display("FAIL: DIR=%b OE_n=%b A=%02h B=%02h -> B_OUT=%02h expected %02h",
                         DIR, OE_n, A, B, B_OUT, eb);
            end
            if (A_OUT !== ea) begin
              errors = errors + 1;
              if (errors < 10)
                $display("FAIL: DIR=%b OE_n=%b A=%02h B=%02h -> A_OUT=%02h expected %02h",
                         DIR, OE_n, A, B, A_OUT, ea);
            end
          end
        end
      end
    end

    // ---- named property checks, so a failure says WHAT broke -------------

    // 1. Isolated: OE_n high means BOTH sides read zero, whatever DIR says
    DIR = 1'b1; OE_n = 1'b1; A = 8'hFF; B = 8'hFF; #1;
    if (A_OUT !== 8'h00 || B_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL ISOLATED_DIR1: A_OUT=%02h B_OUT=%02h, both must be 00", A_OUT, B_OUT);
    end
    DIR = 1'b0; OE_n = 1'b1; #1;
    if (A_OUT !== 8'h00 || B_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL ISOLATED_DIR0: A_OUT=%02h B_OUT=%02h, both must be 00", A_OUT, B_OUT);
    end

    // 2. THE ONE THAT MATTERS: with DIR=1 (A drives B), the B input must have
    //    NO influence on B_OUT. This is exactly what the old shared-helper
    //    form violated structurally, and it is why the loop existed.
    DIR = 1'b1; OE_n = 1'b0; A = 8'h5A;
    B = 8'h00; #1; eb = B_OUT;
    B = 8'hFF; #1;
    checks = checks + 1;
    if (B_OUT !== eb || B_OUT !== 8'h5A) begin
      errors = errors + 1;
      $display("FAIL B_DOES_NOT_REACH_B_OUT: B_OUT changed with B (%02h -> %02h)", eb, B_OUT);
    end

    // 3. Mirror: with DIR=0 (B drives A), A must not influence A_OUT
    DIR = 1'b0; OE_n = 1'b0; B = 8'hA5;
    A = 8'h00; #1; ea = A_OUT;
    A = 8'hFF; #1;
    checks = checks + 1;
    if (A_OUT !== ea || A_OUT !== 8'hA5) begin
      errors = errors + 1;
      $display("FAIL A_DOES_NOT_REACH_A_OUT: A_OUT changed with A (%02h -> %02h)", ea, A_OUT);
    end

    // 4. Only ONE side ever drives at a time - the idle side reads zero
    DIR = 1'b1; OE_n = 1'b0; A = 8'hFF; B = 8'hFF; #1;
    checks = checks + 1;
    if (A_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL ONE_DRIVER_DIR1: A_OUT=%02h while A drives B, must be 00", A_OUT);
    end
    DIR = 1'b0; OE_n = 1'b0; #1;
    checks = checks + 1;
    if (B_OUT !== 8'h00) begin
      errors = errors + 1;
      $display("FAIL ONE_DRIVER_DIR0: B_OUT=%02h while B drives A, must be 00", B_OUT);
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
