/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_CPU_ALU_RALU testbench                                            **
**                                                                       **
** Verification of the RALU datapath slice (drawing page 46): two        **
** MUX216L input inverters, the LOGOP bit-function generator (page 48),  **
** a 16-bit Adder, the AF/LF result mux, and the CRY / ZF / SGR / OVF    **
** condition gates.                                                      **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (CGA_CPU_ALU_RALU.v plus its three sub-circuits                       **
** CGA_ALU_RALU_MUX216L.v, CGA_ALU_RALU_LOGOP.v, and Shared Adder).      **
** No ND documentation and no drawing was used. The port comments in     **
** the RTL name the intended operations, but the polarity of every mux   **
** was taken from the gates, because MUX216L inverts its output          **
** (MUX21LP drives ZN) and MUX41P selects on {B,A} with A as the LSB.    **
**                                                                       **
** Transcribed model:                                                    **
**   A  = RSN  ? RN_15_0 : ~RN_15_0        (RN_R_MUX, note the ZN)       **
**   B  = ALUI4 ? ~S_15_0 : S_15_0         (SN_S_MUX)                    **
**   LF[n] = (A[n]^S[n]) ? ALUI4                                         **
**                       : (A[n] & S[n]) ? FSEL : 1'b0                   **
**        (LOGOP MUX41P: D0=0, D1=D2=ALU14, D3=FSEL, sel={S[n],A[n]})    **
**        NOTE it is the RAW S_15_0 that reaches LOGOP, not B.           **
**   {co,AF} = A + B + CI                                                **
**   F  = LOG ? LF : AF                    (AF_LF_MUX, double inversion) **
**   CRY = ~LOG & co                                                     **
**   ZF  = (F == 0)                        (NAND tree over ~F)           **
**   SGR = (~A15&~F15) | (~A15&~B15) | (~B15&~F15)                       **
**   OVF = ( A15& B15&~F15) | (~A15&~B15& F15)                           **
** SGR and OVF are CHARACTERISED, not specified: the gate network was    **
** transcribed as-is; nothing here decides whether those two flags are   **
** the ones the CPU actually wants.                                      **
**                                                                       **
** Test plan (all 32 control combinations {ALUI4,CI,FSEL,LOG,RSN} for    **
** every data pattern):                                                  **
**   1. walking-one on RN_15_0 with S_15_0 = 0000  (per-bit RN wiring)   **
**   2. walking-one on S_15_0  with RN_15_0 = FFFF (per-bit S wiring)    **
**   3. walking-zero on both buses (stuck-at-1 per bit)                  **
**   4. carry-chain corners: 0000/FFFF/8000/7FFF/0001 pairs incl. the    **
**      combinations that make the adder overflow into bit 16            **
**   5. 2048 fixed-seed LFSR data pairs, control field also randomised   **
** F_15_0, CRY, ZF, SGR and OVF are each checked on every vector.        **
**                                                                       **
** Purely combinational - no flip-flop and no `ifdef FPGA_FF_MODE in     **
** this module or its sub-circuits. The Makefile target                  **
** test-cpu-alu-ralu nevertheless builds it both ways and both must      **
** print PASS, which proves the mode define does not reach here.         **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_ALU/sim && make test-cpu-alu-ralu        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_CPU_ALU_RALU_tb;

  reg         ALUI4 = 0;
  reg         CI = 0;
  reg         FSEL = 0;
  reg         LOG = 0;
  reg         RSN = 0;
  reg  [15:0] RN_15_0 = 0;
  reg  [15:0] S_15_0 = 0;

  wire        CRY;
  wire [15:0] F_15_0;
  wire        OVF;
  wire        SGR;
  wire        ZF;

  integer errors = 0;
  integer checks = 0;
  integer i, c;
  reg [31:0] lfsr;

  CGA_CPU_ALU_RALU dut (
      .sysclk   (1'b0),
      .sys_rst_n(1'b1),
      .ALUI4    (ALUI4),
      .CI       (CI),
      .FSEL     (FSEL),
      .LOG      (LOG),
      .RSN      (RSN),
      .RN_15_0  (RN_15_0),
      .S_15_0   (S_15_0),
      .CRY      (CRY),
      .F_15_0   (F_15_0),
      .OVF      (OVF),
      .SGR      (SGR),
      .ZF       (ZF)
  );

  initial begin
    $dumpfile("CGA_CPU_ALU_RALU_tb.vcd");
    $dumpvars(0, CGA_CPU_ALU_RALU_tb);
  end

  // ---------------- independent model ----------------
  reg [15:0] m_a, m_b, m_lf, m_af, m_f;
  reg        m_co, m_cry, m_zf, m_sgr, m_ovf;
  integer    bb;

  task model;
    reg [16:0] sum;
    begin
      m_a = RSN ? RN_15_0 : ~RN_15_0;
      m_b = ALUI4 ? ~S_15_0 : S_15_0;
      for (bb = 0; bb < 16; bb = bb + 1)
        m_lf[bb] = (m_a[bb] ^ S_15_0[bb]) ? ALUI4 :
                   ((m_a[bb] & S_15_0[bb]) ? FSEL : 1'b0);
      sum   = {1'b0, m_a} + {1'b0, m_b} + {16'b0, CI};
      m_af  = sum[15:0];
      m_co  = sum[16];
      m_f   = LOG ? m_lf : m_af;
      m_cry = (~LOG) & m_co;
      m_zf  = (m_f == 16'h0000);
      m_sgr = ((~m_a[15]) & (~m_f[15])) | ((~m_a[15]) & (~m_b[15])) |
              ((~m_b[15]) & (~m_f[15]));
      m_ovf = (m_a[15] & m_b[15] & (~m_f[15])) |
              ((~m_a[15]) & (~m_b[15]) & m_f[15]);
    end
  endtask

  task vec(input [4:0] ctl, input [15:0] rn, input [15:0] s, input [255:0] name);
    begin
      {ALUI4, CI, FSEL, LOG, RSN} = ctl;
      RN_15_0 = rn;
      S_15_0  = s;
      #2;
      model;
      checks = checks + 1;
      if (F_15_0 !== m_f) begin
        errors = errors + 1;
        $display("FAIL %0s F: got %04h exp %04h (ctl=%b RN=%04h S=%04h)",
                 name, F_15_0, m_f, ctl, rn, s);
      end
      checks = checks + 1;
      if (CRY !== m_cry) begin
        errors = errors + 1;
        $display("FAIL %0s CRY: got %b exp %b (ctl=%b RN=%04h S=%04h)",
                 name, CRY, m_cry, ctl, rn, s);
      end
      checks = checks + 1;
      if (ZF !== m_zf) begin
        errors = errors + 1;
        $display("FAIL %0s ZF: got %b exp %b F=%04h (ctl=%b)", name, ZF, m_zf, F_15_0, ctl);
      end
      checks = checks + 1;
      if (SGR !== m_sgr) begin
        errors = errors + 1;
        $display("FAIL %0s SGR: got %b exp %b (ctl=%b RN=%04h S=%04h A15=%b B15=%b F15=%b)",
                 name, SGR, m_sgr, ctl, rn, s, m_a[15], m_b[15], m_f[15]);
      end
      checks = checks + 1;
      if (OVF !== m_ovf) begin
        errors = errors + 1;
        $display("FAIL %0s OVF: got %b exp %b (ctl=%b RN=%04h S=%04h A15=%b B15=%b F15=%b)",
                 name, OVF, m_ovf, ctl, rn, s, m_a[15], m_b[15], m_f[15]);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_CPU_ALU_RALU_tb: built with FPGA_FF_MODE (must not matter here)");
`else
    $display("CGA_CPU_ALU_RALU_tb: default build mode");
