`timescale 1ns / 1ps

/**************************************************************************
** Testbench for DECODE_DGA_COMM - microcode COMM command decode sheet   **
** (DGA pages 16-19): CSCOMM/CSMIS strobe decode, memory-cycle type     **
** registers (RT/DT/FETCH/MREQ/FORM/WRITE/SHORT/SLOW), IORQ/RWCS/DVACC, **
** SSEMA semaphore FSM, SIOC-loaded RESET/EMCL flags, cache-clear       **
** (A204 + F595 CCLRN) and the comb ECREQ/STOCN/ESTOFN/EMPID/LDPANC    **
** output gates.                                                         **
**                                                                       **
** Clocked primitives: six D_FLIPFLOP_EN (MEMORY_63 CA10 w/ async       **
** WRITE&UCLK clear, A226, A232, A227, MEMORY_68/66 w/ async CLEAR),    **
** seven F924_EN 4-bit registers (A181/A214/A140/A187/A160/A188), the   **
** CLK3-FALL flop A204, and the F595 RS latch (CCLRN). CLK1/CLK2/CLK3   **
** are all the board XCLK in the parent (DECODE_DGA.v) and are driven   **
** together here except in the default-build clock-group routing phase. **
**                                                                       **
** Build modes (all four ifdef combinations differ):                     **
**   plain                        - regs on routed CLK nets, F595       **
**                                  sampled synchronously on sysclk     **
**   -DVERILATOR_SIM              - regs on CLK nets, F595 TRANSPARENT  **
**   -DFPGA_FF_MODE               - regs on sysclk + CLK_EN/CLK_FALL_EN,**
**                                  F595 synchronous (the FPGA config)  **
**   -DVERILATOR_SIM -DFPGA_FF_MODE - FF regs + transparent F595        **
**                                                                       **
** INDEPENDENT golden model, re-derived from the gate structure as an    **
** octal command map (never a net-by-net transliteration):               **
**   o05:CEUART(+SLOW kill)  o06&M=10:LDPANC  o07:SIOC (the NEXT CLK3   **
**   rise loads RESET<=IDBI7 and EMCLN<=IDBI5 while SIOCN is low)       **
**   o12:EMPID  o13:START  o14:SSTOP  o15:CLRTI                         **
**   o21&M=00:WCHIM  o21&M=01:SSEMA set + DVACC  o21&M=10:CCLR (A204    **
**   captures the decode on the CLK3 FALL, F595 then pulls CCLRN low    **
**   for the following CLK3-high phase)  o21&M=11: arms A226 to load    **
**   IDBI2 on the next CLK2 rise (a214_q0=0 window)                     **
**   o22(M1x or M0x per gate)/o23/o24-o27/o30-o35: memory-cycle family  **
**   feeding RT/DT/FETCH/MREQ/FORM/WRITE/CA10 group ORs                 **
**   o36&M0:RWCS(M=01)+SLOW kill  o37&M1:IORQ+DVACC                     **
**   SHORT = OR of seven M/C group products; DVACC also fires whenever  **
**   PONI=0, and via a226_q_n & M=11 & o34/o35.                         **
**                                                                       **
** PINNED RTL behaviors (documented, not patched):                       **
**  P1. Power-on flops are 0, so before the first clock many active-low **
**      outputs read ASSERTED: SSTOPN=STARTN=WCHIMN=CLRTIN=SIOCN=       **
**      CEUARTN=RWCSN=IORQN=EMCLN=SLOWN=0 and LHIT=1; the internal IORQ **
**      side reads 1 so ECREQ/STOCN can assert before any command.      **
**  P2. F595 latency split (the known FPGA divergence class, same as    **
**      the "TVEC=016 miss after COMM.CONTINUE" warning): with a CCLR   **
**      pending (a204_q=0), a CLK3 rise pulls CCLRN low IMMEDIATELY in  **
**      VERILATOR_SIM builds (transparent latch) but only at the NEXT   **
**      posedge sysclk in plain/FPGA builds (synchronous branch).       **
**  P3. sys_rst_n split: the non-VERILATOR F595 branch forces CCLRN=1   **
**      while sys_rst_n=0; the VERILATOR_SIM branch IGNORES sys_rst_n   **
**      completely (CCLRN stays asserted through reset).                **
**  P4. Power-on CCLR split (default-vs-FPGA_FF_MODE): A204 clocks on   **
**      the INVERTED net s_clk3_n, which transitions X->1 at t=0 - a    **
**      phantom posedge that loads A204 with the idle a189 value (1) in **
**      the routed-net builds, so the first CLK3-high phase does NOT    **
**      assert CCLRN. In FPGA_FF_MODE (sysclk+CLK_FALL_EN) there is no  **
**      phantom edge, a204_q stays 0, and the FIRST CLK3-high phase     **
**      asserts CCLRN (boot cache auto-clear) until a CLK3 fall with a  **
**      non-CCLR command loads a204_q=1.                                **
**  P5. The net s_mreq (port MREQ, no _n suffix) is the Q-BAR tap of    **
**      A160: it idles 1 and goes LOW during memory-reference commands. **
**      The parent confirms the polarity (wires it to s_xmrn).          **
**  P6. ESTOFN = LSHADOW & RT (A246 plain AND): deasserted (high) ONLY  **
**      during an RT cycle with LSHADOW=1; low (asserted) at idle.      **
**  P7. FMISS D-input = (LCSN & MREQ & FMISS) | (LCSN & SSEMA): FMISS   **
**      is SET from the SSEMA flag and HOLDS while the active-low MREQ  **
**      is deasserted (high). Unusual coupling, pinned as-is.           **
**  P8. In FPGA_FF_MODE the CLK1/CLK2/CLK3 register groups share the    **
**      single CLK_EN and cannot be clocked separately; the clock-group **
**      routing layer therefore runs only in the default builds.        **
**                                                                       **
** Layers:                                                               **
**  A. Power-on state (full 29-output check + pinned literal checks).   **
**  B. Exhaustive decode sweep: LCSN x M x C = 256 combos, full rise +  **
**     full fall, 29-output check after each edge, misc inputs varied   **
**     deterministically per combo.                                     **
**  C. Directed walks: SSEMA set/hold/release + FMISS coupling, IORQ +  **
**     ECREQ/STOCN comb terms, SIOC->RESET/EMCL load + async CLEAR,     **
**     CA10 all five product groups + async WRITE&UCLK clear, RT/LHIT   **
**     capture-vs-hold, DVACC PONI/a226 paths (incl. the o21&M=11 arm   **
**     window), EMPID/LDPANC latched+comb-gate, 4x32 comb-output combo  **
**     sweep, no-clock hold, CCLR pipeline, F595 latency (P2) and       **
**     sys_rst_n (P3) pinned checks.                                    **
**  D. (default builds only) Clock-group routing: CLK1-only, CLK2-only, **
**     CLK3-only rises prove which register sits on which clock pin.    **
**  E. 4000-step fixed-seed xorshift32 soak (seed 32'h5EED_C044),       **
**     steered command codes, random rise+fall / no-clock events, full  **
**     29-output check after every event.                               **
**                                                                       **
** Ronny Hansen                                                          **
** 01-AUG-2026                                                           **
***************************************************************************/

module DECODE_DGA_COMM_tb;

`ifdef FPGA_FF_MODE
  localparam EXPECTED_CHECKS = 218781;
`else
  localparam EXPECTED_CHECKS = 219100;  // + clock-group routing layer
`endif

  reg       sysclk;
  reg       sys_rst_n;
  reg       CLK_EN;
  reg       CLK_FALL_EN;
  reg       BRKN;
  reg       CLEAR;
  reg       CLK1;
  reg       CLK2;
  reg       CLK3;
  reg [4:0] C;      // CSCOMM_4_0
  reg [1:0] M;      // CSMIS_1_0
  reg       DAPN;
  reg       EORFN;
  reg       HITN;
  reg       IDBI2;
  reg       IDBI5;
  reg       IDBI7;
  reg       L;      // LCSN
  reg       LSHADOW;
  reg       PONI;
  reg       UCLK;

  wire CA10, CCLRN, CEUARTN, CLRTIN, DTN, DVACCN, ECREQ, EMCLN, EMPIDN;
  wire ESTOFN, FETCH, FMISS, FORMN, IORQN, LDPANCN, LHIT, MREQ, RESET;
  wire RTN, RWCSN, SHORTN, SIOCN, SLOWN, SSEMAN, SSTOPN, STARTN, STOCN;
  wire WCHIMN, WRITE;

  DECODE_DGA_COMM dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .CLK_EN(CLK_EN),
      .CLK_FALL_EN(CLK_FALL_EN),
      .BRKN(BRKN),
      .CLEAR(CLEAR),
      .CLK1(CLK1),
      .CLK2(CLK2),
      .CLK3(CLK3),
      .CSCOMM_4_0(C),
      .CSMIS_1_0(M),
      .DAPN(DAPN),
      .EORFN(EORFN),
      .HITN(HITN),
      .IDBI2(IDBI2),
      .IDBI5(IDBI5),
      .IDBI7(IDBI7),
      .LCSN(L),
      .LSHADOW(LSHADOW),
      .PONI(PONI),
      .UCLK(UCLK),
      .CA10(CA10),
      .CCLRN(CCLRN),
      .CEUARTN(CEUARTN),
      .CLRTIN(CLRTIN),
      .DTN(DTN),
      .DVACCN(DVACCN),
      .ECREQ(ECREQ),
      .EMCLN(EMCLN),
      .EMPIDN(EMPIDN),
      .ESTOFN(ESTOFN),
      .FETCH(FETCH),
      .FMISS(FMISS),
      .FORMN(FORMN),
      .IORQN(IORQN),
      .LDPANCN(LDPANCN),
      .LHIT(LHIT),
      .MREQ(MREQ),
      .RESET(RESET),
      .RTN(RTN),
      .RWCSN(RWCSN),
      .SHORTN(SHORTN),
      .SIOCN(SIOCN),
      .SLOWN(SLOWN),
      .SSEMAN(SSEMAN),
      .SSTOPN(SSTOPN),
      .STARTN(STARTN),
      .STOCN(STOCN),
      .WCHIMN(WCHIMN),
      .WRITE(WRITE)
  );

  always #5 sysclk = ~sysclk;

  integer checks, errors;
  reg lvl;  // tracked XCLK level (0=low, 1=high) - edge discipline guard

  /*************************************************************************
   ** Independent golden model state (register level, init 0 like RTL)    **
   *************************************************************************/
  // CLK1 group
  reg g_ca10, g_lhitn;
  // CLK2 group
  reg g_a226, g_dvr, g_q0, g_r1, g_rwcsn, g_iorqn;
  reg g_fetch, g_dtr, g_rt, g_fmiss, g_formr, g_mreqr, g_write;
  // CLK3 group
  reg g_reset, g_sstopn, g_ceuartn, g_ssema;
  reg g_clrtin, g_siocn, g_empl, g_slown;
  reg g_startn, g_ldpl, g_wchimn, g_emcln;
  // CLK3-fall flop + F595 output state
  reg g_a204, g_qb;

  // Captured-D temporaries
  reg d_ca10, d_lhitn, d_a226, d_dvr, d_q0, d_r1, d_rwcsn, d_iorqn;
  reg d_fetch, d_dtr, d_rt, d_fmiss, d_formr, d_mreqr, d_write;
  reg d_reset, d_sstopn, d_ceuartn, d_ssema;
  reg d_clrtin, d_siocn, d_empl, d_slown;
  reg d_startn, d_ldpl, d_wchimn, d_emcln;

  task gold_dvals;
    reg p37m1, p21m01, p21m00, p21m11;
    reg g2427, g2327, p36m01, p05, g3031, p14, g3034;
    reg shA, shB, shC, shD, shE, shF, shG;
    reg p36m0nl, p05nl, g3233, g30313435, p12, p22nm1, p22m11, p22m1;
    reg p07, p15, p35, p06m10, p13;
    reg mreq_c, p215, p224;
    begin
      // Command-code products (all gated by LCSN unless noted)
      p37m1     = L & M[1] & (C == 5'o37);
      p21m01    = L & (M == 2'b01) & (C == 5'o21);
      p21m00    = L & (M == 2'b00) & (C == 5'o21);
      p21m11    = L & (M == 2'b11) & (C == 5'o21);
      g2427     = L & C[4] & ~C[3] & C[2];            // o24..o27
      g2327     = L & C[4] & ~C[3] & C[1] & C[0];     // o23,o27
      p36m01    = L & (M == 2'b01) & (C == 5'o36);
      p05       = L & (C == 5'o05);
      g3031     = L & C[4] & C[3] & ~C[2] & ~C[1];    // o30,o31
      p14       = L & (C == 5'o14);
      g3034     = L & C[4] & C[3] & ~C[1] & ~C[0];    // o30,o34
      shA       = L & M[0] & ~C[4] & C[2] & C[1];     // o06,07,16,17
      shB       = L & M[0] & ~C[3] & ~C[2] & ~C[1];   // o00,01,20,21
      shC       = L & M[1] & ~C[3] & ~C[2] & ~C[1];   // o00,01,20,21
      shD       = L & ~C[4] & C[2] & ~C[1] & ~C[0];   // o04,o14
      shE       = L & ~C[3] & ~C[2] & ~C[1] & ~C[0];  // o00,o20
      shF       = L & ~C[4] & ~C[3] & ~C[2];          // o00..o03
      shG       = L & ~C[4] & C[3] & C[2];            // o14..o17
      p36m0nl   = (C == 5'o36) & M[0];                // A185 has no LCSN pin
      p05nl     = (C == 5'o05);                       // A198 has no LCSN pin
      g3233     = L & C[4] & C[3] & ~C[2] & C[1];     // o32,o33
      g30313435 = L & C[4] & C[3] & ~C[1];            // o30,31,34,35
      p12       = L & (C == 5'o12);
      p22nm1    = L & ~M[1] & (C == 5'o22);
      p22m11    = L & M[1] & M[0] & (C == 5'o22);
      p22m1     = L & M[1] & (C == 5'o22);
      p07       = L & (C == 5'o07);
      p15       = L & (C == 5'o15);
      p35       = L & (C == 5'o35);
      p06m10    = L & (M == 2'b10) & (C == 5'o06);
      p13       = L & (C == 5'o13);
      // Pre-edge state-dependent helpers
      mreq_c    = ~g_mreqr;                            // active-low MREQ (P5)
      p215      = L & ~g_a226 & (M == 2'b11) & C[4] & C[3] & C[2] & ~C[1];
      p224      = L & ~PONI;
      // Register D values
      d_ca10    = p22m11 | g2327 | p35 | g2427 | g3233;
      d_lhitn   = g_rt ? HITN : g_lhitn;
      d_a226    = g_q0 ? g_a226 : IDBI2;
      d_dvr     = p37m1 | p215 | p224;
      d_q0      = ~p21m11;
      d_r1      = shA | shB | shC | shD | shE | shF | shG;
      d_rwcsn   = ~p36m01;
      d_iorqn   = ~p37m1;
      d_fetch   = g2427 | g2327 | p22m11;
      d_dtr     = g3233 | g30313435 | p22nm1;
      d_rt      = g2427 | p22m11 | p22nm1 | g3034 | g2327 | g3031;
      d_fmiss   = (L & mreq_c & g_fmiss) | (L & g_ssema);
      d_formr   = p22m1 | g2427 | g2327;
      d_mreqr   = p22nm1 | p22m11 | g2427 | g2327 | g30313435 | g3233;
      d_write   = g3233 | p35;
      d_reset   = g_siocn ? g_reset : IDBI7;
      d_sstopn  = ~p14;
      d_ceuartn = ~p05;
      d_ssema   = (g_ssema & mreq_c & L) | p21m01;
      d_clrtin  = ~p15;
      d_siocn   = ~p07;
      d_empl    = p12;
      d_slown   = p36m0nl | p05nl | ~L;
      d_startn  = ~p13;
      d_ldpl    = p06m10;
      d_wchimn  = ~p21m00;
      d_emcln   = g_siocn ? g_emcln : IDBI5;
    end
  endtask

  task gold_async;
    begin
      if (CLEAR) begin
        g_reset = 1'b0;
        g_emcln = 1'b0;
      end
      if (g_write & UCLK) g_ca10 = 1'b0;
    end
  endtask

  // Settled F595 output (S = ~a204_q & CLK3, R = ~CLK3, G = 1)
  task gold_f595;
    begin
`ifndef VERILATOR_SIM
      if (!sys_rst_n) g_qb = 1'b1;
      else
`endif
      if (!CLK3) g_qb = 1'b1;
      else if (!g_a204) g_qb = 1'b0;
      // else: hold
    end
  endtask

  // mask[0]=CLK1 group, mask[1]=CLK2 group, mask[2]=CLK3 rise group
  task gold_rise(input [2:0] mask);
    begin
      gold_dvals;
      if (mask[0]) begin
        // MEMORY_63's async reset (WRITE & UCLK) is evaluated with the
        // PRE-edge WRITE inside the triggered always block, so a rise that
        // simultaneously drops WRITE still captures 0 while UCLK is high.
        g_ca10  = (g_write & UCLK) ? 1'b0 : d_ca10;
        g_lhitn = d_lhitn;
      end
      if (mask[1]) begin
        g_a226  = d_a226;
        g_dvr   = d_dvr;
        g_q0    = d_q0;
        g_r1    = d_r1;
        g_rwcsn = d_rwcsn;
        g_iorqn = d_iorqn;
        g_fetch = d_fetch;
        g_dtr   = d_dtr;
        g_rt    = d_rt;
        g_fmiss = d_fmiss;
        g_formr = d_formr;
        g_mreqr = d_mreqr;
        g_write = d_write;
      end
      if (mask[2]) begin
        g_reset   = d_reset;
        g_sstopn  = d_sstopn;
        g_ceuartn = d_ceuartn;
        g_ssema   = d_ssema;
        g_clrtin  = d_clrtin;
        g_siocn   = d_siocn;
        g_empl    = d_empl;
        g_slown   = d_slown;
        g_startn  = d_startn;
        g_ldpl    = d_ldpl;
        g_wchimn  = d_wchimn;
        g_emcln   = d_emcln;
      end
      gold_async;
    end
  endtask

  task gold_fall;
    begin
      g_a204 = ~(L & (M == 2'b10) & (C == 5'o21));
      gold_async;
    end
  endtask

  /*************************************************************************
   ** Clock-event driver (mode-uniform stimulus)                          **
   *************************************************************************/
  task ev(input integer kind);  // 0=no clock, 1=full rise, 2=full fall
    begin
      if (kind == 1 && lvl !== 1'b0) begin
        errors = errors + 1;
        $display("STIMULUS BUG: rise while XCLK already high at %0t", $time);
      end
      if (kind == 2 && lvl !== 1'b1) begin
        errors = errors + 1;
        $display("STIMULUS BUG: fall while XCLK already low at %0t", $time);
      end
`ifdef FPGA_FF_MODE
      @(negedge sysclk);
      if (kind == 1) begin
        CLK1 = 1; CLK2 = 1; CLK3 = 1;
        #1 CLK_EN = 1;
      end else if (kind == 2) begin
        CLK1 = 0; CLK2 = 0; CLK3 = 0;
        #1 CLK_FALL_EN = 1;
      end
      @(posedge sysclk);
      #1 CLK_EN = 0;
      CLK_FALL_EN = 0;
      @(posedge sysclk);
      #1;
`else
      #2;
      if (kind == 1) begin
        CLK1 = 1; CLK2 = 1; CLK3 = 1;
      end else if (kind == 2) begin
        CLK1 = 0; CLK2 = 0; CLK3 = 0;
      end
      #2;
      @(posedge sysclk);
      #1;
      @(posedge sysclk);
      #1;
`endif
      if (kind == 1) begin
        lvl = 1;
        gold_rise(3'b111);
      end else if (kind == 2) begin
        lvl = 0;
        gold_fall;
      end else gold_async;
      gold_f595;
    end
  endtask

  /*************************************************************************
   ** Checkers                                                            **
   *************************************************************************/
  task expect1(input [8*24:1] msg, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL t=%0t %0s: got %b expected %b (C=%o M=%b L=%b)",
                 $time, msg, got, exp, C, M, L);
      end
    end
  endtask

  task check_all;
    reg erof, a242, x_ecreq, x_stocn;
    begin
      gold_async;
      gold_f595;
      erof    = ~EORFN;
      a242    = BRKN & ~LSHADOW & erof;
      x_ecreq = (g_rt & HITN & a242) | (g_write & a242) | (erof & ~g_iorqn);
      x_stocn = (g_rt & ~LSHADOW) | (~g_iorqn & ~DAPN);
      expect1("CA10", CA10, g_ca10);
      expect1("CCLRN", CCLRN, g_qb);
      expect1("CEUARTN", CEUARTN, g_ceuartn);
      expect1("CLRTIN", CLRTIN, g_clrtin);
      expect1("DTN", DTN, ~g_dtr);
      expect1("DVACCN", DVACCN, ~g_dvr);
      expect1("ECREQ", ECREQ, x_ecreq);
      expect1("EMCLN", EMCLN, g_emcln);
      expect1("EMPIDN", EMPIDN, ~(erof & g_empl));
      expect1("ESTOFN", ESTOFN, LSHADOW & g_rt);
      expect1("FETCH", FETCH, g_fetch);
      expect1("FMISS", FMISS, g_fmiss);
      expect1("FORMN", FORMN, ~g_formr);
      expect1("IORQN", IORQN, g_iorqn);
      expect1("LDPANCN", LDPANCN, ~(erof & g_ldpl));
      expect1("LHIT", LHIT, ~g_lhitn);
      expect1("MREQ", MREQ, ~g_mreqr);
      expect1("RESET", RESET, g_reset);
      expect1("RTN", RTN, ~g_rt);
      expect1("RWCSN", RWCSN, g_rwcsn);
      expect1("SHORTN", SHORTN, ~g_r1);
      expect1("SIOCN", SIOCN, g_siocn);
      expect1("SLOWN", SLOWN, g_slown);
      expect1("SSEMAN", SSEMAN, ~g_ssema);
      expect1("SSTOPN", SSTOPN, g_sstopn);
      expect1("STARTN", STARTN, g_startn);
      expect1("STOCN", STOCN, x_stocn);
      expect1("WCHIMN", WCHIMN, g_wchimn);
      expect1("WRITE", WRITE, g_write);
    end
  endtask

  function [31:0] xs(input [31:0] x);
    begin
      x  = x ^ (x << 13);
      x  = x ^ (x >> 17);
      x  = x ^ (x << 5);
      xs = x;
    end
  endfunction

  function [4:0] steer(input [3:0] s);
    begin
      case (s)
        4'd0:  steer = 5'o21;
        4'd1:  steer = 5'o22;
        4'd2:  steer = 5'o05;
        4'd3:  steer = 5'o06;
        4'd4:  steer = 5'o07;
        4'd5:  steer = 5'o12;
        4'd6:  steer = 5'o13;
        4'd7:  steer = 5'o14;
        4'd8:  steer = 5'o15;
        4'd9:  steer = 5'o24;
        4'd10: steer = 5'o27;
        4'd11: steer = 5'o33;
        4'd12: steer = 5'o34;
        4'd13: steer = 5'o35;
        4'd14: steer = 5'o36;
        4'd15: steer = 5'o37;
      endcase
    end
  endfunction

  task set_idle;
    begin
      C = 5'o01;
      M = 2'b00;
      L = 1;
      BRKN = 1; CLEAR = 0; DAPN = 1; EORFN = 1; HITN = 1;
      IDBI2 = 0; IDBI5 = 0; IDBI7 = 0; LSHADOW = 0; PONI = 1; UCLK = 0;
    end
  endtask

  integer i, j, k;
  reg [8:0] idx;
  reg [31:0] rnd;

  initial begin
    sysclk = 0;
    sys_rst_n = 1;
    CLK_EN = 0;
    CLK_FALL_EN = 0;
    CLK1 = 0; CLK2 = 0; CLK3 = 0;
    lvl = 0;
    checks = 0;
    errors = 0;
    set_idle;

    // Golden init (matches RTL initial values)
    g_ca10 = 0; g_lhitn = 0;
    g_a226 = 0; g_dvr = 0; g_q0 = 0; g_r1 = 0; g_rwcsn = 0; g_iorqn = 0;
    g_fetch = 0; g_dtr = 0; g_rt = 0; g_fmiss = 0; g_formr = 0;
    g_mreqr = 0; g_write = 0;
    g_reset = 0; g_sstopn = 0; g_ceuartn = 0; g_ssema = 0;
    g_clrtin = 0; g_siocn = 0; g_empl = 0; g_slown = 0;
    g_startn = 0; g_ldpl = 0; g_wchimn = 0; g_emcln = 0;
`ifdef FPGA_FF_MODE
    g_a204 = 0;  // no phantom edge: A204 waits for the first CLK_FALL_EN (P4)
`else
    g_a204 = 1;  // t=0 phantom posedge on s_clk3_n loads the idle a189=1 (P4)
`endif
    g_qb = 1;

    /***********************************************************************
     ** Layer A: power-on state (P1)                                      **
     ***********************************************************************/
    #12;
    @(posedge sysclk);
    #1;
    check_all;
    expect1("PWRON SSTOPN", SSTOPN, 1'b0);
    expect1("PWRON STARTN", STARTN, 1'b0);
    expect1("PWRON SIOCN", SIOCN, 1'b0);
    expect1("PWRON IORQN", IORQN, 1'b0);
    expect1("PWRON RWCSN", RWCSN, 1'b0);
    expect1("PWRON SLOWN", SLOWN, 1'b0);
    expect1("PWRON LHIT", LHIT, 1'b1);
    expect1("PWRON CCLRN", CCLRN, 1'b1);

    /***********************************************************************
     ** Layer B: exhaustive decode sweep (256 combos x rise+fall)         **
     ***********************************************************************/
    for (i = 0; i < 512; i = i + 1) begin
      idx     = i[8:0];
      L       = idx[8];
      M       = idx[6:5];
      C       = idx[4:0];
      HITN    = idx[0] ^ idx[4];
      IDBI2   = idx[1];
      IDBI5   = idx[2] ^ idx[7];
      IDBI7   = idx[3];
      BRKN    = ~(idx[1] ^ idx[6]);
      EORFN   = idx[5];
      DAPN    = idx[3] ^ idx[8];
      LSHADOW = idx[6] & idx[0];
      PONI    = ~idx[2];
      UCLK    = idx[4] & idx[1];
      CLEAR   = 0;
      ev(1);
      check_all;
      ev(2);
      check_all;
    end

    /***********************************************************************
     ** Layer C: directed walks                                           **
     ***********************************************************************/
    set_idle;
    ev(1); check_all; ev(2); check_all;

    // C1: SSEMA set (o21,M=01), hold via MREQ deasserted, FMISS coupling (P7)
    C = 5'o21; M = 2'b01;
    ev(1); check_all;
    expect1("SSEMA set", SSEMAN, 1'b0);
    expect1("DVACC on o21m01", DVACCN, 1'b1);  // p37/p215/p224 all off (PONI=1)
    ev(2); check_all;
    C = 5'o01; M = 2'b00;
    ev(1); check_all;
    expect1("SSEMA hold", SSEMAN, 1'b0);
    expect1("FMISS from SSEMA", FMISS, 1'b1);
    ev(2); check_all;
    C = 5'o24;  // memory decode: MREQ asserts (low), breaks the hold next edge
    ev(1); check_all;
    expect1("MREQ low on o24", MREQ, 1'b0);
    expect1("SSEMA pre-break", SSEMAN, 1'b0);
    ev(2); check_all;
    ev(1); check_all;
    expect1("SSEMA released", SSEMAN, 1'b1);
    expect1("FMISS holds w/ ssema", FMISS, 1'b1);  // pre-edge ssema was 1
    ev(2); check_all;
    C = 5'o01;
    ev(1); check_all;
    ev(2); check_all;
    ev(1); check_all;
    expect1("FMISS decays", FMISS, 1'b0);
    ev(2); check_all;

    // C2: IORQ (o37,M1x) + comb ECREQ/STOCN terms
    C = 5'o37; M = 2'b10;
    ev(1); check_all;
    expect1("IORQN set", IORQN, 1'b0);
    expect1("DVACC on IORQ", DVACCN, 1'b0);
    DAPN = 0;
    ev(0); check_all;
    expect1("STOCN iorq&dap", STOCN, 1'b1);
    EORFN = 0;
    ev(0); check_all;
    expect1("ECREQ erof&iorq", ECREQ, 1'b1);
    EORFN = 1; DAPN = 1;
    ev(2); check_all;
    C = 5'o01; M = 2'b00;
    ev(1); check_all;
    expect1("IORQN clear", IORQN, 1'b1);
    ev(2); check_all;

    // C3: SIOC (o07) -> RESET/EMCL load from IDBI7/IDBI5, hold, async CLEAR
    C = 5'o07;
    ev(1); check_all;
    expect1("SIOCN set", SIOCN, 1'b0);
    ev(2); check_all;
    C = 5'o01; IDBI7 = 1; IDBI5 = 1;
    ev(1); check_all;
    expect1("RESET loaded", RESET, 1'b1);
    expect1("EMCLN loaded", EMCLN, 1'b1);
    expect1("SIOCN back", SIOCN, 1'b1);
    ev(2); check_all;
    IDBI7 = 0; IDBI5 = 0;
    ev(1); check_all;
    expect1("RESET holds", RESET, 1'b1);
    expect1("EMCLN holds", EMCLN, 1'b1);
    ev(2); check_all;
    CLEAR = 1;
    ev(0); check_all;
    expect1("RESET async clear", RESET, 1'b0);
    expect1("EMCLN async clear", EMCLN, 1'b0);
    CLEAR = 0;
    ev(0); check_all;
    // reload with 0s through SIOC
    C = 5'o07; ev(1); check_all; ev(2); check_all;
    C = 5'o01; IDBI7 = 0; IDBI5 = 0;
    ev(1); check_all;
    expect1("RESET loads 0", RESET, 1'b0);
    ev(2); check_all;

    // C4: CA10 - all five product groups, then async WRITE&UCLK clear
    C = 5'o22; M = 2'b11; ev(1); check_all;
    expect1("CA10 o22m11", CA10, 1'b1);
    ev(2); check_all;
    C = 5'o23; M = 2'b00; ev(1); check_all;
    expect1("CA10 o23", CA10, 1'b1);
    ev(2); check_all;
    C = 5'o35; ev(1); check_all;
    expect1("CA10 o35", CA10, 1'b1);
    expect1("WRITE o35", WRITE, 1'b1);
    ev(2); check_all;
    C = 5'o24; ev(1); check_all;
    expect1("CA10 o24", CA10, 1'b1);
    ev(2); check_all;
    C = 5'o32; ev(1); check_all;
    expect1("CA10 o32", CA10, 1'b1);
    ev(2); check_all;
    C = 5'o01; ev(1); check_all;
    expect1("CA10 idle drop", CA10, 1'b0);
    ev(2); check_all;
    C = 5'o33; ev(1); check_all;
    expect1("WRITE o33", WRITE, 1'b1);
    expect1("CA10 o33", CA10, 1'b1);
    ev(2); check_all;
    UCLK = 1;
    ev(0); check_all;
    expect1("CA10 wr&uclk clear", CA10, 1'b0);
    C = 5'o35;  // capture attempt while async clear held
    ev(1); check_all;
    expect1("CA10 held clear", CA10, 1'b0);
    ev(2); check_all;
    UCLK = 0;
    C = 5'o01; ev(1); check_all; ev(2); check_all;

    // C5: RT / LHIT capture vs hold, ESTOFN (P6)
    C = 5'o24; HITN = 0;
    ev(1); check_all;
    expect1("RTN on o24", RTN, 1'b0);
    LSHADOW = 1;
    ev(0); check_all;
    expect1("ESTOFN rt&lsh", ESTOFN, 1'b1);
    LSHADOW = 0;
    ev(2); check_all;
    ev(1); check_all;  // rt=1 pre-edge: captures HITN=0
    expect1("LHIT captured hit", LHIT, 1'b1);
    ev(2); check_all;
    HITN = 1;
    ev(1); check_all;  // rt still 1: captures HITN=1
    expect1("LHIT captured miss", LHIT, 1'b0);
    ev(2); check_all;
    C = 5'o01; HITN = 0;
    ev(1); check_all;  // rt drops; capture used pre-edge rt=1 -> HITN=0
    ev(2); check_all;
    HITN = 1;
    ev(1); check_all;
    expect1("LHIT hold rt=0", LHIT, 1'b1);
    ev(2); check_all;
    HITN = 1;

    // C6: DVACC paths - PONI=0, and a226/a214_q0 arm window (o21,M=11)
    PONI = 0;
    C = 5'o01; ev(1); check_all;
    expect1("DVACC poni=0", DVACCN, 1'b0);
    ev(2); check_all;
    PONI = 1;
    ev(1); check_all;
    expect1("DVACC poni=1", DVACCN, 1'b1);
    ev(2); check_all;
    C = 5'o21; M = 2'b11;  // arm: a214_q0 <= 0
    ev(1); check_all; ev(2); check_all;
    C = 5'o01; M = 2'b00; IDBI2 = 0;
    ev(1); check_all; ev(2); check_all;  // a226 <= IDBI2 = 0
    C = 5'o34; M = 2'b11;  // p215 = ~a226 & M=11 & o34
    ev(1); check_all;
    expect1("DVACC a226 path", DVACCN, 1'b0);
    ev(2); check_all;
    C = 5'o21; M = 2'b11; ev(1); check_all; ev(2); check_all;  // re-arm
    C = 5'o01; M = 2'b00; IDBI2 = 1;
    ev(1); check_all; ev(2); check_all;  // a226 <= 1
    C = 5'o34; M = 2'b11;
    ev(1); check_all;
    expect1("DVACC a226=1 blocks", DVACCN, 1'b1);
    ev(2); check_all;
    C = 5'o01; M = 2'b00;
    ev(1); check_all; ev(2); check_all;

    // C7: EMPID / LDPANC latched decode + EORFN comb gate
    C = 5'o12; EORFN = 0;
    ev(1); check_all;
    expect1("EMPIDN latched", EMPIDN, 1'b0);
    EORFN = 1;
    ev(0); check_all;
    expect1("EMPIDN eorf gate", EMPIDN, 1'b1);
    EORFN = 0;
    ev(2); check_all;
    C = 5'o06; M = 2'b10;
    ev(1); check_all;
    expect1("EMPIDN drop", EMPIDN, 1'b1);
    expect1("LDPANCN latched", LDPANCN, 1'b0);
    ev(2); check_all;
    C = 5'o01; M = 2'b00; EORFN = 1;
    ev(1); check_all; ev(2); check_all;

    // C8: single-code strobes (literal spot checks on top of layer B)
    C = 5'o14; ev(1); check_all;
    expect1("SSTOPN o14", SSTOPN, 1'b0);
    ev(2); check_all;
    C = 5'o13; ev(1); check_all;
    expect1("STARTN o13", STARTN, 1'b0);
    ev(2); check_all;
    C = 5'o15; ev(1); check_all;
    expect1("CLRTIN o15", CLRTIN, 1'b0);
    ev(2); check_all;
    C = 5'o05; ev(1); check_all;
    expect1("CEUARTN o05", CEUARTN, 1'b0);
    expect1("SLOWN killed o05", SLOWN, 1'b1);
    ev(2); check_all;
    C = 5'o36; M = 2'b01; ev(1); check_all;
    expect1("RWCSN o36m01", RWCSN, 1'b0);
    expect1("SLOWN killed o36", SLOWN, 1'b1);
    ev(2); check_all;
    C = 5'o21; M = 2'b00; ev(1); check_all;
    expect1("WCHIMN o21m00", WCHIMN, 1'b0);
    ev(2); check_all;
    C = 5'o01; M = 2'b00; ev(1); check_all;
    expect1("SLOWN idle", SLOWN, 1'b0);
    ev(2); check_all;

    // C9: comb-output combo sweep under four register contexts
    for (j = 0; j < 4; j = j + 1) begin
      set_idle;
      case (j)
        0: begin C = 5'o24; M = 2'b00; end          // rt=1
        1: begin C = 5'o33; M = 2'b00; end          // write=1 (UCLK kept 0)
        2: begin C = 5'o37; M = 2'b10; end          // iorq=1
        3: begin C = 5'o12; M = 2'b00; end          // empl=1
      endcase
      ev(1); check_all;
      for (k = 0; k < 32; k = k + 1) begin
        {LSHADOW, BRKN, EORFN, DAPN, HITN} = k[4:0];
        ev(0);
        check_all;
      end
      set_idle;
      ev(2); check_all;
    end

    // C10: no-clock hold with full input churn
    set_idle;
    ev(1); check_all; ev(2); check_all;
    C = 5'o22; M = 2'b11; HITN = 0; IDBI2 = 1; IDBI5 = 1; IDBI7 = 1;
    PONI = 0; LSHADOW = 1; BRKN = 0; DAPN = 0; EORFN = 0;
    ev(0); check_all;
    C = 5'o37; M = 2'b01; PONI = 1; LSHADOW = 0; BRKN = 1; EORFN = 1;
    ev(0); check_all;
    set_idle;

    /***********************************************************************
     ** Layer C11/C12: CCLR pipeline + F595 latency (P2) and reset (P3)   **
     ***********************************************************************/
    // Load a CCLR command into A204 (captured on the CLK3 FALL)
    C = 5'o21; M = 2'b10;
    ev(1); check_all;
    ev(2); check_all;      // a204_q <= 0 here
    C = 5'o01; M = 2'b00;  // idle: CLK3-group re-capture is a no-op
    // Raise CLK3 alone; sample CCLRN BEFORE the next sysclk posedge
    @(negedge sysclk);
    #1 CLK3 = 1;
    lvl = 1;  // partial-high; restored via full ev(2) below
`ifndef FPGA_FF_MODE
    gold_rise(3'b100);  // routed-net build: CLK3 rise clocks the CLK3 group
`endif
    #1;
`ifdef VERILATOR_SIM
    expect1("CCLRN pre-edge", CCLRN, 1'b0);   // transparent: immediate
`else
    expect1("CCLRN pre-edge", CCLRN, 1'b1);   // sync: waits for sysclk
`endif
    @(posedge sysclk);
    #1;
    expect1("CCLRN post-edge", CCLRN, 1'b0);
    g_qb = 0;
    check_all;
    // P3: sys_rst_n behavior split
    sys_rst_n = 0;
    @(posedge sysclk); #1;
    @(posedge sysclk); #1;
`ifdef VERILATOR_SIM
    expect1("CCLRN in reset", CCLRN, 1'b0);   // transparent branch ignores it
`else
    expect1("CCLRN in reset", CCLRN, 1'b1);   // sync branch forces idle
`endif
    sys_rst_n = 1;
    @(posedge sysclk); #1;
    @(posedge sysclk); #1;
    expect1("CCLRN after reset", CCLRN, 1'b0);  // S still active in both
    g_qb = 0;
    check_all;
    // Fall clears CCLRN and loads a204_q=1 (idle); next high phase = no clear
    ev(2); check_all;
    expect1("CCLRN clr on fall", CCLRN, 1'b1);
    ev(1); check_all;
    expect1("CCLRN no-clear hold", CCLRN, 1'b1);
    ev(2); check_all;

`ifndef FPGA_FF_MODE
    /***********************************************************************
     ** Layer D (default builds only, P8): clock-group routing            **
     ***********************************************************************/
    set_idle;
    C = 5'o24;  // would set CA10 (CLK1), RT/MREQ (CLK2)
    #2; CLK1 = 1; #2;
    @(posedge sysclk); #1; @(posedge sysclk); #1;
    gold_rise(3'b001);
    check_all;
    expect1("route1 CA10", CA10, 1'b1);
    expect1("route1 RTN hold", RTN, 1'b1);
    expect1("route1 MREQ hold", MREQ, 1'b1);
    #2; CLK2 = 1; #2;
    @(posedge sysclk); #1; @(posedge sysclk); #1;
    gold_rise(3'b010);
    check_all;
    expect1("route2 RTN", RTN, 1'b0);
    expect1("route2 MREQ", MREQ, 1'b0);
    expect1("route2 SIOCN hold", SIOCN, 1'b1);
    C = 5'o07;
    #2; CLK3 = 1; #2;
    @(posedge sysclk); #1; @(posedge sysclk); #1;
    gold_rise(3'b100);
    check_all;
    expect1("route3 SIOCN", SIOCN, 1'b0);
    expect1("route3 RTN hold", RTN, 1'b0);
    // CLK3-only fall clocks A204 (and only A204)
    C = 5'o21; M = 2'b10;
    #2; CLK3 = 0; #2;
    @(posedge sysclk); #1; @(posedge sysclk); #1;
    gold_fall;
    check_all;
    #2; CLK1 = 0; CLK2 = 0; #2;
    @(posedge sysclk); #1; @(posedge sysclk); #1;
    check_all;
    lvl = 0;
    set_idle;
    // flush the pending CCLR + SIOC state with idle full cycles
    ev(1); check_all; ev(2); check_all;
    ev(1); check_all; ev(2); check_all;
`endif

    /***********************************************************************
     ** Layer E: fixed-seed soak                                          **
     ***********************************************************************/
    set_idle;
    ev(1); check_all; ev(2); check_all;
    rnd = 32'h5EED_C044;
    for (i = 0; i < 4000; i = i + 1) begin
      rnd     = xs(rnd);
      HITN    = rnd[0];
      IDBI2   = rnd[1];
      IDBI5   = rnd[2];
      IDBI7   = rnd[3];
      BRKN    = rnd[4];
      EORFN   = rnd[5];
      DAPN    = rnd[6];
      LSHADOW = rnd[7];
      PONI    = rnd[8];
      UCLK    = rnd[9] & rnd[10];
      CLEAR   = (rnd[30:26] == 5'd0);
      L       = (rnd[13:11] != 3'd0);
      M       = rnd[22:21];
      C       = rnd[23] ? steer(rnd[19:16]) : rnd[20:16];
      if (rnd[25:24] == 2'b00) begin
        ev(0);
        check_all;
      end else begin
        ev(1);
        check_all;
        ev(2);
        check_all;
      end
    end

    /***********************************************************************
     ** Verdict                                                           **
     ***********************************************************************/
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else begin
      if (checks != EXPECTED_CHECKS)
        $display("CHECK-COUNT MISMATCH: got %0d expected %0d", checks,
                 EXPECTED_CHECKS);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

endmodule
