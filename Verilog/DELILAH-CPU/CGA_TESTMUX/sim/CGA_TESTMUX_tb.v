/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_TESTMUX testbench                                                 **
**                                                                       **
** Verification of the microcode condition test multiplexer (drawing     **
** page 105): five MUX81 slices sharing one 3-bit select, feeding the    **
** 5-bit TEST_4_0 bus that the microprogram branches on.                 **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (Verilog/DELILAH-CPU/CGA_TESTMUX/circuit/CGA_TESTMUX.v). The whole    **
** point of this module is its wiring, so the 5 x 8 input map below is   **
** a hand transcription of the five MUX81 instances - a single swapped   **
** Dn pin, or a signal landing on the wrong TEST bit, fails here.        **
** Nothing was taken from ND documentation.                              **
**                                                                       **
** Select decode (transcribed):                                          **
**   A = TSEL_2_0[0] & PTSTN,  B = TSEL_2_0[1] & PTSTN,                  **
**   C = TSEL_2_0[2] & PTSTN,  MUX81 sel = {C,B,A}                       **
**   => PTSTN=0 FORCES select 0 whatever TSEL says.                      **
**   GATES_1 is a NAND with BubblesMask=2'b11, i.e. an OR:               **
**   s_gates1_out = PTSTN | PTREEOUT.                                    **
**                                                                       **
** Per-slice source map (sel 0..7):                                      **
**   TEST[0]: PTSTN|PTREEOUT, VACCN, MI,      OVF, UPN,  LCZN,   SC[0], TVEC[0]
**   TEST[1]: CSMREQ,         INDN,  PTM,     ZF,  COND, DZD,    SC[1], TVEC[1]
**   TEST[2]: LDIRV,          CBRKN, WPN,     F15, PN,   OOD,    SC[2], TVEC[2]
**   TEST[3]: VEX,            WRITEN,XFETCHN, SGR, TN,   CFETCH, SC[3], TVEC[3]
**   TEST[4]: 1,              DSTOPN,1,       CRY, 1,    RESTR,  DEEP,  0     
** (SC[n] means SC_6_3[n], TVEC[n] means TVEC_3_0[n].)                   **
** CHARACTERISED, not judged: TEST[4] is hard-wired to 1 for selects 0,  **
** 2 and 4 and to 0 for select 7 - three constant-one taps and one       **
** constant-zero tap are what the netlist says, and this testbench       **
** simply records that.                                                  **
**                                                                       **
** Test plan:                                                            **
**   1. EXHAUSTIVE over all 8 TSEL values x both PTSTN values:           **
**      - walking-one across all 36 data inputs (one input high, all     **
**        the rest low) - catches a Dn pin taken from the wrong signal   **
**      - all-zeros and all-ones vectors - catches stuck taps            **
**   2. explicit PTSTN override check: with PTSTN=0 the select must      **
**      collapse to 0 for every TSEL value while the data inputs carry   **
**      a pattern that makes all eight sources distinguishable           **
**   3. 512 fixed-seed LFSR vectors with every input random              **
** The whole 5-bit TEST_4_0 bus is compared on every vector.             **
**                                                                       **
** Purely combinational - no flip-flop, no `ifdef FPGA_FF_MODE in this   **
** module. The Makefile target test-testmux-iv builds it both ways and   **
** both must print PASS.                                                 **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_TESTMUX/sim && make test-testmux-iv      **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_TESTMUX_tb;

  // sig[] packing - index order is fixed and used by the model
  localparam integer I_CBRKN    = 0;
  localparam integer I_CFETCH   = 1;
  localparam integer I_COND     = 2;
  localparam integer I_CRY      = 3;
  localparam integer I_CSMREQ   = 4;
  localparam integer I_DEEP     = 5;
  localparam integer I_DSTOPN   = 6;
  localparam integer I_DZD      = 7;
  localparam integer I_F15      = 8;
  localparam integer I_INDN     = 9;
  localparam integer I_LCZN     = 10;
  localparam integer I_LDIRV    = 11;
  localparam integer I_MI       = 12;
  localparam integer I_OOD      = 13;
  localparam integer I_OVF      = 14;
  localparam integer I_PN       = 15;
  localparam integer I_PTM      = 16;
  localparam integer I_PTREEOUT = 17;
  localparam integer I_RESTR    = 18;
  localparam integer I_SGR      = 19;
  localparam integer I_TN       = 20;
  localparam integer I_UPN      = 21;
  localparam integer I_VACCN    = 22;
  localparam integer I_VEX      = 23;
  localparam integer I_WPN      = 24;
  localparam integer I_WRITEN   = 25;
  localparam integer I_XFETCHN  = 26;
  localparam integer I_ZF       = 27;
  localparam integer I_SC0      = 28;  // SC_6_3[0] .. SC_6_3[3]
  localparam integer I_TVEC0    = 32;  // TVEC_3_0[0] .. TVEC_3_0[3]
  localparam integer NSIG       = 36;

  reg [35:0] sig = 0;
  reg        PTSTN = 0;
  reg  [2:0] TSEL_2_0 = 0;

  wire [4:0] TEST_4_0;

  integer errors = 0;
  integer checks = 0;
  integer i, t, p;
  reg [31:0] lfsr;

  CGA_TESTMUX dut (
      .CBRKN   (sig[I_CBRKN]),
      .CFETCH  (sig[I_CFETCH]),
      .COND    (sig[I_COND]),
      .CRY     (sig[I_CRY]),
      .CSMREQ  (sig[I_CSMREQ]),
      .DEEP    (sig[I_DEEP]),
      .DSTOPN  (sig[I_DSTOPN]),
      .DZD     (sig[I_DZD]),
      .F15     (sig[I_F15]),
      .INDN    (sig[I_INDN]),
      .LCZN    (sig[I_LCZN]),
      .LDIRV   (sig[I_LDIRV]),
      .MI      (sig[I_MI]),
      .OOD     (sig[I_OOD]),
      .OVF     (sig[I_OVF]),
      .PN      (sig[I_PN]),
      .PTM     (sig[I_PTM]),
      .PTREEOUT(sig[I_PTREEOUT]),
      .PTSTN   (PTSTN),
      .RESTR   (sig[I_RESTR]),
      .SC_6_3  (sig[I_SC0+3:I_SC0]),
      .SGR     (sig[I_SGR]),
      .TN      (sig[I_TN]),
      .TSEL_2_0(TSEL_2_0),
      .TVEC_3_0(sig[I_TVEC0+3:I_TVEC0]),
      .UPN     (sig[I_UPN]),
      .VACCN   (sig[I_VACCN]),
      .VEX     (sig[I_VEX]),
      .WPN     (sig[I_WPN]),
      .WRITEN  (sig[I_WRITEN]),
      .XFETCHN (sig[I_XFETCHN]),
      .ZF      (sig[I_ZF]),
      .TEST_4_0(TEST_4_0)
  );

  initial begin
    $dumpfile("CGA_TESTMUX_tb.vcd");
    $dumpvars(0, CGA_TESTMUX_tb);
  end

  // ---------------- independent model ----------------
  function [4:0] model(input [35:0] s, input ptstn, input [2:0] tsel);
    reg [2:0] sel;
    begin
      sel = {tsel[2] & ptstn, tsel[1] & ptstn, tsel[0] & ptstn};
      case (sel)
        3'd0: model = {1'b1, s[I_VEX], s[I_LDIRV], s[I_CSMREQ], ptstn | s[I_PTREEOUT]};
        3'd1: model = {s[I_DSTOPN], s[I_WRITEN], s[I_CBRKN], s[I_INDN], s[I_VACCN]};
        3'd2: model = {1'b1, s[I_XFETCHN], s[I_WPN], s[I_PTM], s[I_MI]};
        3'd3: model = {s[I_CRY], s[I_SGR], s[I_F15], s[I_ZF], s[I_OVF]};
        3'd4: model = {1'b1, s[I_TN], s[I_PN], s[I_COND], s[I_UPN]};
        3'd5: model = {s[I_RESTR], s[I_CFETCH], s[I_OOD], s[I_DZD], s[I_LCZN]};
        3'd6: model = {s[I_DEEP], s[I_SC0+3], s[I_SC0+2], s[I_SC0+1], s[I_SC0+0]};
        default:
              model = {1'b0, s[I_TVEC0+3], s[I_TVEC0+2], s[I_TVEC0+1], s[I_TVEC0+0]};
      endcase
    end
  endfunction

  task vec(input [35:0] s, input ptstn, input [2:0] tsel, input [255:0] name);
    reg [4:0] exp;
    begin
      sig      = s;
      PTSTN    = ptstn;
      TSEL_2_0 = tsel;
      #2;
      exp    = model(s, ptstn, tsel);
      checks = checks + 1;
      if (TEST_4_0 !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: TEST got %05b exp %05b (TSEL=%0d PTSTN=%b sig=%09h)",
                 name, TEST_4_0, exp, tsel, ptstn, s);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_TESTMUX_tb: built with FPGA_FF_MODE (must not matter here)");
`else
    $display("CGA_TESTMUX_tb: default build mode");
