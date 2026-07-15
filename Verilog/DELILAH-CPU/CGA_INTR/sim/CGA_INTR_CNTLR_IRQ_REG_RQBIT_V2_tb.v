/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRQ_REG_RQBIT vs CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2 equivalence (p.78)            **
**                                                                                               **
** Triple-check harness: the ORIGINAL RQBIT (async cross-coupled OR/NAND request latch feeding   **
** the CP-edge FF), the loop-free V2 (sysclk-clocked request catcher FF + the same CP-edge       **
** output FF) and an INDEPENDENT behavioural golden (transparent-latch semantics written as      **
** plain behavioural code, no gates:                                                             **
**     catcher Lb: if (CPN&CLR) Lb=0; else if (!PN) Lb=1;   (transparent, event-driven)          **
**     output  Lq: on each capture edge, Lq <= ~CLR & (~PN | Lb);                                **
** ) are driven with IDENTICAL inputs. On every scripted edge the tb asserts                     **
**     INR_V1 === Lq   (original == golden; armed after the first clear resolves V1's X-init)    **
**     INR_V2 === Lq   (V2 == golden; inverted in the one documented residual case, see below)   **
** in BOTH build modes:                                                                          **
**   - default          : output FFs capture on posedge CP (= MCLK); sysclk free-runs (period    **
**                        1ns, edges on the .5ns grid) feeding the V2 catcher - mirroring the    **
**                        Verilator latch-mode system sim where sysclk drives everything         **
**   - -DFPGA_FF_MODE   : capture on posedge sysclk gated by MCLK_EN; sysclk period 10ns,        **
**                        MCLK = sysclk/8, MCLK_EN a 1-sysclk pulse aligned to the MCLK rise     **
**                        (the P2 conversion pattern used by CGA_INTR_CNTLR)                     **
**                                                                                               **
** EQUIVALENCE CLAIM (what this tb proves): V1 and V2 are bit-identical at every capture edge    **
** for ALL input activity whose pulses last at least one sysclk cycle - including:               **
**   - in-discipline sequences (inputs stable across each capture edge), all phases: CP-low      **
**     window, mid-CP-high, 1ns before the edge                                                  **
**   - request (PN low) pulses strictly BETWEEN capture edges (>= 1 sysclk): both catch          **
**     (V1 via the async latch, V2 via the sysclk catcher). This is the PID-write set-pulse      **
**     case measured in the system trace (one-sysclk PN pulses between MCLK edges).              **
**   - CLR pulses at CP low strictly between edges: both clear the caught state                  **
**   - CLR pulses while CP HIGH only: BOTH ignore (the async clear path needs CP low)            **
**   - clear coinciding with a still-asserted request, request then dropped mid-high: both       **
**     re-arm from the residue and re-pend                                                       **
**   - exhaustive (state, CLR, PN) transitions from both states; clear-dominates; long holds;    **
**     repeated set/clear; FF-mode MCLK_EN gaps; randomized soak (800 edges per mode)            **
**                                                                                               **
** RESIDUAL (asserted, expected) DIVERGENCE - the one behaviour V2 intentionally drops:          **
**   an event narrower than one sysclk cycle (sub-sysclk glitch / delta race): the transparent   **
**   async latch (and the golden) catch it, the sysclk catcher does not (non-FF "subsys"        **
**   section: V1 === Lq === 1, V2 === 0, then re-sync). On FPGA fabric that glitch sensitivity   **
**   is exactly the failure mode V2 removes; in the Verilator system sim every real signal       **
**   changes on the sysclk grid, so no functional event is lost - the system-level               **
**   golden-trace gates verify that empirically.                                                 **
**                                                                                               **
** Power-on: V2's INR must never be X (monitored from t=0); the original's latch is only         **
** defined after the first clear edge, so its golden check arms there. (The original             **
** OSCILLATES if toggled from X - the pathology V2 removes - so that stimulus is not driven.)    **
**                                                                                               **
** Self-checking, prints "TB_RESULT: PASS/FAIL".                                                 **
** Teeth: compile with -DTEETH_TEST to corrupt the golden -> the harness MUST report FAIL.       **
**                                                                                               **
** Compile+run (from DELILAH-CPU/CGA_INTR/sim/):  make test-rqbitv2   (runs BOTH modes)          **
**   or per mode:                                                                                **
**   iverilog -g2012 [-DFPGA_FF_MODE] -y ../../../Shared/logisim -y ../../../Shared/support \    **
**     -y ../../../Shared/ndlib -y ../circuit -o /tmp/ndtb_rqbitv2 \                              **
**     CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2_tb.v && vvp -N /tmp/ndtb_rqbitv2                           **
**                                                                                               **
** Last reviewed: 16-JUL-2026                                                                    **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2_tb;

  reg CLR = 0;
  reg PN  = 1;  // active-low request; 1 = no request

`ifdef FPGA_FF_MODE
  // P2 clocking: free-running sysclk, MCLK = sysclk/8, MCLK_EN a one-sysclk
  // pulse in the cycle ENDING at the MCLK rise (capture edge = posedge sysclk
  // where cnt wraps 7->0 and MCLK goes high).
  reg        sysclk = 0;
  always #5 sysclk = ~sysclk;
  reg  [2:0] cnt = 0;
  always @(posedge sysclk) cnt <= cnt + 1;
  reg        en_inhibit = 0;
  wire       CP = (cnt < 4);            // MCLK level
  wire       MCLK_EN = (cnt == 3'd7) & ~en_inhibit;
`else
  // Latch/event mode: CP is the capture clock, driven by the tasks at
  // integer-ns times. sysclk free-runs at period 1ns with edges on the
  // .5ns grid (never coinciding with CP/input changes) so the V2 catcher
  // is live, exactly as in the Verilator latch-mode system sim.
  reg  CP = 0;
  reg  sysclk = 0;
  always #0.5 sysclk = ~sysclk;
  wire MCLK_EN = 1'b0;
`endif
  wire CPN = ~CP;  // exactly how CGA_INTR_CNTLR drives s_mclk_n

  wire INR_V1;  // original async-latch DUT
  wire INR_V2;  // loop-free replacement DUT

  CGA_INTR_CNTLR_IRQ_REG_RQBIT dut_v1 (
      .sysclk (sysclk),
      .MCLK_EN(MCLK_EN),
      .CLR    (CLR),
      .CP     (CP),
      .CPN    (CPN),
      .PN     (PN),
      .INR    (INR_V1)
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2 dut_v2 (
      .sysclk (sysclk),
      .MCLK_EN(MCLK_EN),
      .CLR    (CLR),
      .CP     (CP),
      .CPN    (CPN),
      .PN     (PN),
      .INR    (INR_V2)
  );

  /*************************************************************************
   ** Independent behavioural golden: transparent-latch semantics         **
   *************************************************************************/
  reg Lb = 0;  // transparent request catcher (event-driven, defined from t=0)
  always @* begin
    if (CPN & CLR)      Lb = 1'b0;  // clear dominates, needs CP low
    else if (PN == 1'b0) Lb = 1'b1;  // any request sets, any time
  end
  reg Lq = 0;  // captured pending state = expected INR
`ifdef FPGA_FF_MODE
  always @(posedge sysclk) if (MCLK_EN) Lq <= ~CLR & (~PN | Lb);
`else
  always @(posedge CP) Lq <= ~CLR & (~PN | Lb);
`endif

  integer errors = 0;
  integer checks = 0;
  reg     v1_armed = 0;    // V1-vs-golden armed after V1's X-init resolves
  reg     inr_exp;

  // V2 must be DEFINED from power-on: its state elements initialise to 0.
  always @(INR_V2)
    if (INR_V2 === 1'bx) begin
      errors = errors + 1;
      $display("FAIL: INR_V2 went X at t=%0t (V2 must never be X)", $time);
    end

  /*************************************************************************
   ** Mode-abstracted edge primitives                                     **
   *************************************************************************/

  // Park in the input-change window: CP low, >=2 capture-free sysclks ahead.
  task park_low;
    begin
`ifdef FPGA_FF_MODE
      wait (cnt == 3'd5);
`else
      if (CP !== 1'b0) begin
        #1 CP = 0;
      end
      #2;
`endif
    end
  endtask

  // One capture edge with the inputs as currently driven, then settle.
  task pulse_edge;
    begin
`ifdef FPGA_FF_MODE
      wait (cnt == 3'd0);  // capture happened on the 7->0 sysclk edge
      #1;
`else
      #1 CP = 1;
      #2;
`endif
    end
  endtask

  // Return to CP low after a capture (non-FF only; FF mode free-runs).
  task close_edge;
    begin
`ifdef FPGA_FF_MODE
      ;
`else
      #1 CP = 0;
      #2;
`endif
    end
  endtask

  // Post-edge checks: both DUTs against the independent golden.
  task check_edge(input [319:0] what);
    begin
      inr_exp = Lq;
`ifdef TEETH_TEST
      inr_exp = ~inr_exp;  // deliberately wrong -> harness must FAIL
`endif
      checks = checks + 1;
      if (INR_V2 !== inr_exp) begin
        errors = errors + 1;
        $display("FAIL %0s: V2 vs golden: exp=%b got=%b (CLR=%b PN=%b)", what, inr_exp, INR_V2,
                 CLR, PN);
      end
      if (v1_armed && (INR_V1 !== inr_exp)) begin
        errors = errors + 1;
        $display("FAIL %0s: V1 vs golden: exp=%b got=%b (CLR=%b PN=%b)", what, inr_exp, INR_V1,
                 CLR, PN);
      end
    end
  endtask

  // Set inputs in the CP-low window, take one edge, check both DUTs.
  task edge_and_check(input tclr, input tpn, input [319:0] what);
    begin
      park_low;
      CLR = tclr;
      PN  = tpn;
      pulse_edge;
      check_edge(what);
      close_edge;
    end
  endtask

  // Phase variant: change the inputs while CP is HIGH (right after a
  // capture), hold them stable through the NEXT capture edge.
  task edge_and_check_midhigh(input tclr, input tpn, input [319:0] what);
    begin
`ifdef FPGA_FF_MODE
      wait (cnt == 3'd1);  // MCLK high, just after the capture edge
`else
      #1 CP = 1;
      #2;
`endif
      CLR = tclr;
      PN  = tpn;
`ifdef FPGA_FF_MODE
      pulse_edge;
`else
      #1 CP = 0;           // complete this high phase, then a fresh edge
      #2;
      pulse_edge;
`endif
      check_edge(what);
      close_edge;
    end
  endtask

`ifndef FPGA_FF_MODE
  // Phase variant: inputs change only 1ns before the capture edge (still
  // stable AT the edge -> both DUTs must sample the new value). Non-FF
  // mode only: in FF mode input timing is quantised by sysclk anyway.
  task edge_and_check_late(input tclr, input tpn, input [319:0] what);
    begin
      park_low;
      #1;
      CLR = tclr;
      PN  = tpn;
      #1 CP = 1;
      #2;
      check_edge(what);
      close_edge;
    end
  endtask
`endif

  integer i;
  reg [1:0] r;
  reg pass_set, pass_hold1, pass_clr, pass_idle;
  reg p1_eq, p2_eq, p3_eq, p4_eq, sub_v1, sub_v2;

  initial begin
`ifdef FPGA_FF_MODE
    $display("MODE: FPGA_FF_MODE (MCLK_EN-gated sysclk capture)");
`else
    $display("MODE: latch/event mode (posedge CP capture, 1ns sysclk catcher)");
`endif
    p1_eq = 0; p2_eq = 0; p3_eq = 0; p4_eq = 0; sub_v1 = 0; sub_v2 = 0;

    // ---- power-on ----
    // V2 X-monitor is armed from t=0 (above); the golden is defined from
    // t=0 as well. The original's async latch is X until the first clear,
    // so its golden check arms after it.
    edge_and_check(1'b1, 1'b1, "init-clear");
    v1_armed = 1;
    if (INR_V1 !== 1'b0 || INR_V2 !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL init-clear: both must be 0 after first clear edge (V1=%b V2=%b)", INR_V1,
               INR_V2);
    end

    // ---- directed persistence / clear script (from the original RQBIT tb) ----
    edge_and_check(1'b0, 1'b0, "assert request");     pass_set  = (INR_V2 === 1'b1);
    edge_and_check(1'b0, 1'b1, "request removed");     pass_hold1 = (INR_V2 === 1'b1);  // PERSIST
    edge_and_check(1'b0, 1'b1, "still no request");
    edge_and_check(1'b0, 1'b1, "and again");
    edge_and_check(1'b1, 1'b1, "clear it");            pass_clr  = (INR_V2 === 1'b0);
    edge_and_check(1'b0, 1'b1, "idle after clear");    pass_idle = (INR_V2 === 1'b0);
    edge_and_check(1'b0, 1'b1, "idle after clear 2");  pass_idle = pass_idle & (INR_V2 === 1'b0);

    // clear+request simultaneously: clear must dominate
    edge_and_check(1'b1, 1'b0, "clr dominates req");
    if (INR_V2 !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL clr-dominates: INR_V2=%b, must be 0", INR_V2);
    end
    // NOTE: with the request still asserted after that clearing edge, the
    // caught state legitimately re-arms (pulse-4 semantics) - clear it
    // with request gone before continuing.
    edge_and_check(1'b1, 1'b1, "post-dominate cleanup");
    // set, then verify hold across MANY clocks
    edge_and_check(1'b0, 1'b0, "re-assert");
    for (i = 0; i < 12; i = i + 1) edge_and_check(1'b0, 1'b1, "long hold");
    // repeated set/clear back-to-back
    for (i = 0; i < 6; i = i + 1) begin
      edge_and_check(1'b0, 1'b0, "set (rep)");
      edge_and_check(1'b1, 1'b1, "clear (rep)");
    end

    // ---- exhaustive (state, CLR, PN) transitions from BOTH latch states ----
    edge_and_check(1'b1, 1'b1, "seed L=0");
    edge_and_check(1'b0, 1'b0, "from0 clr0 pn0");
    edge_and_check(1'b1, 1'b1, "seed L=0b");
    edge_and_check(1'b0, 1'b1, "from0 clr0 pn1");
    edge_and_check(1'b1, 1'b1, "seed L=0c");
    edge_and_check(1'b1, 1'b0, "from0 clr1 pn0");
    edge_and_check(1'b1, 1'b1, "from0 clr1 pn1 (=seed)");
    edge_and_check(1'b0, 1'b0, "seed L=1");
    edge_and_check(1'b0, 1'b0, "from1 clr0 pn0");
    edge_and_check(1'b0, 1'b0, "seed L=1b");
    edge_and_check(1'b0, 1'b1, "from1 clr0 pn1 (hold 1)");
    edge_and_check(1'b0, 1'b0, "seed L=1c");
    edge_and_check(1'b1, 1'b0, "from1 clr1 pn0");
    edge_and_check(1'b0, 1'b0, "seed L=1d");
    edge_and_check(1'b1, 1'b1, "from1 clr1 pn1");

    // ---- input-phase coverage (must be identical) ----
    // mid-CP-high changes, all four input combinations, from both states
    edge_and_check(1'b1, 1'b1, "phase seed clear");
    edge_and_check_midhigh(1'b0, 1'b0, "midhigh set");
    edge_and_check_midhigh(1'b0, 1'b1, "midhigh hold");
    edge_and_check_midhigh(1'b1, 1'b0, "midhigh clr+req");
    edge_and_check_midhigh(1'b0, 1'b0, "midhigh set 2");
    edge_and_check_midhigh(1'b1, 1'b1, "midhigh clear");
    edge_and_check_midhigh(1'b0, 1'b1, "midhigh idle");
`ifndef FPGA_FF_MODE
    // changes landing 1ns before the capture edge
    edge_and_check_late(1'b0, 1'b0, "late set");
    edge_and_check_late(1'b0, 1'b1, "late hold");
    edge_and_check_late(1'b1, 1'b1, "late clear");
    edge_and_check_late(1'b0, 1'b0, "late set 2");
    edge_and_check_late(1'b1, 1'b0, "late clr dominates");
    edge_and_check(1'b1, 1'b1, "late cleanup");
`endif

`ifdef FPGA_FF_MODE
    // ---- MCLK_EN inhibited: no capture while the enable is held off ----
    // request HELD across the gap, then re-enabled -> caught at first
    // re-enabled edge by BOTH.
    edge_and_check(1'b1, 1'b1, "gap seed clear");
    park_low;
    CLR = 0;
    PN  = 0;                    // request asserted and HELD
    en_inhibit = 1;
    for (i = 0; i < 24; i = i + 1) begin  // 3 full MCLK periods, no capture
      @(posedge sysclk);
      #1;
      if (INR_V1 !== 1'b0 || INR_V2 !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL en-gap: INR changed with MCLK_EN inhibited (V1=%b V2=%b)", INR_V1, INR_V2);
      end
    end
    en_inhibit = 0;
    pulse_edge;
    check_edge("first edge after en-gap (request held)");
    if (INR_V2 !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL en-gap capture: INR_V2=%b, must be 1", INR_V2);
    end
    // clear HELD across a gap likewise
    park_low;
    CLR = 1;
    PN  = 1;
    en_inhibit = 1;
    for (i = 0; i < 16; i = i + 1) begin
      @(posedge sysclk);
      #1;
      if (INR_V1 !== 1'b1 || INR_V2 !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL en-gap2: INR changed with MCLK_EN inhibited (V1=%b V2=%b)", INR_V1, INR_V2);
      end
    end
    en_inhibit = 0;
    pulse_edge;
    check_edge("first edge after en-gap (clear held)");
    if (INR_V2 !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL en-gap clear: INR_V2=%b, must be 0", INR_V2);
    end
    close_edge;
`endif

    // ---- pulse-catching equivalence: events strictly between captures ----
    // These are the async latch's raison d'etre; the V2 sysclk catcher
    // must match it for every pulse of >= 1 sysclk.

    // pulse-1: PN low pulse strictly between capture edges (from cleared)
    // -> BOTH catch and pend. (The PID-write set-pulse case.)
    edge_and_check(1'b1, 1'b1, "pulse1 seed clear");
    park_low;
    CLR = 0;
    PN  = 0;   // pulse on...
`ifdef FPGA_FF_MODE
    @(posedge sysclk);
    @(posedge sysclk);
`else
    #2;
`endif
    PN = 1;    // ...and off again before any capture edge
    pulse_edge;
    check_edge("pulse1: sub-edge request pulse");
    p1_eq = (INR_V1 === 1'b1) && (INR_V2 === 1'b1);
    if (!p1_eq) begin
      errors = errors + 1;
      $display("FAIL pulse1: expected BOTH caught =1, got V1=%b V2=%b", INR_V1, INR_V2);
    end
    close_edge;
    edge_and_check(1'b1, 1'b1, "pulse1 cleanup clear");

    // pulse-2: CLR pulse while CP LOW, strictly between captures (from set)
    // -> BOTH lose the caught state and drop at the next edge.
    edge_and_check(1'b0, 1'b0, "pulse2 seed set");
    edge_and_check(1'b0, 1'b1, "pulse2 hold");
    park_low;
    PN  = 1;
    CLR = 1;   // pulse on (CP low -> the CPN&CLR clear path is live)...
`ifdef FPGA_FF_MODE
    @(posedge sysclk);
    @(posedge sysclk);
`else
    #2;
`endif
    CLR = 0;   // ...and off again before any capture edge
    pulse_edge;
    check_edge("pulse2: CP-low CLR pulse");
    p2_eq = (INR_V1 === 1'b0) && (INR_V2 === 1'b0);
    if (!p2_eq) begin
      errors = errors + 1;
      $display("FAIL pulse2: expected BOTH cleared =0, got V1=%b V2=%b", INR_V1, INR_V2);
    end
    close_edge;

    // pulse-3: CLR pulse while CP HIGH only -> the async clear path needs
    // CP low, so BOTH must hold the caught state.
    edge_and_check(1'b0, 1'b0, "pulse3 seed set");
`ifdef FPGA_FF_MODE
    wait (cnt == 3'd1);  // MCLK high, just after a capture
    CLR = 1;
    @(posedge sysclk);
    CLR = 0;             // off again while MCLK still high (cnt==2)
`else
    #1 CP = 1;
    #2 CLR = 1;
    #2 CLR = 0;
    #1 CP = 0;           // CLR already 0 when CP falls
    #2;
`endif
    edge_and_check(1'b0, 1'b1, "pulse3 edge after high-only CLR pulse");
    p3_eq = (INR_V1 === 1'b1) && (INR_V2 === 1'b1);
    if (!p3_eq) begin
      errors = errors + 1;
      $display("FAIL pulse3: expected both HELD =1, got V1=%b V2=%b", INR_V1, INR_V2);
    end
    edge_and_check(1'b1, 1'b1, "pulse3 cleanup clear");

    // pulse-4: clear coincides with a still-asserted request, request then
    // dropped mid-CP-high without a fresh capture -> the residual request
    // re-arms BOTH catchers; BOTH re-pend at the next edge.
    edge_and_check(1'b0, 1'b0, "pulse4 seed request");        // both pend
    edge_and_check(1'b1, 1'b0, "pulse4 clear w/ req held");   // both clear, req still low
`ifdef FPGA_FF_MODE
    wait (cnt == 3'd1);
`else
    #1 CP = 1;
    #2;
`endif
    CLR = 0;
    PN  = 1;   // request dropped mid-high
`ifdef FPGA_FF_MODE
    pulse_edge;
`else
    #1 CP = 0;
    #2;
    pulse_edge;
`endif
    check_edge("pulse4: residual request re-arm");
    p4_eq = (INR_V1 === 1'b1) && (INR_V2 === 1'b1);
    if (!p4_eq) begin
      errors = errors + 1;
      $display("FAIL pulse4: expected BOTH re-pend =1, got V1=%b V2=%b", INR_V1, INR_V2);
    end
    close_edge;
    edge_and_check(1'b1, 1'b1, "pulse4 cleanup clear");

`ifndef FPGA_FF_MODE
    // ---- RESIDUAL divergence: sub-sysclk glitch (asserted, expected) ----
    // A PN pulse that fits entirely between two sysclk samples: the
    // transparent async latch (and the golden) catch it, the sysclk
    // catcher cannot. This is the glitch sensitivity V2 removes.
    edge_and_check(1'b1, 1'b1, "subsys seed clear");
    park_low;
    CLR = 0;
    #0.6 PN = 0;   // pulse lives 0.6ns..0.9ns after an integer instant:
    #0.3 PN = 1;   // no .5ns-grid sysclk posedge falls inside it
    #1.1;
    pulse_edge;
    sub_v1 = (INR_V1 === 1'b1) && (Lq === 1'b1);  // latch + golden caught it
    sub_v2 = (INR_V2 === 1'b0);                   // sysclk catcher rejected it
    if (!sub_v1 || !sub_v2) begin
      errors = errors + 1;
      $display("FAIL subsys: expected V1=Lq=1 (glitch caught) V2=0 (rejected), got V1=%b Lq=%b V2=%b",
               INR_V1, Lq, INR_V2);
    end
    close_edge;
    // re-sync all three with a clear edge, then resume strict checking
    edge_and_check(1'b1, 1'b1, "subsys re-sync clear");
    if (INR_V1 !== INR_V2) begin
      errors = errors + 1;
      $display("FAIL subsys re-sync: V1=%b V2=%b", INR_V1, INR_V2);
    end
`else
    sub_v1 = 1;  // non-applicable in FF mode (input timing is sysclk-quantised)
    sub_v2 = 1;
`endif

    // ---- randomized soak: strict three-way equivalence, mixed phases ----
    for (i = 0; i < 800; i = i + 1) begin
      r = $random;
      if (i % 3 == 0) edge_and_check_midhigh(r[1], r[0], "random midhigh");
      else            edge_and_check(r[1], r[0], "random");
    end

    $display("spotlights: set=%b hold=%b clr=%b idle-stays-clear=%b pulse1-eq=%b pulse2-eq=%b pulse3-eq=%b pulse4-eq=%b subsys(V1=1,V2=0)=%b%b",
             pass_set, pass_hold1, pass_clr, pass_idle, p1_eq, p2_eq, p3_eq, p4_eq, sub_v1,
             sub_v2);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
