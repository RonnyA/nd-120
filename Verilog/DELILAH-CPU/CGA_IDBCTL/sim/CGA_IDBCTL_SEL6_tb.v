/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_IDBCTL_SEL6 testbench                                             **
**                                                                       **
** Exhaustive verification of the IDB source selector (PDF page 99):     **
** all 4096 combinations of the 6 data inputs {D,M,V,S,PCR,PGS} and the  **
** 6 enable bits E_PINS[5:0] (ED,EM,EV,ES,EPCR,EPGS) are checked against **
** the independent model                                                 **
**                                                                       **
**   D0 = (D & ED) | (M & EM) | (V & EV) | (S & ES)                      **
**      | (PCR & EPCR) | (PGS & EPGS)                                    **
**                                                                       **
** derived from the schematic (six 2-input AND-with-negated-output       **
** gates into a negated-input 6-OR, which reduces to the sum of          **
** products above). Model cross-checked gate-vs-behavior in the          **
** generator script (scratchpad gen_tier1_golden.py, 0 mismatches).     **
**                                                                       **
** Pure combinational (no FF/latch primitives): a single build mode      **
** covers it.                                                            **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_IDBCTL_SEL6_tb;

  reg        D = 0;
  reg  [5:0] E_PINS = 0;
  reg        M = 0;
  reg        PCR = 0;
  reg        PGS = 0;
  reg        S = 0;
  reg        V = 0;

  wire D0;

  integer errors = 0;
  integer checks = 0;
  integer idx;
  reg expected;

  CGA_IDBCTL_SEL6 dut (
      .D(D),
      .E_PINS(E_PINS),
      .M(M),
      .PCR(PCR),
      .PGS(PGS),
      .S(S),
      .V(V),
      .D0(D0)
  );

  initial begin
    // Exhaustive sweep: index = {D,M,V,S,PCR,PGS,E_PINS[5:0]}
    for (idx = 0; idx < 4096; idx = idx + 1) begin
      {D, M, V, S, PCR, PGS, E_PINS} = idx[11:0];
      #2;
      expected = (D   & E_PINS[5]) | (M   & E_PINS[4]) | (V   & E_PINS[3]) |
                 (S   & E_PINS[2]) | (PCR & E_PINS[1]) | (PGS & E_PINS[0]);
      checks = checks + 1;
      if (D0 !== expected) begin
        errors = errors + 1;
        $display("FAIL idx=%04o: D0=%b expected %b (D=%b M=%b V=%b S=%b PCR=%b PGS=%b E=%06b)",
                 idx[11:0], D0, expected, D, M, V, S, PCR, PGS, E_PINS);
      end
    end

    if (errors == 0 && checks == 4096)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 4096 checks)", errors, checks);
    $finish;
  end

endmodule
