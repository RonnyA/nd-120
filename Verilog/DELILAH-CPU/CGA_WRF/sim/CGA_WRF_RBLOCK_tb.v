/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA_WRF_RBLOCK testbench (PARENT level)                               **
** DUT: DELILAH-CPU/CGA_WRF/circuit/CGA_WRF_RBLOCK.v (PDF page 60)       **
**                                                                       **
** The submodules (SEL16 / LR16 / DR16) have their own tbs; this tb      **
** verifies the register-file ADDRESSING and SELECTION wiring between    **
** them, with an independent behavioral golden model re-derived from     **
** the schematic intent (never the DUT's own wiring):                    **
**                                                                       **
**   16 registers reg[0..15] (0=Z 1=D 2=P 3=B 4=L 5=A 6=T 7=X 8=STS     **
**   9..15=R1..R7). On the ALUCLK rise: reg[k] <= RB when WR_15_0[k].    **
**   Register 2 (P, PREG) extra source: when WR[2]=0 and XFETCHN=0,      **
**   P <= NLCA (MUX31LP sel={WR2,XFETCH}: 00->hold, 01->NLCA,            **
**   1x->RB, so WR2 wins over XFETCH).                                   **
**   Read ports (SEL16 = A02 AOI + NAND, BubblesMask 0):                 **
**     A[n] = OR over k of (EA[k] & reg[k][n])  (wired-OR, EA=0 -> 0)    **
**     B[n] = OR over k of (EB[k] & reg[k][n])                           **
**   Direct outputs:                                                     **
**     PR = transparent latch of the PREG input mux while ALUCLK=0       **
**          (WR2 ? RB : XFETCH ? NLCA : P), held while ALUCLK=1.         **
**     BR = LR16 latch of reg 3 path, gate = ~ALUCLK & WR[3]:            **
**          follows RB while open, holds otherwise (IR = WR?RB:R).       **
**     XR = same from reg 7, gate = ~ALUCLK & WR[7].                     **
**                                                                       **
** Coverage layers:                                                      **
**   A. defining load: every register written with a distinct constant   **
**   B. full read-back sweep on both ports (any EA/EB/WR decode swap     **
**      or SEL_n input-pin swap between registers is caught)             **
**   C. write-strobe gating: WR=0 clock edge changes nothing;            **
**      XFETCH edge loads ONLY register 2 with NLCA                      **
**   D. WR2-over-XFETCH priority (phantom D3 = D2 in MUX31LP)            **
**   E. read-select corners: EA=EB=0 -> 0, multi-enable wired-OR,        **
**      all-enable OR of the whole file                                  **
**   F. crossbar exhaustive: walking-1 AND walking-0 written to every    **
**      register and read back on both ports (16x16x2 = all 256          **
**      register-bit crossings, both polarities)                         **
**   G. latch-close semantics on PR/BR/XR: transparent before the        **
**      edge, held while ALUCLK=1 with RB changing, reopened after,      **
**      closed by WR while ALUCLK=0 (registers keep the edge value)      **
**   H. hold with no clock event                                         **
**   I. 4200-step fixed-seed LFSR soak: random EA/EB/WR (multi-bit       **
**      writes included)/RB/NLCA/XFETCHN, model compared before and      **
**      after every edge on all five output buses                        **
**                                                                       **
** Build modes: DR16/R81_EN registers switch on FPGA_FF_MODE             **
** (sysclk+ALUCLK_EN capture), the L8 latches (PR/BR/XR) switch on       **
** USE_TRANSPARENT_LATCHES - the Makefile target test-wrf-rblock runs    **
** this THREE times: default, -DFPGA_FF_MODE, -DUSE_TRANSPARENT_LATCHES. **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with a   **
** hard expected-check-count assertion (47349 checks).                   **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_WRF_RBLOCK_tb;

  reg         sysclk = 0;
  reg         sys_rst_n = 1;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg  [15:0] EA_15_0 = 0;
  reg  [15:0] EB_15_0 = 0;
  reg  [15:0] RB_15_0 = 0;
  reg  [15:0] WR_15_0 = 0;
  reg  [15:0] NLCA_15_0 = 0;
  reg         XFETCHN = 1;

  wire [15:0] A_15_0;
  wire [15:0] B_15_0;
  wire [15:0] PR_15_0;
  wire [15:0] BR_15_0;
  wire [15:0] XR_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i, k, b;

  // ---- independent golden model --------------------------------------
  reg [15:0] m_reg[0:15];  // the register file
  reg [15:0] m_br;         // BR latch (reg 3 write path)
  reg [15:0] m_xr;         // XR latch (reg 7 write path)
  reg [31:0] lfsr;

  // read-port wired-OR
  function [15:0] rdmux(input [15:0] en);
    integer j;
    begin
      rdmux = 16'h0000;
      for (j = 0; j < 16; j = j + 1)
        if (en[j]) rdmux = rdmux | m_reg[j];
    end
  endfunction

  // PREG input mux (PR is transparent to this while ALUCLK=0)
  function [15:0] preg_mux;
    begin
      preg_mux = WR_15_0[2] ? RB_15_0 : (~XFETCHN ? NLCA_15_0 : m_reg[2]);
    end
  endfunction

  CGA_WRF_RBLOCK dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .ALUCLK_EN(ALUCLK_EN),
      .ALUCLK(ALUCLK),
      .EA_15_0(EA_15_0),
      .EB_15_0(EB_15_0),
      .RB_15_0(RB_15_0),
      .WR_15_0(WR_15_0),
      .NLCA_15_0(NLCA_15_0),
      .XFETCHN(XFETCHN),
      .A_15_0(A_15_0),
      .B_15_0(B_15_0),
      .PR_15_0(PR_15_0),
      .BR_15_0(BR_15_0),
      .XR_15_0(XR_15_0)
  );

  always #5 sysclk = ~sysclk;

  // One ALUCLK event, valid in ALL build modes: the EN-mode registers
  // capture at posedge sysclk while ALUCLK_EN=1; the CP-mode registers
  // capture at the posedge of ALUCLK raised just after the same sysclk
  // edge (inputs stable). The L8 gates close when ALUCLK rises; the
  // same sysclk edge refreshed the FPGA-form latch hold value.
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

  // model update at the ALUCLK rise
  task model_edge;
    integer j;
    begin
      for (j = 0; j < 16; j = j + 1) begin
        if (j == 2) begin
          if (WR_15_0[2])     m_reg[2] = RB_15_0;
          else if (~XFETCHN)  m_reg[2] = NLCA_15_0;
        end else if (WR_15_0[j]) m_reg[j] = RB_15_0;
      end
    end
  endtask

  // model update for the open BR/XR latch gates (call with ALUCLK=0)
  task model_latches;
    begin
      if (WR_15_0[3]) m_br = RB_15_0;
      if (WR_15_0[7]) m_xr = RB_15_0;
    end
  endtask

  task check_bus(input [15:0] got, input [15:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h expected %04h (WR=%04h EA=%04h EB=%04h RB=%04h ALUCLK=%b)",
                 name, got, exp, WR_15_0, EA_15_0, EB_15_0, RB_15_0, ALUCLK);
      end
    end
  endtask

  // check all five output buses (ALUCLK=0 assumed: PR transparent)
  task check5(input [127:0] name);
    begin
      check_bus(A_15_0, rdmux(EA_15_0), name);
      check_bus(B_15_0, rdmux(EB_15_0), name);
      check_bus(PR_15_0, preg_mux(), name);
      check_bus(BR_15_0, m_br, name);
      check_bus(XR_15_0, m_xr, name);
    end
  endtask

  // full step: apply inputs, pre-check, one ALUCLK edge, post-check.
  // 10 checks per call.
  task step(input [15:0] v_ea, input [15:0] v_eb, input [15:0] v_wr,
            input [15:0] v_rb, input [15:0] v_nlca, input v_xfn,
            input [127:0] name);
    begin
      EA_15_0   = v_ea;
      EB_15_0   = v_eb;
      WR_15_0   = v_wr;
      RB_15_0   = v_rb;
      NLCA_15_0 = v_nlca;
      XFETCHN   = v_xfn;
      #2;
      model_latches;
      check5(name);
      pulse_aluclk;
      model_edge;
      #2;                // ALUCLK back low: gates reopen, same RB/WR
      model_latches;
      check5(name);
    end
  endtask

  // defining load, no checks (power-up register content is undefined)
  task load_reg(input [3:0] v_k, input [15:0] v_val);
    begin
      EA_15_0 = 0; EB_15_0 = 0;
      WR_15_0 = 16'h0001 << v_k;
      RB_15_0 = v_val;
      XFETCHN = 1;
      #2;
      model_latches;
      pulse_aluclk;
      model_edge;
      #2;
      model_latches;
    end
  endtask

  // read-back sweep over the whole file, A and B ports (32 checks)
  task sweep_all(input [127:0] name);
    begin
      WR_15_0 = 0;
      for (k = 0; k < 16; k = k + 1) begin
        EA_15_0 = 16'h0001 << k;
        EB_15_0 = 16'h0001 << (15 - k);
        #2;
        check_bus(A_15_0, m_reg[k], name);
        check_bus(B_15_0, m_reg[15-k], name);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  reg [15:0] r_ea, r_eb, r_wr, r_rb, r_nlca;
  reg        r_xfn;

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_WRF_RBLOCK_tb: USE_TRANSPARENT_LATCHES mode");
`elsif FPGA_FF_MODE
    $display("CGA_WRF_RBLOCK_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_WRF_RBLOCK_tb: default mode (posedge ALUCLK / sync latch)");
`endif

    // A. defining load: distinct constant per register (k * 0x1111)
    for (i = 0; i < 16; i = i + 1) load_reg(i[3:0], i[15:0] * 16'h1111);

    // B. full read-back on both ports + direct outputs (5 x 16 = 80)
    WR_15_0 = 0; XFETCHN = 1;
    for (k = 0; k < 16; k = k + 1) begin
      EA_15_0 = 16'h0001 << k;
      EB_15_0 = 16'h0001 << (15 - k);
      #2;
      check5("readback");
    end

    // C. write-strobe gating: WR=0 edge must change nothing (10 + 32)
    step(16'h0008, 16'h0080, 16'h0000, 16'hFFFF, 16'h0000, 1, "strobe gate");
    sweep_all("strobe gate sweep");

    // C2. XFETCH loads ONLY register 2 with NLCA (10 + 32)
    step(16'h0004, 16'h0004, 16'h0000, 16'h0F0F, 16'hA5C3, 0, "xfetch load");
    sweep_all("xfetch sweep");

    // D. WR2 wins over XFETCH (MUX31LP D3 phantom = D2): PR shows RB
    //    before the edge, register 2 captures RB (10)
    step(16'h0004, 16'h0004, 16'h0004, 16'h3C5A, 16'h1111, 0, "wr2 priority");

    // E. read-select corners (6)
    WR_15_0 = 0; XFETCHN = 1;
    EA_15_0 = 16'h0000; EB_15_0 = 16'h0000; #2;
    check_bus(A_15_0, 16'h0000, "EA=0");
    check_bus(B_15_0, 16'h0000, "EB=0");
    EA_15_0 = 16'h0011; EB_15_0 = 16'h8100; #2;
    check_bus(A_15_0, m_reg[0] | m_reg[4], "EA multi");
    check_bus(B_15_0, m_reg[8] | m_reg[15], "EB multi");
    EA_15_0 = 16'hFFFF; EB_15_0 = 16'hFFFF; #2;
    check_bus(A_15_0, rdmux(16'hFFFF), "EA all");
    check_bus(B_15_0, rdmux(16'hFFFF), "EB all");

    // F. crossbar exhaustive: walking-1 then walking-0 into every
    //    register, read back on both ports (512 steps x 10 = 5120)
    for (k = 0; k < 16; k = k + 1)
      for (b = 0; b < 16; b = b + 1) begin
        step(16'h0001 << k, 16'h0001 << k, 16'h0001 << k,
             16'h0001 << b, 16'h0000, 1, "walk1");
        step(16'h0001 << k, 16'h0001 << k, 16'h0001 << k,
             ~(16'h0001 << b), 16'h0000, 1, "walk0");
      end

    // G. latch-close semantics on PR/BR/XR (14)
    EA_15_0 = 16'h0008; EB_15_0 = 16'h0080;      // read regs 3 and 7
    WR_15_0 = 16'h008C;                          // write regs 2, 3, 7
    RB_15_0 = 16'h55AA; NLCA_15_0 = 16'h0000; XFETCHN = 1;
    #2;
    model_latches;
    check_bus(PR_15_0, 16'h55AA, "G pre PR");    // transparent to RB
    check_bus(BR_15_0, 16'h55AA, "G pre BR");
    check_bus(XR_15_0, 16'h55AA, "G pre XR");
    @(negedge sysclk);
    ALUCLK_EN = 1;
    @(posedge sysclk);
    #1 ALUCLK = 1;
    ALUCLK_EN = 0;
    model_edge;                                  // regs 2,3,7 <= 55AA
    #1 RB_15_0 = 16'h1234;                       // change RB, gates closed
    #2;
    check_bus(PR_15_0, 16'h55AA, "G closed PR");
    check_bus(BR_15_0, 16'h55AA, "G closed BR");
    check_bus(XR_15_0, 16'h55AA, "G closed XR");
    @(negedge sysclk);
    ALUCLK = 0;                                  // gates reopen (WR still up)
    #2;
    model_latches;                               // m_br = m_xr = 1234
    check_bus(PR_15_0, 16'h1234, "G reopen PR"); // WR2=1 -> RB
    check_bus(BR_15_0, 16'h1234, "G reopen BR");
    check_bus(XR_15_0, 16'h1234, "G reopen XR");
    check_bus(A_15_0, 16'h55AA, "G reg3 kept");  // registers keep edge value
    check_bus(B_15_0, 16'h55AA, "G reg7 kept");
    // The FPGA-form L8 refreshes its hold value only at posedge sysclk
    // while the gate is open: keep the gate open across one sysclk edge
    // before closing it, so all three latch forms hold the same value.
    @(posedge sysclk);
    #1;
    WR_15_0 = 16'h0000; RB_15_0 = 16'hFFFF;      // close gates by WR, no edge
    #2;
    check_bus(BR_15_0, 16'h1234, "G wr-closed BR");
    check_bus(XR_15_0, 16'h1234, "G wr-closed XR");
    check_bus(PR_15_0, m_reg[2], "G hold PR");   // back to P (55AA)

    // H. hold with no clock event (32 + 3 = 35)
    WR_15_0 = 16'h0000; RB_15_0 = 16'hBEEF; NLCA_15_0 = 16'h7777; XFETCHN = 1;
    #40;
    sweep_all("no-clock hold");
    check_bus(PR_15_0, m_reg[2], "no-clock PR");
    check_bus(BR_15_0, m_br, "no-clock BR");
    check_bus(XR_15_0, m_xr, "no-clock XR");

    // I. 4200-step fixed-seed LFSR soak (4200 x 10 = 42000)
    lfsr = 32'hC0FFEE01;
    for (i = 0; i < 4200; i = i + 1) begin
      lfsr = lfsr_next(lfsr); r_ea   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); r_eb   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); r_wr   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); r_rb   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); r_nlca = lfsr[15:0];
      r_xfn = lfsr[16];
      step(r_ea, r_eb, r_wr, r_rb, r_nlca, r_xfn, "lfsr soak");
    end

    // Verdict. 80+42+42+10+6+5120+14+35+42000 = 47349 checks.
    if (errors == 0 && checks == 47349)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 47349 checks)", errors, checks);
    $finish;
  end

endmodule
