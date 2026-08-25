`timescale 1ns / 1ps

/**************************************************************************
** Testbench for the small pure-combinational DGA standard cells:        **
**   F091 - H,L level generator (constant 1 / constant 0)                **
**   F103 - inverter x3 signal drive                                     **
**   F571 - 2-to-1 multiplexer with active-low enable                    **
**                                                                       **
** Exhaustive: F091 has no inputs (2 output checks), F103 sweeps both    **
** input values (2 checks), F571 sweeps all 16 input combinations        **
** against a literal golden table re-derived from the NEC cell function  **
** (2:1 mux, ENB_N=1 forces output low - the gate-array cell drives 0    **
** when disabled, not Z).                                                **
**                                                                       **
** None of these modules contain VERILATOR_SIM / FPGA_FF_MODE ifdefs,   **
** so a single iverilog build covers the only code path.                 **
**                                                                       **
** Verdict: TB_RESULT: PASS (<n> checks) with a hard expected count.     **
***************************************************************************/

module DGA_FCELLS_tb;

  localparam EXPECTED_CHECKS = 20;  // 2 (F091) + 2 (F103) + 16 (F571)

  integer checks;
  integer errors;

  // ---------------- F091 ----------------
  wire f091_n01, f091_n02;
  F091 dut_f091 (
      .N01(f091_n01),
      .N02(f091_n02)
  );

  // ---------------- F103 ----------------
  reg  f103_in;
  wire f103_out;
  F103 dut_f103 (
      .F_IN (f103_in),
      .F_OUT(f103_out)
  );

  // ---------------- F571 ----------------
  reg  f571_a, f571_d0, f571_d1, f571_enb_n;
  wire f571_y;
  F571 dut_f571 (
      .A    (f571_a),
      .D0   (f571_d0),
      .D1   (f571_d1),
      .ENB_N(f571_enb_n),
      .Y    (f571_y)
  );

  task check_bit(input [127:0] name, input actual, input expected);
    begin
      checks = checks + 1;
      if (actual !== expected) begin
        errors = errors + 1;
        $display("ERROR: %0s actual=%b expected=%b", name, actual, expected);
      end
    end
  endtask

  // F571 golden table, index {ENB_N, A, D1, D0}. Re-derived from the cell
  // function: ENB_N=1 -> 0; else A=0 -> D0, A=1 -> D1.
  function golden_f571(input [3:0] v);
    begin
      case (v)
        4'b0000: golden_f571 = 1'b0;  // en, A=0, D0=0
        4'b0001: golden_f571 = 1'b1;  // en, A=0, D0=1
        4'b0010: golden_f571 = 1'b0;  // en, A=0, D0=0 (D1=1 ignored)
        4'b0011: golden_f571 = 1'b1;  // en, A=0, D0=1
        4'b0100: golden_f571 = 1'b0;  // en, A=1, D1=0
        4'b0101: golden_f571 = 1'b0;  // en, A=1, D1=0 (D0=1 ignored)
        4'b0110: golden_f571 = 1'b1;  // en, A=1, D1=1
        4'b0111: golden_f571 = 1'b1;  // en, A=1, D1=1
        default: golden_f571 = 1'b0;  // ENB_N=1 -> disabled, drives 0
      endcase
    end
  endfunction

  integer v;

  initial begin
    checks = 0;
    errors = 0;

    // F091: constant level generator
    #1;
    check_bit("F091.N01(high)", f091_n01, 1'b1);
    check_bit("F091.N02(low)", f091_n02, 1'b0);

    // F103: inverter, both input values
    f103_in = 1'b0;
    #1;
    check_bit("F103(in=0)", f103_out, 1'b1);
    f103_in = 1'b1;
    #1;
    check_bit("F103(in=1)", f103_out, 1'b0);

    // F571: exhaustive 16-combination sweep
    for (v = 0; v < 16; v = v + 1) begin
      {f571_enb_n, f571_a, f571_d1, f571_d0} = v[3:0];
      #1;
      check_bit("F571", f571_y, golden_f571(v[3:0]));
    end

    // Verdict with hard expected-count assertion
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
