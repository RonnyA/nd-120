`timescale 1ns / 1ps

/**************************************************************************
** Testbench for DECODE_DGA_IDBS - IDB source enable decoder + panel     **
** PRQ/VAL handshake (DGA pages 14/15).                                  **
**                                                                       **
** Sequential DUT: four F924 4-bit D-registers - A282 (panel FSM) and    **
** A259 (RINR/EPAN/TRAALD) on CLK1; A248 (ECSR/EIOR/EPES/EPEA) and      **
** A275 (EDO/RUART/MAPANS) on CLK0 - fed by a NAND decode of            **
** CSIDBS[4:0] gated by LCSN, plus the combinational EPANSN bypass.      **
** In the parent (DECODE_DGA.v) CLK0 and CLK1 are BOTH s_xclk.           **
**                                                                       **
** Build modes (no latch primitives, so USE_TRANSPARENT_LATCHES does     **
** not apply):                                                           **
**   default        - F924 clocks on posedge CLK0/CLK1 (routed nets)     **
**   -DFPGA_FF_MODE - all four F924_EN capture on posedge sysclk gated   **
**                    by the single CLK_EN (P2 conversion; one enable    **
**                    for both clock pins, valid because both are XCLK)  **
**                                                                       **
** INDEPENDENT golden model, re-derived from schematic intent as exact   **
** octal CSIDBS code sets and register-level FSM equations (never a      **
** transliteration of the NAND netlist):                                 **
**   ECSRN<=o24  EIORN<=o16  EPESN<=o13  EPEAN<=o12  RUARTN<=o37        **
**   RINRN<=o35  EPANN<=o27  TRAALDN<=o26  MAPANS(int)<=o21             **
**   EDON <= {0,1,2,3,4,6,10,11,14,15,22,23,25,31,36} (octal)           **
**   EPANSN = COMB ~(CSIDBS==o20 & LCSN & RWCSN) & ~MAPANS(A275, CLK0)  **
**            (28-AUG split: comb for the 20 ms MIPANS check, registered **
**             for the macro TRA PANS read. 30-AUG: the comb window is   **
**             SHUT while RWCSN is low - during an RWCS microinstruction **
**             the control store carries DATA words, and decoding them   **
**             put the panel status word on the IDB: CACHE-1X0-A00       **
**             test 1, layer F below. RWCSN is the DGA's own COMM-sheet  **
**             RWCS decode, not a gate-array pin.)                       **
**   Panel FSM (all products gated by LCSN):                            **
**     VAL'    = RIWR_n & STAT4                                         **
**     RIWR'   = STAT4 & ((VAL & MAPANS) | RIWR)                        **
**     DSTAT3' = STAT3 & (DSTAT3 | PRQ)                                 **
**     PRQ'    = ~dec2021 & ((STAT3 & ~DSTAT3) | PRQ)                   **
**                                                                       **
** PINNED RTL behaviors (documented, not patched):                       **
**  P1. Power-on flop state is 0, so before the FIRST clock every        **
**      active-low enable output reads 0 (asserted) and the Q-bar-       **
**      sourced signals read 1: VAL=1, RIWR=1, DSTAT3=1, PRQ=1,          **
**      MAPANS(internal)=1, only EDON=1 deasserted. Checked at t=0.      **
**  P2. EPANSN = comb o20 term AND ~MAPANS (A275.Q3B) (see DUT comment); **
**      other 9 enables are registered - one clock later.                **
**                                                                       **
** STALE-COMMENT findings (gates are internally consistent, comments     **
** are not - reported in the campaign log, DUT untouched):               **
**  S1. A250's comment claims "12=PEA,13=PES,16=IOR,17=NONE" but the     **
**      gate term (~b4 & b3 & ~b1) decodes o10,o11,o14,o15 - which is    **
**      what the EDO merge needs (12/13/16 have their own enables).      **
**  S2. The EDON port comment lists sources 0,1,2,3,4,6,10,11,14,25,36;  **
**      the gates additionally fire on o15 (A250), o22/o23 (A256,        **
**      commented GPR_SE/PGS) and o31 (A269).                            **
**                                                                       **
** Layers:                                                               **
**  A. t=0 power-on state check (12).                                    **
**  B. Exhaustive decode sweep: 32 codes x LCSN {1,0}, comb EPANSN       **
**     check before the clock + full 12-output check after (64 x 13).    **
**  C. Directed panel-FSM walk: PRQ set/hold, DSTAT3 fence, PRQ clear    **
**     on MIPANS/MAPANS read, VAL->RIWR->VAL-drop chain via MAPANS,      **
**     RIWR hold on STAT4, LCSN=0 global mask, no-clock comb-vs-         **
**     registered split (P2).                                            **
**  D. (default build only) Clock-group routing: CLK1-only and           **
**     CLK0-only pulses prove which register sits on which clock pin.    **
**  F. THE CONTROL-STORE DATA WINDOW (regression for CACHE-1X0-A00       **
**     test 1, 30-AUG-2026). With RWCSN low (an RWCS microinstruction:   **
**     the store outputs the word being read/written, not a micro-       **
**     instruction), every code is walked through CSIDBS with NO clock   **
**     and ALL TEN enables must hold - o20 included, which with RWCSN    **
**     high asserts EPANSN combinationally (checked there too). Without  **
**     the gate, 017000B (bits 41:37 = o20) enabled the panel status     **
**     driver during its own read-back: found XOR expected on the Nexys  **
**     was the panel word (163400, 020400 ...), in Verilator 100000.     **
**  E. 4000-step fixed-seed xorshift32 soak (seed 32'h1DB5C0DE),         **
**     steered panel codes + stat lines, full 12-output check per step.  **
**                                                                       **
** Ronny Hansen                                                          **
** 01-AUG-2026                                                           **
***************************************************************************/

module DECODE_DGA_IDBS_tb;

`ifdef FPGA_FF_MODE
  localparam EXPECTED_CHECKS = 49495;  // A:12 B:832 C:293 E:48000 F:358
