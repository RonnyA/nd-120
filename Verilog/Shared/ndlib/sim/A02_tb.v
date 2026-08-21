/****************************************************************************
** A02 - exhaustive self-checking testbench                                **
**                                                                         **
** A02 is the LSI Logic AND-OR-INVERT cell used on CGA/ALU page 61:        **
**     Z = ~((A & B) | (C & D))                                            **
** It is purely combinational - no clock, no state, nothing to reset. It   **
** is in the sequential-cell sweep only because it sits in the same ndlib  **
** directory and had no testbench at all.                                  **
**                                                                         **
** COVERAGE: all 16 input combinations, checked against the AOI function   **
** written out independently. With 16 of 16 cases there is no sampling     **
** argument - exhaustive means exhaustive.                                 **
**                                                                         **
** Also checked, because they are the mistakes this cell invites: the      **
** output is INVERTED (an AOI, not an AO), the two AND pairs are (A,B) and **
** (C,D) and not (A,C)/(B,D), and Z never goes unknown for any defined     **
** input. Each of those is a separate named check so a wrong transcription **
** says which way it is wrong.                                             **
**                                                                         **
** BUILD MODE: no `ifdef and no state, so latch mode and -DFPGA_FF_MODE    **
** are bit-identical. Both are run.                                        **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-a02                       **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module A02_tb;

  integer checks = 0;
  integer errors = 0;

`define CHK(NM, GOT, EXP) \
  begin \
    checks = checks + 1; \
    if ((GOT) !== (EXP)) begin \
      errors = errors + 1; \
      $display("FAIL t=%0t %0s : got=%b expected=%b", $time, NM, (GOT), (EXP)); \
    end \
  end

  reg [3:0] in = 4'b0000;   // {D,C,B,A}
  wire A = in[0];
  wire B = in[1];
  wire C = in[2];
  wire D = in[3];
  wire Z;

  A02 DUT (.A(A), .B(B), .C(C), .D(D), .Z(Z));

  // independent reference
  function ref_z(input a, input b, input c, input d);
    begin
      ref_z = ~((a & b) | (c & d));
    end
  endfunction

  integer i;

  initial begin
    $dumpfile("A02_tb.vcd");
    $dumpvars(0, A02_tb);
  end

  initial begin
    // ---- exhaustive truth table ----
    for (i = 0; i < 16; i = i + 1) begin
      in = i[3:0];
      #2;
      `CHK("AOI truth table", Z, ref_z(in[0], in[1], in[2], in[3]))
      `CHK("Z is never unknown", ^Z === 1'bx, 1'b0)
    end

    // ---- the inversion: A=B=1 must FORCE Z low, not high ----
    in = 4'b0011; #2;                      // A=1 B=1 C=0 D=0
    `CHK("A&B=1 pulls Z LOW (it is an AOI, not an AO)", Z, 1'b0)
    in = 4'b1100; #2;                      // C=1 D=1 A=0 B=0
    `CHK("C&D=1 pulls Z LOW", Z, 1'b0)

    // ---- the pairing: (A,B) and (C,D), not (A,C)/(B,D) ----
    in = 4'b0101; #2;                      // A=1 C=1, B=0 D=0
    `CHK("A=1,C=1 alone must NOT pull Z low (wrong-pairing guard)", Z, 1'b1)
    in = 4'b1010; #2;                      // B=1 D=1, A=0 C=0
    `CHK("B=1,D=1 alone must NOT pull Z low (wrong-pairing guard)", Z, 1'b1)

    // ---- all inputs low / all high ----
    in = 4'b0000; #2;
    `CHK("all inputs low -> Z high", Z, 1'b1)
    in = 4'b1111; #2;
    `CHK("all inputs high -> Z low", Z, 1'b0)

    $display("A02_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
