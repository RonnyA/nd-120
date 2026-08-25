/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_INTR_CNTLR_VECGEN testbench (whole VECGEN, pages 83-89)           **
**                                                                       **
** Closes the CGA_INTR subtree: the submodules (PTY/PTYENC, ISMUX,       **
** OSMUX, CMP/MAGCMP, STAT/SBIT, VHR) each have their own tb; this one   **
** verifies the assembled vector generator against an independent        **
** behavioral model derived by reading every gate (all forms cross-      **
** checked gate-vs-behavior in scratchpad gen_tier1_golden.py,           **
** 0 mismatches):                                                        **
**                                                                       **
**   PTY   : HIVEC/LOVEC = highest-priority ACTIVE-LOW request in        **
**           MIREQ_N[15:8] / [7:0]; HIDET/LODET = any request active     **
**   ISMUX : HISIN = (~HIGSN&~OESN) ? HISTAT : FIDBO_2_0 (LO likewise    **
**           with LOGSN)                                                 **
**   CMP   : HIVGES = (HIVEC >= HISTAT), LOVGES = (LOVEC >= LOSTAT)      **
**   OSMUX : PICS = (hi_en ? HISTAT : 0) | (lo_en ? LOSTAT : 0),         **
**           hi_en = ~HIGSN&~OESN, lo_en = ~LOGSN&~OESN                  **
**   STAT  : per group, on MCLK (fence-ON default, Am2914):              **
**             G=1,F=0 -> hold        G=1,F=1 -> GPE ? SIN : 0 (LDSTAT)  **
**             G=0,F=1 -> VEC+1       G=0,F=0 -> 0 (MCLR)                **
**           F = HIF/LOF, GPE = ~FIDBO3 / ~FIDBO4                        **
**   VHR   : on MCLK, N=1 hold, N=0 load HIVEC/LOVEC into HX/LX          **
**                                                                       **
** Test plan: MCLR init; exhaustive 65536-value MIREQ sweep (all comb    **
** outputs); LDSTAT + comparator exhaustive (8 STAT x 8 VEC per group);  **
** OSMUX/ISMUX enable sweep; vector+1 fence incl. wrap + GPE blocking;   **
** VHR load/hold; 512 fixed-seed LFSR random steps checked before and    **
** after every clock. Every check compares the full 25-bit output        **
** vector.                                                               **
**                                                                       **
** Registered module (SCAN_FF_EN in VHR, D_FLIPFLOP_EN in SBIT, both     **
** switched by FPGA_FF_MODE): the Makefile target test-intr-vecgen runs  **
** this twice - default latch/CP mode and -DFPGA_FF_MODE. No latch       **
** primitives, so USE_TRANSPARENT_LATCHES is not relevant here. Built    **
** WITHOUT ND120_INTR_STATUS_FENCE_OFF (the RTL default = fence ON).     **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_VECGEN_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK = 0;
  reg         FIDBO3 = 0;
  reg         FIDBO4 = 0;
  reg  [2:0]  FIDBO_2_0 = 0;
  reg         G = 1;
  reg         HIF = 0;
  reg         HIGSN = 1;
  reg         LOF = 0;
  reg         LOGSN = 1;
  reg  [15:0] MIREQ_15_0_N = 16'hFFFF;
  reg         N = 1;
  reg         OESN = 1;

  wire        HIDET, HIVGES, LODET, LOVGES;
  wire [2:0]  HIVEC_2_0, HX_2_0, HX_2_0_N, LOVEC_2_0, LX_2_0, LX_2_0_N, PICS_2_0;

  integer errors = 0;
  integer checks = 0;
  integer i, s, v, c;
  reg [31:0] lfsr;

  // ---------------- reference model state ----------------
  reg [2:0] m_histat, m_lostat, m_hx, m_lx;

  CGA_INTR_CNTLR_VECGEN dut (
      .sysclk(sysclk),
      .MCLK_EN(MCLK_EN),
      .FIDBO3(FIDBO3),
      .FIDBO4(FIDBO4),
      .FIDBO_2_0(FIDBO_2_0),
      .G(G),
      .HIF(HIF),
      .HIGSN(HIGSN),
      .LOF(LOF),
      .LOGSN(LOGSN),
      .MCLK(MCLK),
      .MIREQ_15_0_N(MIREQ_15_0_N),
      .N(N),
      .OESN(OESN),
      .HIDET(HIDET),
      .HIVEC_2_0(HIVEC_2_0),
      .HIVGES(HIVGES),
      .HX_2_0(HX_2_0),
      .HX_2_0_N(HX_2_0_N),
      .LODET(LODET),
      .LOVEC_2_0(LOVEC_2_0),
      .LOVGES(LOVGES),
      .LX_2_0(LX_2_0),
      .LX_2_0_N(LX_2_0_N),
      .PICS_2_0(PICS_2_0)
  );

  always #5 sysclk = ~sysclk;

  // priority encoder over one active-low request byte: {DET, VEC[2:0]}
  function [3:0] pty(input [7:0] rn);
    integer k;
    begin
      pty = 4'b0000;
      for (k = 0; k < 8; k = k + 1)
        if (!rn[k]) pty = {1'b1, k[2:0]};
    end
  endfunction

  // combinational expecteds (functions of inputs + model state)
  wire [3:0] e_hip    = pty(MIREQ_15_0_N[15:8]);
  wire [3:0] e_lop    = pty(MIREQ_15_0_N[7:0]);
  wire       e_hidet  = e_hip[3];
  wire [2:0] e_hivec  = e_hip[2:0];
  wire       e_lodet  = e_lop[3];
  wire [2:0] e_lovec  = e_lop[2:0];
  wire       g_hi     = ~HIGSN & ~OESN;
  wire       g_lo     = ~LOGSN & ~OESN;
  wire [2:0] e_hisin  = g_hi ? m_histat : FIDBO_2_0;
  wire [2:0] e_losin  = g_lo ? m_lostat : FIDBO_2_0;
  wire       e_hivges = (e_hivec >= m_histat);
  wire       e_lovges = (e_lovec >= m_lostat);
  wire [2:0] e_pics   = (g_hi ? m_histat : 3'b000) | (g_lo ? m_lostat : 3'b000);

  wire [24:0] got = {HIDET, HIVEC_2_0, HIVGES, HX_2_0, HX_2_0_N,
                     LODET, LOVEC_2_0, LOVGES, LX_2_0, LX_2_0_N, PICS_2_0};
  wire [24:0] exp = {e_hidet, e_hivec, e_hivges, m_hx, ~m_hx,
                     e_lodet, e_lovec, e_lovges, m_lx, ~m_lx, e_pics};

  task check_all(input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %25b expected %25b", name, got, exp);
        $display("     (MIREQ_N=%04h G=%b HIF=%b LOF=%b N=%b GSN/OESN=%b%b%b FIDBO=%o/%b%b histat=%o lostat=%o hx=%o lx=%o)",
                 MIREQ_15_0_N, G, HIF, LOF, N, HIGSN, LOGSN, OESN,
                 FIDBO_2_0, FIDBO3, FIDBO4, m_histat, m_lostat, m_hx, m_lx);
      end
    end
  endtask

  // One MCLK event, valid in BOTH build modes (see CGA_MAC_DECODE_tb.v),
  // followed by the model's state update and a full output compare.
  task pulse_step(input [127:0] name);
    reg [2:0] n_histat, n_lostat, n_hx, n_lx;
    begin
      #1;  // let the expected-value wires settle after the caller's input edits
      // next state from PRE-edge inputs and model state
      n_histat = G ? (HIF ? (FIDBO3 ? 3'b000 : e_hisin) : m_histat)
                   : (HIF ? (e_hivec + 3'b001) : 3'b000);
      n_lostat = G ? (LOF ? (FIDBO4 ? 3'b000 : e_losin) : m_lostat)
                   : (LOF ? (e_lovec + 3'b001) : 3'b000);
      n_hx     = N ? m_hx : e_hivec;
      n_lx     = N ? m_lx : e_lovec;
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK     = 0;
      MCLK_EN  = 0;
      m_histat = n_histat;
      m_lostat = n_lostat;
      m_hx     = n_hx;
      m_lx     = n_lx;
      #2;
      check_all(name);
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_INTR_CNTLR_VECGEN_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_INTR_CNTLR_VECGEN_tb: latch/CP mode (posedge MCLK capture)");
`endif

    // ---- 1. MCLR: G=0, HIF=0, LOF=0 clears both STATs; N=0 defines VHR
    G = 0; HIF = 0; LOF = 0; N = 0; MIREQ_15_0_N = 16'hFFFF;
    m_histat = 0; m_lostat = 0; m_hx = 0; m_lx = 0;   // expected post-clear
    pulse_step("mclr 1");
    pulse_step("mclr 2");

    // ---- 2. exhaustive PTY sweep (state held: G=1, no strobes, no clock)
    G = 1; HIF = 0; LOF = 0; N = 1;
    for (i = 0; i < 65536; i = i + 1) begin
      MIREQ_15_0_N = i[15:0];
      #1;
      check_all("pty sweep");
    end
    MIREQ_15_0_N = 16'hFFFF;

    // ---- 3. LDSTAT + comparator exhaustive: 8 status x 8 vector, both groups
    for (s = 0; s < 8; s = s + 1) begin
      G = 1; HIF = 1; LOF = 1; FIDBO3 = 0; FIDBO4 = 0;
      HIGSN = 1; LOGSN = 1; OESN = 1;      // ISMUX selects the FIDBO S-bus
      FIDBO_2_0 = s[2:0];
      pulse_step("ldstat");
      HIF = 0; LOF = 0;                    // hold
      for (v = 0; v < 8; v = v + 1) begin
        MIREQ_15_0_N = ~((16'h0001 << (8 + v)) | (16'h0001 << v));
        #1;
        check_all("cmp");
      end
      MIREQ_15_0_N = 16'hFFFF;
    end

    // ---- 4. OSMUX / ISMUX enable sweep with distinct group statuses
    G = 1; HIF = 1; LOF = 0; FIDBO_2_0 = 3'o5; OESN = 1;
    pulse_step("load histat=5");
    HIF = 0; LOF = 1; FIDBO_2_0 = 3'o3;
    pulse_step("load lostat=3");
    HIF = 0; LOF = 0;
    for (c = 0; c < 8; c = c + 1) begin
      {HIGSN, LOGSN, OESN} = c[2:0];
      #1;
      check_all("enable sweep");
    end
    HIGSN = 1; LOGSN = 1; OESN = 1;

    // ---- 5. vector+1 fence (READ VECTOR) + wrap + GPE blocking
    // histat=5, lostat=3 here. G=0,HIF=1 loads HIVEC+1 into HISTAT;
    // LOF=0 with G=0 is the MCLR case for LO -> clears LOSTAT.
    MIREQ_15_0_N = ~(16'h0001 << 14);      // HIVEC=6
    G = 0; HIF = 1; LOF = 0;
    pulse_step("fence hi 6->7");
    MIREQ_15_0_N = ~(16'h0001 << 15);      // HIVEC=7
    pulse_step("fence hi wrap 7->0");
    MIREQ_15_0_N = ~(16'h0001 << 3);       // LOVEC=3
    HIF = 0; LOF = 1;
    pulse_step("fence lo 3->4");
    // GPE blocking: LDSTAT with FIDBO3=1 loads 0, not the S-bus
    MIREQ_15_0_N = 16'hFFFF;
    G = 1; HIF = 1; LOF = 0; FIDBO3 = 1; FIDBO_2_0 = 3'o6;
    pulse_step("gpe block hi");
    FIDBO3 = 0; HIF = 0;

    // ---- 6. VHR load / hold
    MIREQ_15_0_N = ~((16'h0001 << 13) | (16'h0001 << 2));  // HIVEC=5, LOVEC=2
    N = 0;
    pulse_step("vhr load");
    N = 1; MIREQ_15_0_N = 16'hFFFF;
    pulse_step("vhr hold");

    // ---- 7. fixed-seed LFSR random steps, checked before and after clock
    lfsr = 32'h1D8BC0DE;
    for (i = 0; i < 512; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      MIREQ_15_0_N = lfsr[15:0];
      lfsr = lfsr_next(lfsr);
      {FIDBO3, FIDBO4, FIDBO_2_0, G, HIF, LOF, N, HIGSN, LOGSN, OESN} = lfsr[11:0];
      #1;
      check_all("lfsr comb");
      pulse_step("lfsr clock");
    end

    // Verdict. Expected: 2 + 65536 + 8*(1+8) + (2+8) + 4 + 2 + 512*2 = 66650.
    if (errors == 0 && checks == 66650)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 66650 checks)", errors, checks);
    $finish;
  end

endmodule
