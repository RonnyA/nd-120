/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - COMMAND-SEQUENCE functional test                        **
** CGA_INTR_CNTLR   (Am2914-equivalent priority interrupt controller, schematic p.77)             **
**                                                                                               **
** WHAT THIS TB DOES                                                                              **
**   Drives CGA_INTR_CNTLR through realistic PIC command SEQUENCES (Am2914 microinstructions on    **
**   LAA_3_0, EPIC=1 to execute, one MCLK rising edge per command) and validates the REPORTED      **
**   INTERRUPT LEVEL, the mask register, the masked-request vector, and the 16-level HI/LO         **
**   cascade priority - all against an INDEPENDENT golden model reasoned from the shared spec      **
**   and the RTL, NEVER read back from DUT wires.                                                  **
**                                                                                               **
** GOLDEN SOURCES (cited)                                                                         **
**   - docs/am2914-command-model.md : Am2914 instruction table (Table I, book p.2-108), the        **
**     LAA_3_0<->PIC mapping (S2), the measured mask-command outcomes (S4 probe table), the         **
**     16-level cascade / IREQ-bit->group->in-group-index map (S3), and the worked sequence (S5).   **
**   - RTL: CGA_INTR_CNTLR.v (MIREQ = latched-request AND enabled-mask), _VECGEN_PTY(_PTYENC).v     **
**     (two 8-input priority encoders, "highest active LOW input wins", DET=any-active), _CLR(     **
**     _CLRBIT).v (CLRQ = (J&K) | (J&DATA) | (K&Xvec)), _IRSRC.v (software set-request path).        **
**                                                                                               **
** WHY THE CHECKS ARE ON THE ENCODER/MASK/MIREQ PLANE (and IRQN only when idle)                    **
**   The controller's REPORTED-LEVEL primitives - PICMASK, the masked-request vector MIREQ, and     **
**   the two priority encoders HIVEC/LOVEC + HIDET/LODET - are deterministic combinational/edge     **
**   functions of the mask+request registers and are X-clean the instant those registers are       **
**   loaded (verified by probe). The winning-group VECTOR is exactly "HI group if any HI request,   **
**   else LO", "highest-numbered active input in that group" - which IS the datasheet reported      **
**   level. The TOP-LEVEL PICV_2_0/PICS_2_0/HIGSN/LOGSN and the ACTIVE (asserted) state of IRQN     **
**   are gated by the READ-VECTOR protocol and the group-advance + status-fence FLIP-FLOPS, which   **
**   have no power-on reset and therefore stay X in a bare event-sim in BOTH latch and FPGA_FF_MODE **
**   (measured; exactly the "event-sim hazard" documented in am2914-command-model.md S4). Those     **
**   protocol paths are covered by the dedicated submodule tbs (CGA_INTR_CNTLR_VECGEN_STAT_tb,      **
**   _VECGEN_CMP_tb, _VECGEN_OSMUX_tb, _IRGEL*_tb, _VECGEN_VHR_tb). Here PICV_2_0 = HIVEC*HVE |      **
**   LOVEC*LVE (VMUX) is therefore NOT hard-asserted; the vector VALUE is validated at HIVEC/LOVEC.  **
**   IRQN is deterministic (=1, deasserted) whenever no masked request is pending (measured), so    **
**   the "no interrupt / all cleared" case IS asserted on IRQN.                                     **
**                                                                                               **
** COVERAGE                                                                                        **
**   1. Worked reference sequence (spec S5): MCLR -> enable-all -> assert multiple pins -> read      **
**      highest (HI-over-LO) -> software set-request via the INTERNAL command path (CGA_INTR        **
**      wrapper, EMPIDN+FIDBO) -> re-read -> clear ONE interrupt (CLRMB) -> re-read (LO now wins)    **
**      -> clear-all (MCLR) -> verify cleared.                                                       **
**   2. 16-level cascade: every level 0..15 asserted alone -> reported vector == that level;         **
**      pairwise HI-over-LO and highest-in-group priority; masked level does not appear.             **
**   3. Command classes: MCLR(0), CLAIN(1,reserved), CLRMB(2), LDM(14), BSETM(11), BCLRM(10),        **
**      SETM(8), CLAM(12), ROM(7 -> EPICMASKN), ION(15)/IOF(13) (decode-deterministic), RDVC(5)/     **
**      LOSTA(9) do-not-corrupt-mask/req (their status-fence effect is submodule-covered - noted).   **
**                                                                                               **
** SELF-CHECKING: prints exactly "TB_RESULT: PASS" (or FAIL + step). Golden is independent.         **
** TEETH: -DTEETH_TEST corrupts the golden (lowest-index instead of highest, LO-over-HI, and a       **
**   flipped PICMASK bit) so a CORRECT DUT mismatches -> FAIL, proving the checks have teeth.        **
** Mode: default (posedge-MCLK) build. MCLK_EN=0. sysclk free-runs for the V2 request catcher FF.   **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -y Shared/logisim -y Shared/support -y Shared/ndlib \                          **
**     -y DELILAH-CPU/CGA_INTR/circuit -o /tmp/x DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_seq_tb.v \  **
**     && vvp -N /tmp/x       (or: make -C DELILAH-CPU/CGA_INTR/sim iv-CGA_INTR_CNTLR_seq)           **
**                                                                                               **
** Last reviewed: 16-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_seq_tb;

  // ---- primary DUT: CGA_INTR_CNTLR ----
  reg         sysclk = 0;
  reg         EPIC   = 1;
  reg  [15:0] FIDBO  = 16'h0000;
  reg  [15:0] IREQ_N = 16'hFFFF;   // active-low: no requests
  reg  [ 3:0] LAA    = 4'd0;

  // Mode-aware clocking:
  //   default (posedge-MCLK): MCLK toggled by the commit task; MCLK_EN tied 0; sysclk free-runs
  //                           on the .5ns grid (RQBIT_V2 request-catcher FF).
  //   FPGA_FF_MODE          : sysclk free-runs (10ns), MCLK = sysclk/8, MCLK_EN a one-sysclk pulse
  //                           in the cycle whose posedge is the MCLK rise (capture edge).
