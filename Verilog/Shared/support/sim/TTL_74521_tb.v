/****************************************************************************
** TTL_74521 - exhaustive functional testbench                             **
**                                                                         **
** 8-bit identity comparator, built on Shared/logisim/Comparator.v. Read   **
** from Verilog/Shared/support/TTL_74521.v:                                **
**   s_e        = ~E_n;                                                    **
**   AB_n       = s_e ? ~aEqualsB : 1'b0;                                  **
** i.e. when E_n=0 (enabled): AB_n = ~(A==B)  - active-low "equal" output,  **
** matching the real 74521's enabled behaviour.                            **
** when E_n=1 (DISABLED): AB_n is forced to 1'b0 UNCONDITIONALLY, for      **
** every A and every B. THIS IS A REAL DEPARTURE FROM THE DATASHEET: on a   **
** genuine 74521, deasserting the enable forces the P=Q output HIGH        **
** (inactive/open, i.e. "not equal" is reported / the compare result is    **
** suppressed to its inactive level), not LOW. This RTL instead drives the **
** ACTIVE level (0, meaning "equal asserted") whenever disabled, for every **
** single A/B pair including A!=B. This is flagged here and reported.      **
** Because AB_n is a genuine combinational output (not tri-stated to a      **
** shared bus) rather than a 3-state bus driver, the repo's "disabled      **
** output drives 0 not z" tri-state convention is not the mechanism at     **
** work here - this is the RTL's own definition of what E_n does, and it   **
** happens to always be 0 when disabled, verified exhaustively below.      **
**                                                                         **
** DEPENDENCY: this module instantiates Comparator from                    **
** Verilog/Shared/logisim/Comparator.v - both files are on the iverilog    **
** command line.                                                          **
**                                                                         **
** COVERAGE: fully exhaustive - all 256 x 256 x 2 = 131,072 combinations   **
** of A, B, E_n are checked against a reference model.                     **
**                                                                         **
** Run: cd Verilog/Shared/support/sim && make test-74521                  **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module TTL_74521_tb;

  reg [7:0] A_7_0, B_7_0;
  reg       E_n;
  wire      AB_n;

  integer errors = 0;
  integer checks = 0;

  TTL_74521 DUT (
      .A_7_0(A_7_0),
      .B_7_0(B_7_0),
      .E_n  (E_n),
      .AB_n (AB_n)
  );

  // ---- reference model, straight from the RTL's own assign statements ----
  function ref_ab_n;
    input [7:0] a, b;
    input       e_n;
    begin
      if (e_n)
        ref_ab_n = 1'b0;               // RTL forces 0 whenever disabled
      else
        ref_ab_n = (a == b) ? 1'b0 : 1'b1;
    end
  endfunction

  integer ia, ib, ie;
  reg eab;

  initial begin
    $dumpfile("TTL_74521_tb.vcd");
    $dumpvars(0, TTL_74521_tb);

    $display("=====================================================");
    $display(" TTL_74521 exhaustive functional testbench");
    $display(" (all 131,072 input combinations)");
    $display("=====================================================");

    // ---- short documentation sequence -------------------------------------
    A_7_0 = 8'h00; B_7_0 = 8'h00; E_n = 1'b1; #10; // disabled, equal inputs
    E_n = 1'b0; #10;                                // enabled, A==B -> AB_n=0
    B_7_0 = 8'h01; #10;                             // enabled, A!=B -> AB_n=1
    A_7_0 = 8'h01; #10;                             // enabled, A==B again -> AB_n=0
    E_n = 1'b1; #10;                                // disabled again, equal inputs
    B_7_0 = 8'hFF; #10;                             // disabled, unequal inputs
    A_7_0 = 8'hFF; B_7_0 = 8'h00; #10;              // disabled, boundary values unequal
    E_n = 1'b0; #10;                                // re-enabled, unequal -> AB_n=1
    A_7_0 = 8'h00; #10;                             // enabled, A==B=00 -> AB_n=0
    A_7_0 = 8'hFF; B_7_0 = 8'hFF; #10;              // enabled, A==B=FF -> AB_n=0

    $dumpoff;

    // ---- exhaustive sweep --------------------------------------------------
    for (ie = 0; ie < 2; ie = ie + 1)
    for (ia = 0; ia < 256; ia = ia + 1)
    for (ib = 0; ib < 256; ib = ib + 1) begin
      E_n = ie[0];
      A_7_0 = ia[7:0];
      B_7_0 = ib[7:0];
      #1;
      eab = ref_ab_n(A_7_0, B_7_0, E_n);
      checks = checks + 1;
      if (AB_n !== eab) begin
        errors = errors + 1;
        if (errors < 10)
          $display("FAIL: A=%02h B=%02h E_n=%b -> AB_n=%b expected %b",
                    A_7_0, B_7_0, E_n, AB_n, eab);
      end
    end

    // ---- named boundary checks, E_n asserted (disabled) --------------------

    // A==B at 00, disabled
    A_7_0 = 8'h00; B_7_0 = 8'h00; E_n = 1'b1; #1;
    checks = checks + 1;
    if (AB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_EQ_00: A=00 B=00 E_n=1 -> AB_n=%b expected 0", AB_n);
    end

    // A==B at FF, disabled
    A_7_0 = 8'hFF; B_7_0 = 8'hFF; E_n = 1'b1; #1;
    checks = checks + 1;
    if (AB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_EQ_FF: A=FF B=FF E_n=1 -> AB_n=%b expected 0", AB_n);
    end

    // A!=B, 00 vs FF, disabled
    A_7_0 = 8'h00; B_7_0 = 8'hFF; E_n = 1'b1; #1;
    checks = checks + 1;
    if (AB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_NEQ_00_FF: A=00 B=FF E_n=1 -> AB_n=%b expected 0 (RTL forces 0 even though A!=B)", AB_n);
    end

    // A!=B, FF vs 00, disabled
    A_7_0 = 8'hFF; B_7_0 = 8'h00; E_n = 1'b1; #1;
    checks = checks + 1;
    if (AB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL DISABLED_NEQ_FF_00: A=FF B=00 E_n=1 -> AB_n=%b expected 0 (RTL forces 0 even though A!=B)", AB_n);
    end

    // sanity mirror with E_n de-asserted (enabled), same boundary values
    A_7_0 = 8'h00; B_7_0 = 8'h00; E_n = 1'b0; #1;
    checks = checks + 1;
    if (AB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL ENABLED_EQ_00: A=00 B=00 E_n=0 -> AB_n=%b expected 0", AB_n);
    end
    A_7_0 = 8'hFF; B_7_0 = 8'hFF; E_n = 1'b0; #1;
    checks = checks + 1;
    if (AB_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL ENABLED_EQ_FF: A=FF B=FF E_n=0 -> AB_n=%b expected 0", AB_n);
    end
    A_7_0 = 8'h00; B_7_0 = 8'hFF; E_n = 1'b0; #1;
    checks = checks + 1;
    if (AB_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL ENABLED_NEQ_00_FF: A=00 B=FF E_n=0 -> AB_n=%b expected 1", AB_n);
    end
    A_7_0 = 8'hFF; B_7_0 = 8'h00; E_n = 1'b0; #1;
    checks = checks + 1;
    if (AB_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL ENABLED_NEQ_FF_00: A=FF B=00 E_n=0 -> AB_n=%b expected 1", AB_n);
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
