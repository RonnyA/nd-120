`timescale 1ns / 1ps

/**************************************************************************
** Testbench for DECODE_DGA_POW - power-up / master-clear / RTC / bus-    **
** timeout sheet of the Decoder Gate Array (DGA pages 8/9/10).            **
**                                                                       **
** Sequential DUT: five F595 RS latches (A571 STOP flag, A570 ESLOAD,    **
** A576 LOAD flag, A574 RESTART flag, A575 CONTINUE flag), the A572      **
** restart-capture FF (clocked by the s_clear_n rise, async preset by    **
** CLRTI), the synchronous sysclk RTC counter (replaces the original    **
** A577/F714 divide chain), and the RTOSC ripple network: A633 rfclk    **
** (/2), A629 PANOSC (/4), A623..A619 6-bit ripple (TESTO = /64), and   **
** the A630/A631 F617 pair whose NOR A636 produces TOUT.                **
**                                                                       **
** Build modes (all five run by the Makefile target test-dga-pow):       **
**   1. plain                    - F595 sync branch, ripple-chain F714s, **
**                                 RTC limit derived from the default    **
**                                 BOARD_CLK_FREQ (100 MHz -> 1999999 /  **
**                                 499999; checked statically via        **
**                                 dut.s_rtc_limit, rollover not run)    **
**   2. -DVERILATOR_SIM          - sync F595 (transparent branch was     **
**                                 deleted 20-AUG-2026), RTC 8192/2048   **
**                                 with                                  **
**                                 the runtime-writable period regs      **
**                                 (s_rtc_20ms_var / s_rtc_5ms_var,      **
**                                 poked hierarchically by this tb)      **
**   3. -DVERILATOR_SIM -DRTC_SIM_20MS=600 - build-knob period override, **
**                                 600/150 (the 4:1 ratio via /4)        **
**   4. -DFPGA_FF_MODE -DBOARD_CLK_FREQ=25600 - synchronous chain + A572 **
**                                 sysclk capture; derived limit 511/127 **
**                                 exercised dynamically (rollover run)  **
**   5. -DVERILATOR_SIM -DFPGA_FF_MODE - the sim FF-mode combination     **
**                                 (sync F595 + synchronous chain)       **
**                                                                       **
** INDEPENDENT golden model, re-derived from the gate structure (F595   **
** truth table incl. the S&R -> Q=1,QB=1 row; NAND network; F714 ripple **
** as a binary counter; F617 clocked-sample-of-old-value semantics),    **
** evaluated at settled points only. The RTC mirror re-implements the   **
** counter semantics: count sysclk edges, fire (rtc_n -> 0, LATCHED)    **
** at limit+1 edges after release, re-arm only on CLRTI or RESCL.       **
**                                                                       **
** TOUT (bus-timeout) gate behavior measured and pinned here (feeds the **
** MOR/IOX-error level-12/14 chain; Tang "TOUT never fires" analysis is **
** deferred - this tb documents the sim gates, it changes NOTHING):     **
**   - rfclk = RTOSC/2 (A633, reset high by CLOSC).                     **
**   - A630: REFRQN <= 0 (request refresh) on EVERY rfclk rise (D=0);   **
**     REFN low async-sets REFRQN=1 (acknowledge).                      **
**   - A631: on every rfclk rise samples the PRE-EDGE REFRQN (both      **
**     F617s clock on the same edge; A631 sees the old A630 value);     **
**     BDRY50N low async-sets A631.Q=1.                                 **
**   - TOUT = ~(A631.Q | rfclk): asserted during rfclk-LOW half-periods **
**     while A631.Q=0. Arming: a refresh request that survives one full **
**     rfclk period unacknowledged (no REFN pulse) with no BDRY50N      **
**     activity. From the first request to TOUT: 3 more RTOSC rises     **
**     (1.5 rfclk periods). TOUT is a PERIODIC LEVEL (re-asserts every  **
**     rfclk-low half) until cleared by BDRY50N (immediate), an acked   **
**     REFN cycle (at the next rfclk rise), or CLOSC (forces rfclk=1).  **
**                                                                       **
** PINNED RTL behaviors (documented, not patched):                       **
**  P1. sys_rst_n release (20-AUG-2026, F595 unified to the sync FF in  **
**      EVERY build): the F595s are forced idle during reset and A572   **
**      captures the forced ESLOADN=1, so the RESTART flag is NEVER     **
**      set by sys_rst_n. The old transparent-build release race is     **
**      gone with the deleted branch.                                   **
**  P2. Post-reset STOP flag: every build leaves it CLEAR (STPN=1; the  **
**      forced-idle window swallows the set and A580 is low by the      **
**      first free clock edge).                                         **
**  P3. RTC fire is LATCHED: s_rtc_n stays 0 after the terminal count   **
**      until CLRTIN or RESCL (CLOSC|RESET); it never self-clears.      **
**      Fire happens exactly limit+1 sysclk edges after release.        **
**  P4. F595 S&R rows are reachable (e.g. PWCL=1 while STPN=1 drives    **
**      A570 to Q=1,QB=1) and are exercised by the soak.                **
**  P5. Dead logic: the A620/A624/A616/A618/A617/A627/A626 divide chain **
**      (the original RTC path) drives no output - TESTE is observable  **
**      only at the A620 mux output (checked hierarchically).           **
**  P6. The TANG_NO_RTC_PAN diagnostic knob is NOT built here.          **
**                                                                       **
** Layers:                                                               **
**  A. Power-up sequencing (CLOSC/RESET window, CLEAR/MCL/IDB codes).   **
**  B. Flag directed: STOP/START/SSTOP, LOAD (only latches while        **
**     stopped), CONTINUE, RESTART via warm sys_rst_n (per-build P1),   **
**     CLRTIN flag clear, EMCLN master clear, PRQN codes.               **
**  C. RTC: static limit checks (both SEL5MSN values), fire timing      **
**     (limit+1 edges), latched-until-clear, PANN level-13 assertion,   **
**     re-arm via CLRTIN and via RESET, 5 ms path, runtime pokes        **
**     (VERILATOR_SIM builds only). Plain build: static checks only.    **
**  D. TOUT/refresh directed script (explicit expected values, see      **
**     above) + CLOSC re-arm.                                            **
**  E. Divider: 130 RTOSC cycles checking TESTO (/64), PANOSC (/4),     **
**     rfclk phase, REFRQN cadence, TOUT periodicity - with and         **
**     without REFN acks.                                                **
**  F. Hold: long idle, outputs stable.                                  **
**  G. 4000-step fixed-seed xorshift32 soak (seed 32'h9C0FFEE1), all    **
**     17 inputs toggled, full 14-signal check per step.                **
**                                                                       **
** Ronny Hansen                                                          **
** 01-AUG-2026                                                           **
***************************************************************************/

module DECODE_DGA_POW_tb;

`ifdef VERILATOR_SIM
  localparam EXPECTED_CHECKS = 61956;  // builds 2/3/5 (fire + poke tests; one VS-only warm-restart check removed with the F595 unification, 20-AUG-2026)