`ifdef FPGA_FF_MODE
  reg  [2:0]  cnt = 3'd0;
  always @(posedge sysclk) cnt <= cnt + 3'd1;
  wire        MCLK    = cnt[2];            // sysclk/8, rises on cnt 3->4
  wire        MCLK_EN = (cnt == 3'd3);     // asserted at the posedge that makes the MCLK rise
`else
  reg         MCLK    = 0;
  wire        MCLK_EN = 1'b0;
`endif

  wire        EPICMASKN, HIGSN, IRQN, LOGSN, PD;
  wire [15:0] PICMASK;
  wire [ 2:0] PICS, PICV;

  CGA_INTR_CNTLR dut (
      .sysclk(sysclk), .MCLK_EN(MCLK_EN),
      .EPIC(EPIC), .FIDBO_15_0(FIDBO), .IREQ_15_0_N(IREQ_N), .LAA_3_0(LAA), .MCLK(MCLK),
      .EPICMASKN(EPICMASKN), .HIGSN(HIGSN), .IRQN(IRQN), .LOGSN(LOGSN), .PD(PD),
      .PICMASK_15_0(PICMASK), .PICS_2_0(PICS), .PICV_2_0(PICV)
  );

  // ---- secondary DUT: CGA_INTR wrapper, only for the software-set-request path (EMPIDN+FIDBO) ----
  reg         wEPIC = 1, wEMPIDN = 1;
  reg  [15:0] wFIDBO = 16'h0000;
  reg  [ 3:0] wLAA   = 4'd0;
  reg         wB10=1,wB11=1,wB12=1,wB13=1,wB15=1,wCLIRQN=1,wIOX=1,wMOR=1,wPAN=1,wPAR=1,wPOW=1,wZ=0;
  wire        wEPICMASKN,wHIGSN,wINTRQN,wIRQ,wLOGSN,wPD;
  wire [15:0] wPICMASK;
  wire [ 2:0] wPICS,wPICV;

  CGA_INTR wdut (
      .sysclk(sysclk), .MCLK_EN(1'b0),
      .BINT10N(wB10), .BINT11N(wB11), .BINT12N(wB12), .BINT13N(wB13), .BINT15N(wB15),
      .CLIRQN(wCLIRQN), .EMPIDN(wEMPIDN), .EPIC(wEPIC), .FIDBO_15_0(wFIDBO),
      .IOXERRN(wIOX), .LAA_3_0(wLAA), .MCLK(MCLK), .MORN(wMOR), .PANN(wPAN),
      .PARERRN(wPAR), .POWFAILN(wPOW), .Z(wZ),
      .EPICMASKN(wEPICMASKN), .HIGSN(wHIGSN), .INTRQN(wINTRQN), .IRQ(wIRQ), .LOGSN(wLOGSN),
      .PD(wPD), .PICMASK_15_0(wPICMASK), .PICS_2_0(wPICS), .PICV_2_0(wPICV)
  );

`ifdef FPGA_FF_MODE
  always #5   sysclk = ~sysclk;   // 10ns sysclk; MCLK = sysclk/8