`endif

    // Preamble: Shared/logisim/Multiplexer_8.v uses always @(*) and Icarus
    // does not execute it until an input actually transitions, so any mux
    // whose inputs never move stays X. Wiggle everything once first.
    // (Reported as a simulator-visible oddity of the shared mux primitive.)
    sig = {NSIG{1'b1}}; PTSTN = 1'b1; TSEL_2_0 = 3'd7; #1;
    sig = 36'd0;        PTSTN = 1'b0; TSEL_2_0 = 3'd0; #1;

    // 1. exhaustive select sweep, walking-one over every data input
    for (t = 0; t < 8; t = t + 1)
      for (p = 0; p < 2; p = p + 1) begin
        for (i = 0; i < NSIG; i = i + 1)
          vec(36'd1 << i, p[0], t[2:0], "walk1 input");
        vec(36'h0_0000_0000, p[0], t[2:0], "all zeros");
        vec({NSIG{1'b1}}, p[0], t[2:0], "all ones");
      end

    // 2. PTSTN override: a pattern where the eight sources of TEST[0] differ,
    //    then walk TSEL with PTSTN=0. The select must stay at 0 throughout.
    //    sources of TEST[0] for sel 1..7: VACCN MI OVF UPN LCZN SC0 TVEC0.
    for (t = 0; t < 8; t = t + 1) begin
      vec((36'd1 << I_VACCN) | (36'd1 << I_MI) | (36'd1 << I_OVF) |
          (36'd1 << I_UPN) | (36'd1 << I_LCZN) | (36'd1 << I_SC0) |
          (36'd1 << I_TVEC0), 1'b0, t[2:0], "PTSTN override");
      // Every sel!=0 source of TEST[0] is 1 in that pattern, and the sel=0
      // source (PTSTN|PTREEOUT) is 0, so TEST[0]=0 proves the collapse.
      checks = checks + 1;
      if (TEST_4_0[0] !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL PTSTN override TSEL=%0d: TEST[0]=%b, select did not collapse",
                 t, TEST_4_0[0]);
      end
    end

    // 3. pseudo-random soak
    lfsr = 32'hFEEDBEEF;
    for (i = 0; i < 512; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      vec({lfsr[3:0], lfsr}, lfsr[7], lfsr[10:8], "lfsr");
      lfsr = lfsr_next(lfsr);
    end

    // vectors = 8*2*(36+2) + 8 + 512 = 608 + 8 + 512 = 1128 vec checks
    //         + 8 override checks = 1136
    if (errors == 0 && checks == 1136) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 1136 checks)", checks, errors);
    if (errors == 0 && checks == 1136) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