`elsif FPGA_FF_MODE
  localparam EXPECTED_CHECKS = 61894;  // build 4 (fire tests, no pokes)
`else
  localparam EXPECTED_CHECKS = 61802;  // build 1 (static RTC checks only)
`endif

  // Expected RTC limits per build (hard-coded independently of the DUT
  // arithmetic; the Makefile pairs -DRTC_SIM_20MS=600 / -DBOARD_CLK_FREQ=25600
  // with these constants).
`ifdef RTC_SIM_20MS
  localparam [20:0] TB_LIM20 = 21'd600;
  localparam [20:0] TB_LIM5  = 21'd150;
`elsif VERILATOR_SIM
  localparam [20:0] TB_LIM20 = 21'd8192;
  localparam [20:0] TB_LIM5  = 21'd2048;
`elsif FPGA_FF_MODE
  localparam [20:0] TB_LIM20 = 21'd511;   // 25600/50 - 1
  localparam [20:0] TB_LIM5  = 21'd127;   // 25600/200 - 1
`else
  localparam [20:0] TB_LIM20 = 21'd1999999;  // 100 MHz default
  localparam [20:0] TB_LIM5  = 21'd499999;
`endif

`ifdef VERILATOR_SIM
  `define TB_DO_FIRE
`elsif FPGA_FF_MODE
  `define TB_DO_FIRE