`else
  always #0.5 sysclk = ~sysclk;   // .5ns grid free-running catcher-FF clock
`endif

  integer errors = 0;
  integer checks = 0;

  // ---------------------------------------------------------------------------
  // INDEPENDENT GOLDEN MODEL (shadow of the two visible registers)
  //   g_mask : mask register (== PICMASK). bit=1 DISABLES that level (Am2914, spec S6).
  //   g_req  : latched interrupt-request register (bit=1 -> request latched).
  // Update rules (per MCLK edge), derived from the RTL:
  //   request : g_req[i] = CLRQ[i] ? 0 : (~IREQ_N[i] ? 1 : g_req[i])   (clear-dominant)
  //   CLRQ    : from CLR.v/CLRBIT.v = (J&K) | (J&DATA) | (K&Xvec); command level:
  //             MCLR(0)/CLAIN(1) -> all;  CLRMB(2) -> FIDBO bits;  else 0 (CLRVC(4) Xvec unused here)
  //   mask    : MCLR(0)->0, LDM(14)->FIDBO, BSETM(11)->|FIDBO, BCLRM(10)->&~FIDBO,
  //             SETM(8)->FFFF, CLAM(12)->0, others unchanged   (spec S4 measured table)
  // ---------------------------------------------------------------------------
  reg [15:0] g_mask = 16'h0000;
  reg [15:0] g_req  = 16'h0000;

  // highest-set-index priority encoder for one 8-bit group.
  // returns {det, idx[2:0]} : det=|v, idx=highest set bit (ascending loop -> last wins).
  // TEETH: returns LOWEST set index instead (breaks the priority/cascade checks).
  function [3:0] topidx(input [7:0] v);
    integer k; reg found;
    begin
      topidx = 4'b0000; found = 1'b0;
      for (k = 0; k < 8; k = k + 1)
        if (v[k]) begin
