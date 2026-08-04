/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_CPU_ALU_CONTR testbench                                           **
** DUT: DELILAH-CPU/CGA_ALU/circuit/CGA_CPU_ALU_CONTR.v (page 42)        **
**                                                                       **
** Golden behavior re-derived independently from the schematic intent    **
** (behavioral equations, not transliterated gates):                     **
**                                                                       **
**   Comb pre-register decode (CSALUM mode):                             **
**     mode 01: alui1n = DGPR0,  else alui1n = ~CSALUI[1]                **
**     mode 10: alui3n = DGPR0,  else alui3n = CSALUI[3]   (see PIN-1)   **
**     mode 11 (shift-type): isel  = SSEL latch (CD[10:9] via LDIRV),    **
**       ialii7 = UPN, ialii8 = LCZN; else isel = CSMIS, ialii7/8 =      **
**       CSALUI[7]/[8].                                                  **
**   Registered on ALUCLK (R41P/R81/D_FLIPFLOP, FF mode: sysclk +        **
**   ALUCLK_EN):                                                         **
**     alui6<=CSALUI[6]; BDEST<=ialii7|ialii8; ALUI4<=CSALUI[4];         **
**     RSN<=alui3n&(CSALUI[5]|~CSALUI[4]); FSEL<=~(CSALUI[5]&CSALUI[4]); **
**     LOG<=(alui3n&CSALUI[4])|CSALUI[5];                                **
**     SB<=CSALUI[2]&(CSALUI[0]|alui1n);                                 **
**     SA<=(CSALUI[2]&alui1n)|(~CSALUI[2]&CSALUI[0]);                    **
**     RA<=alui1n&~CSALUI[2]; RD<=CSALUI[2]&(~alui1n|CSALUI[0]);         **
**     ssel<=isel; alui7<=ialii7; alui8<=ialii8; CSTS[0]<=CSSST[0];      **
**     csst1<=CSSST[1]; cinsel<=CSCINSEL.                                **
**   Comb post-register outputs (async inputs mix in unclocked):         **
**     ALUD2N=~(~alui6&alui7&~alui8); ALUI7=alui7; ALUI8N=~alui8;        **
**     QSEL1=~alui6&alui8; QSEL0=~alui6&~alui7;                          **
**     MI=(alui7&F15)|(~alui7&~alui6&Q0)|(~alui7&alui6&F0);              **
**     QLI=(STS7&ssel==11)|(F15&ssel==01);                               **
**     RRI=(STS7&ssel==11)|(CRY&ssel==10&~alui6)                         **
**         |(((alui6&F0)|(~alui6&Q0))&ssel==01)|(F15&ssel==00);          **
**     RLI=(QLI&alui6)|(~alui6&Q15);                                     **
**     GPRLI=majority(STS7,CRY,GPR0);                                    **
**     GPRC0=~(XFETCHN&~alui7)&LDGPRN; GPRC1=LDGPRN&XFETCHN;             **
**     GPRC2=GPRC1&~alui8;                                               **
**     CSTS[1]=csst1|(alui8&(CSALUM==11));            (see PIN-2)        **
**     CI={cinsel}==00->0, 01->1, 10->STS6, 11->GPR0. (see PIN-3)        **
**                                                                       **
** PINNED netlist behavior (current RTL, verified per gate):             **
**   PIN-1: net s_alui3n carries CSALUI[3] UNINVERTED outside CSALUM=10  **
**     (ALUI3_MUX.B is the pre-inverted s_csalui3_n and MUX21LP negates  **
**     again), while the sibling s_alui1n carries ~CSALUI[1]. In         **
**     CSALUM=10 both carry DGPR0. The asymmetry cannot be resolved      **
**     against the schematic scan from here - behavior PINNED as-is;     **
**     flag for a schematic audit (the full self-test and the 13-area    **
**     instruction campaign pass with this polarity).                    **
**   PIN-2: CSTS_1_0[1] mixes the REGISTERED CSSST[1]/ALUI8 state with   **
**     the CURRENT unregistered CSALUM==11 decode (GATES_49 taps the     **
**     comb s_gates1_out, not a registered copy).                        **
**   PIN-3: the CI select semantics from the gates are 00->0, 01->1,     **
**     10->STS6, 11->GPR0; the CSCINSEL port comment ("Carry In / Carry  **
**     In Not") is usage text, not what the MUX41P decodes.              **
**   PIN-4 (the historical SHIFT bug, FIXED): SSEL capture is a          **
**     TRANSPARENT LATCH on LDIRV (L8 SSEL_LATCH) - the value present    **
**     LATE in the LDIRV-high window is what sticks. Every latch load    **
**     in this tb uses the late-data protocol (garbage at the LDIRV      **
**     rise, real data only later in the window) so a regression to      **
**     rise-edge sampling (the old bug: SSEL stuck 00, every ROT /       **
**     ZIN-right / LIN shift ran as a plain shift) FAILS loudly.         **
**                                                                       **
** Layers:                                                               **
**   0. Init wiggle + first defining load.                    (1 call)   **
**   A. Exhaustive control sweep: 2 aux tuples x 4 CSALUM x 512 CSALUI,  **
**      latch loaded late-data, all 21 outputs checked.   (4096 calls)   **
**   B. Async/comb sweep: 4 directed register states (all 4 SSEL states, **
**      all 4 CI selects) x 1024 async-input combos with NO clock event  **
**      (register-input churn included = hold proof).     (4100 calls)   **
**   C. SSEL latch directed: 4 late-data loads + 4 stale-hold (LDIRV     **
**      low, CD churning) loads under CSALUM=11.             (8 calls)   **
**   D. 4000-step fixed-seed xorshift soak, latch reload every 5th       **
**      step, all inputs randomized.                      (4000 calls)   **
**   Each call checks all 21 output fields: 12205 x 21 = 256305 checks.  **
**                                                                       **
** Sequential (ALUCLK + LDIRV latch domain): compile plain (posedge      **
** ALUCLK, L8 as mux+FF), with -DFPGA_FF_MODE (sysclk+ALUCLK_EN          **
** capture) and with -DUSE_TRANSPARENT_LATCHES (real latch L8) -         **
** Makefile target test-alu-contr runs all three.                        **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with a   **
** hard expected-check-count assertion (256305 checks).                  **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_CPU_ALU_CONTR_tb;

  reg        sysclk = 0;
  reg        ALUCLK_EN = 0;
  reg        ALUCLK = 0;
  reg  [1:0] CD_10_9 = 0;
  reg        CRY = 0;
  reg  [8:0] CSALUI_8_0 = 0;
  reg  [1:0] CSALUM_1_0 = 0;
  reg  [1:0] CSCINSEL_1_0 = 0;
  reg  [1:0] CSMIS_1_0 = 0;
  reg  [1:0] CSSST_1_0 = 0;
  reg        DGPR0N = 0;
  reg        F0 = 0;
  reg        F15 = 0;
  reg        GPR0 = 0;
  reg        LCZN = 0;
  reg        LDGPRN = 0;
  reg        LDIRV = 0;
  reg        Q0 = 0;
  reg        Q15 = 0;
  reg        STS6 = 0;
  reg        STS7 = 0;
  reg        UPN = 0;
  reg        XFETCHN = 0;

  wire       ALUD2N;
  wire       ALUI4;
  wire       ALUI7;
  wire       ALUI8N;
  wire       BDEST;
  wire       CI;
  wire [1:0] CSTS_1_0;
  wire       FSEL;
  wire [2:0] GPRC_2_0;
  wire       GPRLI;
  wire       LOG;
  wire       MI;
  wire       QLI;
  wire [1:0] QSEL_1_0;
  wire       RA;
  wire       RD;
  wire       RLI;
  wire       RRI;
  wire       RSN;
  wire       SA;
  wire       SB;

  integer errors = 0;
  integer checks = 0;
  integer i, m, t, s, k;

  localparam integer EXPECTED_CHECKS = 256305;

  CGA_CPU_ALU_CONTR dut (
      .sysclk(sysclk),
      .ALUCLK_EN(ALUCLK_EN),
      .ALUCLK(ALUCLK),
      .CD_10_9(CD_10_9),
      .CRY(CRY),
      .CSALUI_8_0(CSALUI_8_0),
      .CSALUM_1_0(CSALUM_1_0),
      .CSCINSEL_1_0(CSCINSEL_1_0),
      .CSMIS_1_0(CSMIS_1_0),
      .CSSST_1_0(CSSST_1_0),
      .DGPR0N(DGPR0N),
      .F0(F0),
      .F15(F15),
      .GPR0(GPR0),
      .LCZN(LCZN),
      .LDGPRN(LDGPRN),
      .LDIRV(LDIRV),
      .Q0(Q0),
      .Q15(Q15),
      .STS6(STS6),
      .STS7(STS7),
      .UPN(UPN),
      .XFETCHN(XFETCHN),

      .ALUD2N(ALUD2N),
      .ALUI4(ALUI4),
      .ALUI7(ALUI7),
      .ALUI8N(ALUI8N),
      .BDEST(BDEST),
      .CI(CI),
      .CSTS_1_0(CSTS_1_0),
      .FSEL(FSEL),
      .GPRC_2_0(GPRC_2_0),
      .GPRLI(GPRLI),
      .LOG(LOG),
      .MI(MI),
      .QLI(QLI),
      .QSEL_1_0(QSEL_1_0),
      .RA(RA),
      .RD(RD),
      .RLI(RLI),
      .RRI(RRI),
      .RSN(RSN),
      .SA(SA),
      .SB(SB)
  );

  always #5 sysclk = ~sysclk;

  // ---------------------------------------------------------------------
  // Independent golden model.
  // ---------------------------------------------------------------------

  // SSEL latch model: transparent while LDIRV is high.
  reg [1:0] glat = 0;
  always @(*) if (LDIRV) glat = CD_10_9;

  // Golden register state (captured at each ALUCLK event).
  reg g_alui6, g_bdest, g_alui4, g_rsn, g_fsel, g_log;
  reg g_sb, g_sa, g_ra, g_rd;
  reg g_ssel1, g_ssel0, g_alui7, g_alui8;
  reg g_csts0, g_csst1, g_cin0, g_cin1;

  reg [31:0] lfsr = 32'hC0A71042;

  task golden_capture;
    reg mode3, mode01, mode10;
    reg alui1n, alui3n, i7, i8;
    begin
      mode3   = (CSALUM_1_0 == 2'b11);
      mode01  = (CSALUM_1_0 == 2'b01);
      mode10  = (CSALUM_1_0 == 2'b10);
      alui1n  = mode01 ? ~DGPR0N : ~CSALUI_8_0[1];
      alui3n  = mode10 ? ~DGPR0N : CSALUI_8_0[3];  // PIN-1
      i7      = mode3 ? UPN : CSALUI_8_0[7];
      i8      = mode3 ? LCZN : CSALUI_8_0[8];

      g_ssel1 = mode3 ? glat[1] : CSMIS_1_0[1];
      g_ssel0 = mode3 ? glat[0] : CSMIS_1_0[0];
      g_alui7 = i7;
      g_alui8 = i8;
      g_alui6 = CSALUI_8_0[6];
      g_bdest = i7 | i8;
      g_alui4 = CSALUI_8_0[4];
      g_rsn   = alui3n & (CSALUI_8_0[5] | ~CSALUI_8_0[4]);
      g_fsel  = ~(CSALUI_8_0[5] & CSALUI_8_0[4]);
      g_log   = (alui3n & CSALUI_8_0[4]) | CSALUI_8_0[5];
      g_sb    = CSALUI_8_0[2] & (CSALUI_8_0[0] | alui1n);
      g_sa    = (CSALUI_8_0[2] & alui1n) | (~CSALUI_8_0[2] & CSALUI_8_0[0]);
      g_ra    = alui1n & ~CSALUI_8_0[2];
      g_rd    = CSALUI_8_0[2] & (~alui1n | CSALUI_8_0[0]);
      g_csts0 = CSSST_1_0[0];
      g_csst1 = CSSST_1_0[1];
      g_cin0  = CSCINSEL_1_0[0];
      g_cin1  = CSCINSEL_1_0[1];
    end
  endtask

  // One ALUCLK event, valid in all three build modes (house pattern),
  // then update the golden model.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
      golden_capture;
      #1;
    end
  endtask

  // Late-data latch load (PIN-4 protocol): 'early' garbage is on CD at
  // the LDIRV rise, the real value arrives only later in the high
  // window (spanning a sysclk edge), and the bus is gone after the
  // fall. A rise-edge flip-flop (the historical bug) captures 'early'.
  task latch_load(input [1:0] early, input [1:0] late);
    begin
      @(negedge sysclk);
      CD_10_9 = early;
      #1 LDIRV = 1;
      @(posedge sysclk);
      #1 CD_10_9 = late;
      @(posedge sysclk);
      #1 LDIRV = 0;
      #1 CD_10_9 = ~late;
    end
  endtask

  task chk(input [151:0] name, input [3:0] act, input [3:0] exp);
    begin
      checks = checks + 1;
      if (act !== exp) begin
        errors = errors + 1;
        if (errors <= 30)
          $display("FAIL %0s: got %b expected %b (CSALUM=%b CSALUI=%o glat=%b)",
                   name, act, exp, CSALUM_1_0, CSALUI_8_0, glat);
      end
    end
  endtask

  task check_all;
    reg e_qli, st11, st01, st10, st00, e_gprc1;
    begin
      st11 = g_ssel1 & g_ssel0;
      st01 = ~g_ssel1 & g_ssel0;
      st10 = g_ssel1 & ~g_ssel0;
      st00 = ~g_ssel1 & ~g_ssel0;
      e_qli   = (STS7 & st11) | (F15 & st01);
      e_gprc1 = LDGPRN & XFETCHN;

      chk("ALUD2N", {3'b0, ALUD2N}, {3'b0, ~(~g_alui6 & g_alui7 & ~g_alui8)});
      chk("ALUI4",  {3'b0, ALUI4},  {3'b0, g_alui4});
      chk("ALUI7",  {3'b0, ALUI7},  {3'b0, g_alui7});
      chk("ALUI8N", {3'b0, ALUI8N}, {3'b0, ~g_alui8});
      chk("BDEST",  {3'b0, BDEST},  {3'b0, g_bdest});
      chk("CI",     {3'b0, CI},
          {3'b0, ({g_cin1, g_cin0} == 2'b00) ? 1'b0 :
                 ({g_cin1, g_cin0} == 2'b01) ? 1'b1 :
                 ({g_cin1, g_cin0} == 2'b10) ? STS6 : GPR0});
      chk("CSTS",   {2'b0, CSTS_1_0},
          {2'b0, g_csst1 | (g_alui8 & (CSALUM_1_0 == 2'b11)), g_csts0});
      chk("FSEL",   {3'b0, FSEL},   {3'b0, g_fsel});
      chk("GPRC",   {1'b0, GPRC_2_0},
          {1'b0, e_gprc1 & ~g_alui8, e_gprc1,
                 ~(XFETCHN & ~g_alui7) & LDGPRN});
      chk("GPRLI",  {3'b0, GPRLI},
          {3'b0, (STS7 & CRY) | (STS7 & GPR0) | (GPR0 & CRY)});
      chk("LOG",    {3'b0, LOG},    {3'b0, g_log});
      chk("MI",     {3'b0, MI},
          {3'b0, (g_alui7 & F15) | (~g_alui7 & ~g_alui6 & Q0) |
                 (~g_alui7 & g_alui6 & F0)});
      chk("QLI",    {3'b0, QLI},    {3'b0, e_qli});
      chk("QSEL",   {2'b0, QSEL_1_0},
          {2'b0, ~g_alui6 & g_alui8, ~g_alui6 & ~g_alui7});
      chk("RA",     {3'b0, RA},     {3'b0, g_ra});
      chk("RD",     {3'b0, RD},     {3'b0, g_rd});
      chk("RLI",    {3'b0, RLI},
          {3'b0, (e_qli & g_alui6) | (~g_alui6 & Q15)});
      chk("RRI",    {3'b0, RRI},
          {3'b0, (STS7 & st11) | (CRY & st10 & ~g_alui6) |
                 (((g_alui6 & F0) | (~g_alui6 & Q0)) & st01) |
                 (F15 & st00)});
      chk("RSN",    {3'b0, RSN},    {3'b0, g_rsn});
      chk("SA",     {3'b0, SA},     {3'b0, g_sa});
      chk("SB",     {3'b0, SB},     {3'b0, g_sb});
    end
  endtask

  // Apply one of the two aux tuples (everything except CSALUM/CSALUI).
  task apply_tuple(input integer n);
    begin
      if (n == 0) begin
        DGPR0N = 0; CSMIS_1_0 = 2'b01; CSCINSEL_1_0 = 2'b10;
        CSSST_1_0 = 2'b01; UPN = 0; LCZN = 1;
        F15 = 1; F0 = 0; Q0 = 1; Q15 = 0; STS7 = 1; STS6 = 0;
        CRY = 1; GPR0 = 0; XFETCHN = 1; LDGPRN = 1;
        latch_load(2'b01, 2'b10);  // latch (10) differs from CSMIS (01)
      end else begin
        DGPR0N = 1; CSMIS_1_0 = 2'b10; CSCINSEL_1_0 = 2'b01;
        CSSST_1_0 = 2'b10; UPN = 1; LCZN = 0;
        F15 = 0; F0 = 1; Q0 = 0; Q15 = 1; STS7 = 0; STS6 = 1;
        CRY = 0; GPR0 = 1; XFETCHN = 0; LDGPRN = 0;
        latch_load(2'b10, 2'b01);
      end
    end
  endtask

  initial begin
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_CPU_ALU_CONTR_tb: USE_TRANSPARENT_LATCHES mode");
`elsif FPGA_FF_MODE
    $display("CGA_CPU_ALU_CONTR_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_CPU_ALU_CONTR_tb: plain mode (posedge ALUCLK, L8 mux+FF)");
`endif

    // ------------------------------------------------------------------
    // 0. Init wiggle (kick every always @(*) primitive out of its
    //    startup X) + first defining load. (1 call)
    // ------------------------------------------------------------------
    #12;
    {CRY, DGPR0N, F0, F15, GPR0, LCZN, LDGPRN, Q0, Q15, STS6, STS7,
     UPN, XFETCHN} = 13'h1FFF;
    CSALUI_8_0 = 9'h1FF; CSALUM_1_0 = 3; CSCINSEL_1_0 = 3;
    CSMIS_1_0 = 3; CSSST_1_0 = 3; CD_10_9 = 3;
    #7;
    {CRY, DGPR0N, F0, F15, GPR0, LCZN, LDGPRN, Q0, Q15, STS6, STS7,
     UPN, XFETCHN} = 13'h0000;
    CSALUI_8_0 = 0; CSALUM_1_0 = 0; CSCINSEL_1_0 = 0;
    CSMIS_1_0 = 0; CSSST_1_0 = 0; CD_10_9 = 0;
    #7;
    apply_tuple(0);
    CSALUM_1_0 = 2'b00;
    CSALUI_8_0 = 9'o125;
    pulse_aluclk;
    check_all;

    // ------------------------------------------------------------------
    // A. Exhaustive control sweep: 2 tuples x 4 CSALUM x 512 CSALUI.
    //    (4096 calls)
    // ------------------------------------------------------------------
    for (t = 0; t < 2; t = t + 1) begin
      apply_tuple(t);
      for (m = 0; m < 4; m = m + 1) begin
        CSALUM_1_0 = m[1:0];
        for (i = 0; i < 512; i = i + 1) begin
          CSALUI_8_0 = i[8:0];
          pulse_aluclk;
          check_all;
        end
      end
    end

    // ------------------------------------------------------------------
    // B. Async/comb sweep with NO clock event: 4 register states
    //    (SSEL 00/01/10/11, CI selects 00/01/10/11, alui6/7/8 spread)
    //    x 1024 async combos; register-input churn included so this is
    //    also the hold proof. (4100 calls)
    // ------------------------------------------------------------------
    for (s = 0; s < 4; s = s + 1) begin
      apply_tuple(0);
      CSALUM_1_0   = 2'b00;
      CSMIS_1_0    = s[1:0];
      CSCINSEL_1_0 = s[1:0];
      case (s)
        0: CSALUI_8_0 = 9'b010010101;  // alui7=1, alui6=0, alui8=0
        1: CSALUI_8_0 = 9'b101101010;  // alui8=1, alui6=1, alui7=0
        2: CSALUI_8_0 = 9'b100011001;  // alui8=1, alui6=0, alui7=0
        default: CSALUI_8_0 = 9'b000100110;  // alui6/7/8 = 0
      endcase
      pulse_aluclk;
      check_all;
      for (i = 0; i < 1024; i = i + 1) begin
        {F0, F15, Q0, Q15, STS6, STS7, CRY, GPR0, XFETCHN, LDGPRN} = i[9:0];
        CSALUM_1_0 = {i[3] ^ i[7], i[1] ^ i[9]};   // comb CSTS1 term
        CSALUI_8_0 = {i[8:0]} ^ 9'o252;            // reg-input churn
        CSMIS_1_0  = ~s[1:0];
        DGPR0N     = i[5];
        #2;
        check_all;
      end
    end

    // ------------------------------------------------------------------
    // C. SSEL latch directed (PIN-4, the historical bug lock-in):
    //    4 late-data loads + 4 stale-hold checks under CSALUM=11.
    //    (8 calls)
    // ------------------------------------------------------------------
    apply_tuple(0);
    CSALUM_1_0 = 2'b11;
    CSALUI_8_0 = 9'o123;
    STS7 = 1; F15 = 1; CRY = 1; Q0 = 1; F0 = 1;
    for (i = 0; i < 4; i = i + 1) begin
      CSMIS_1_0 = ~i[1:0];          // mode3 must ignore CSMIS
      latch_load(~i[1:0], i[1:0]);  // garbage at rise, value late
      pulse_aluclk;
      check_all;
    end
    // Stale hold: LDIRV stays low, CD churns, latch must not move.
    for (i = 0; i < 4; i = i + 1) begin
      CD_10_9 = i[1:0];
      #4;
      pulse_aluclk;
      check_all;
    end

    // ------------------------------------------------------------------
    // D. 4000-step fixed-seed xorshift soak, latch reload every 5th
    //    step. (4000 calls)
    // ------------------------------------------------------------------
    for (k = 0; k < 4000; k = k + 1) begin
      lfsr = lfsr ^ (lfsr << 13);
      lfsr = lfsr ^ (lfsr >> 17);
      lfsr = lfsr ^ (lfsr << 5);
      {CRY, DGPR0N, F0, F15, GPR0, LCZN, LDGPRN, Q0, Q15, STS6, STS7,
       UPN, XFETCHN} = lfsr[12:0];
      CSALUI_8_0   = lfsr[21:13];
      CSALUM_1_0   = lfsr[23:22];
      CSCINSEL_1_0 = lfsr[25:24];
      CSMIS_1_0    = lfsr[27:26];
      CSSST_1_0    = lfsr[29:28];
      if (k % 5 == 0) latch_load(lfsr[31:30], lfsr[11:10] ^ lfsr[31:30]);
      pulse_aluclk;
      check_all;
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: (1 + 4096 + 4100 + 8 + 4000) x 21 = 256305.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