`endif

    for (c = 0; c < 32; c = c + 1) begin
      // 1. walking one on RN
      for (i = 0; i < 16; i = i + 1) vec(c[4:0], 16'h0001 << i, 16'h0000, "walk1 RN");
      // 2. walking one on S
      for (i = 0; i < 16; i = i + 1) vec(c[4:0], 16'hFFFF, 16'h0001 << i, "walk1 S");
      // 3. walking zero on both
      for (i = 0; i < 16; i = i + 1) vec(c[4:0], ~(16'h0001 << i), 16'hFFFF, "walk0 RN");
      for (i = 0; i < 16; i = i + 1) vec(c[4:0], 16'h0000, ~(16'h0001 << i), "walk0 S");
      // 4. carry / sign corners
      vec(c[4:0], 16'h0000, 16'h0000, "corner 0,0");
      vec(c[4:0], 16'hFFFF, 16'hFFFF, "corner F,F");
      vec(c[4:0], 16'h0000, 16'hFFFF, "corner 0,F");
      vec(c[4:0], 16'hFFFF, 16'h0000, "corner F,0");
      vec(c[4:0], 16'h8000, 16'h8000, "corner 8,8");
      vec(c[4:0], 16'h7FFF, 16'h0001, "corner 7FFF,1");
      vec(c[4:0], 16'h0001, 16'h7FFF, "corner 1,7FFF");
      vec(c[4:0], 16'h8000, 16'h7FFF, "corner 8000,7FFF");
    end

    // 5. pseudo-random soak, control field random too
    lfsr = 32'h5A5AC3C3;
    for (i = 0; i < 2048; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      vec(lfsr[4:0], lfsr[20:5], {lfsr[9:0], lfsr[31:26]}, "lfsr");
    end

    // vectors = 32*(16*4+8) + 2048 = 32*72 + 2048 = 4352 ; 5 checks each
    if (errors == 0 && checks == 21760) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 21760 checks)", checks, errors);
    if (errors == 0 && checks == 21760) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