`ifdef TEETH_TEST
          if (!found) topidx = {1'b1, k[2:0]};   // lowest wins (wrong)
`else
          topidx = {1'b1, k[2:0]};               // highest wins (Am2914-correct)
`endif
          found = 1'b1;
        end
    end
  endfunction

  // apply one command through the golden model (call with the SAME args as the DUT command)
  task gold_apply(input [3:0] laa, input ep, input [15:0] fidbo, input [15:0] ireqn);
    reg [15:0] clrq;
    integer i;
    begin
      clrq = 16'h0000;
      if (ep) case (laa)
        4'd0, 4'd1: clrq = 16'hFFFF;   // MCLR / CLAIN : clear all requests
        4'd2:       clrq = fidbo;      // CLRMB        : clear M-bus-selected requests
        default:    clrq = 16'h0000;
      endcase
      for (i = 0; i < 16; i = i + 1)
        g_req[i] = clrq[i] ? 1'b0 : (~ireqn[i] ? 1'b1 : g_req[i]);
      if (ep) case (laa)
        4'd0:  g_mask = 16'h0000;            // MCLR
        4'd8:  g_mask = 16'hFFFF;            // SETM
        4'd12: g_mask = 16'h0000;            // CLAM
        4'd14: g_mask = fidbo;              // LDM
        4'd11: g_mask = g_mask | fidbo;     // BSETM
        4'd10: g_mask = g_mask & ~fidbo;    // BCLRM
        default: ;                           // ROM(7)/others: unchanged
      endcase
    end
  endtask

  // ---- advance exactly one MCLK capture (mode-aware), inputs already set ----
  task commit;
    begin
`ifdef FPGA_FF_MODE
      @(negedge MCLK);                 // inputs are stable across the coming capture
      @(posedge MCLK);                 // capture edge (MCLK_EN asserted here)
      repeat (3) @(posedge sysclk);    // let the combinational encoder settle
`else
      #2; MCLK = 1'b1; #2; MCLK = 1'b0; #2;
`endif
    end
  endtask

  // ---- issue one command on the DUT: set inputs, one MCLK capture, let it settle ----
  task drive(input [3:0] laa, input ep, input [15:0] fidbo, input [15:0] ireqn);
    begin
`ifdef FPGA_FF_MODE
      @(negedge MCLK);
      LAA = laa; EPIC = ep; FIDBO = fidbo; IREQ_N = ireqn;
      @(posedge MCLK);
      repeat (3) @(posedge sysclk);
`else
      LAA = laa; EPIC = ep; FIDBO = fidbo; IREQ_N = ireqn;
      #2; MCLK = 1'b1; #2; MCLK = 1'b0; #2;
`endif
    end
  endtask

  // ---- combined: golden update + DUT command (keeps them in lockstep) ----
  task step(input [3:0] laa, input ep, input [15:0] fidbo, input [15:0] ireqn);
    begin
      gold_apply(laa, ep, fidbo, ireqn);
      drive(laa, ep, fidbo, ireqn);
    end
  endtask

  // ---- the reported-level + mask + masked-request check against the golden ----
  //   exp_epicmaskn : caller-supplied expected EPICMASKN for the command just issued.
  task check(input [255:0] tag, input exp_epicmaskn);
    reg [15:0] enabled, mireq_act, exp_mireq_n, exp_mask;
    reg [3:0]  hi, lo;
    reg        exp_hidet, exp_lodet;
    reg [2:0]  exp_hivec, exp_lovec;
    integer    i;
    begin
      enabled = ~g_mask;
      for (i = 0; i < 16; i = i + 1) mireq_act[i] = g_req[i] & enabled[i];
      exp_mireq_n = ~mireq_act;
      hi = topidx(mireq_act[15:8]);
      lo = topidx(mireq_act[7:0]);
      exp_hidet = hi[3]; exp_hivec = hi[2:0];
      exp_lodet = lo[3]; exp_lovec = lo[2:0];
      exp_mask = g_mask;
`ifdef TEETH_TEST
      exp_mask = g_mask ^ 16'h0001;   // TEETH: also corrupt the mask golden
`endif

      // --- PICMASK (mask register read-back) ---
      checks = checks + 1;
      if (PICMASK !== exp_mask) begin
        errors = errors + 1;
        $display("FAIL[%0s] PICMASK=%h exp=%h", tag, PICMASK, exp_mask);
      end
      // --- EPICMASKN (mask output-enable strobe: low only on ROM(7)/CLRMR(3)) ---
      checks = checks + 1;
      if (EPICMASKN !== exp_epicmaskn) begin
        errors = errors + 1;
        $display("FAIL[%0s] EPICMASKN=%b exp=%b", tag, EPICMASKN, exp_epicmaskn);
      end
      // --- masked-request vector (active-low) ---
      checks = checks + 1;
      if (dut.s_mireq_15_0 !== exp_mireq_n) begin
        errors = errors + 1;
        $display("FAIL[%0s] MIREQ_N=%h exp=%h (req=%h mask=%h)",
                 tag, dut.s_mireq_15_0, exp_mireq_n, g_req, g_mask);
      end
      // --- priority-encoder detect flags (any request in group) ---
      checks = checks + 1;
      if (dut.s_hidet !== exp_hidet || dut.s_lodet !== exp_lodet) begin
        errors = errors + 1;
        $display("FAIL[%0s] HIDET=%b(exp %b) LODET=%b(exp %b)",
                 tag, dut.s_hidet, exp_hidet, dut.s_lodet, exp_lodet);
      end
      // --- reported vector VALUE per group (only meaningful where that group detects) ---
      if (exp_hidet) begin
        checks = checks + 1;
        if (dut.s_hivec_2_0 !== exp_hivec) begin
          errors = errors + 1;
          $display("FAIL[%0s] HIVEC=%0d exp=%0d", tag, dut.s_hivec_2_0, exp_hivec);
        end
      end
      if (exp_lodet) begin
        checks = checks + 1;
        if (dut.s_lovec_2_0 !== exp_lovec) begin
          errors = errors + 1;
          $display("FAIL[%0s] LOVEC=%0d exp=%0d", tag, dut.s_lovec_2_0, exp_lovec);
        end
      end
      // --- IRQN deasserted (=1) iff no masked request pending (deterministic idle case) ---
      if (!exp_hidet && !exp_lodet) begin
        checks = checks + 1;
        if (IRQN !== 1'b1) begin
          errors = errors + 1;
          $display("FAIL[%0s] IRQN=%b exp=1 (no masked request pending)", tag, IRQN);
        end
      end
    end
  endtask

  // convenience: the winning ABSOLUTE level (0..15) the encoder reports, from the golden.
  // HI group wins over LO; within a group the highest active index wins. -1 = none.
  function integer winner_level(input dummy);
    reg [15:0] enabled, act; reg [3:0] hi, lo; integer i;
    begin
      enabled = ~g_mask;
      for (i = 0; i < 16; i = i + 1) act[i] = g_req[i] & enabled[i];
      hi = topidx(act[15:8]); lo = topidx(act[7:0]);
      if (hi[3])      winner_level = 8 + hi[2:0];
      else if (lo[3]) winner_level = lo[2:0];
      else            winner_level = -1;
    end
  endfunction

  task expect_winner(input [255:0] tag, integer exp_lvl);
    begin
      checks = checks + 1;
      if (winner_level(1'b0) !== exp_lvl) begin
        errors = errors + 1;
        $display("FAIL[%0s] reported winner level=%0d exp=%0d", tag, winner_level(1'b0), exp_lvl);
      end
    end
  endtask

  integer lvl, hi_lvl, lo_lvl;
  reg [15:0] pat;

  // EPICMASKN golden: low (0) only for LAA 3 (CLRMR) and 7 (ROM) with EPIC=1; else 1.
  function exp_emn(input [3:0] laa, input ep);
    exp_emn = ~(((laa == 4'd3) | (laa == 4'd7)) & ep);
  endfunction

  initial begin
    $dumpfile("CGA_INTR_CNTLR_seq_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_seq_tb);

    // ============================================================= PREAMBLE
    // Cold X -> defined: Master Clear several times (clears the request register), no requests.
    // NOTE (spec S4 event-sim hazard): from a cold-X start the LAA decoder + mask-register
    // read-back stay X until at least one NON-MCLR PIC command executes (measured: MCLR alone
    // does not flush the decode X in bare iverilog event-sim, a CLAM/LDM does). So the preamble
    // ends with CLAM(12) (== "enable all", mask->0) to bring the mask/decode plane to a defined
    // state before the first read-back is asserted. The request register IS defined by MCLR
    // (measured: req->0 -> MIREQ=FFFF), so IRQN/DET checks are valid immediately.
    repeat (5) step(4'd0, 1'b1, 16'h0000, 16'hFFFF);
    step(4'd12, 1'b1, 16'h0000, 16'hFFFF);   // CLAM: enable all, flush decode/mask to defined
    check("preamble-clam", exp_emn(4'd12,1'b1));
    expect_winner("preamble-none", -1);

    // ============================================================= COMMAND CLASS: mask ops
    step(4'd14, 1'b1, 16'h0000, 16'hFFFF); check("LDM=0000",  exp_emn(4'd14,1'b1)); // enable all
    step(4'd14, 1'b1, 16'hFFFF, 16'hFFFF); check("LDM=FFFF",  exp_emn(4'd14,1'b1)); // disable all
    step(4'd14, 1'b1, 16'hA53C, 16'hFFFF); check("LDM=A53C",  exp_emn(4'd14,1'b1)); // arbitrary
    step(4'd11, 1'b1, 16'h0F00, 16'hFFFF); check("BSETM+0F00",exp_emn(4'd11,1'b1)); // set bits
    step(4'd10, 1'b1, 16'h0300, 16'hFFFF); check("BCLRM-0300",exp_emn(4'd10,1'b1)); // clear bits
    step(4'd8,  1'b1, 16'h0000, 16'hFFFF); check("SETM",      exp_emn(4'd8 ,1'b1)); // inhibit all
    step(4'd12, 1'b1, 16'h0000, 16'hFFFF); check("CLAM",      exp_emn(4'd12,1'b1)); // enable all
    step(4'd7,  1'b1, 16'h1234, 16'hFFFF); check("ROM",       exp_emn(4'd7 ,1'b1)); // read mask: EPICMASKN=0, mask held
    // EPIC=0 -> NOP: LDM with EPIC low must NOT change the mask
    step(4'd14, 1'b0, 16'hFFFF, 16'hFFFF); check("LDM-EPIC0-nop", exp_emn(4'd14,1'b0));

    // ============================================================= WORKED REFERENCE SEQUENCE (spec S5)
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF); check("wrk-mclr",  exp_emn(4'd0,1'b1));
    step(4'd14, 1'b1, 16'h0000, 16'hFFFF); check("wrk-enable-all", exp_emn(4'd14,1'b1));  // all enabled
    step(4'd15, 1'b1, 16'h0000, 16'hFFFF); check("wrk-ion",   exp_emn(4'd15,1'b1));       // ENIN
    // assert bit10(IOX,HI idx2) + bit3(lvl13,LO idx3) + bit0(lvl10,LO idx0). EPIC=0 NOP while reqs latch.
    step(4'd0,  1'b0, 16'h0000, ~16'h0409); check("wrk-assert-10-3-0", exp_emn(4'd0,1'b0));
    expect_winner("wrk-hi-over-lo", 10);   // HI bit10 wins over LO bit3/bit0
    // clear ONE interrupt: drop bit10 via CLRMB (M-bus data = bit10). LO now wins (bit3).
    step(4'd2,  1'b1, 16'h0400, 16'hFFFF);  check("wrk-clrmb-bit10", exp_emn(4'd2,1'b1));
    expect_winner("wrk-lo-wins", 3);        // bit3 = lvl13 (LO idx3)
    // clear the rest (bit3,bit0) via CLRMB, back to none
    step(4'd2,  1'b1, 16'h0009, 16'hFFFF);  check("wrk-clrmb-rest", exp_emn(4'd2,1'b1));
    expect_winner("wrk-after-clrmb-none", -1);
    // clear-all / chip clear
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF);  check("wrk-final-mclr", exp_emn(4'd0,1'b1));
    expect_winner("wrk-cleared", -1);

    // ============================================================= 16-LEVEL CASCADE: each level alone
    for (lvl = 0; lvl < 16; lvl = lvl + 1) begin
      step(4'd0,  1'b1, 16'h0000, 16'hFFFF);              // MCLR
      step(4'd14, 1'b1, 16'h0000, 16'hFFFF);              // enable all
      step(4'd0,  1'b0, 16'h0000, ~(16'h1 << lvl));       // assert exactly this level (EPIC=0 NOP)
      check("cascade-assert", exp_emn(4'd0,1'b0));
      expect_winner("cascade-level", lvl);                // reported vector == this absolute level
    end

    // ============================================================= CASCADE: pairwise priority
    // For a spread of (hi_lvl in HI group) vs (lo_lvl in LO group): HI must win.
    for (hi_lvl = 8; hi_lvl < 16; hi_lvl = hi_lvl + 3)
      for (lo_lvl = 0; lo_lvl < 8; lo_lvl = lo_lvl + 3) begin
        step(4'd0,  1'b1, 16'h0000, 16'hFFFF);
        step(4'd14, 1'b1, 16'h0000, 16'hFFFF);
        step(4'd0,  1'b0, 16'h0000, ~((16'h1 << hi_lvl) | (16'h1 << lo_lvl)));
        check("pair-assert", exp_emn(4'd0,1'b0));
        expect_winner("pair-hi-wins", hi_lvl);            // HI over LO always
      end

    // CASCADE: two levels within the HI group -> higher index wins; then within LO group.
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF);
    step(4'd14, 1'b1, 16'h0000, 16'hFFFF);
    step(4'd0,  1'b0, 16'h0000, ~((16'h1 << 9) | (16'h1 << 13)));  // HI idx1 vs idx5
    check("hi-pair", exp_emn(4'd0,1'b0));
    expect_winner("hi-higher-index-wins", 13);
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF);
    step(4'd14, 1'b1, 16'h0000, 16'hFFFF);
    step(4'd0,  1'b0, 16'h0000, ~((16'h1 << 2) | (16'h1 << 6)));   // LO idx2 vs idx6, no HI
    check("lo-pair", exp_emn(4'd0,1'b0));
    expect_winner("lo-higher-index-wins", 6);

    // ============================================================= MASK GATING: masked level hidden
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF);
    // enable ONLY bit10 (mask = ~0x0400 = FBFF; bit10=0 enabled, all others=1 disabled)
    step(4'd14, 1'b1, 16'hFBFF, 16'hFFFF); check("mask-only-10", exp_emn(4'd14,1'b1));
    // assert bit10 (enabled) AND bit3 (masked). Only bit10 may appear.
    step(4'd0,  1'b0, 16'h0000, ~16'h0408); check("mask-gate-assert", exp_emn(4'd0,1'b0));
    expect_winner("mask-gate-only10", 10);              // bit3 masked out -> HI bit10 reported
    // now enable bit3 too (mask bit3->0), same latched requests -> bit10 still higher, stays HI
    step(4'd10, 1'b1, 16'h0008, 16'hFFFF); check("mask-enable-3", exp_emn(4'd10,1'b1)); // BCLRM bit3
    expect_winner("mask-both-hi-wins", 10);
    // disable bit10 by masking it (BSETM bit10) -> now only bit3 passes -> LO reports
    step(4'd11, 1'b1, 16'h0400, 16'hFFFF); check("mask-disable-10", exp_emn(4'd11,1'b1));
    expect_winner("mask-now-lo3", 3);

    // ============================================================= CLAIN(1) reserved: clears reqs, mask held
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF);
    step(4'd14, 1'b1, 16'hA5A5, 16'hFFFF);              // load a non-trivial mask
    step(4'd0,  1'b0, 16'h0000, ~16'h00FF);            // latch some LO requests (only enabled ones matter)
    check("clain-pre", exp_emn(4'd0,1'b0));
    step(4'd1,  1'b1, 16'h0000, 16'hFFFF);              // CLAIN: clear all requests, mask unchanged
    check("clain-post", exp_emn(4'd1,1'b1));
    expect_winner("clain-cleared", -1);
    // confirm the mask really survived CLAIN
    checks = checks + 1;
    if (PICMASK !== 16'hA5A5) begin
      errors = errors + 1;
      $display("FAIL[clain-mask-held] PICMASK=%h exp=A5A5", PICMASK);
    end

    // ============================================================= RDVC/LOSTA: must not corrupt mask/req
    step(4'd0,  1'b1, 16'h0000, 16'hFFFF);
    step(4'd14, 1'b1, 16'h3C3C, 16'hFFFF); check("rl-mask", exp_emn(4'd14,1'b1));
    step(4'd0,  1'b0, 16'h0000, ~16'h0011); check("rl-reqs", exp_emn(4'd0,1'b0)); // latch bits 0,4
    // RDVC(5): reads vector (+ status-fence load, submodule-covered). Mask+req must be untouched.
    step(4'd5,  1'b1, 16'h0000, 16'hFFFF);  check("rl-rdvc-no-corrupt", exp_emn(4'd5,1'b1));
    // LOSTA(9): loads status from S-bus (fence). Mask+req must be untouched.
    step(4'd9,  1'b1, 16'h0003, 16'hFFFF);  check("rl-losta-no-corrupt", exp_emn(4'd9,1'b1));
    // IOF(13)/ION(15): interrupt disable/enable. Mask+req untouched.
    step(4'd13, 1'b1, 16'h0000, 16'hFFFF);  check("rl-iof-no-corrupt", exp_emn(4'd13,1'b1));
    step(4'd15, 1'b1, 16'h0000, 16'hFFFF);  check("rl-ion-no-corrupt", exp_emn(4'd15,1'b1));

    // ============================================================= SOFTWARE SET-REQUEST via INTERNAL command
    // (CGA_INTR wrapper: raising a request through EMPIDN+FIDBO, NOT an IREQ pin - spec S4.1)
    // (a) combinational IRSRC set path: EMPIDN=0 + FIDBO bit -> that IREQ_15_0_N bit goes low.
    wEMPIDN = 1'b0; wFIDBO = 16'h4000; #3;   // software-raise bit14
    checks = checks + 1;
    if (wdut.s_ireq_15_0_n !== 16'hBFFF) begin
      errors = errors + 1;
      $display("FAIL[sw-set-14] wrapper IREQ_N=%h exp=BFFF", wdut.s_ireq_15_0_n);
    end
    wFIDBO = 16'h0400; #3;                    // software-raise bit10 (IOX line)
    checks = checks + 1;
    if (wdut.s_ireq_15_0_n !== 16'hFBFF) begin
      errors = errors + 1;
      $display("FAIL[sw-set-10] wrapper IREQ_N=%h exp=FBFF", wdut.s_ireq_15_0_n);
    end
    wEMPIDN = 1'b1; wFIDBO = 16'h0000; #3;    // release: no software request
    checks = checks + 1;
    if (wdut.s_ireq_15_0_n !== 16'hFFFF) begin
      errors = errors + 1;
      $display("FAIL[sw-set-release] wrapper IREQ_N=%h exp=FFFF", wdut.s_ireq_15_0_n);
    end
    // (b) tie it to the reported level: MCLR the wrapper's core, enable all, software-raise bit14,
    //     latch it, and confirm the wrapper's priority encoder reports HI idx6 (level 14).
    //     (wrapper shares MCLK; advance captures via the mode-aware commit task.)
    //     DEFAULT-MODE ONLY: this is the sole LATCHED (request-register) wrapper check; the
    //     wrapper's FPGA_FF_MODE request-capture timing (RQBIT_V2 sysclk catcher + MCLK_EN
    //     alignment) is validated by CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2_tb (make test-rqbitv2) and
    //     the IRQ submodule tbs. The COMBINATIONAL IRSRC set-request path (a) above runs and
    //     passes in BOTH modes - that is the "set request via the internal command" contract.
`ifndef FPGA_FF_MODE
    wLAA = 4'd0;  wEPIC = 1'b1; wEMPIDN = 1'b1; wFIDBO = 16'h0000; commit;   // MCLR
    wLAA = 4'd12; commit;                                                     // CLAM: flush decode/mask
    repeat (2) begin wLAA = 4'd0; commit; end                                 // more MCLR
    wLAA = 4'd14; wFIDBO = 16'h0000; commit;                                  // LDM enable all
    wLAA = 4'd15; commit;                                                     // ION
    wEMPIDN = 1'b0; wFIDBO = 16'h4000; wLAA = 4'd15; commit;                  // latch software bit14
    commit;                                                                   // 2nd capture: absorb the
                                                                              // FF-mode RQBIT_V2 catcher
                                                                              // pipeline stage (held req)
    checks = checks + 1;
    if (wdut.CNTLR.s_hidet !== 1'b1 || wdut.CNTLR.s_hivec_2_0 !== 3'd6) begin
      errors = errors + 1;
      $display("FAIL[sw-set-encoder] wrapper HIDET=%b HIVEC=%0d exp HIDET=1 HIVEC=6",
               wdut.CNTLR.s_hidet, wdut.CNTLR.s_hivec_2_0);
    end
    wEMPIDN = 1'b1; wFIDBO = 16'h0000;
`endif

    // ============================================================= VERDICT
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
