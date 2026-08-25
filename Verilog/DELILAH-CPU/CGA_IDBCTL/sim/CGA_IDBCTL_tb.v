/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_IDBCTL - top-level IDB source select testbench                    **
**                                                                       **
** PDF page 97 of 108. This is the 16-bit-wide IDB read multiplexer:     **
** sixteen CGA_IDBCTL_SEL6 slices sharing one 6-bit enable vector        **
** E_PINS, plus the paging-status register CGA_IDBCTL_PGSREG that        **
** supplies the PGS source.                                              **
**                                                                       **
** WHY THIS TESTBENCH EXISTS                                            **
**   CGA_IDBCTL sits in the combinational ring                          **
**       FIDBO -> MAC/INTR -> PCR/PGS -> CGA_IDBCTL_SEL6 -> FIDBI       **
**   that Vivado reports as a timing loop. The ring can only be broken  **
**   if the D (XFIDBI) input of every slice is FULLY off whenever an    **
**   internal source is selected. Nothing had ever tested that, nor     **
**   what the multiplexer does when more than one enable is asserted    **
**   at once. Both are measured here and printed as explicit verdicts.  **
**                                                                      **
** THE ENABLE VECTOR IS NOT A ONE-HOT CODE ON THIS MODULE               **
**   CGA_IDBCTL has FIVE independent active-low enable pins             **
**   (EPGSN, EPCRN, EPICSN, EPICVN, EPICMASKN). CGA_IDBCTL.v:105-110    **
**   builds E_PINS from them and derives ED (the XFIDBI enable) as      **
**   "none of the five is active". All 32 combinations are legal input  **
**   to the module, so all 32 are driven here. Whether the CPU can ever **
**   present two of them at once is a question about the DECODERS       **
**   (CGA_DCD sheet 8/10 for four of them, CGA_INTR_CNTLR_MDCD for      **
**   EPICMASKN), not about this module, and is reported separately.     **
**                                                                      **
** REFERENCE MODEL - read off the netlist, NOT from documentation.      **
**   Per-slice source wiring, CGA_IDBCTL.v:121-282:                     **
**     D   = XFIDBI[15:0]                     (all 16 slices)           **
**     M   = PICMASK[15:0]                    (all 16 slices)           **
**     PCR = PCR[15:7], 0 for bits 6..3, PCR[2:0]                       **
**     PGS = PGS15,PGS14, 0 for bits 13..12, PGS_11_0[11:0]             **
**     S   = 0 for bits 15..5, LOGSN(4), HIGSN(3), PICS[2:0]            **
**     V   = 0 for bits 15..4, PD(3), PICV[2:0]                         **
**   Slice function, CGA_IDBCTL_SEL6.v:87-94: a 6-input AND/OR - each   **
**   source is ANDed with its own enable and the six products are ORed. **
**   Enables, CGA_IDBCTL.v:105-110:                                     **
**     EPGS=~EPGSN  EPCR=~EPCRN  ES=~EPICSN  EV=~EPICVN  EM=~EPICMASKN  **
**     ED = EPICMASKN & EPICVN & EPICSN & EPCRN & EPGSN                 **
**                                                                      **
** TEST PLAN                                                            **
**   1. walking-one on each of the six sources with only that source's  **
**      enable asserted - catches a swapped or misrouted bit            **
**   2. all 32 enable combinations x 16 pseudo-random source vectors    **
**      against the model                                               **
**   3. RING CHECK: for every enable combination with at least one      **
**      internal source enabled, XFIDBI is swept 0 / all-ones / random  **
**      and the output must not move                                    **
**   4. no-x / no-z check on every sample (a disabled source in this    **
**      repo contributes 0, never z)                                    **
**   5. multi-hot characterisation: with two enables asserted the       **
**      output is compared against the bitwise OR of the two single-    **
**      source results, and the verdict is PRINTED                      **
**                                                                      **
** PGS is an internal register, so it is loaded through PGSREG          **
** (LA_21_10 / FETCHN / PVIOL, captured on an MCLK event with VACCN=0)  **
** and then held with VACCN=1 for the combinational sweeps.             **
** PGS_15_14[1] is taken from the QN pin of PGS15, so the held value is **
** ~FETCHN - that inversion is in the model.                            **
**                                                                      **
** Registered submodule (PGSREG uses SCAN_FF_EN, switched by            **
** FPGA_FF_MODE): the Makefile target test-idbctl runs this twice,      **
** default latch/CP mode and -DFPGA_FF_MODE.                            **
**                                                                      **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).         **
**                                                                      **
** 20-AUG-2026                                                          **
** Ronny Hansen                                                         **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_IDBCTL_tb;

  // ---- DUT pins ------------------------------------------------------
  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK = 0;

  reg         EPCRN = 1;
  reg         EPGSN = 1;
  reg         EPICMASKN = 1;
  reg         EPICSN = 1;
  reg         EPICVN = 1;

  reg         FETCHN = 0;
  reg         HIGSN = 0;
  reg  [11:0] LA_21_10 = 0;
  reg         LOGSN = 0;
  reg  [15:0] PCR_15_0 = 0;
  reg         PD = 0;
  reg  [15:0] PICMASK_15_0 = 0;
  reg  [ 2:0] PICS_2_0 = 0;
  reg  [ 2:0] PICV_2_0 = 0;
  reg         PVIOL = 0;
  reg         VACCN = 1;
  reg  [15:0] XFIDBI_15_0 = 0;

  wire [15:0] FIDBI_15_0_OUT;

  integer     errors = 0;
  integer     checks = 0;
  integer     i, j, k;

  // held PGS state, as loaded through PGSREG (see load_pgs)
  reg  [15:0] pgs_held;

  CGA_IDBCTL dut (
      .sysclk        (sysclk),
      .MCLK_EN       (MCLK_EN),
      .EPCRN         (EPCRN),
      .EPGSN         (EPGSN),
      .EPICMASKN     (EPICMASKN),
      .EPICSN        (EPICSN),
      .EPICVN        (EPICVN),
      .FETCHN        (FETCHN),
      .HIGSN         (HIGSN),
      .LA_21_10      (LA_21_10),
      .LOGSN         (LOGSN),
      .MCLK          (MCLK),
      .PCR_15_0      (PCR_15_0),
      .PD            (PD),
      .PICMASK_15_0  (PICMASK_15_0),
      .PICS_2_0      (PICS_2_0),
      .PICV_2_0      (PICV_2_0),
      .PVIOL         (PVIOL),
      .VACCN         (VACCN),
      .XFIDBI_15_0   (XFIDBI_15_0),
      .FIDBI_15_0_OUT(FIDBI_15_0_OUT)
  );

  always #5 sysclk = ~sysclk;

  // ---- reference model -----------------------------------------------
  // Per-source 16-bit contribution vectors, exactly as wired in
  // CGA_IDBCTL.v (bits with the source tied to s_gnd contribute 0).
  function [15:0] src_d;
    input [15:0] xfidbi;
    begin
      src_d = xfidbi;
    end
  endfunction

  function [15:0] src_m;
    input [15:0] picmask;
    begin
      src_m = picmask;
    end
  endfunction

  function [15:0] src_pcr;
    input [15:0] pcr;
    begin
      src_pcr = {pcr[15:7], 4'b0000, pcr[2:0]};
    end
  endfunction

  function [15:0] src_pgs;
    input [15:0] pgs;  // {pgs15, pgs14, xx, xx, pgs11_0}
    begin
      src_pgs = {pgs[15:14], 2'b00, pgs[11:0]};
    end
  endfunction

  function [15:0] src_s;
    input logs_n;
    input higs_n;
    input [2:0] pics;
    begin
      src_s = {11'b0, logs_n, higs_n, pics[2:0]};
    end
  endfunction

  function [15:0] src_v;
    input pd;
    input [2:0] picv;
    begin
      src_v = {12'b0, pd, picv[2:0]};
    end
  endfunction

  function [15:0] model;
    reg ed, em, ev, es, epcr, epgs;
    reg [15:0] o;
    begin
      epgs = ~EPGSN;
      epcr = ~EPCRN;
      es   = ~EPICSN;
      ev   = ~EPICVN;
      em   = ~EPICMASKN;
      ed   = EPICMASKN & EPICVN & EPICSN & EPCRN & EPGSN;
      o    = 16'h0000;
      if (ed) o = o | src_d(XFIDBI_15_0);
      if (em) o = o | src_m(PICMASK_15_0);
      if (ev) o = o | src_v(PD, PICV_2_0);
      if (es) o = o | src_s(LOGSN, HIGSN, PICS_2_0);
      if (epcr) o = o | src_pcr(PCR_15_0);
      if (epgs) o = o | src_pgs(pgs_held);
      model = o;
    end
  endfunction

  task check;
    input [255:0] tag;
    reg [15:0] exp;
    begin
      #1;
      exp    = model();
      checks = checks + 1;
      if (FIDBI_15_0_OUT !== exp) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL %0s: en(gs,pcr,s,v,m)=%b%b%b%b%b got=%h exp=%h", tag, ~EPGSN, ~EPCRN,
                   ~EPICSN, ~EPICVN, ~EPICMASKN, FIDBI_15_0_OUT, exp);
      end
      // repo rule: a disabled source contributes 0, never z
      if (^FIDBI_15_0_OUT === 1'bx) begin
        errors = errors + 1;
        if (errors <= 20) $display("FAIL %0s: output has x/z: %b", tag, FIDBI_15_0_OUT);
      end
    end
  endtask

  // One MCLK event valid in BOTH build modes (see CGA_IDBCTL_PGSREG_tb.v).
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
    end
  endtask

  // Load PGS with a chosen 16-bit pattern, then hold it (VACCN=1).
  // PGS_15_14[1] comes from QN of PGS15 whose TI is FETCHN, so to hold
  // bit 15 = v[15] the capture must present FETCHN = ~v[15].
  task load_pgs;
    input [15:0] v;
    begin
      FETCHN   = ~v[15];
      PVIOL    = v[14];
      LA_21_10 = v[11:0];
      VACCN    = 0;
      pulse_mclk;
      VACCN    = 1;
      pgs_held = {v[15:14], 2'b00, v[11:0]};
      // move the capture inputs away so a broken hold shows up
      FETCHN   = 1'b0;
      PVIOL    = 1'b0;
      LA_21_10 = 12'h000;
      #1;
    end
  endtask

  task set_enables;
    input [4:0] e;  // {epgs, epcr, es, ev, em}, active high
    begin
      EPGSN     = ~e[4];
      EPCRN     = ~e[3];
      EPICSN    = ~e[2];
      EPICVN    = ~e[1];
      EPICMASKN = ~e[0];
      #1;
    end
  endtask

  task clear_sources;
    begin
      XFIDBI_15_0  = 16'h0000;
      PICMASK_15_0 = 16'h0000;
      PCR_15_0     = 16'h0000;
      LOGSN        = 1'b0;
      HIGSN        = 1'b0;
      PICS_2_0     = 3'b000;
      PD           = 1'b0;
      PICV_2_0     = 3'b000;
      #1;
    end
  endtask

  reg [31:0] lfsr;
  function [31:0] nxt;
    input [31:0] s;
    begin
      nxt = {s[30:0], s[31] ^ s[21] ^ s[1] ^ s[0]};
    end
  endfunction

  // multi-hot characterisation results
  reg multihot_is_or;
  reg multihot_any;
  reg [15:0] out_a, out_b, out_ab;

  initial begin
    $dumpfile("CGA_IDBCTL_tb.vcd");
    $dumpvars(0, CGA_IDBCTL_tb);
  end

  initial begin
    lfsr           = 32'h1234_5678;
    multihot_is_or = 1'b1;
    multihot_any   = 1'b0;
    pgs_held       = 16'h0000;

    clear_sources;
    set_enables(5'b00000);
    load_pgs(16'h0000);

    // ------------------------------------------------------------------
    // 1. walking-one per source, only that source enabled
    // ------------------------------------------------------------------
    // D (XFIDBI) - enabled when NO internal enable is asserted
    set_enables(5'b00000);
    for (i = 0; i < 16; i = i + 1) begin
      clear_sources;
      XFIDBI_15_0 = 16'h0001 << i;
      check("walk-D");
    end
    clear_sources;

    // M (PICMASK)
    set_enables(5'b00001);
    for (i = 0; i < 16; i = i + 1) begin
      clear_sources;
      PICMASK_15_0 = 16'h0001 << i;
      check("walk-M");
    end
    clear_sources;

    // PCR
    set_enables(5'b01000);
    for (i = 0; i < 16; i = i + 1) begin
      clear_sources;
      PCR_15_0 = 16'h0001 << i;
      check("walk-PCR");
    end
    clear_sources;

    // PGS - reload the register for each walking bit, then read it back
    set_enables(5'b10000);
    for (i = 0; i < 16; i = i + 1) begin
      clear_sources;
      load_pgs(16'h0001 << i);
      set_enables(5'b10000);
      check("walk-PGS");
    end
    load_pgs(16'h0000);
    clear_sources;

    // S (LOGSN bit4, HIGSN bit3, PICS bits2:0)
    set_enables(5'b00100);
    for (i = 0; i < 5; i = i + 1) begin
      clear_sources;
      LOGSN    = (i == 4);
      HIGSN    = (i == 3);
      PICS_2_0 = (i < 3) ? (3'b001 << i) : 3'b000;
      check("walk-S");
    end
    clear_sources;

    // V (PD bit3, PICV bits2:0)
    set_enables(5'b00010);
    for (i = 0; i < 4; i = i + 1) begin
      clear_sources;
      PD       = (i == 3);
      PICV_2_0 = (i < 3) ? (3'b001 << i) : 3'b000;
      check("walk-V");
    end
    clear_sources;

    // ------------------------------------------------------------------
    // 2. all 32 enable combinations x 16 pseudo-random source vectors
    // ------------------------------------------------------------------
    load_pgs(16'hA53C);
    for (i = 0; i < 32; i = i + 1) begin
      set_enables(i[4:0]);
      for (j = 0; j < 16; j = j + 1) begin
        lfsr         = nxt(lfsr);
        XFIDBI_15_0  = lfsr[15:0];
        lfsr         = nxt(lfsr);
        PICMASK_15_0 = lfsr[15:0];
        lfsr         = nxt(lfsr);
        PCR_15_0     = lfsr[15:0];
        lfsr         = nxt(lfsr);
        {LOGSN, HIGSN, PICS_2_0} = lfsr[4:0];
        lfsr         = nxt(lfsr);
        {PD, PICV_2_0} = lfsr[3:0];
        check("rand");
      end
    end
    clear_sources;

    // ------------------------------------------------------------------
    // 3. RING CHECK - with any internal source enabled, XFIDBI must be
    //    completely disconnected from the output.
    // ------------------------------------------------------------------
    for (i = 1; i < 32; i = i + 1) begin
      set_enables(i[4:0]);
      PICMASK_15_0 = 16'h0F0F;
      PCR_15_0     = 16'hF0F0;
      {LOGSN, HIGSN, PICS_2_0} = 5'b10101;
      {PD, PICV_2_0} = 4'b1010;
      XFIDBI_15_0  = 16'h0000;
      #1;
      out_a        = FIDBI_15_0_OUT;
      check("ring-0");
      XFIDBI_15_0 = 16'hFFFF;
      #1;
      check("ring-1");
      if (FIDBI_15_0_OUT !== out_a) begin
        errors = errors + 1;
        $display("FAIL RING: enables=%b XFIDBI moved the output %h -> %h", i[4:0], out_a,
                 FIDBI_15_0_OUT);
      end
      checks      = checks + 1;
      XFIDBI_15_0 = 16'h5A5A;
      #1;
      check("ring-r");
      if (FIDBI_15_0_OUT !== out_a) begin
        errors = errors + 1;
        $display("FAIL RING: enables=%b XFIDBI moved the output %h -> %h", i[4:0], out_a,
                 FIDBI_15_0_OUT);
      end
      checks      = checks + 1;
      XFIDBI_15_0 = 16'h0000;
    end
    clear_sources;

    // ------------------------------------------------------------------
    // 5. multi-hot characterisation: every ordered pair of the five
    //    internal enables. Is out(A|B) == out(A) | out(B) ?
    // ------------------------------------------------------------------
    PICMASK_15_0 = 16'hFFFF;
    PCR_15_0     = 16'hFFFF;
    {LOGSN, HIGSN, PICS_2_0} = 5'b11111;
    {PD, PICV_2_0} = 4'b1111;
    load_pgs(16'hFFFF);
    PICMASK_15_0 = 16'hFFFF;
    PCR_15_0     = 16'hFFFF;
    {LOGSN, HIGSN, PICS_2_0} = 5'b11111;
    {PD, PICV_2_0} = 4'b1111;
    for (i = 0; i < 5; i = i + 1) begin
      for (j = i + 1; j < 5; j = j + 1) begin
        set_enables(5'b00001 << i);
        #1;
        out_a = FIDBI_15_0_OUT;
        set_enables(5'b00001 << j);
        #1;
        out_b = FIDBI_15_0_OUT;
        set_enables((5'b00001 << i) | (5'b00001 << j));
        #1;
        out_ab       = FIDBI_15_0_OUT;
        multihot_any = 1'b1;
        checks       = checks + 1;
        if (out_ab !== (out_a | out_b)) begin
          multihot_is_or = 1'b0;
          $display("NOTE multi-hot pair (%0d,%0d): out=%h  A=%h B=%h  A|B=%h", i, j, out_ab, out_a,
                   out_b, (out_a | out_b));
        end
      end
    end

    $display("");
    $display("---- CGA_IDBCTL findings -------------------------------------");
    if (multihot_any && multihot_is_or)
      $display(
          "MULTI-HOT: NOT mutually exclusive - two asserted enables OR their two sources together.");
    else if (multihot_any)
      $display("MULTI-HOT: output is NOT the plain OR of the two sources (see NOTE lines above).");
    // XFIDBI default path
    set_enables(5'b00000);
    XFIDBI_15_0 = 16'hBEEF;
    #1;
    $display("DEFAULT (no enable asserted): out=%h, XFIDBI=%h  -> XFIDBI is the DEFAULT source.",
             FIDBI_15_0_OUT, XFIDBI_15_0);
    set_enables(5'b00001);
    PICMASK_15_0 = 16'h0000;
    XFIDBI_15_0  = 16'hFFFF;
    #1;
    $display("ONE internal enable asserted, its source = 0: out=%h (must be 0000, XFIDBI is FFFF).",
             FIDBI_15_0_OUT);
    checks = checks + 1;
    if (FIDBI_15_0_OUT !== 16'h0000) begin
      errors = errors + 1;
      $display("FAIL: disabled D path leaked");
    end
    $display("--------------------------------------------------------------");
    $display("");

    $display("checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