`endif

  // ---------------------------------------------------------------- DUT I/O
  reg  sysclk;
  reg  sys_rst_n_r;
  reg  r_BDRY50N, r_CLOSC, r_CLRTIN, r_CONTINUEN, r_EMCLN, r_LOADN;
  reg  r_POWSENSE, r_PRQN, r_PWCL, r_REFN, r_RESET, r_RTOSC;
  reg  r_SEL5MSN, r_SSTOPN, r_STARTN, r_STOPN, r_TESTE;

  wire CLEAR, IDB0, IDB1, IDB2, MCL, PANN, PANOSC, POWFAILN;
  wire REFRQN, STPN, TESTO, TOUT;

  DECODE_DGA_POW dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n_r),
      .BDRY50N(r_BDRY50N),
      .CLOSC(r_CLOSC),
      .CLRTIN(r_CLRTIN),
      .CONTINUEN(r_CONTINUEN),
      .EMCLN(r_EMCLN),
      .LOADN(r_LOADN),
      .POWSENSE(r_POWSENSE),
      .PRQN(r_PRQN),
      .PWCL(r_PWCL),
      .REFN(r_REFN),
      .RESET(r_RESET),
      .RTOSC(r_RTOSC),
      .SEL5MSN(r_SEL5MSN),
      .SSTOPN(r_SSTOPN),
      .STARTN(r_STARTN),
      .STOPN(r_STOPN),
      .TESTE(r_TESTE),
      .CLEAR(CLEAR),
      .IDB0(IDB0),
      .IDB1(IDB1),
      .IDB2(IDB2),
      .MCL(MCL),
      .PANN(PANN),
      .PANOSC(PANOSC),
      .POWFAILN(POWFAILN),
      .REFRQN(REFRQN),
      .STPN(STPN),
      .TESTO(TESTO),
      .TOUT(TOUT)
  );

  always begin
    sysclk = 1'b0; #5;
    sysclk = 1'b1; #5;
  end

  // ------------------------------------------------------------ golden model
  // F595 latch states (q, qb pairs)
  reg m_stp_q, m_stp_qb;   // A571 STOP flag
  reg m_esl_q, m_esl_qb;   // A570 ESLOAD (qb = s_esload_n)
  reg m_lod_q, m_lod_qb;   // A576 LOAD flag (qb = s_lod_n)
  reg m_rst_q, m_rst_qb;   // A574 RESTART flag (qb = s_rst_n)
  reg m_con_q, m_con_qb;   // A575 CONTINUE flag (qb = s_conn_n)
  reg m_a572_q;            // A572 (s_lrst = ~q)
  // ripple chain
  reg       m_q633;        // A633 Q (rfclk = ~Q)
  reg       m_q629;        // A629 Q (PANOSC = ~Q)
  reg [5:0] m_cnt6;        // A623..A619 (TESTO = ~cnt6[5])
  reg       m_refrq_n;     // A630 Q
  reg       m_a631;        // A631 Q
  // RTC mirror
  reg [20:0] m_rtc_cnt;
  reg        m_rtc_n;
  reg [20:0] tb_lim20, tb_lim5;

  wire w_clrti_lvl = ~r_CLRTIN;
  wire w_rescl_lvl = r_CLOSC | r_RESET;

  // Independent RTC mirror: re-derived counter semantics (see header P3).
  always @(posedge sysclk) begin
    if (w_clrti_lvl) begin
      m_rtc_n   <= 1'b1;
      m_rtc_cnt <= 21'd0;
    end else if (w_rescl_lvl) begin
      m_rtc_n   <= 1'b1;
      m_rtc_cnt <= 21'd0;
    end else if (m_rtc_cnt >= (r_SEL5MSN ? tb_lim20 : tb_lim5)) begin
      m_rtc_cnt <= 21'd0;
      m_rtc_n   <= 1'b0;
    end else begin
      m_rtc_cnt <= m_rtc_cnt + 21'd1;
    end
  end

  integer checks, errors;

  task chk(input [127:0] name, input act, input exp);
    begin
      checks = checks + 1;
      if (act !== exp) begin
        errors = errors + 1;
        if (errors < 60)
          $display("FAIL @%0t %0s act=%b exp=%b", $time, name, act, exp);
      end
    end
  endtask

  // F595 settled evaluation (S&R row -> Q=1,QB=1)
  task upd595(inout q, inout qb, input s, input r, input force_idle);
    begin
      if (force_idle) begin
        q  = 1'b0;
        qb = 1'b1;
      end else if (s & r) begin
        q  = 1'b1;
        qb = 1'b1;
      end else if (r) begin
        q  = 1'b0;
        qb = 1'b1;
      end else if (s) begin
        q  = 1'b1;
        qb = 1'b0;
      end
      // else hold
    end
  endtask

  reg e_clear_n, e_mcl, e_mcl_n, e_a579n, e_fi;

  // One topological pass over the latch network at settled input levels.
  task settle_model;
    begin
      e_clear_n = sys_rst_n_r;
      e_mcl     = ~(r_EMCLN & e_clear_n);
      e_mcl_n   = ~e_mcl;
      // 20-AUG-2026 (approved): F595's VERILATOR_SIM transparent branch was
      // deleted from the RTL (sim/silicon unification) - every build now runs
      // the synchronous RS flip-flop, so the model is unconditional.
      e_fi = ~sys_rst_n_r;            // sync F595: forced idle while in reset
      upd595(m_stp_q, m_stp_qb, ~(r_SSTOPN & e_clear_n & r_STOPN), ~r_STARTN, e_fi);
      upd595(m_esl_q, m_esl_qb, m_stp_qb, r_PWCL, e_fi);
      e_a579n = ~(e_mcl_n & r_CLRTIN & m_stp_q);
      upd595(m_lod_q, m_lod_qb, ~r_LOADN, e_a579n, e_fi);
      upd595(m_rst_q, m_rst_qb, ~m_a572_q, e_a579n, e_fi);
      upd595(m_con_q, m_con_qb, ~r_CONTINUEN, e_a579n, e_fi);
    end
  endtask

  // rfclk-rise side effects (A630/A631 clocked, A629 toggles unless CLOSC)
  reg e_old_refrq;
  task ev_rfclk_rise;
    begin
      e_old_refrq = m_refrq_n;
      if (r_BDRY50N == 1'b0) m_a631 = 1'b1;
      else m_a631 = e_old_refrq;
      if (r_REFN == 1'b0) m_refrq_n = 1'b1;
      else m_refrq_n = 1'b0;
      if (r_CLOSC) m_q629 = 1'b0;
      else m_q629 = ~m_q629;
    end
  endtask

  reg e_nq633;
  task ev_rtosc_rise;
    begin
      if (r_CLOSC) e_nq633 = 1'b0;
      else e_nq633 = ~m_q633;
      if (m_q633 == 1'b1 && e_nq633 == 1'b0) ev_rfclk_rise;
      m_q633 = e_nq633;
      if (r_CLOSC | r_RESET) m_cnt6 = 6'd0;
      else m_cnt6 = m_cnt6 + 6'd1;
    end
  endtask

  task ev_closc_assert;
    begin
      if (m_q633 == 1'b1) ev_rfclk_rise;  // CLOSC-forced rfclk rise
      m_q633 = 1'b0;
      m_q629 = 1'b0;
      m_cnt6 = 6'd0;
    end
  endtask

  // sys_rst_n release event ordering (header P1)
  task ev_rst_release;
    begin
      m_a572_q = (~r_CLRTIN) ? 1'b1 : m_esl_qb;
      settle_model;
    end
  endtask

  task ev_clrti_assert;
    begin
      m_a572_q = 1'b1;
      settle_model;
    end
  endtask

  task tb_settle;
    begin
      repeat (4) @(negedge sysclk);
      #1;
    end
  endtask

  reg e_prq, e_a597, e_a598, e_a599, e_a592, e_rfclk;
  task check_all;
    begin
      settle_model;
      settle_model;
      e_prq   = ~r_PRQN;
      e_a597  = ~(m_con_qb & m_lod_qb & e_prq);
      e_a598  = ~(m_rst_qb & ~m_con_qb);
      e_a599  = ~(~m_rtc_n & r_PRQN & m_lod_qb & m_rst_qb);
      e_a592  = ~(e_mcl_n & m_rst_qb & m_con_qb & m_lod_qb & r_PRQN & m_rtc_n & m_stp_qb);
      e_rfclk = ~m_q633;
      chk("CLEAR", CLEAR, ~e_clear_n);
      chk("MCL", MCL, e_mcl);
      chk("POWFAILN", POWFAILN, 1'b1);
      chk("STPN", STPN, m_stp_qb);
      chk("IDB2", IDB2, ~(m_lod_qb & m_con_qb & m_rst_qb & e_mcl_n));
      chk("IDB1", IDB1, ~(e_a597 & m_rst_qb & e_mcl_n));
      chk("IDB0", IDB0, ~(e_mcl_n & e_a598 & e_a599));
      chk("PANN", PANN, ~(r_SSTOPN & e_a592));
      chk("TESTO", TESTO, ~m_cnt6[5]);
      chk("PANOSC", PANOSC, ~m_q629);
      chk("REFRQN", REFRQN, m_refrq_n);
      chk("TOUT", TOUT, ~(m_a631 | e_rfclk));
      chk("RTC_N", dut.s_rtc_n, m_rtc_n);
      chk("A620Y", dut.s_a620_y, r_TESTE ? r_RTOSC : ~m_cnt6[5]);
    end
  endtask

  task step_check;
    begin
      tb_settle;
      check_all;
    end
  endtask

  // ------------------------------------------------------- stimulus helpers
  task rtosc_rise_t;
    begin
      @(negedge sysclk);
      r_RTOSC = 1'b1;
      ev_rtosc_rise;
      step_check;
    end
  endtask

  task rtosc_fall_t;
    begin
      @(negedge sysclk);
      r_RTOSC = 1'b0;
      step_check;
    end
  endtask

  task refn_pulse;
    begin
      @(negedge sysclk);
      r_REFN = 1'b0;
      m_refrq_n = 1'b1;
      repeat (2) @(negedge sysclk);
      r_REFN = 1'b1;
      step_check;
    end
  endtask

  task bdry_pulse;
    begin
      @(negedge sysclk);
      r_BDRY50N = 1'b0;
      m_a631 = 1'b1;
      repeat (2) @(negedge sysclk);
      r_BDRY50N = 1'b1;
      step_check;
    end
  endtask

  task closc_pulse;
    begin
      @(negedge sysclk);
      r_CLOSC = 1'b1;
      ev_closc_assert;
      repeat (3) @(negedge sysclk);
      r_CLOSC = 1'b0;
      step_check;
    end
  endtask

  task reset_pulse;
    begin
      @(negedge sysclk);
      r_RESET = 1'b1;
      m_cnt6 = 6'd0;
      repeat (3) @(negedge sysclk);
      r_RESET = 1'b0;
      step_check;
    end
  endtask

  task clrtin_pulse;
    begin
      @(negedge sysclk);
      r_CLRTIN = 1'b0;
      ev_clrti_assert;
      step_check;  // mid-pulse: a579n=1, flags reset, RTC re-armed
      @(negedge sysclk);
      r_CLRTIN = 1'b1;
      step_check;
    end
  endtask

  // Active-low pulse on one input, selected by index (task inout args are
  // copy-in/copy-out in Verilog, so the regs are driven via a case instead):
  // 0=STARTN 1=STOPN 2=SSTOPN 3=LOADN 4=CONTINUEN
  task npulse(input integer sel);
    begin
      @(negedge sysclk);
      case (sel)
        0: r_STARTN = 1'b0;
        1: r_STOPN = 1'b0;
        2: r_SSTOPN = 1'b0;
        3: r_LOADN = 1'b0;
        4: r_CONTINUEN = 1'b0;
      endcase
      step_check;  // mid-pulse level check (also settles the model)
      @(negedge sysclk);
      case (sel)
        0: r_STARTN = 1'b1;
        1: r_STOPN = 1'b1;
        2: r_SSTOPN = 1'b1;
        3: r_LOADN = 1'b1;
        4: r_CONTINUEN = 1'b1;
      endcase
      step_check;
    end
  endtask

  task warm_rst_pulse;
    begin
      @(negedge sysclk);
      sys_rst_n_r = 1'b0;
      step_check;  // in-reset state (per-build forced/transparent, model knows)
      @(negedge sysclk);
      sys_rst_n_r = 1'b1;
      ev_rst_release;
      step_check;
    end
  endtask

  // RTC fire-timing test: pulse CLRTIN, then count sysclk edges to the fire.
  integer fn;
  reg f_fired;
  task rtc_fire_test(input [20:0] limit);
    begin
      @(negedge sysclk);
      r_CLRTIN = 1'b0;
      ev_clrti_assert;
      repeat (3) @(negedge sysclk);
      r_CLRTIN = 1'b1;
      fn = 0;
      f_fired = 1'b0;
      while (!f_fired && fn < (limit + 21'd10)) begin
        @(posedge sysclk);
        #1;
        fn = fn + 1;
        if (dut.s_rtc_n === 1'b0) f_fired = 1'b1;
      end
      chk("RTC_FIRE_EDGE", (f_fired && (fn == limit + 1)) ? 1'b1 : 1'b0, 1'b1);
      // P3: latched until cleared
      repeat (60) @(posedge sysclk);
      #1;
      chk("RTC_LATCHED", dut.s_rtc_n, 1'b0);
      step_check;
    end
  endtask

  // ------------------------------------------------------------------- soak
  reg [31:0] lfsr;
  function [31:0] xnext(input [31:0] x);
    reg [31:0] y;
    begin
      y = x ^ (x << 13);
      y = y ^ (y >> 17);
      y = y ^ (y << 5);
      xnext = y;
    end
  endfunction

  integer i, act;

  initial begin
    checks = 0;
    errors = 0;
    tb_lim20 = TB_LIM20;
    tb_lim5  = TB_LIM5;

    // idle input levels
    sys_rst_n_r = 1'b0;
    r_BDRY50N = 1'b1;
    r_CLOSC = 1'b0;
    r_CLRTIN = 1'b1;
    r_CONTINUEN = 1'b1;
    r_EMCLN = 1'b1;
    r_LOADN = 1'b1;
    r_POWSENSE = 1'b0;
    r_PRQN = 1'b1;
    r_PWCL = 1'b0;
    r_REFN = 1'b1;
    r_RESET = 1'b0;
    r_RTOSC = 1'b0;
    r_SEL5MSN = 1'b1;
    r_SSTOPN = 1'b1;
    r_STARTN = 1'b1;
    r_STOPN = 1'b1;
    r_TESTE = 1'b0;

    // model init (aligned by the power-up sequence below)
    m_stp_q = 1'b0; m_stp_qb = 1'b1;
    m_esl_q = 1'b0; m_esl_qb = 1'b1;
    m_lod_q = 1'b0; m_lod_qb = 1'b1;
    m_rst_q = 1'b0; m_rst_qb = 1'b1;
    m_con_q = 1'b0; m_con_qb = 1'b1;
    m_a572_q = 1'b0;
    m_q633 = 1'b0;
    m_q629 = 1'b0;
    m_cnt6 = 6'd0;
    m_refrq_n = 1'b1;
    m_a631 = 1'b1;
    m_rtc_cnt = 21'd0;
    m_rtc_n = 1'b1;

    // ------------------------------------------------- A. power-up sequence
    repeat (2) @(negedge sysclk);
    r_CLOSC = 1'b1;   // CLOSC high briefly at power-on (clears the chain X)
    r_RESET = 1'b1;
    ev_closc_assert;
    m_cnt6 = 6'd0;
    repeat (4) @(negedge sysclk);
    // Deterministic F617 init: one REFN and one BDRY50N pulse while in reset
    r_REFN = 1'b0;
    m_refrq_n = 1'b1;
    repeat (2) @(negedge sysclk);
    r_REFN = 1'b1;
    r_BDRY50N = 1'b0;
    m_a631 = 1'b1;
    repeat (2) @(negedge sysclk);
    r_BDRY50N = 1'b1;
    step_check;  // in-reset, CLOSC+RESET high: CLEAR=1, MCL=1, IDBx=1
    // explicit reset-window landmarks
    chk("PU_CLEAR", CLEAR, 1'b1);
    chk("PU_MCL", MCL, 1'b1);
    chk("PU_IDB2", IDB2, 1'b1);
    chk("PU_IDB1", IDB1, 1'b1);
    chk("PU_IDB0", IDB0, 1'b1);
    @(negedge sysclk);
    r_CLOSC = 1'b0;
    r_RESET = 1'b0;
    step_check;
    @(negedge sysclk);
    sys_rst_n_r = 1'b1;
    ev_rst_release;
    step_check;
    chk("PU_CLEAR0", CLEAR, 1'b0);
    chk("PU_MCL0", MCL, 1'b0);
    // P1/P2: with the sync F595 in every build (transparent branch deleted
    // 20-AUG-2026), the forced-idle window swallows the release race.
    chk("PU_RSTFLAG", dut.s_rst_n, 1'b1);
    chk("PU_STPN", STPN, 1'b1);
    // CLRTIN clears lrst and the RESTART flag in every build
    clrtin_pulse;
    chk("PU_RSTCLR", dut.s_rst_n, 1'b1);

    // --------------------------------------------------- B. flag directed
    // START: clear the STOP flag -> running (STPN=1)
    npulse(0);
    chk("B_RUN_STPN", STPN, 1'b1);
    chk("B_ESLOADN", dut.s_esload_n, 1'b0);  // running arms ESLOAD (S=STPN)
    // STOP: set the STOP flag
    npulse(1);
    chk("B_STOP_STPN", STPN, 1'b0);
    // SSTOP also sets it (after a re-start)
    npulse(0);
    npulse(2);
    chk("B_SSTOP_STPN", STPN, 1'b0);
    // LOAD latches only while stopped (a579n=0)
    npulse(3);
    chk("B_LOD_IDB2", IDB2, 1'b1);
    chk("B_LOD_IDB1", IDB1, 1'b0);
    chk("B_LOD_IDB0", IDB0, 1'b0);
    // starting the machine clears the LOAD flag (stp -> 0 -> a579n=1)
    npulse(0);
    chk("B_LODCLR_IDB2", IDB2, 1'b0);
    // LOAD while running does NOT latch (S&R -> QB=1, then R-only reset)
    npulse(3);
    chk("B_LODRUN_IDB2", IDB2, 1'b0);
    // CONTINUE latches while stopped: IDB2 + IDB0 code
    npulse(1);
    npulse(4);
    chk("B_CON_IDB2", IDB2, 1'b1);
    chk("B_CON_IDB0", IDB0, 1'b1);
    npulse(0);  // clears CONTINUE flag
    chk("B_CONCLR_IDB2", IDB2, 1'b0);
    // PRQ code: IDB1 while no conn/lod flag
    @(negedge sysclk);
    r_PRQN = 1'b0;
    step_check;
    chk("B_PRQ_IDB1", IDB1, 1'b1);
    chk("B_PRQ_PANN", PANN, 1'b0);
    @(negedge sysclk);
    r_PRQN = 1'b1;
    step_check;
    // EMCLN master clear: all IDB codes + PANN, flags wiped
    npulse(1);
    npulse(3);  // set a flag to be wiped
    @(negedge sysclk);
    r_EMCLN = 1'b0;
    step_check;
    chk("B_MCL", MCL, 1'b1);
    chk("B_MCL_IDB2", IDB2, 1'b1);
    chk("B_MCL_IDB1", IDB1, 1'b1);
    chk("B_MCL_IDB0", IDB0, 1'b1);
    chk("B_MCL_PANN", PANN, 1'b0);
    @(negedge sysclk);
    r_EMCLN = 1'b1;
    step_check;
    chk("B_MCLREL_IDB2", IDB2, 1'b0);  // LOAD flag was wiped by MCL
    // Warm restart: run, then pulse sys_rst_n (P1 per-build outcome)
    npulse(0);
    chk("B_WARM_ESL", dut.s_esload_n, 1'b0);
    warm_rst_pulse;
    chk("B_WARM_RST", dut.s_rst_n, 1'b1);
    chk("B_WARM_IDB2", IDB2, 1'b0);
    clrtin_pulse;
    chk("B_WARMCLR_RST", dut.s_rst_n, 1'b1);
    // PWCL: S&R row on A570 (P4) - while running, PWCL forces ESLOADN=1
    npulse(0);
    @(negedge sysclk);
    r_PWCL = 1'b1;
    step_check;
    chk("B_PWCL_ESL", dut.s_esload_n, 1'b1);
    @(negedge sysclk);
    r_PWCL = 1'b0;
    step_check;
    chk("B_PWCLREL_ESL", dut.s_esload_n, 1'b0);  // re-set (S=STPN=1)
    // POWSENSE is a no-op input in the FPGA version
    @(negedge sysclk);
    r_POWSENSE = 1'b1;
    step_check;
    @(negedge sysclk);
    r_POWSENSE = 1'b0;
    step_check;

    // ----------------------------------------------------------- C. RTC
    // static limit checks (divider-length arithmetic, both SEL5MSN values)
    chk("C_LIM20", (dut.s_rtc_limit === TB_LIM20) ? 1'b1 : 1'b0, 1'b1);
    @(negedge sysclk);
    r_SEL5MSN = 1'b0;
    #1;
    chk("C_LIM5", (dut.s_rtc_limit === TB_LIM5) ? 1'b1 : 1'b0, 1'b1);
    @(negedge sysclk);
    r_SEL5MSN = 1'b1;
    step_check;
`ifdef TB_DO_FIRE
    // machine running, RTC armed: fire at limit+1 edges, then PANN=0
    rtc_fire_test(TB_LIM20);
    chk("C_FIRE_PANN", PANN, 1'b0);   // level-13 request line via A592
    clrtin_pulse;                      // CLRTIN re-arms
    chk("C_REARM_PANN", PANN, 1'b1);
    chk("C_REARM_RTCN", dut.s_rtc_n, 1'b1);
    // 5 ms path
    @(negedge sysclk);
    r_SEL5MSN = 1'b0;
    rtc_fire_test(TB_LIM5);
    // RESET (RESCL) also re-arms
    reset_pulse;
    chk("C_RESCL_RTCN", dut.s_rtc_n, 1'b1);
    @(negedge sysclk);
    r_SEL5MSN = 1'b1;
    step_check;
`endif
`ifdef VERILATOR_SIM
    // runtime-tunable period regs (public_flat_rw pair): poke and re-measure
    @(negedge sysclk);
    dut.s_rtc_20ms_var = 21'd97;
    tb_lim20 = 21'd97;
    #1;
    chk("C_POKE20_LIM", (dut.s_rtc_limit === 21'd97) ? 1'b1 : 1'b0, 1'b1);
    rtc_fire_test(21'd97);
    @(negedge sysclk);
    dut.s_rtc_5ms_var = 21'd25;
    tb_lim5 = 21'd25;
    r_SEL5MSN = 1'b0;
    #1;
    chk("C_POKE5_LIM", (dut.s_rtc_limit === 21'd25) ? 1'b1 : 1'b0, 1'b1);
    rtc_fire_test(21'd25);
    // restore build defaults
    @(negedge sysclk);
    dut.s_rtc_20ms_var = TB_LIM20;
    dut.s_rtc_5ms_var  = TB_LIM5;
    tb_lim20 = TB_LIM20;
    tb_lim5  = TB_LIM5;
    r_SEL5MSN = 1'b1;
    clrtin_pulse;
`endif
    clrtin_pulse;  // leave the RTC re-armed for the rest of the run

    // ------------------------------------------- D. TOUT directed script
    // known phase: chain cleared, request/monitor flops set
    closc_pulse;
    refn_pulse;
    bdry_pulse;
    chk("D_INIT_TOUT", TOUT, 1'b0);
    chk("D_INIT_REFRQN", REFRQN, 1'b1);
    rtosc_rise_t;                       // q633=1, rfclk=0
    chk("D_S1_TOUT", TOUT, 1'b0);
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk rise 1: request raised
    chk("D_S2_REFRQN", REFRQN, 1'b0);
    chk("D_S2_TOUT", TOUT, 1'b0);
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk low half: grace period
    chk("D_S3_TOUT", TOUT, 1'b0);
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk rise 2: unacked -> A631=0
    chk("D_S4_TOUT", TOUT, 1'b0);       // still masked by rfclk=1
    chk("D_S4_REFRQN", REFRQN, 1'b0);
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk falls: TIMEOUT
    chk("D_S5_TOUT", TOUT, 1'b1);
    // BDRY50N clears TOUT immediately
    bdry_pulse;
    chk("D_BDRY_TOUT", TOUT, 1'b0);
    // periodic re-assert: next rfclk cycle re-arms and re-fires
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk rise: A631 <= 0 again
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk low: TOUT again
    chk("D_S7_TOUT", TOUT, 1'b1);
    // REFN ack: does not clear TOUT immediately...
    refn_pulse;
    chk("D_ACK_TOUT", TOUT, 1'b1);
    // ...but the next rfclk rise loads A631=1 and the cycle stays clean
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk rise: A631 <= 1, new request
    chk("D_S8_TOUT", TOUT, 1'b0);
    rtosc_fall_t;
    rtosc_rise_t;                       // rfclk low: no timeout (A631=1)
    chk("D_S9_TOUT", TOUT, 1'b0);
    // recreate TOUT, then CLOSC clears it (forces rfclk=1)
    rtosc_fall_t;
    rtosc_rise_t;                       // rise: A631 <= 0
    rtosc_fall_t;
    rtosc_rise_t;                       // low: TOUT
    chk("D_S10_TOUT", TOUT, 1'b1);
    closc_pulse;
    chk("D_CLOSC_TOUT", TOUT, 1'b0);
    @(negedge sysclk);
    r_RTOSC = 1'b0;
    step_check;

    // ------------------------------------------------ E. divider sweep
    // free-running, no acks: TESTO=/64, PANOSC=/4, TOUT periodic
    for (i = 0; i < 130; i = i + 1) begin
      rtosc_rise_t;
      rtosc_fall_t;
    end
    // acked refresh cadence: REFN pulse every 4 RTOSC rises - no TOUT
    for (i = 0; i < 32; i = i + 1) begin
      rtosc_rise_t;
      rtosc_fall_t;
      if ((i % 4) == 3) begin
        refn_pulse;
        chk("E_ACK_TOUT", TOUT, 1'b0);
      end
    end

    // ------------------------------------------------------- F. hold
    repeat (100) @(negedge sysclk);
    step_check;
    repeat (100) @(negedge sysclk);
    step_check;

    // ------------------------------------------------------- G. soak
    lfsr = 32'h9C0FFEE1;
    for (i = 0; i < 4000; i = i + 1) begin
      lfsr = xnext(lfsr);
      act  = lfsr % 18;
      case (act)
        0: begin
          @(negedge sysclk);
          if (r_RTOSC) r_RTOSC = 1'b0;
          else begin
            r_RTOSC = 1'b1;
            ev_rtosc_rise;
          end
        end
        1: begin
          @(negedge sysclk);
          r_REFN = 1'b0;
          m_refrq_n = 1'b1;
          repeat (2) @(negedge sysclk);
          r_REFN = 1'b1;
        end
        2: begin
          @(negedge sysclk);
          r_BDRY50N = 1'b0;
          m_a631 = 1'b1;
          repeat (2) @(negedge sysclk);
          r_BDRY50N = 1'b1;
        end
        3: begin
          @(negedge sysclk);
          r_STARTN = 1'b0;
          settle_model;
          repeat (2) @(negedge sysclk);
          r_STARTN = 1'b1;
        end
        4: begin
          @(negedge sysclk);
          r_STOPN = 1'b0;
          settle_model;
          repeat (2) @(negedge sysclk);
          r_STOPN = 1'b1;
        end
        5: begin
          @(negedge sysclk);
          r_SSTOPN = 1'b0;
          settle_model;
          repeat (2) @(negedge sysclk);
          r_SSTOPN = 1'b1;
        end
        6: begin
          @(negedge sysclk);
          r_LOADN = 1'b0;
          settle_model;
          repeat (2) @(negedge sysclk);
          r_LOADN = 1'b1;
        end
        7: begin
          @(negedge sysclk);
          r_CONTINUEN = 1'b0;
          settle_model;
          repeat (2) @(negedge sysclk);
          r_CONTINUEN = 1'b1;
        end
        8: begin
          @(negedge sysclk);
          r_EMCLN = 1'b0;
          settle_model;
          repeat (2) @(negedge sysclk);
          r_EMCLN = 1'b1;
        end
        9: begin
          @(negedge sysclk);
          r_PRQN = ~r_PRQN;
        end
        10: begin
          @(negedge sysclk);
          r_CLRTIN = 1'b0;
          ev_clrti_assert;
          repeat (2) @(negedge sysclk);
          r_CLRTIN = 1'b1;
        end
        11: begin
          @(negedge sysclk);
          r_TESTE = ~r_TESTE;
        end
        12: begin
          @(negedge sysclk);
          r_SEL5MSN = ~r_SEL5MSN;
        end
        13: begin
          @(negedge sysclk);
          r_PWCL = ~r_PWCL;
        end
        14: begin
          @(negedge sysclk);
          r_CLOSC = 1'b1;
          ev_closc_assert;
          repeat (2) @(negedge sysclk);
          r_CLOSC = 1'b0;
        end
        15: begin
          @(negedge sysclk);
          r_RESET = 1'b1;
          m_cnt6 = 6'd0;
          repeat (2) @(negedge sysclk);
          r_RESET = 1'b0;
        end
        16: begin
          @(negedge sysclk);
          sys_rst_n_r = 1'b0;
          repeat (2) @(negedge sysclk);
          settle_model;
          sys_rst_n_r = 1'b1;
          ev_rst_release;
        end
        17: begin
          @(negedge sysclk);
          r_POWSENSE = ~r_POWSENSE;
        end
      endcase
      step_check;
    end

    // --------------------------------------------------------- verdict
    $display("checks=%0d errors=%0d (expected %0d)", checks, errors, EXPECTED_CHECKS);
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
