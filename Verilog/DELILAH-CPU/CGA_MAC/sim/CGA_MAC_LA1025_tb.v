/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MAC_LA1025 testbench                                              **
**                                                                       **
** Verification of the LA1025 logical-address block (/CGA/MAC/LA1025,    **
** page 40): the wired-OR merge of the address sources into the upper    **
** logical address LA23-LA10, registered on MCLK, plus the ECCRHIN       **
** (ECC-register high-part hit, active low) decode.                      **
**                                                                       **
** Netlist read-out (BubblesMask decoded, checked gate by gate):         **
**   ILA23/22 NAND: ~(SEG[7/6] & A1617); registered via QCN/QDN so the  **
**                  inversion cancels -> LA23/22 = SEG[7/6]&A1617.       **
**   ILA21/20 NAND: same with SEG[5/4]&B1821 via QEN/QFN.                **
**   ILA19/18     : A02 AOI pairs + bubbled OR2 (= OR of the four        **
**                  product terms), registered true (QG/QH).             **
**   ILA17/16     : 3x A02 + 1 NAND + bubbled OR4 = 7-term wired OR.    **
**   ILA15..10    : A02 (ICA&A10 | ICA&BB10) + NAND (ICA&C10) +          **
**                  bubbled OR2 = 3-term wired OR.                       **
**   R_LA_H/R_LA_L: R81_EN posedge-MCLK registers (FF mode: posedge      **
**                  sysclk gated by MCLK_EN). NO L4/L8/LATCH             **
**                  primitives anywhere in this module.                  **
**   GATES_23     : ECCRHIN = ~(LA15 & ~LA14 & ~LA13 & ~LA12 & ~LA11    **
**                  & ~LA10), i.e. low only when the registered          **
**                  LA[15:10] == 6'b100000 - the upper bits of IOX      **
**                  address 100115 (octal), matching the CALCA low-part  **
**                  ECCR decode (LCA[9:0]==0115).                        **
**   regICA       : always @(s_ica_input) nonblocking copy - a delta     **
**                  delay only; functionally a pass-through. The tb      **
**                  always toggles ICA before priming so the reg never   **
**                  holds x.                                             **
**                                                                       **
** Behavioral golden model (schematic intent, not gate transliteration): **
** each LA bit is the OR of its enabled address-source products:         **
**   LA23=SEG7&A1617                LA22=SEG6&A1617                      **
**   LA21=SEG5&B1821                LA20=SEG4&B1821                      **
**   LA19=(A1619&~PCR14)|(SEG3&B1821)|(~ICA10&A1819)|(~PCR10&B1819)      **
**   LA18=(A1619&~PCR13)|(SEG2&B1821)|(~ICA9&A1819)|(~PCR9&B1819)        **
**   LA17=(ICA7&A10)|(ICA8&BB10)|(PCR12&A1619)|(SEG1&A1617)              **
**        |(PCR10&D1617)|(PCR8&E1617)|(XPT1&F1617)                       **
**   LA16=(ICA6&A10)|(ICA7&BB10)|(PCR11&A1619)|(SEG0&A1617)              **
**        |(PCR9&D1617)|(PCR7&E1617)|(XPT0&F1617)                        **
**   LA[15:10][n]=(ICA[n-10]&A10)|(ICA[n-9]&BB10)|(ICA[n]&C10)           **
** PCR[15] and PCR[6:0] are unused by the gates (pinned by the S2        **
** exhaustive control sweep with PCR=FFFF vs 0000 tuples).               **
**                                                                       **
** Check layers (fixed total 24962, 2 checks per load: LA + ECCRHIN):    **
**  S1 priming: 2 loads (ICA toggled FFFF->0000 to flush regICA) = 4.    **
**  S2 EXHAUSTIVE control sweep: all 2^11 combos of {A10,A1617,A1619,    **
**     A1819,B1819,B1821,BB10,C10,D1617,E1617,F1617} x 4 distinct-       **
**     constant data tuples = 8192 loads = 16384.                        **
**  S3 walking-1/0 per data input: ICA under each of A10/BB10/C10        **
**     alone (96 loads), SEG under A1617/B1821 (32), PCR under           **
**     A1619/B1819/D1617/E1617 (128), XPT 4 values under F1617 (4)       **
**     = 260 loads = 520.                                                **
**  S4 ECCRHIN directed: hits via C10 (ICA=8000), A10 (ICA=0020),        **
**     BB10 (ICA=0040) + 8 one-bit near-misses = 11 loads = 22.          **
**  S5 register hold: 8 patterns, load then change every input with      **
**     MCLK held 1 and MCLK_EN held 0 - outputs must hold = 32.          **
**  S6 soak: 4000 fixed-seed xorshift32 loads, random controls+data,     **
**     every 8th steered to an ECCRHIN hit = 8000.                       **
**                                                                       **
** The load pulse is the proven AP09/CALCA sequence (MCLK low, EN-mode   **
** capture at posedge sysclk, CP-mode capture at the MCLK rise just      **
** after). Only R81_EN registers here, so the plain and                  **
** -DUSE_TRANSPARENT_LATCHES builds are identical netlists; the          **
** Makefile target test-mac-la1025 still runs all three modes for        **
** campaign uniformity with the AP09/SEGPT family.                       **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MAC_LA1025_tb;

  reg         sysclk = 0;
  reg         MCLK = 1;
  reg         MCLK_EN = 0;
  reg         A10 = 0;
  reg         A1617 = 0;
  reg         A1619 = 0;
  reg         A1819 = 0;
  reg         B1819 = 0;
  reg         B1821 = 0;
  reg         BB10 = 0;
  reg         C10 = 0;
  reg         D1617 = 0;
  reg         E1617 = 0;
  reg         F1617 = 0;
  reg  [15:0] ICA = 0;
  reg  [15:0] PCR = 0;
  reg  [ 7:0] SEG = 0;
  reg  [ 1:0] XPT = 0;

  wire        ECCRHIN;
  wire [13:0] LA;

  integer errors = 0;
  integer checks = 0;
  integer i, c, t, k;
  reg [13:0] hold_la;   // S5: expected held value
  reg        hold_ec;
  reg [31:0] rnd;

  localparam integer EXPECTED_CHECKS = 24962;

  reg [15:0] tup_ica[0:3];
  reg [15:0] tup_pcr[0:3];
  reg [ 7:0] tup_seg[0:3];
  reg [ 1:0] tup_xpt[0:3];
  reg [15:0] emiss  [0:10];

  CGA_MAC_LA1025 dut (
      .sysclk  (sysclk),
      .MCLK_EN (MCLK_EN),
      .A10     (A10),
      .A1617   (A1617),
      .A1619   (A1619),
      .A1819   (A1819),
      .B1819   (B1819),
      .B1821   (B1821),
      .BB10    (BB10),
      .C10     (C10),
      .D1617   (D1617),
      .E1617   (E1617),
      .F1617   (F1617),
      .ICA_15_0(ICA),
      .MCLK    (MCLK),
      .PCR_15_0(PCR),
      .SEG_7_0 (SEG),
      .XPT_1_0 (XPT),
      .ECCRHIN (ECCRHIN),
      .LA_23_10(LA)
  );

  always #5 sysclk = ~sysclk;

  // Behavioral golden LA[23:10] (index [13:0] = LA23..LA10): OR-merge of
  // every enabled address-source product per bit.
  function [13:0] la_of;
    input dummy;
    reg [13:0] v;
    begin
      v[13] = SEG[7] & A1617;                                        // LA23
      v[12] = SEG[6] & A1617;                                        // LA22
      v[11] = SEG[5] & B1821;                                        // LA21
      v[10] = SEG[4] & B1821;                                        // LA20
      v[ 9] = (A1619 & ~PCR[14]) | (SEG[3] & B1821)
            | (~ICA[10] & A1819) | (~PCR[10] & B1819);               // LA19
      v[ 8] = (A1619 & ~PCR[13]) | (SEG[2] & B1821)
            | (~ICA[9] & A1819)  | (~PCR[9] & B1819);                // LA18
      v[ 7] = (ICA[7] & A10) | (ICA[8] & BB10) | (PCR[12] & A1619)
            | (SEG[1] & A1617) | (PCR[10] & D1617)
            | (PCR[8] & E1617) | (XPT[1] & F1617);                   // LA17
      v[ 6] = (ICA[6] & A10) | (ICA[7] & BB10) | (PCR[11] & A1619)
            | (SEG[0] & A1617) | (PCR[9] & D1617)
            | (PCR[7] & E1617) | (XPT[0] & F1617);                   // LA16
      v[ 5] = (ICA[5] & A10) | (ICA[6] & BB10) | (ICA[15] & C10);    // LA15
      v[ 4] = (ICA[4] & A10) | (ICA[5] & BB10) | (ICA[14] & C10);    // LA14
      v[ 3] = (ICA[3] & A10) | (ICA[4] & BB10) | (ICA[13] & C10);    // LA13
      v[ 2] = (ICA[2] & A10) | (ICA[3] & BB10) | (ICA[12] & C10);    // LA12
      v[ 1] = (ICA[1] & A10) | (ICA[2] & BB10) | (ICA[11] & C10);    // LA11
      v[ 0] = (ICA[0] & A10) | (ICA[1] & BB10) | (ICA[10] & C10);    // LA10
      la_of = v;
    end
  endfunction

  // ECCRHIN: low only when registered LA[15:10] == 6'b100000.
  function ec_of;
    input [13:0] la_v;
    begin
      ec_of = ~(la_v[5] & ~la_v[4] & ~la_v[3] & ~la_v[2]
                        & ~la_v[1] & ~la_v[0]);
    end
  endfunction

  // xorshift32, fixed seed - reproducible across simulators.
  function [31:0] xs32;
    input [31:0] x;
    reg [31:0] y;
    begin
      y    = x ^ (x << 13);
      y    = y ^ (y >> 17);
      xs32 = y ^ (y << 5);
    end
  endfunction

  task chk14(input [13:0] got, input [13:0] exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: LA got %04x expected %04x (ctl=%b%b%b%b%b%b%b%b%b%b%b ICA=%04x PCR=%04x SEG=%02x XPT=%b)",
                 name, got, exp, A10, A1617, A1619, A1819, B1819, B1821,
                 BB10, C10, D1617, E1617, F1617, ICA, PCR, SEG, XPT);
      end
    end
  endtask

  task chk1(input got, input exp, input [127:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: ECCRHIN got %b expected %b (LA=%04x)",
                 name, got, exp, LA);
      end
    end
  endtask

  // One full load event, valid in all builds (proven AP09/CALCA sequence):
  // inputs stable, MCLK low, EN-mode capture at posedge sysclk, CP-mode
  // capture at the MCLK rise just after. Leaves MCLK=1. Checks: 2.
  task load_and_check(input [127:0] name);
    reg [13:0] exp_la;
    begin
      #2;
      exp_la = la_of(1'b0);
      @(negedge sysclk);
      MCLK    = 0;
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);   // FF-mode R81 capture
      #1 MCLK = 1;         // CP-mode R81 capture
      @(negedge sysclk);
      MCLK_EN = 0;
      #1;
      chk14(LA, exp_la, name);
      chk1(ECCRHIN, ec_of(exp_la), name);
      hold_la = exp_la;
      hold_ec = ec_of(exp_la);
    end
  endtask

  task set_ctl(input [10:0] ctl);
    begin
      {A10, A1617, A1619, A1819, B1819, B1821,
       BB10, C10, D1617, E1617, F1617} = ctl;
    end
  endtask

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_MAC_LA1025_tb: USE_TRANSPARENT_LATCHES build (no latch prims here - identical to plain)");
`elsif FPGA_FF_MODE
    $display("CGA_MAC_LA1025_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MAC_LA1025_tb: plain build (posedge-MCLK CP register)");
`endif

    // ------------------------------------------------------------------
    // S1. Priming: toggle ICA so the regICA delta-copy never holds x,
    //     then two all-zero-select loads. 4 checks.
    // ------------------------------------------------------------------
    ICA = 16'hFFFF;
    #2;
    ICA = 16'h0000;
    load_and_check("S1 prime0");
    set_ctl(11'h7FF);
    ICA = 16'hFFFF; PCR = 16'hFFFF; SEG = 8'hFF; XPT = 2'b11;
    load_and_check("S1 prime1");

    // ------------------------------------------------------------------
    // S2. Exhaustive control sweep: all 2048 combos x 4 distinct-constant
    //     data tuples. 8192 loads = 16384 checks.
    //     Tuple pairs (FFFF/0000 and mixed) make every product term and
    //     every inverted-PCR/inverted-ICA input distinguishable, and pin
    //     PCR[15]/PCR[6:0] as unused.
    // ------------------------------------------------------------------
    tup_ica[0]=16'h0000; tup_pcr[0]=16'hFFFF; tup_seg[0]=8'h00; tup_xpt[0]=2'b11;
    tup_ica[1]=16'hFFFF; tup_pcr[1]=16'h0000; tup_seg[1]=8'hFF; tup_xpt[1]=2'b00;
    tup_ica[2]=16'hA5C3; tup_pcr[2]=16'h35CA; tup_seg[2]=8'h5A; tup_xpt[2]=2'b01;
    tup_ica[3]=16'h5A3C; tup_pcr[3]=16'hCA35; tup_seg[3]=8'hA5; tup_xpt[3]=2'b10;

    for (c = 0; c < 2048; c = c + 1) begin
      set_ctl(c[10:0]);
      for (t = 0; t < 4; t = t + 1) begin
        ICA = tup_ica[t]; PCR = tup_pcr[t];
        SEG = tup_seg[t]; XPT = tup_xpt[t];
        load_and_check("S2 sweep");
      end
    end

    // ------------------------------------------------------------------
    // S3. Walking-1/0 per data input under one select at a time.
    //     260 loads = 520 checks.
    // ------------------------------------------------------------------
    PCR = 0; SEG = 0; XPT = 0; ICA = 0;
    for (i = 0; i < 3; i = i + 1) begin
      set_ctl(11'b0);
      case (i)
        0: A10  = 1;
        1: BB10 = 1;
        default: C10 = 1;
      endcase
      for (k = 0; k < 16; k = k + 1) begin
        ICA = 16'h0001 << k;    load_and_check("S3 walk1 ICA");
        ICA = ~(16'h0001 << k); load_and_check("S3 walk0 ICA");
      end
    end
    ICA = 0;
    for (i = 0; i < 2; i = i + 1) begin
      set_ctl(11'b0);
      if (i == 0) A1617 = 1; else B1821 = 1;
      for (k = 0; k < 8; k = k + 1) begin
        SEG = 8'h01 << k;       load_and_check("S3 walk1 SEG");
        SEG = ~(8'h01 << k);    load_and_check("S3 walk0 SEG");
      end
    end
    SEG = 0;
    for (i = 0; i < 4; i = i + 1) begin
      set_ctl(11'b0);
      case (i)
        0: A1619 = 1;
        1: B1819 = 1;
        2: D1617 = 1;
        default: E1617 = 1;
      endcase
      for (k = 0; k < 16; k = k + 1) begin
        PCR = 16'h0001 << k;    load_and_check("S3 walk1 PCR");
        PCR = ~(16'h0001 << k); load_and_check("S3 walk0 PCR");
      end
    end
    PCR = 0;
    set_ctl(11'b0);
    F1617 = 1;
    for (k = 0; k < 4; k = k + 1) begin
      XPT = k[1:0];             load_and_check("S3 XPT");
    end
    XPT = 0;

    // ------------------------------------------------------------------
    // S4. ECCRHIN directed: LA[15:10]==100000 hits through each ICA
    //     source path + one-bit near-misses. 11 loads = 22 checks.
    // ------------------------------------------------------------------
    emiss[0]=16'h8000;  // hit via C10: LA[15:10]=ICA[15:10]=100000
    emiss[1]=16'h0000;  // bit15 off  -> miss
    emiss[2]=16'h8400;  // +bit10     -> miss
    emiss[3]=16'h8800;  // +bit11     -> miss
    emiss[4]=16'h9000;  // +bit12     -> miss
    emiss[5]=16'hA000;  // +bit13     -> miss
    emiss[6]=16'hC000;  // +bit14     -> miss
    set_ctl(11'b0); C10 = 1;
    for (i = 0; i < 7; i = i + 1) begin
      ICA = emiss[i];
      load_and_check("S4 ECCR C10");
    end
    set_ctl(11'b0); A10 = 1;   // LA[15:10]=ICA[5:0]
    ICA = 16'h0020; load_and_check("S4 ECCR A10 hit");
    ICA = 16'h0030; load_and_check("S4 ECCR A10 miss");
    ICA = 16'h0000; load_and_check("S4 ECCR A10 zero");
    set_ctl(11'b0); BB10 = 1;  // LA[15:10]=ICA[6:1]
    ICA = 16'h0040; load_and_check("S4 ECCR BB10 hit");

    // ------------------------------------------------------------------
    // S5. Register hold: load, then change every input with MCLK held
    //     high and MCLK_EN held low - LA/ECCRHIN must not move.
    //     8 x (2 + 2) = 32 checks.
    // ------------------------------------------------------------------
    for (i = 0; i < 8; i = i + 1) begin
      rnd = 32'h1A102500 + i;
      rnd = xs32(rnd);
      set_ctl(rnd[26:16]);
      ICA = rnd[15:0];
      rnd = xs32(rnd);
      PCR = rnd[15:0]; SEG = rnd[23:16]; XPT = rnd[25:24];
      load_and_check("S5 load");
      // invert everything; no clock event for the registers
      set_ctl(~rnd[26:16]);
      ICA = ~ICA; PCR = ~PCR; SEG = ~SEG; XPT = ~XPT;
      @(negedge sysclk);
      @(negedge sysclk);
      #1;
      chk14(LA, hold_la, "S5 hold LA");
      chk1(ECCRHIN, hold_ec, "S5 hold ECCRHIN");
    end

    // ------------------------------------------------------------------
    // S6. Soak: 4000 fixed-seed xorshift32 loads; every 8th steered to
    //     an ECCRHIN hit through C10. 8000 checks.
    // ------------------------------------------------------------------
    rnd = 32'hC0FFEE25;
    for (i = 0; i < 4000; i = i + 1) begin
      rnd = xs32(rnd);
      ICA = rnd[15:0];
      set_ctl(rnd[26:16]);
      rnd = xs32(rnd);
      PCR = rnd[15:0]; SEG = rnd[23:16]; XPT = rnd[25:24];
      if ((i & 7) == 5) begin
        set_ctl(11'b0); C10 = 1;
        ICA = {6'b100000, ICA[9:0]};
      end
      load_and_check("S6 soak");
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 4 + 16384 + 520 + 22 + 32 + 8000 = 24962.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