`else
  localparam EXPECTED_CHECKS = 49639;  // + D:144 (12 single-clock checksets) F:358
`endif

  reg        sysclk;
  reg        CLK_EN;
  reg        CLK0;
  reg        CLK1;
  reg  [4:0] CSIDBS;
  reg        LCSN;
  reg        RWCSN;
  reg        STAT3;
  reg        STAT4;

  wire ECSRN, EDON, EIORN, EPANN, EPANSN, EPEAN, EPESN;
  wire RINRN, RUARTN, TRAALDN, PRQN, VAL;

  DECODE_DGA_IDBS dut (
      .sysclk(sysclk),
      .CLK_EN(CLK_EN),
      .CLK0(CLK0),
      .CLK1(CLK1),
      .CSIDBS_4_0(CSIDBS),
      .LCSN(LCSN),
      .RWCSN(RWCSN),
      .STAT3(STAT3),
      .STAT4(STAT4),
      .ECSRN(ECSRN),
      .EDON(EDON),
      .EIORN(EIORN),
      .EPANN(EPANN),
      .EPANSN(EPANSN),
      .EPEAN(EPEAN),
      .EPESN(EPESN),
      .RINRN(RINRN),
      .RUARTN(RUARTN),
      .TRAALDN(TRAALDN),
      .PRQN(PRQN),
      .VAL(VAL)
  );

  always #5 sysclk = ~sysclk;

  /*************************************************************************
   ** Independent behavioral model (register level, init 0 like the RTL)  **
   *************************************************************************/
  // A282 flop bits (Q side): [0] a286-reg, [1] RIWR_n, [2] DSTAT3_n, [3] PRQ_n
  reg m_q282_0, m_q282_1, m_q282_2, m_q282_3;
  // A259 (CLK1)
  reg m_rinr_n, m_epan_n, m_traald_n;
  // A248 (CLK0)
  reg m_ecsr_n, m_eior_n, m_epes_n, m_epea_n;
  // A275 (CLK0): m_edo = Q1 (active-high hit), MAPANS = ~m_mapans_n
  reg m_edo, m_ruart_n, m_mapans_n;

  function dec2021(input [4:0] c, input lcs);
    dec2021 = lcs & ((c == 5'o20) | (c == 5'o21));
  endfunction
  function dec20(input [4:0] c, input lcs);
    dec20 = lcs & (c == 5'o20);
  endfunction
  // EPANSN as the pins show it (28-AUG-2026): comb o20 term (MIPANS, the
  // 20 ms COND,F15 check) AND the A275 CLK0-registered o21 term (MAPANS,
  // the macro TRA PANS read) - see the DUT comment.
  function epansn_exp(input [4:0] c, input lcs, input rwcs_n_hi, input mapans_n);
    epansn_exp = ~(dec20(c, lcs) & rwcs_n_hi) & mapans_n;
  endfunction

  function edo_hit(input [4:0] c, input lcs);
    begin
      case (c)
        5'o00, 5'o01, 5'o02, 5'o03, 5'o04, 5'o06,
        5'o10, 5'o11, 5'o14, 5'o15,
        5'o22, 5'o23, 5'o25, 5'o31, 5'o36: edo_hit = lcs;
        default: edo_hit = 1'b0;
      endcase
    end
  endfunction

  // One clock event; grp1 = A282+A259 (CLK1), grp0 = A248+A275 (CLK0).
  // All next-state values computed from OLD state, then committed.
  task model_tick(input do_grp0, input do_grp1);
    reg val, riwr, dstat3, prq, mapans, a260;
    reg n0, n1, n2, n3;
    begin
      val    = ~m_q282_0;
      riwr   = ~m_q282_1;
      dstat3 = ~m_q282_2;
      prq    = ~m_q282_3;
      mapans = ~m_mapans_n;
      a260   = ~dec2021(CSIDBS, LCSN);

      n0 = ~(m_q282_1 & STAT4 & LCSN);
      n1 = ~(((val & STAT4 & mapans) | (riwr & STAT4)) & LCSN);
      n2 = ~(((dstat3 & STAT3) | (prq & STAT3)) & LCSN);
      n3 = ~((((STAT3 & m_q282_2) | prq) & a260) & LCSN);

      if (do_grp1) begin
        m_q282_0   = n0;
        m_q282_1   = n1;
        m_q282_2   = n2;
        m_q282_3   = n3;
        m_rinr_n   = ~(LCSN & (CSIDBS == 5'o35));
        m_epan_n   = ~(LCSN & (CSIDBS == 5'o27));
        m_traald_n = ~(LCSN & (CSIDBS == 5'o26));
      end
      if (do_grp0) begin
        m_ecsr_n   = ~(LCSN & (CSIDBS == 5'o24));
        m_eior_n   = ~(LCSN & (CSIDBS == 5'o16));
        m_epes_n   = ~(LCSN & (CSIDBS == 5'o13));
        m_epea_n   = ~(LCSN & (CSIDBS == 5'o12));
        m_edo      = edo_hit(CSIDBS, LCSN);
        m_ruart_n  = ~(LCSN & (CSIDBS == 5'o37));
        m_mapans_n = ~(LCSN & (CSIDBS == 5'o21));
      end
    end
  endtask

  /*************************************************************************
   ** Clock stimulus                                                      **
   *************************************************************************/
  task tick_both;
    begin
`ifdef FPGA_FF_MODE
      @(negedge sysclk);
      CLK_EN = 1;
      @(negedge sysclk);
      CLK_EN = 0;
`else
      #1;
      CLK0 = 1;
      CLK1 = 1;
      #2;
      CLK0 = 0;
      CLK1 = 0;
`endif
      model_tick(1, 1);
      #1;
    end
  endtask

`ifndef FPGA_FF_MODE
  task tick_clk0_only;
    begin
      #1;
      CLK0 = 1;
      #2;
      CLK0 = 0;
      model_tick(1, 0);
      #1;
    end
  endtask

  task tick_clk1_only;
    begin
      #1;
      CLK1 = 1;
      #2;
      CLK1 = 0;
      model_tick(0, 1);
      #1;
    end
  endtask
`endif

  /*************************************************************************
   ** Checking                                                            **
   *************************************************************************/
  integer checks;
  integer errors;

  task check1(input [127:0] tag, input [127:0] sig, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 40)
          $display("ERROR: %0s %0s=%b expected %b (CSIDBS=%02o LCSN=%b STAT3=%b STAT4=%b)",
                   tag, sig, got, exp, CSIDBS, LCSN, STAT3, STAT4);
      end
    end
  endtask

  task check_all(input [127:0] tag);
    begin
      check1(tag, "ECSRN", ECSRN, m_ecsr_n);
      check1(tag, "EDON", EDON, ~m_edo);
      check1(tag, "EIORN", EIORN, m_eior_n);
      check1(tag, "EPANN", EPANN, m_epan_n);
      check1(tag, "EPANSN", EPANSN, epansn_exp(CSIDBS, LCSN, RWCSN, m_mapans_n));
      check1(tag, "EPEAN", EPEAN, m_epea_n);
      check1(tag, "EPESN", EPESN, m_epes_n);
      check1(tag, "RINRN", RINRN, m_rinr_n);
      check1(tag, "RUARTN", RUARTN, m_ruart_n);
      check1(tag, "TRAALDN", TRAALDN, m_traald_n);
      check1(tag, "PRQN", PRQN, m_q282_3);
      check1(tag, "VAL", VAL, ~m_q282_0);
    end
  endtask

  // Apply inputs mid-cycle (away from any clock event) and settle.
  task apply(input [4:0] c, input lcs, input s3, input s4);
    begin
      CSIDBS = c;
      LCSN   = lcs;
      STAT3  = s3;
      STAT4  = s4;
      #2;
    end
  endtask

  // One full stimulus step: apply, comb-check EPANSN, clock, full check.
  task step(input [127:0] tag, input [4:0] c, input lcs, input s3, input s4);
    begin
      apply(c, lcs, s3, s4);
      tick_both;
      check_all(tag);
    end
  endtask

  /*************************************************************************
   ** Soak PRNG (xorshift32, fixed seed)                                  **
   *************************************************************************/
  reg [31:0] rnd;
  function [31:0] xorshift32(input [31:0] x);
    reg [31:0] y;
    begin
      y = x ^ (x << 13);
      y = y ^ (y >> 17);
      y = y ^ (y << 5);
      xorshift32 = y;
    end
  endfunction

  integer i;
  reg [4:0] sc;
  reg       sl, s3r, s4r;

  initial begin
    sysclk = 0;
    CLK_EN = 0;
    CLK0   = 0;
    CLK1   = 0;
    CSIDBS = 5'o17;  // decodes nothing
    LCSN   = 1;
    RWCSN  = 1;
    STAT3  = 0;
    STAT4  = 0;
    checks = 0;
    errors = 0;

    // model power-on state = RTL flop init
    {m_q282_0, m_q282_1, m_q282_2, m_q282_3} = 4'b0000;
    {m_rinr_n, m_epan_n, m_traald_n} = 3'b000;
    {m_ecsr_n, m_eior_n, m_epes_n, m_epea_n} = 4'b0000;
    {m_edo, m_ruart_n, m_mapans_n} = 3'b000;

    // ---- Layer A: power-on state before any clock (PIN P1) ----
    #2;
    check_all("A_poweron");

    // ---- Layer B: exhaustive decode sweep, both LCSN values ----
    // stat lines held 0 so the panel FSM decays deterministically.
    for (i = 0; i < 64; i = i + 1) begin
      apply(i[4:0], ~i[5], 1'b0, 1'b0);
      check1("B_comb", "EPANSN", EPANSN, epansn_exp(CSIDBS, LCSN, RWCSN, m_mapans_n));
      tick_both;
      check_all("B_sweep");
    end

    // ---- Layer C: directed panel FSM walk ----
    // settle to quiescence
    step("C_settle1", 5'o17, 1, 0, 0);
    step("C_settle2", 5'o17, 1, 0, 0);
    step("C_settle3", 5'o17, 1, 0, 0);

    // PRQ sets on STAT3 with DSTAT3 low, away from panel-status reads
    step("C_prq_set", 5'o17, 1, 1, 0);
    // PRQ holds; DSTAT3 now sets (STAT3 & PRQ)
    step("C_prq_hold", 5'o17, 1, 1, 0);
    step("C_dstat3_up", 5'o17, 1, 1, 0);
    // Read MIPANS (o20): EPANSN comb low pre-clock, PRQ clears at the clock
    apply(5'o20, 1, 1, 0);
    check1("C_mipans", "EPANSN", EPANSN, 1'b0);
    check1("C_mipans", "PRQN_pre", PRQN, 1'b0);  // still set before clock (P2)
    tick_both;
    check_all("C_prq_clear");
    // DSTAT3 fence: STAT3 still high, DSTAT3 holds itself, PRQ must NOT re-set
    step("C_fence1", 5'o17, 1, 1, 0);
    step("C_fence2", 5'o17, 1, 1, 0);
    // STAT3 drops: DSTAT3 clears
    step("C_stat3_dn", 5'o17, 1, 0, 0);
    // re-arm and clear via MAPANS (o21) instead of MIPANS
    step("C_rearm", 5'o17, 1, 1, 0);
    step("C_mapans_clr", 5'o21, 1, 1, 0);
    step("C_calm", 5'o17, 1, 0, 0);

    // VAL/RIWR chain: STAT4 up -> VAL sets (RIWR clear); read MAPANS to
    // raise the internal MAPANS flag; VAL & MAPANS -> RIWR sets and VAL
    // drops; RIWR holds on STAT4 alone; STAT4 down -> both clear.
    step("C_val_set", 5'o17, 1, 0, 1);
    step("C_mapans_rd", 5'o21, 1, 0, 1);  // MAPANS flag set at this clock
    step("C_riwr_set", 5'o17, 1, 0, 1);   // VAL&MAPANS&STAT4 -> RIWR
    step("C_val_drop", 5'o17, 1, 0, 1);   // RIWR_n low kills VAL
    step("C_riwr_hold", 5'o17, 1, 0, 1);
    step("C_stat4_dn", 5'o17, 1, 0, 0);
    step("C_idle", 5'o17, 1, 0, 0);

    // LCSN=0 global mask: with stats high and a hot code, everything off
    step("C_lcs_mask", 5'o37, 0, 1, 1);
    step("C_lcs_mask2", 5'o20, 0, 1, 1);
    step("C_lcs_back", 5'o17, 1, 0, 0);

    // No-clock split (PIN P2): change code to o24 without any clock -
    // EPANSN follows comb inputs, registered ECSRN must NOT move.
    apply(5'o24, 1, 0, 0);
    check1("C_noclk", "ECSRN", ECSRN, 1'b1);
    check1("C_noclk", "EPANSN", EPANSN, 1'b1);
    apply(5'o20, 1, 0, 0);
    check1("C_noclk", "EPANSN_comb", EPANSN, 1'b0);
    step("C_c_end", 5'o17, 1, 0, 0);

`ifndef FPGA_FF_MODE
    // ---- Layer D: clock-group routing (default build only) ----
    // ECSR (o24) lives on CLK0: a CLK1-only pulse must not assert it.
    apply(5'o24, 1, 0, 0);
    tick_clk1_only;
    check_all("D_ecsr_clk1");
    tick_clk0_only;
    check_all("D_ecsr_clk0");
    // TRAALD (o26) lives on CLK1: a CLK0-only pulse must not assert it.
    apply(5'o26, 1, 0, 0);
    tick_clk0_only;
    check_all("D_tra_clk0");
    tick_clk1_only;
    check_all("D_tra_clk1");
    // Panel FSM (A282) is CLK1; MAPANS flag (A275) is CLK0.
    apply(5'o17, 1, 1, 0);
    tick_clk0_only;
    check_all("D_prq_clk0");  // PRQ must not set on CLK0
    tick_clk1_only;
    check_all("D_prq_clk1");  // now it sets
    apply(5'o21, 1, 1, 0);
    tick_clk1_only;
    check_all("D_map_clk1");  // MAPANS flag must not set on CLK1
    tick_clk0_only;
    check_all("D_map_clk0");
    // UART (o37, CLK0) vs RINR (o35, CLK1) cross
    apply(5'o37, 1, 0, 0);
    tick_clk1_only;
    check_all("D_uart_clk1");
    tick_clk0_only;
    check_all("D_uart_clk0");
    apply(5'o35, 1, 0, 0);
    tick_clk0_only;
    check_all("D_rinr_clk0");
    tick_clk1_only;
    check_all("D_rinr_clk1");
    // resync to a clean state for the soak
    apply(5'o17, 1, 0, 0);
    tick_both;
`endif

    // ---- Layer E: 4000-step fixed-seed soak ----
    rnd = 32'h1DB5C0DE;
    for (i = 0; i < 4000; i = i + 1) begin
      rnd = xorshift32(rnd);
      sc  = rnd[4:0];
      // steer 1-in-8 steps onto the panel/handshake-relevant codes
      if (rnd[7:5] == 3'b000) begin
        case (rnd[9:8])
          2'b00: sc = 5'o20;
          2'b01: sc = 5'o21;
          2'b10: sc = 5'o24;
          2'b11: sc = 5'o37;
        endcase
      end
      sl  = (rnd[12:10] != 3'b000);  // LCSN low 1 step in 8
      s3r = rnd[13];
      s4r = rnd[14];
      apply(sc, sl, s3r, s4r);
      tick_both;
      check_all("E_soak");
    end

    // ---- Layer F: the control-store data window (RWCSN low) ----
    step("F_settle", 5'o17, 1, 0, 0);
    step("F_settle2", 5'o17, 1, 0, 0);
    RWCSN = 1'b0;   // an RWCS microinstruction is executing: CSIDBS now
                    // carries bits 41:37 of DATA words, with no clock edge
    for (i = 0; i < 32; i = i + 1) begin
      apply(i[4:0], 1'b1, 1'b0, 1'b0);
      check1("F_dataword", "EPANSN",  EPANSN,  1'b1);
      check1("F_dataword", "RINRN",   RINRN,   1'b1);
      check1("F_dataword", "RUARTN",  RUARTN,  1'b1);
      check1("F_dataword", "TRAALDN", TRAALDN, 1'b1);
      check1("F_dataword", "EPANN",   EPANN,   1'b1);
      check1("F_dataword", "EIORN",   EIORN,   1'b1);
      check1("F_dataword", "ECSRN",   ECSRN,   1'b1);
      check1("F_dataword", "EPESN",   EPESN,   1'b1);
      check1("F_dataword", "EPEAN",   EPEAN,   1'b1);
      check1("F_dataword", "EDON",    EDON,    1'b1);
    end
    // the word that failed first on the board, 017000B (o20), held: nothing
    apply(5'o20, 1'b1, 1'b0, 1'b0);
    #40;
    check1("F_017000", "EPANSN", EPANSN, 1'b1);
    RWCSN = 1'b1;
    // and the comb window itself is still alive outside RWCS
    apply(5'o20, 1'b1, 1'b0, 1'b0);
    check1("F_comb_alive", "EPANSN", EPANSN, 1'b0);
    step("F_end", 5'o17, 1, 0, 0);

    // ---- Verdict ----
    if (errors == 0 && checks == EXPECTED_CHECKS) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      $display("checks=%0d expected=%0d errors=%0d", checks, EXPECTED_CHECKS, errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule
