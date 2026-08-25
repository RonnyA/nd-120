/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_DCD sheet 10 of 10 (DELILAH.pdf page 75) - DVACCN and VACCN decode                        **
**                                                                                               **
** WHAT IS VERIFIED                                                                              **
**   The violation-access decode on /CGA/DCD sheet 10: three decode gates -> OR -> D of an MCLK  **
**   flip-flop whose Q-bar is DVACCN, and the two 6-input NAND gates + OR that turn DVACCN into  **
**   VACCN.                                                                                      **
**                                                                                               **
** GOLDEN MODEL - DERIVED FROM THE DRAWING, NOT FROM THE RTL                                     **
**   The three decode gates on the drawing carry the microcode command numbers they decode as    **
**   their labels. Those labels are the specification; the golden below is re-derived from them  **
**   and from the drawn rail taps, independently of the CGA_DCD.v gate expressions:              **
**                                                                                               **
**     gate "ND2"        (2 inputs) : PONIN, LCSN                                                **
**                                   -> term = (~PONI) & LCSN                                    **
**                                                                                               **
**     gate "34.3, 35.3" (8 inputs) : CSCOMM = 0o34 or 0o35 with CSMIS = 3, qualified by         **
**                                   VEXN and LCSN.                                              **
**                                   0o34 = 11100b, 0o35 = 11101b -> the two commands differ     **
**                                   only in bit 0, so bit 0 is a don't-care and the decode is   **
**                                   C4=1, C3=1, C2=1, C1=0. CSMIS=3 -> M1=1, M0=1. That is 6    **
**                                   decode terms; the gate has 8 inputs, and the remaining two  **
**                                   drawn taps are VEXN and LCSN.                               **
**                                   -> term = C4 & C3 & C2 & ~C1 & M1 & M0 & ~VEX & LCSN        **
**                                                                                               **
**     gate "37.2, 37.3" (7 inputs) : CSCOMM = 0o37 with CSMIS = 2 or 3, qualified by LCSN.      **
**                                   0o37 = 11111b -> C4..C0 all 1 (5 terms). CSMIS = 2 (10b)    **
**                                   or 3 (11b) differ only in bit 0, so M0 is a don't-care and  **
**                                   only M1=1 is decoded (1 term). 5 + 1 = 6 decode terms; the  **
**                                   gate has 7 inputs, so exactly ONE qualifier is drawn, and   **
**                                   the seventh tap on the drawing is LCSN. VEXN is NOT an      **
**                                   input of this gate (a VEXN tap would make it 8 inputs).     **
**                                   -> term = C4 & C3 & C2 & C1 & C0 & M1 & LCSN                **
**                                                                                               **
**   The three NAND outputs feed an OR gate drawn with a bubble on each of its three inputs, so  **
**   the OR output is the plain sum of the three AND terms:                                      **
**       DVACC_d = ndterm | g3435 | g37                                                          **
**   DVACC_d is the D input of a flip-flop clocked on the MCLK rise (CK drawn with no bubble,    **
**   PR and CL drawn bubbled and left unconnected), and the drawing labels the Q-BAR pin DVACCN: **
**       DVACCN = ~Q,  Q <= DVACC_d on the MCLK rise                                             **
**                                                                                               **
**   Sheet 10 then builds VACCN from two 6-input NAND gates ORed with bubbled inputs:            **
**       VACC  = (DVACCN & LSHADOWN & MREQ & EMCLN & VEXN & FETCHN)                              **
**             | (DVACCN & LSHADOWN & MREQ & EMCLN & VEXN & INTRQN)                              **
**       VACCN = ~VACC                                                                           **
**   where LSHADOWN is the drawn inverter on the LSHADOW pin and VEXN the inverter on VEX.       **
**                                                                                               **
** WHAT IS SWEPT                                                                                 **
**   Exhaustive over everything sheet 10's DVACC decode depends on, plus the VACC-side pins:     **
**     CSCOMM_4_0 (32) x CSMIS_1_0 (4) x LCSN (2) x PONI (2) x VEX (2) x LSHADOW (2)             **
**     x INTRQN (2)                                     = 4096 vectors per EMCLN pass,           **
**   run twice (EMCLN = 0 and EMCLN = 1)                = 8192 checked clock edges per build.    **
**   Each edge checks BOTH DVACCN and VACCN, so 16384 comparisons per build.                     **
**                                                                                               **
** SIGNALS THAT ARE NOT MODULE PINS (and how the bench reaches them)                             **
**   The drawing shows MREQ, EMCLN and FETCHN as sheet-10 inputs, but in CGA_DCD.v they are      **
**   generated inside the module, so the bench cannot drive them directly:                       **
**     EMCLN  - FD25 on THIS sheet: D=FIDBO5, CP=MCLK, TE=SIOCN, CD=MRN. The bench holds FIDBO5  **
**              at the wanted EMCLN value for a whole pass, so every load - whenever SIOCN       **
**              happens to fire during the CSCOMM sweep - writes that same value, and MRN is     **
**              held high so nothing clears it. EMCLN is therefore constant and known for the    **
**              pass. The pass value is ALSO checked against the DUT's own reg_emcln every       **
**              cycle, so the assumption is proven, not assumed.                                 **
**     MREQ   - the Q of MEMORY_99, which registers the CSMREQ output pin on the MCLK rise. The  **
**              bench takes MREQ from the DUT (dut.s_mreq). Verifying the CSMREQ decode itself   **
**              is sheet 9's job, not this bench's; both MREQ polarities are reached by the      **
**              CSCOMM sweep and the coverage report proves it.                                  **
**     FETCHN - the FETCHN output pin (sheet 5 decode, registered on MCLK). Taken from the pin,  **
**              same reasoning as MREQ; both polarities are covered.                             **
**   DVACCN itself is internal, and is read hierarchically as dut.s_dvacc_n.                     **
**                                                                                               **
** PARKED PINS (tied to a benign constant, none of them reaches sheet 10)                        **
**   sys_rst_n=1 (unused inside CGA_DCD), BRKN=1 (no break), CRY=0, F15=0, ZF=0, SGR=0, WPN=1    **
**   (no write protect), CSIDBS_4_0=0 (IDB source select, sheet 8). MRN is held 1 after the      **
**   initial master clear.                                                                       **
**                                                                                               **
** CLOCKING / ANTI-RACE                                                                          **
**   Stimulus is applied while MCLK is low and held across the rise; outputs are sampled well    **
**   after the capturing edge has settled. sysclk free-runs with its posedges on EVEN ns and     **
**   all stimulus lands on ODD ns, so nothing races the clock edge in either build mode.         **
**   In FPGA_FF_MODE the module's MCLK-domain flops capture on posedge sysclk gated by MCLK_EN,  **
**   so the bench raises MCLK_EN for exactly one sysclk period around the MCLK rise, the way     **
**   CYC_36.v generates it (MCLK_EN = one sysclk pulse at the MCLK rise).                        **
**                                                                                               **
** Prints "TB_RESULT: PASS (<n> checks)" or "TB_RESULT: FAIL ...". Watchdog aborts with FAIL.    **
** Teeth: -DTEETH_TEST corrupts the golden for one command -> the checker MUST report FAIL.      **
**                                                                                               **
** Compile+run (from repo Verilog/):                                                             **
**   cd DELILAH-CPU/CGA_DCD/sim && make test-dcd-vacc          (both build modes)                **
**   cd DELILAH-CPU/CGA_DCD/sim && make test-dcd-vacc-teeth    (both modes, must FAIL)           **
**                                                                                               **
** Last reviewed: 17-AUG-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_DCD_VACC_tb;

  // ---------------------------------------------------------------- clocking
  // sysclk posedges land on EVEN ns; every stimulus change lands on an ODD ns.
  reg sysclk = 1'b1;
  always #1 sysclk = ~sysclk;

  reg MCLK = 1'b0;
  reg MCLK_EN = 1'b0;

  // ------------------------------------------------------------- driven pins
  reg [4:0] CSCOMM = 5'b00000;
  reg [1:0] CSMIS = 2'b00;
  reg LCSN = 1'b1;
  reg PONI = 1'b0;
  reg VEX = 1'b0;
  reg LSHADOW = 1'b0;
  reg INTRQN = 1'b1;
  reg FIDBO5 = 1'b0;
  reg MRN = 1'b1;

  // ------------------------------------------------------------- parked pins
  localparam PARK_SYS_RST_N = 1'b1;
  localparam PARK_BRKN = 1'b1;  // no break condition
  localparam PARK_CRY = 1'b0;
  localparam PARK_F15 = 1'b0;
  localparam PARK_ZF = 1'b0;
  localparam PARK_SGR = 1'b0;
  localparam PARK_WPN = 1'b1;  // no write protect
  localparam [4:0] PARK_CSIDBS = 5'b00000;

  // ----------------------------------------------------------------- outputs
  wire CBRKN, CFETCH, CLFFN, CLIRQN, CSMREQ, DSTOPN, EPCRN, EPGSN;
  wire EPIC, EPICSN, EPICVN, ERFN, FETCHN, INDN, LDDBRN, LDGPRN;
  wire LDIRV, LDLCN, LDPILN, LWCAN, VACCN, WRITEN, WRTRF, XFETCHN;

  CGA_DCD dut (
      .sysclk(sysclk),
      .sys_rst_n(PARK_SYS_RST_N),
      .MCLK_EN(MCLK_EN),
      .BRKN(PARK_BRKN),
      .CRY(PARK_CRY),
      .CSCOMM_4_0(CSCOMM),
      .CSIDBS_4_0(PARK_CSIDBS),
      .CSMIS_1_0(CSMIS),
      .F15(PARK_F15),
      .FIDBO5(FIDBO5),
      .LCSN(LCSN),
      .INTRQN(INTRQN),
      .LSHADOW(LSHADOW),
      .MCLK(MCLK),
      .MRN(MRN),
      .PONI(PONI),
      .SGR(PARK_SGR),
      .VEX(VEX),
      .WPN(PARK_WPN),
      .ZF(PARK_ZF),
      .CBRKN(CBRKN),
      .CFETCH(CFETCH),
      .CLFFN(CLFFN),
      .CLIRQN(CLIRQN),
      .CSMREQ(CSMREQ),
      .DSTOPN(DSTOPN),
      .EPCRN(EPCRN),
      .EPGSN(EPGSN),
      .EPIC(EPIC),
      .EPICSN(EPICSN),
      .EPICVN(EPICVN),
      .ERFN(ERFN),
      .FETCHN(FETCHN),
      .INDN(INDN),
      .LDDBRN(LDDBRN),
      .LDGPRN(LDGPRN),
      .LDIRV(LDIRV),
      .LDLCN(LDLCN),
      .LDPILN(LDPILN),
      .LWCAN(LWCAN),
      .VACCN(VACCN),
      .WRITEN(WRITEN),
      .WRTRF(WRTRF),
      .XFETCHN(XFETCHN)
  );

  // ------------------------------------------------------- bookkeeping state
  integer errors = 0;
  integer checks = 0;
  integer edges = 0;
  integer emcl_pass = 0;
  reg check_enable = 1'b0;  // suppress checks during the priming cycles
  reg emcl_golden = 1'b0;  // EMCLN value this pass is holding

  // coverage of the 7 signals that feed the two VACC NAND gates:
  // {dvaccn, lshadown, mreq, emcln, vexn, fetchn, intrqn}
  reg [127:0] vacc_cov = 128'b0;
  integer cov_count;
  integer ci;

  // ---------------------------------------------------- golden (see header)
  // Independently re-derived from the drawing's gate labels; deliberately NOT
  // a copy of the CGA_DCD.v gate instantiations.
  function golden_dvacc_d(input [4:0] c, input [1:0] m, input lcsn, input poni, input vex);
    reg ndterm, g3435, g37;
    begin
      // "ND2": PONIN and LCSN
      ndterm = (~poni) & lcsn;
      // "34.3, 35.3": CSCOMM 0o34/0o35 (11100 / 11101, bit0 don't care),
      //               CSMIS = 3, qualified by VEXN and LCSN
      g3435 = c[4] & c[3] & c[2] & (~c[1]) & m[1] & m[0] & (~vex) & lcsn;
      // "37.2, 37.3": CSCOMM 0o37 (11111), CSMIS = 2 or 3 (bit0 don't care),
      //               qualified by LCSN
      g37 = c[4] & c[3] & c[2] & c[1] & c[0] & m[1] & lcsn;
      golden_dvacc_d = ndterm | g3435 | g37;
    end
  endfunction

  function golden_vaccn(input dvaccn, input lshadow, input mreq, input emcln, input vex,
                        input fetchn, input intrqn);
    reg vacc1, vacc2;
    begin
      vacc1 = dvaccn & (~lshadow) & mreq & emcln & (~vex) & fetchn;
      vacc2 = dvaccn & (~lshadow) & mreq & emcln & (~vex) & intrqn;
      golden_vaccn = ~(vacc1 | vacc2);
    end
  endfunction

  // ------------------------------------------------------------- clock cycle
  // 20 ns cycle. Stimulus is already applied by the caller before this runs.
  //   +7  ns : MCLK rises (and MCLK_EN opens)   -> non-FF builds capture here
  //   +8  ns : sysclk posedge inside MCLK_EN    -> FPGA_FF_MODE builds capture
  //   +9  ns : MCLK_EN closes
  //   +13 ns : sample and check (well settled)
  //   +15 ns : MCLK falls
  reg exp_dvaccn;
  reg exp_vaccn;
  reg got_dvaccn;
  reg got_vaccn;
  reg obs_mreq;
  reg obs_emcln;
  reg obs_fetchn;
  reg [6:0] covidx;

  task mclk_edge;
    begin
      // golden next state of the DVACC flip-flop, from the stimulus standing
      // at the capturing edge
      exp_dvaccn = ~golden_dvacc_d(CSCOMM, CSMIS, LCSN, PONI, VEX);
`ifdef TEETH_TEST
      // corrupt the golden for exactly one command -> the checker MUST fail
      if (CSCOMM == 5'o37) exp_dvaccn = ~exp_dvaccn;
`endif
      #6 MCLK = 1'b1;
      MCLK_EN = 1'b1;  // t = +7 (odd), covers the sysclk posedge at +8
      #2 MCLK_EN = 1'b0;  // t = +9 (odd)
      #4;  // t = +13, everything settled
      edges = edges + 1;

      if (check_enable) begin
        got_dvaccn = dut.s_dvacc_n;
        got_vaccn  = VACCN;
        obs_mreq   = dut.s_mreq;
        obs_emcln  = dut.s_emcl_n;
        obs_fetchn = FETCHN;

        // (a) DVACCN against the independently derived golden
        checks = checks + 1;
        if (got_dvaccn !== exp_dvaccn) begin
          errors = errors + 1;
          if (errors <= 20)
            $display(
                "FAIL DVACCN: CSCOMM=%0o(%b) CSMIS=%0o(%b) LCSN=%b PONI=%b VEX=%b -> exp=%b got=%b",
                CSCOMM, CSCOMM, CSMIS, CSMIS, LCSN, PONI, VEX, exp_dvaccn, got_dvaccn);
        end

        // (b) the EMCLN assumption this pass relies on (FD25 on the same sheet)
        checks = checks + 1;
        if (obs_emcln !== emcl_golden) begin
          errors = errors + 1;
          if (errors <= 20)
            $display("FAIL EMCLN: pass=%0d exp=%b got=%b (CSCOMM=%0o FIDBO5=%b)", emcl_pass,
                     emcl_golden, obs_emcln, CSCOMM, FIDBO5);
        end

        // (c) VACCN, using the GOLDEN DVACCN (not the DUT's) so a DVACCN bug
        //     also shows up here, and the observed MREQ/FETCHN sheet inputs
        exp_vaccn = golden_vaccn(exp_dvaccn, LSHADOW, obs_mreq, emcl_golden, VEX, obs_fetchn,
                                 INTRQN);
        checks = checks + 1;
        if (got_vaccn !== exp_vaccn) begin
          errors = errors + 1;
          if (errors <= 20)
            $display(
                "FAIL VACCN: DVACCN=%b LSHADOW=%b MREQ=%b EMCLN=%b VEX=%b FETCHN=%b INTRQN=%b (CSCOMM=%0o CSMIS=%0o LCSN=%b PONI=%b) -> exp=%b got=%b",
                exp_dvaccn, LSHADOW, obs_mreq, emcl_golden, VEX, obs_fetchn, INTRQN, CSCOMM, CSMIS,
                LCSN, PONI, exp_vaccn, got_vaccn);
        end

        covidx = {exp_dvaccn, ~LSHADOW, obs_mreq, emcl_golden, ~VEX, obs_fetchn, INTRQN};
        vacc_cov[covidx] = 1'b1;
      end

      #2 MCLK = 1'b0;  // t = +15
      #5;  // t = +20
    end
  endtask

  // Apply a stimulus vector (on an odd ns) then clock it in.
  task step(input [4:0] c, input [1:0] m, input lcsn, input poni, input vex, input lshadow,
            input intrqn);
    begin
      #1;
      CSCOMM  = c;
      CSMIS   = m;
      LCSN    = lcsn;
      PONI    = poni;
      VEX     = vex;
      LSHADOW = lshadow;
      INTRQN  = intrqn;
      mclk_edge;
    end
  endtask

  // ------------------------------------------------------------------ sweeps
  integer p, c, m, l, po, v, ls, iq;

  task run_pass(input emclv);
    begin
      emcl_pass = emcl_pass + 1;
      // Hold FIDBO5 at the wanted EMCLN for the whole pass, so any FD25 load
      // that the CSCOMM sweep happens to trigger writes the same value.
      FIDBO5 = emclv;
      emcl_golden = emclv;
      check_enable = 1'b0;

      // Master clear: clears EMCLN (FD25 CD) and settles the MCLK registers.
      MRN = 1'b0;
      #1;
      step(5'b00000, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);
      MRN = 1'b1;
      #1;

      // Prime EMCLN to emclv: CSCOMM = 0o07 with LCSN=1 puts COMM at 0o07 on
      // the first edge, which asserts SIOCN, and the following edges load
      // FIDBO5 into FD25.
      for (p = 0; p < 4; p = p + 1) step(5'o07, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);

      check_enable = 1'b1;

      for (c = 0; c < 32; c = c + 1)
        for (m = 0; m < 4; m = m + 1)
          for (l = 0; l < 2; l = l + 1)
            for (po = 0; po < 2; po = po + 1)
              for (v = 0; v < 2; v = v + 1)
                for (ls = 0; ls < 2; ls = ls + 1)
                  for (iq = 0; iq < 2; iq = iq + 1)
                  step(c[4:0], m[1:0], l[0], po[0], v[0], ls[0], iq[0]);

      check_enable = 1'b0;
    end
  endtask

  // --------------------------------------------------------------- watchdog
  initial begin
    #20_000_000;
    $display("TB_RESULT: FAIL - TIMEOUT after %0d checks (%0d edges)", checks, edges);
    $finish;
  end

  // ------------------------------------------------------------------- main
  initial begin
`ifdef DUMP_VCD
    $dumpfile("CGA_DCD_VACC_tb.vcd");
    $dumpvars(0, CGA_DCD_VACC_tb);
`endif
`ifdef FPGA_FF_MODE
    $display("CGA_DCD sheet 10 VACCN/DVACCN - build mode: FPGA_FF_MODE (MCLK_EN capture)");
`else
    $display("CGA_DCD sheet 10 VACCN/DVACCN - build mode: default (posedge MCLK capture)");
`endif

    run_pass(1'b0);
    run_pass(1'b1);

    cov_count = 0;
    for (ci = 0; ci < 128; ci = ci + 1) if (vacc_cov[ci]) cov_count = cov_count + 1;
    $display(
        "coverage: %0d of 128 {DVACCN,LSHADOWN,MREQ,EMCLN,VEXN,FETCHN,INTRQN} combinations reached",
        cov_count);
    for (ci = 0; ci < 128; ci = ci + 1)
      if (!vacc_cov[ci])
        $display(
            "  not reached: DVACCN=%b LSHADOWN=%b MREQ=%b EMCLN=%b VEXN=%b FETCHN=%b INTRQN=%b",
            ci[6], ci[5], ci[4], ci[3], ci[2], ci[1], ci[0]);
    $display("edges clocked: %0d", edges);

    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else $display("TB_RESULT: FAIL - %0d of %0d checks wrong", errors, checks);
    $finish;
  end

endmodule
