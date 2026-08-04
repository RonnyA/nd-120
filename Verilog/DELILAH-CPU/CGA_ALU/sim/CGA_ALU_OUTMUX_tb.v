/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_ALU_OUTMUX testbench (parent netlist, page 55)                    **
**                                                                       **
** Verifies the selector WIRING between the submodules (16x SEL8/SEL7    **
** D-mux slices, 16x MUX31LP G-mux, and the IDBS enable decoder) against **
** an INDEPENDENT golden model re-derived gate-by-gate from the netlist  **
** and the schematic intent:                                             **
**                                                                       **
**  IDBS enable decode, REGISTERED on the ALUCLK event (rcs = the        **
**  CSIDBS_4_0 value captured at the last ALUCLK):                       **
**    rcs= 0: EA/EF   (G-mux takes A or F, split by the UNREGISTERED     **
**                     ALUD2N: EA = ~ALUD2N, EF = ALUD2N)                **
**    rcs= 1: EBMG    -> D = EA_15_0 (effective address bus)             **
**    rcs= 2: EGPRH+EGPRL -> D = GPR_15_0 (full word)                    **
**    rcs= 3: EDBR    -> D = DBR_15_0                                    **
**    rcs= 4: EARG    -> D = ARG_15_0                                    **
**    rcs= 6: ESTS    -> D = STS_15_0                                    **
**    rcs= 8: EBARG+EABARG -> D = {12'b0, AARG0, LBA_2_0}                **
**    rcs= 9: ESWAP   -> D = SW_15_0                                     **
**    rcs=12: EAARG+EABARG -> D = {9'b0, LAA_3_1, AARG0, 3'b0}           **
**    rcs=18: EGPRL+EGPRS  -> D = {8x GPR[7], GPR[7:0]} (sign-extend)    **
**    any other rcs (incl. 0): EFIDB -> D = FIDBI_15_0                   **
**  Slice wiring facts checked: slot 6 is EGPRL for bits 0..7 (bit 7     **
**  goes through the 7-slot SEL7, which has no slot 7) and EGPRH for     **
**  bits 8..15; slot 7 carries LBA on bits 0..2, AARG0 (via EABARG) on   **
**  bit 3, LAA_3_1 (via EAARG) on bits 4..6 and GPR[7] (via EGPRS) on    **
**  bits 8..15. Enables OR-merge inside a slice (SEL8 = AND-OR).         **
**                                                                       **
**  G-mux (MUX31LP, ZN output): G_15_0 is INVERTED -                     **
**    G[n] = ~( EA ? A[n] : EF ? F[n] : D[n] ).                          **
**  PINNED as netlist behavior: the G bus is active-low (MUX31LP.ZN =    **
**  ~mux), and with rcs==0 the D bus still shows FIDBI (EFIDB decode     **
**  does not exclude code 0) while G shows ~A / ~F.                      **
**                                                                       **
** Layers:                                                               **
**  1. Exhaustive select sweep: all 32 rcs x 2 ALUD2N x 4 directed data  **
**     tuples with DISTINCT per-source constants (any wrong routing      **
**     lands on a different word).                                       **
**  2. Walking-1/walking-0 per 16-bit data bus under its selecting rcs   **
**     (EA@1, DBR@3, ARG@4, STS@6, SW@9, FIDBI@5, GPR@2, GPR@18, A@0/    **
**     ALUD2N=0, F@0/ALUD2N=1) + exhaustive {LBA,AARG0} under rcs=8 and  **
**     {LAA,AARG0} under rcs=12.                                         **
**  3. Registered-vs-comb seam: change CSIDBS and data WITHOUT a new     **
**     ALUCLK - enables must hold (old rcs) while D follows the new      **
**     data; flip ALUD2N without a clock under rcs=0 - G must switch     **
**     ~A <-> ~F combinationally.                                        **
**  4. 25000-step fixed-seed LFSR random soak: random rcs+data, pulse,   **
**     check D+G; then mutate data+ALUD2N without a pulse and re-check.  **
**                                                                       **
** NOT pure combinational: the IDBS decoder holds two R81_EN registers   **
** clocked by ALUCLK (latch/CP mode) or sysclk+ALUCLK_EN (FPGA_FF_MODE). **
** Compile once plain and once with -DFPGA_FF_MODE - the Makefile        **
** target runs both.                                                     **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with a   **
** hard expected-check-count assertion.                                  **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_ALU_OUTMUX_tb;

  localparam integer EXPECTED_CHECKS = 101236;

  reg         sysclk = 0;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg         AARG0 = 0;
  reg         ALUD2N = 0;
  reg  [15:0] ARG_15_0 = 0;
  reg  [15:0] A_15_0 = 0;
  reg  [ 4:0] CSIDBS_4_0 = 0;
  reg  [15:0] DBR_15_0 = 0;
  reg  [15:0] EA_15_0 = 0;
  reg  [15:0] FIDBI_15_0 = 0;
  reg  [15:0] F_15_0 = 0;
  reg  [15:0] GPR_15_0 = 0;
  reg  [ 2:0] LAA_3_1 = 0;
  reg  [ 2:0] LBA_2_0 = 0;
  reg  [15:0] STS_15_0 = 0;
  reg  [15:0] SW_15_0 = 0;

  wire [15:0] D_15_0;
  wire [15:0] G_15_0;

  // Golden-model state: the CSIDBS value captured at the last ALUCLK.
  reg  [ 4:0] golden_rcs = 0;

  integer errors = 0;
  integer checks = 0;
  integer i, b, pol, pat, cfg;
  reg [31:0] lfsr;

  CGA_ALU_OUTMUX dut (
      .sysclk    (sysclk),
      .sys_rst_n (1'b1),
      .AARG0     (AARG0),
      .ALUCLK_EN (ALUCLK_EN),
      .ALUCLK    (ALUCLK),
      .ALUD2N    (ALUD2N),
      .ARG_15_0  (ARG_15_0),
      .A_15_0    (A_15_0),
      .CSIDBS_4_0(CSIDBS_4_0),
      .DBR_15_0  (DBR_15_0),
      .EA_15_0   (EA_15_0),
      .FIDBI_15_0(FIDBI_15_0),
      .F_15_0    (F_15_0),
      .GPR_15_0  (GPR_15_0),
      .LAA_3_1   (LAA_3_1),
      .LBA_2_0   (LBA_2_0),
      .STS_15_0  (STS_15_0),
      .SW_15_0   (SW_15_0),
      .D_15_0    (D_15_0),
      .G_15_0    (G_15_0)
  );

  always #5 sysclk = ~sysclk;

  // 32-bit fixed-seed LFSR (x^32 + x^22 + x^2 + x + 1), reproducible
  // across simulators.
  function [31:0] lfsr_next(input [31:0] s);
    begin
      lfsr_next = {s[30:0], s[31] ^ s[21] ^ s[1] ^ s[0]};
    end
  endfunction

  // One ALUCLK event, valid in BOTH build modes: the EN-mode register
  // captures at posedge sysclk while ALUCLK_EN=1; the CP-mode register
  // captures at the posedge of ALUCLK raised just after the same sysclk
  // edge (inputs stable). Also updates the golden registered select.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      golden_rcs = CSIDBS_4_0;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
    end
  endtask

  // Independent golden model: expected D and G from the registered
  // select (golden_rcs) and the CURRENT data inputs / ALUD2N.
  task compute_expected(output [15:0] exp_d, output [15:0] exp_g);
    reg e_bmg, e_gprh, e_dbr, e_arg, e_sts, e_barg, e_swap;
    reg e_aarg, e_abarg, e_gprl, e_gprs, e_fidb, q0, e_a, e_f;
    integer n;
    reg slot6, slot7;
    begin
      e_bmg   = (golden_rcs == 5'd1);
      e_gprh  = (golden_rcs == 5'd2);
      e_dbr   = (golden_rcs == 5'd3);
      e_arg   = (golden_rcs == 5'd4);
      e_sts   = (golden_rcs == 5'd6);
      e_barg  = (golden_rcs == 5'd8);
      e_swap  = (golden_rcs == 5'd9);
      e_aarg  = (golden_rcs == 5'd12);
      e_abarg = (golden_rcs == 5'd8) || (golden_rcs == 5'd12);
      e_gprl  = (golden_rcs == 5'd2) || (golden_rcs == 5'd18);
      e_gprs  = (golden_rcs == 5'd18);
      e_fidb  = !((golden_rcs == 5'd1) || (golden_rcs == 5'd2) ||
                  (golden_rcs == 5'd3) || (golden_rcs == 5'd4) ||
                  (golden_rcs == 5'd6) || (golden_rcs == 5'd8) ||
                  (golden_rcs == 5'd9) || (golden_rcs == 5'd12) ||
                  (golden_rcs == 5'd18));
      q0      = (golden_rcs == 5'd0);
      e_a     = ~ALUD2N & q0;
      e_f     = ALUD2N & q0;

      for (n = 0; n < 16; n = n + 1) begin
        slot6 = (n <= 7) ? (e_gprl & GPR_15_0[n]) : (e_gprh & GPR_15_0[n]);
        case (n)
          0, 1, 2: slot7 = e_barg & LBA_2_0[n];
          3:       slot7 = e_abarg & AARG0;
          4, 5, 6: slot7 = e_aarg & LAA_3_1[n-4];
          7:       slot7 = 1'b0;  // SEL7 slice: no slot 7
          default: slot7 = e_gprs & GPR_15_0[7];
        endcase
        exp_d[n] = (e_bmg  & EA_15_0[n])    | (e_dbr  & DBR_15_0[n]) |
                   (e_arg  & ARG_15_0[n])   | (e_sts  & STS_15_0[n]) |
                   (e_swap & SW_15_0[n])    | (e_fidb & FIDBI_15_0[n]) |
                   slot6 | slot7;
        exp_g[n] = ~(e_a ? A_15_0[n] : (e_f ? F_15_0[n] : exp_d[n]));
      end
    end
  endtask

  task check_dg(input [127:0] tag);
    reg [15:0] exp_d, exp_g;
    begin
      #1;
      compute_expected(exp_d, exp_g);
      checks = checks + 1;
      if (D_15_0 !== exp_d) begin
        errors = errors + 1;
        $display("FAIL %0s: rcs=%0d ALUD2N=%b D=%04h expected %04h",
                 tag, golden_rcs, ALUD2N, D_15_0, exp_d);
      end
      checks = checks + 1;
      if (G_15_0 !== exp_g) begin
        errors = errors + 1;
        $display("FAIL %0s: rcs=%0d ALUD2N=%b G=%04h expected %04h",
                 tag, golden_rcs, ALUD2N, G_15_0, exp_g);
      end
    end
  endtask

  // Distinct per-source constants: on every bit position at least one
  // pair differs between any two sources, so a wrong slot routing gives
  // a different word.
  task load_pattern(input integer p);
    begin
      case (p)
        0: begin
          EA_15_0    = 16'hA35C; DBR_15_0 = 16'h5CA3; ARG_15_0 = 16'h3C5A;
          STS_15_0   = 16'hC5A3; SW_15_0  = 16'h69C6; FIDBI_15_0 = 16'h9639;
          GPR_15_0   = 16'h0FF0; A_15_0   = 16'h1E87; F_15_0   = 16'hE178;
          LBA_2_0    = 3'b101;   LAA_3_1  = 3'b011;   AARG0    = 1'b1;
        end
        1: begin  // bitwise complements of pattern 0
          EA_15_0    = 16'h5CA3; DBR_15_0 = 16'hA35C; ARG_15_0 = 16'hC3A5;
          STS_15_0   = 16'h3A5C; SW_15_0  = 16'h9639; FIDBI_15_0 = 16'h69C6;
          GPR_15_0   = 16'hF00F; A_15_0   = 16'hE178; F_15_0   = 16'h1E87;
          LBA_2_0    = 3'b010;   LAA_3_1  = 3'b100;   AARG0    = 1'b0;
        end
        2: begin  // all-ones data, control bits set
          EA_15_0    = 16'hFFFF; DBR_15_0 = 16'hFFFF; ARG_15_0 = 16'hFFFF;
          STS_15_0   = 16'hFFFF; SW_15_0  = 16'hFFFF; FIDBI_15_0 = 16'hFFFF;
          GPR_15_0   = 16'hFFFF; A_15_0   = 16'hFFFF; F_15_0   = 16'hFFFF;
          LBA_2_0    = 3'b111;   LAA_3_1  = 3'b111;   AARG0    = 1'b1;
        end
        default: begin  // all-zeros
          EA_15_0    = 16'h0000; DBR_15_0 = 16'h0000; ARG_15_0 = 16'h0000;
          STS_15_0   = 16'h0000; SW_15_0  = 16'h0000; FIDBI_15_0 = 16'h0000;
          GPR_15_0   = 16'h0000; A_15_0   = 16'h0000; F_15_0   = 16'h0000;
          LBA_2_0    = 3'b000;   LAA_3_1  = 3'b000;   AARG0    = 1'b0;
        end
      endcase
    end
  endtask

  // Set one 16-bit bus by config index; all others get the background.
  task set_bus(input integer c, input [15:0] v, input [15:0] bg);
    begin
      EA_15_0    = (c == 0) ? v : bg;
      DBR_15_0   = (c == 1) ? v : bg;
      ARG_15_0   = (c == 2) ? v : bg;
      STS_15_0   = (c == 3) ? v : bg;
      SW_15_0    = (c == 4) ? v : bg;
      FIDBI_15_0 = (c == 5) ? v : bg;
      GPR_15_0   = (c == 6 || c == 7) ? v : bg;
      A_15_0     = (c == 8) ? v : bg;
      F_15_0     = (c == 9) ? v : bg;
    end
  endtask

  function [4:0] cfg_rcs(input integer c);
    begin
      case (c)
        0: cfg_rcs = 5'd1;   // EA bus via EBMG
        1: cfg_rcs = 5'd3;   // DBR
        2: cfg_rcs = 5'd4;   // ARG
        3: cfg_rcs = 5'd6;   // STS
        4: cfg_rcs = 5'd9;   // SW
        5: cfg_rcs = 5'd5;   // FIDBI (EFIDB-only code)
        6: cfg_rcs = 5'd2;   // GPR full word
        7: cfg_rcs = 5'd18;  // GPR low byte + sign extend
        8: cfg_rcs = 5'd0;   // A via EA   (ALUD2N=0)
        default: cfg_rcs = 5'd0;  // F via EF (ALUD2N=1)
      endcase
    end
  endfunction

  reg [15:0] walk_v, bg16;

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_ALU_OUTMUX_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_ALU_OUTMUX_tb: latch/CP mode (posedge ALUCLK capture)");
`endif

    // Wiggle every input once so all always @(*) blocks inside the
    // logisim primitives (Decoder_8 etc.) evaluate at least once -
    // iverilog leaves them X until an input CHANGES, so a select that
    // sits constant at 0 from time 0 would read back X. Simulator
    // start-up artifact only, not DUT behavior.
    load_pattern(2);
    CSIDBS_4_0 = 5'b11111;
    ALUD2N = 1;
    #1;
    // Establish a known register state (latch-mode R81 powers up X).
    load_pattern(0);
    CSIDBS_4_0 = 5'd0;
    ALUD2N = 0;
    pulse_aluclk;

    // ------------------------------------------------------------------
    // Layer 1: exhaustive select sweep - all 32 rcs x 2 ALUD2N x 4
    // directed data tuples. 512 checks.
    // ------------------------------------------------------------------
    for (i = 0; i < 32; i = i + 1) begin
      for (pat = 0; pat < 4; pat = pat + 1) begin
        load_pattern(pat);
        CSIDBS_4_0 = i[4:0];
        ALUD2N = 0;
        pulse_aluclk;
        check_dg("sweep-d2n0");
        ALUD2N = 1;  // combinational: no new pulse needed
        check_dg("sweep-d2n1");
      end
    end

    // ------------------------------------------------------------------
    // Layer 2: walking-1 / walking-0 per data bus under its selecting
    // rcs. 10 configs x 16 bits x 2 polarities. 640 checks.
    // ------------------------------------------------------------------
    for (cfg = 0; cfg < 10; cfg = cfg + 1) begin
      CSIDBS_4_0 = cfg_rcs(cfg);
      ALUD2N = (cfg == 9);  // F needs ALUD2N=1; A (cfg 8) needs 0
      LBA_2_0 = 3'b111; LAA_3_1 = 3'b111; AARG0 = 1'b1;  // must not leak
      for (pol = 0; pol < 2; pol = pol + 1) begin
        bg16 = pol ? 16'hFFFF : 16'h0000;
        for (b = 0; b < 16; b = b + 1) begin
          walk_v = pol ? ~(16'h0001 << b) : (16'h0001 << b);
          set_bus(cfg, walk_v, bg16);
          pulse_aluclk;
          check_dg("walk");
        end
      end
    end

    // Layer 2b: exhaustive {LBA,AARG0} under rcs=8 and {LAA,AARG0}
    // under rcs=12, on an all-ones data background (leak check).
    // 64 checks.
    load_pattern(2);
    CSIDBS_4_0 = 5'd8;
    ALUD2N = 0;
    for (i = 0; i < 16; i = i + 1) begin
      LBA_2_0 = i[2:0];
      AARG0   = i[3];
      pulse_aluclk;
      check_dg("lba-aarg0");
    end
    CSIDBS_4_0 = 5'd12;
    for (i = 0; i < 16; i = i + 1) begin
      LAA_3_1 = i[2:0];
      AARG0   = i[3];
      pulse_aluclk;
      check_dg("laa-aarg0");
    end

    // ------------------------------------------------------------------
    // Layer 3: registered-vs-comb seam. 20 checks.
    // ------------------------------------------------------------------
    // Enables must HOLD when CSIDBS changes without an ALUCLK, while D
    // keeps following the (new) data combinationally.
    for (i = 0; i < 8; i = i + 1) begin
      load_pattern(0);
      CSIDBS_4_0 = 5'd3;  // capture EDBR
      ALUD2N = 0;
      pulse_aluclk;
      CSIDBS_4_0 = i[4:0] ^ 5'd4;  // stale select attempt (no pulse)
      load_pattern(1);             // and new data
      check_dg("stale-select");    // model still uses golden_rcs=3
    end
    // EA/EF split is combinational on ALUD2N under a held rcs==0.
    load_pattern(0);
    CSIDBS_4_0 = 5'd0;
    ALUD2N = 0;
    pulse_aluclk;
    check_dg("ea-comb");   // G = ~A
    ALUD2N = 1;            // no pulse
    check_dg("ef-comb");   // G = ~F

    // ------------------------------------------------------------------
    // Layer 4: 25000-step fixed-seed LFSR soak. Each step: random
    // select+data, pulse, check; then mutate data+ALUD2N+CSIDBS with
    // no pulse and re-check (hold seam). 100000 checks.
    // ------------------------------------------------------------------
    lfsr = 32'hC0FFEE01;
    for (i = 0; i < 25000; i = i + 1) begin
      lfsr = lfsr_next(lfsr); EA_15_0    = lfsr[15:0];
      lfsr = lfsr_next(lfsr); DBR_15_0   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); ARG_15_0   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); STS_15_0   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); SW_15_0    = lfsr[15:0];
      lfsr = lfsr_next(lfsr); FIDBI_15_0 = lfsr[15:0];
      lfsr = lfsr_next(lfsr); GPR_15_0   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); A_15_0     = lfsr[15:0];
      lfsr = lfsr_next(lfsr); F_15_0     = lfsr[15:0];
      lfsr = lfsr_next(lfsr);
      {CSIDBS_4_0, ALUD2N, LBA_2_0, LAA_3_1, AARG0} = lfsr[12:0];
      pulse_aluclk;
      check_dg("soak");
      // Mutate without a pulse: enables hold, D/G follow new data.
      lfsr = lfsr_next(lfsr); DBR_15_0   = lfsr[15:0];
      lfsr = lfsr_next(lfsr); FIDBI_15_0 = lfsr[15:0];
      lfsr = lfsr_next(lfsr); GPR_15_0   = lfsr[15:0];
      lfsr = lfsr_next(lfsr);
      {CSIDBS_4_0, ALUD2N} = lfsr[5:0];
      check_dg("soak-hold");
    end

    // ------------------------------------------------------------------
    // Verdict
    // ------------------------------------------------------------------
    if (checks != EXPECTED_CHECKS) begin
      $display("TB_RESULT: FAIL (check count %0d != expected %0d)",
               checks, EXPECTED_CHECKS);
    end else if (errors == 0) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      $display("TB_RESULT: FAIL (%0d errors in %0d checks)", errors, checks);
    end
    $finish;
  end

endmodule
