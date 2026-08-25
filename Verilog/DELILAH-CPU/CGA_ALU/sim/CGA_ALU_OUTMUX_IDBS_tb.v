/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_ALU_OUTMUX_IDBS testbench                                         **
**                                                                       **
** Verification of the IDBS source-enable decoder (drawing page 55):     **
** the 5-bit microcode field CSIDBS_4_0 is decoded by two ND38GLP        **
** 3-to-8 decoders and a scattering of NAND gates, latched into two      **
** R81 registers on ALUCLK, and fanned out as 14 enable signals.         **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_OUTMUX_IDBS.v). No       **
** drawing and no ND documentation was used, so this is an INDEPENDENT   **
** TRANSCRIPTION of the same gates - it catches a wrong decoder output   **
** index, a wrong register bit tap, or a true/complement (Qx vs QxN)     **
** mix-up, but it cannot tell whether the schematic itself was right.    **
** Where the intended meaning of a code was not derivable from the RTL   **
** it is simply CHARACTERISED (recorded) rather than judged.             **
**                                                                       **
** Transcribed gate map (n = CSIDBS_4_0):                                **
**   en1 = ~n[4] & ~n[3]  enables IDBS_G1, en2 = ~n[4] & n[3] -> G2      **
**   Zi (active low) = ~(en & n[2:0]==i)                                 **
**   r1 = {h,g,f,e,d,c,b,a} = {G2.Z1,G2.Z0,G1.Z6,G1.Z4,                  **
**                             G1.Z3,G1.Z2,G1.Z1,G1.Z0}                  **
**   r2_a = G2.Z4                                                        **
**   r2_e = ~(n[4] & ~n[3] & ~n[2] & n[1] & ~n[0])   (i.e. code 22 oct)  **
**   r2_b = ~(r1_g & r2_a)                                               **
**   r2_d = ~(r1_c & r2_e)                                               **
**   r2_c = ~(r1_b & r1_c & r1_d & r1_e & r1_f & r1_h & ~r2_b & r2_e)    **
**   R1 <= {r1_h..r1_a} , R2 <= {0,0,0,r2_e,r2_d,r2_c,r2_b,r2_a} on CP   **
** Output taps (note the deliberate mix of true and inverted taps):      **
**   EBMG=~R1[1] EGPRH=~R1[2] EDBR=~R1[3] EARG=~R1[4]                    **
**   ESTS=~R1[5] EBARG=~R1[6] ESWAP=~R1[7]                               **
**   EA  = ~ALUD2N & ~R1[0]      EF = ALUD2N & ~R1[0]   (combinational)  **
**   EAARG=~R2[0] EABARG=R2[1] EFIDB=~R2[2] EGPRL=R2[3] EGPRS=~R2[4]     **
**                                                                       **
** Test plan:                                                            **
**   1. EXHAUSTIVE: all 32 CSIDBS codes x both ALUD2N values, clocked,   **
**      all 14 outputs compared each time (896 checks). A single wrong   **
**      decoder pin or register tap fails here.                          **
**   2. ALUD2N steered combinationally with NO clock: EA and EF must     **
**      swap without a new capture, and must never both be high.         **
**   3. hold: CSIDBS changed with no clock, all 12 registered outputs    **
**      must not move.                                                   **
**                                                                       **
** Registered module (2x R81_EN switched by FPGA_FF_MODE): the Makefile  **
** target test-alu-outmux-idbs runs this twice - default latch/CP mode   **
** (posedge ALUCLK) and -DFPGA_FF_MODE (posedge sysclk gated by          **
** ALUCLK_EN). Note the plain R81 has no initial value, so the very      **
** first check is only made after a defining clock.                      **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_ALU/sim && make test-alu-outmux-idbs     **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_ALU_OUTMUX_IDBS_tb;

  reg        sysclk = 0;
  reg        ALUCLK_EN = 0;
  reg        ALUCLK = 0;
  reg        ALUD2N = 0;
  reg  [4:0] CSIDBS_4_0 = 0;

  wire EA, EAARG, EABARG, EARG, EBARG, EBMG, EDBR;
  wire EF, EFIDB, EGPRH, EGPRL, EGPRS, ESTS, ESWAP;

  integer errors = 0;
  integer checks = 0;
  integer i;

  reg [7:0] m_r1;  // model R1 register
  reg [7:0] m_r2;  // model R2 register

  CGA_ALU_OUTMUX_IDBS dut (
      .sysclk    (sysclk),
      .ALUCLK_EN (ALUCLK_EN),
      .ALUCLK    (ALUCLK),
      .ALUD2N    (ALUD2N),
      .CSIDBS_4_0(CSIDBS_4_0),
      .EA        (EA),
      .EAARG     (EAARG),
      .EABARG    (EABARG),
      .EARG      (EARG),
      .EBARG     (EBARG),
      .EBMG      (EBMG),
      .EDBR      (EDBR),
      .EF        (EF),
      .EFIDB     (EFIDB),
      .EGPRH     (EGPRH),
      .EGPRL     (EGPRL),
      .EGPRS     (EGPRS),
      .ESTS      (ESTS),
      .ESWAP     (ESWAP)
  );

  always #5 sysclk = ~sysclk;

  initial begin
    $dumpfile("CGA_ALU_OUTMUX_IDBS_tb.vcd");
    $dumpvars(0, CGA_ALU_OUTMUX_IDBS_tb);
  end

  // ---- independent transcription of the combinational front end ----------
  function [7:0] model_r1(input [4:0] n);
    reg en1, en2;
    begin
      en1 = (~n[4]) & (~n[3]);
      en2 = (~n[4]) & n[3];
      model_r1[0] = ~(en1 & (n[2:0] == 3'd0));  // a = G1.Z0
      model_r1[1] = ~(en1 & (n[2:0] == 3'd1));  // b = G1.Z1
      model_r1[2] = ~(en1 & (n[2:0] == 3'd2));  // c = G1.Z2
      model_r1[3] = ~(en1 & (n[2:0] == 3'd3));  // d = G1.Z3
      model_r1[4] = ~(en1 & (n[2:0] == 3'd4));  // e = G1.Z4
      model_r1[5] = ~(en1 & (n[2:0] == 3'd6));  // f = G1.Z6
      model_r1[6] = ~(en2 & (n[2:0] == 3'd0));  // g = G2.Z0
      model_r1[7] = ~(en2 & (n[2:0] == 3'd1));  // h = G2.Z1
    end
  endfunction

  function [7:0] model_r2(input [4:0] n);
    reg en2, r2a, r2b, r2c, r2d, r2e;
    reg [7:0] r1;
    begin
      r1  = model_r1(n);
      en2 = (~n[4]) & n[3];
      r2a = ~(en2 & (n[2:0] == 3'd4));  // G2.Z4
      r2e = ~(n[4] & ~n[3] & ~n[2] & n[1] & ~n[0]);
      r2b = ~(r1[6] & r2a);
      r2d = ~(r1[2] & r2e);
      r2c = ~(r1[1] & r1[2] & r1[3] & r1[4] & r1[5] & r1[7] & (~r2b) & r2e);
      model_r2 = {3'b000, r2e, r2d, r2c, r2b, r2a};
    end
  endfunction

  task chk(input [255:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %b expected %b (CSIDBS=%0d ALUD2N=%b)",
                 name, got, exp, CSIDBS_4_0, ALUD2N);
      end
    end
  endtask

  task compare_all;
    begin
      chk("EBMG",   EBMG,   ~m_r1[1]);
      chk("EGPRH",  EGPRH,  ~m_r1[2]);
      chk("EDBR",   EDBR,   ~m_r1[3]);
      chk("EARG",   EARG,   ~m_r1[4]);
      chk("ESTS",   ESTS,   ~m_r1[5]);
      chk("EBARG",  EBARG,  ~m_r1[6]);
      chk("ESWAP",  ESWAP,  ~m_r1[7]);
      chk("EA",     EA,     (~ALUD2N) & (~m_r1[0]));
      chk("EF",     EF,     ALUD2N & (~m_r1[0]));
      chk("EAARG",  EAARG,  ~m_r2[0]);
      chk("EABARG", EABARG,  m_r2[1]);
      chk("EFIDB",  EFIDB,  ~m_r2[2]);
      chk("EGPRL",  EGPRL,   m_r2[3]);
      chk("EGPRS",  EGPRS,  ~m_r2[4]);
    end
  endtask

  // One ALUCLK event, valid in BOTH build modes.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
    end
  endtask

  task step(input [4:0] n, input d2n);
    begin
      CSIDBS_4_0 = n;
      ALUD2N     = d2n;
      pulse_aluclk;
      m_r1 = model_r1(n);
      m_r2 = model_r2(n);
      #2;
      compare_all;
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_ALU_OUTMUX_IDBS_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_ALU_OUTMUX_IDBS_tb: latch/CP mode (posedge ALUCLK capture)");
`endif

    // Preamble: Shared/logisim/Decoder_8.v uses always @(*) and Icarus does
    // not execute it until an input actually transitions, so a decoder whose
    // select/enable never move stays X. Wiggle every CSIDBS bit once before
    // the first defining clock. (Reported as a simulator-visible oddity of
    // Decoder_8, not of this module.)
    CSIDBS_4_0 = 5'b11111; #1;
    CSIDBS_4_0 = 5'b00000; #1;

    // 1. exhaustive: all 32 codes, both ALUD2N phases
    for (i = 0; i < 32; i = i + 1) step(i[4:0], 1'b0);
    for (i = 0; i < 32; i = i + 1) step(i[4:0], 1'b1);

    // 2. combinational ALUD2N steering with no clock.
    //    Park on code 0 (the only code that clears R1[0]) so EA/EF are live.
    step(5'd0, 1'b0);
    ALUD2N = 1'b1;
    #7;
    chk("EA  after comb flip", EA, (~ALUD2N) & (~m_r1[0]));
    chk("EF  after comb flip", EF, ALUD2N & (~m_r1[0]));
    chk("EA&EF never both hi", EA & EF, 1'b0);
    ALUD2N = 1'b0;
    #7;
    chk("EA  after comb back", EA, (~ALUD2N) & (~m_r1[0]));
    chk("EF  after comb back", EF, ALUD2N & (~m_r1[0]));
    chk("EA&EF never both hi", EA & EF, 1'b0);

    // 3. hold: change the code with no clock, registered outputs must freeze
    CSIDBS_4_0 = 5'd9;
    #20;
    compare_all;

    if (errors == 0 && checks == 930) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 930 checks)", checks, errors);
    if (errors == 0 && checks == 930) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
