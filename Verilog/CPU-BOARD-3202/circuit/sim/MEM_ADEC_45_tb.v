/**************************************************************************
** ND120 CPU Board 3202D - unit test                                     **
** MEM_ADEC_45 - MEM/ADEC address decoders (sheet 45), REAL DUT          **
**                                                                       **
** The older CPU-BOARD-3202/sim/reqgnt_equiv_tb.v proves the P1b/P1c     **
** request/grant FLAG CONVERSION on an inline model. This tb drives the  **
** REAL MEM_ADEC_45 netlist: PAL_44445B (UCADEC), PAL_44446B (UBADEC),   **
** PAL_44904B (UMSIZE, LCD only - outputs unused on the sheet), the      **
** BLRQ/RLRQ request/grant flags and the grant-gated BANK/MWRITE merge.  **
**                                                                       **
** Two builds, SAME stimulus and check count:                            **
**   plain          - D_FLIPFLOP flags clocked by the strobes, base PALs **
**   -DFPGA_FF_MODE - sysclk edge-detect flags + PAL_4444xB_D mirrors    **
** Contract (from reqgnt_equiv_tb): strobes are generated in the sysclk  **
** domain, at least one sysclk wide, data stable across each strobe      **
** rise; observation points are two negedges after any change.           **
**                                                                       **
** Golden model re-derived INDEPENDENTLY from the PALASM comments in     **
** PAL_44445B.v / PAL_44446B.v (PAL16R4: registered Q0-Q3 inverting,     **
** OE_n gated; combinational B outputs):                                 **
**   UCADEC regs at ECREQ rise:  one-hot bank from PPN21:20              **
**       00->BANK0, 01->BANK2, 10->BANK1, 11->none (the 060687 JLB       **
**       "SWAPPED BANK1 AND BANK2" note), MWRITE<=WRITE                  **
**   UBADEC regs at DBAPR rise:  same decode from BD21:20, MWRITE<=      **
**       BINPUT (=~IBINPUT_n)                                            **
**   CLRQ_n = ~(ECREQ & IORQ_n & ~PPN23 & ~PPN22 & ~PPN21 & MOFF_n)     **
**       (the two PALASM product terms differ only in PPN20 - reduced)   **
**   CRQ_n  = ~(ECREQ & (IORQ | MOFF | PPN23 | PPN22 | PPN21))          **
**   AOK    = ~(BMEM_n | BD23 | BD22 | BD21 | MOFF)      (4 MB limit)    **
**   DDBAPR = DBAPR (comb pass-through -> BLRQ flag clock)               **
** MOFF_n is tied 1 on this sheet (SW2 normal), so the MOFF products of  **
** CRQ/CLRQ/AOK are untestable HERE - they are exercised in the PAL      **
** unit tbs (PAL/sim/PAL_44445B_D_tb.v, PAL_44446B_D_tb.v).              **
**                                                                       **
** PINNED (gate behavior kept, flagged for audit):                       **
**  PIN-1 RESOLVED 11-AUG-2026 - it WAS a transcription error, and not   **
**        benign. Confirmed against the 600 dpi REV-D drawing, sheet 45  **
**        region B4-D5: 9G (/OE=CGNT~) and 6G (/OE=BGNT~) share the      **
**        BANK/MWRITE~ nets with RN18 pull-ups, so the pull-up wins when **
**        BOTH grants are HIGH (both PALs output-disabled). The gates    **
**        tested both grants LOW, leaving BANK=000 and MWRITE_n=0 on an  **
**        idle bus - a write asserted with no grant. Through PAL 45008   **
**        (OET_n = ~MWRITE) that held both AM29833A transceivers driving **
**        LBD onto DD every idle cycle. Fixed in MEM_ADEC_45.v; the      **
**        golden below follows the drawing.                              **
**  PIN-2 Disabled-output asymmetry: PAL_44445B drives MWRITE_n=1 when   **
**        OE_n=1 but PAL_44446B drives MWRITE_n=0; masked here by the    **
**        grant AND-gating in the merge, visible only through PIN-1.     **
**  PIN-3 RLRQ sets on the RISING edge of REFRQ_n (the strobe's         **
**        trailing edge for an active-low request), d = power = 1.       **
**  PIN-4 PD4 only gates the PAL_44904B LCD outputs, which terminate in  **
**        the sheet's unused_lcd_bits - no observable effect; toggled    **
**        in the soak for coverage only.                                 **
**                                                                       **
** Run: make test-adec (CPU-BOARD-3202/circuit/sim, both builds)         **
**                                                                       **
** Last reviewed: 01-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_ADEC_45_tb;

  // Total checks both builds must produce (7 output checks per call).
  parameter EXPECTED_CHECKS = 28602;

  reg sysclk = 0;
  always #10 sysclk = ~sysclk;

  reg sys_rst_n = 0;

  // DUT inputs (idle defaults)
  reg BGNT_n = 1;
  reg BMEM_n = 1;
  reg CGNT_n = 1;
  reg DBAPR = 0;
  reg ECREQ = 0;
  reg IBINPUT_n = 1;
  reg IORQ_n = 1;
  reg PD4 = 1;
  reg REFRQ_n = 0;
  reg RGNT_n = 1;
  reg WRITE = 0;
  reg [4:0] BD23_19_n = 5'b11111;
  reg [4:0] PPN_23_19 = 5'b00000;

  wire [2:0] BANK_2_0;
  wire BLRQ_n, CLRQ_n, CRQ_n, MOFF_n, MWRITE_n, RLRQ_n;

  MEM_ADEC_45 dut (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .BGNT_n(BGNT_n),
      .BMEM_n(BMEM_n),
      .CGNT_n(CGNT_n),
      .DBAPR(DBAPR),
      .ECREQ(ECREQ),
      .IBINPUT_n(IBINPUT_n),
      .IORQ_n(IORQ_n),
      .PD4(PD4),
      .REFRQ_n(REFRQ_n),
      .RGNT_n(RGNT_n),
      .WRITE(WRITE),
      .BD23_19_n(BD23_19_n),
      .PPN_23_19(PPN_23_19),
      .BANK_2_0(BANK_2_0),
      .BLRQ_n(BLRQ_n),
      .CLRQ_n(CLRQ_n),
      .CRQ_n(CRQ_n),
      .MOFF_n(MOFF_n),
      .MWRITE_n(MWRITE_n),
      .RLRQ_n(RLRQ_n)
  );

  /*************************************************************************
   ** Independent golden model state                                       **
   *************************************************************************/
  reg [2:0] g_uc_bank = 3'b000;   // registered one-hot {BANK2,BANK1,BANK0}
  reg       g_uc_mwrite = 1'b0;
  reg [2:0] g_ub_bank = 3'b000;
  reg       g_ub_mwrite = 1'b0;
  reg       g_blrq = 1'b0;        // BLRQ flag (MEMORY_1)
  reg       g_rlrq = 1'b0;        // RLRQ flag (MEMORY_2)

  // One-hot bank decode, re-derived from the PALASM register equations:
  //   BANK0 = ~(b21|b20), BANK1 = b21&~b20, BANK2 = ~b21&b20
  function [2:0] bank_decode(input b21, input b20);
    case ({b21, b20})
      2'b00:   bank_decode = 3'b001;
      2'b01:   bank_decode = 3'b100;
      2'b10:   bank_decode = 3'b010;
      default: bank_decode = 3'b000;
    endcase
  endfunction

  // AOK per the 44446B PALASM (MOFF_n is tied 1 on this sheet)
  function aok_now(input dummy);
    aok_now = (~BMEM_n) & BD23_19_n[4] & BD23_19_n[3] & BD23_19_n[2];
  endfunction

  /*************************************************************************
   ** Check machinery                                                      **
   *************************************************************************/
  integer checks = 0;
  integer errors = 0;

  task cmp(input [2:0] got, input [2:0] exp, input [127:0] what);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors <= 30)
          $display("FAIL t=%0t %0s got=%b exp=%b", $time, what, got, exp);
      end
    end
  endtask

  task settle;
    begin
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  // Level-dominant grant clears (async reset in plain, sync in FF mode -
  // identical at settled observation points).
  task model_dominance;
    begin
      if (!BGNT_n) g_blrq = 1'b0;
      if (!RGNT_n) g_rlrq = 1'b0;
    end
  endtask

  task check_all;
    reg [2:0] exp_bank;
    reg exp_mw_n;
    reg exp_clrq_n;
    reg exp_crq_n;
    begin
      // RESOLVED 11-AUG-2026, was PIN-1. The 600 dpi REV-D drawing, sheet 45
      // region B4-D5, settles it: 9G (/OE = CGNT~) and 6G (/OE = BGNT~) share
      // the BANK2:0 and MWRITE~ nets, each pulled up by RN18. The pull-up wins
      // only when BOTH PALs are output-DISABLED, i.e. BOTH GRANTS HIGH. The
      // gates tested both grants LOW, so an idle bus held BANK=000 and
      // MWRITE_n=0 - a write asserted with no grant outstanding, which through
      // PAL 45008's OET_n = ~MWRITE left both AM29833A transceivers driving
      // LBD onto DD continuously. Fixed in MEM_ADEC_45.v; this golden follows
      // the drawing now instead of pinning the gates.
      if (BGNT_n && CGNT_n) begin
        exp_bank = 3'b111;
        exp_mw_n = 1'b1;
      end else begin
        exp_bank = (CGNT_n ? 3'b000 : g_uc_bank) | (BGNT_n ? 3'b000 : g_ub_bank);
        exp_mw_n = ((BGNT_n == 1'b0) && (g_ub_mwrite == 1'b0)) ||
                   ((CGNT_n == 1'b0) && (g_uc_mwrite == 1'b0));
      end
      exp_clrq_n = ~(ECREQ & IORQ_n & ~PPN_23_19[4] & ~PPN_23_19[3] & ~PPN_23_19[2]);
      exp_crq_n  = ~(ECREQ & (~IORQ_n | PPN_23_19[4] | PPN_23_19[3] | PPN_23_19[2]));

      cmp({2'b00, MOFF_n},   {2'b00, 1'b1},        "MOFF_n");
      cmp(BANK_2_0,          exp_bank,             "BANK_2_0");
      cmp({2'b00, MWRITE_n}, {2'b00, exp_mw_n},    "MWRITE_n");
      cmp({2'b00, BLRQ_n},   {2'b00, ~g_blrq},     "BLRQ_n");
      cmp({2'b00, RLRQ_n},   {2'b00, ~g_rlrq},     "RLRQ_n");
      cmp({2'b00, CLRQ_n},   {2'b00, exp_clrq_n},  "CLRQ_n");
      cmp({2'b00, CRQ_n},    {2'b00, exp_crq_n},   "CRQ_n");
    end
  endtask

  /*************************************************************************
   ** Strobe helpers (rise = capture event, per the golden model)          **
   *************************************************************************/
  task raise_ecreq;
    begin
      @(negedge sysclk);
      ECREQ = 1;
      settle;
      g_uc_bank   = bank_decode(PPN_23_19[2], PPN_23_19[1]);
      g_uc_mwrite = WRITE;
      model_dominance;
    end
  endtask

  task drop_ecreq;
    begin
      @(negedge sysclk);
      ECREQ = 0;
      settle;
      model_dominance;
    end
  endtask

  task raise_dbapr;
    begin
      @(negedge sysclk);
      DBAPR = 1;
      settle;
      g_ub_bank   = bank_decode(~BD23_19_n[2], ~BD23_19_n[1]);
      g_ub_mwrite = ~IBINPUT_n;
      if (BGNT_n) g_blrq = aok_now(1'b0);
      model_dominance;
    end
  endtask

  task drop_dbapr;
    begin
      @(negedge sysclk);
      DBAPR = 0;
      settle;
      model_dominance;
    end
  endtask

  task raise_refrq;
    begin
      @(negedge sysclk);
      REFRQ_n = 1;
      settle;
      if (RGNT_n) g_rlrq = 1'b1;  // PIN-3: d = power = 1
      model_dominance;
    end
  endtask

  task drop_refrq;
    begin
      @(negedge sysclk);
      REFRQ_n = 0;
      settle;
      model_dominance;
    end
  endtask

  // Generic settle after a plain (non-strobe) input change
  task after_change;
    begin
      settle;
      model_dominance;
    end
  endtask

  /*************************************************************************
   ** Soak PRNG (xorshift32, fixed seed)                                   **
   *************************************************************************/
  reg [31:0] prng = 32'hC0FFEE45;
  task prng_next;
    begin
      prng = prng ^ (prng << 13);
      prng = prng ^ (prng >> 17);
      prng = prng ^ (prng << 5);
    end
  endtask

  integer i;

  initial begin
    /*********************************************************************
     ** Reset + priming (defines every latch-mode X register)            **
     *********************************************************************/
    repeat (4) @(negedge sysclk);
    sys_rst_n = 1;
    settle;

    // Prime UCADEC (PPN=0, WRITE=0) and UBADEC (BD idle, BMEM_n=1 -> aok=0)
    raise_ecreq;
    drop_ecreq;
    raise_dbapr;
    drop_dbapr;
    check_all;

    /*********************************************************************
     ** 1. UC bank decode: all four PPN21:20 codes, WRITE both ways      **
     *********************************************************************/
    for (i = 0; i < 4; i = i + 1) begin
      @(negedge sysclk);
      PPN_23_19 = {2'b00, i[1], i[0], 1'b0};
      WRITE     = i[0];
      after_change;
      raise_ecreq;
      check_all;
      @(negedge sysclk);
      CGNT_n = 0;  // observe the registered bank through the grant gate
      after_change;
      check_all;
      @(negedge sysclk);
      CGNT_n = 1;
      after_change;
      drop_ecreq;
      check_all;
    end

    /*********************************************************************
     ** 2. UB bank decode: all four BD21:20 codes, BINPUT both ways      **
     *********************************************************************/
    for (i = 0; i < 4; i = i + 1) begin
      @(negedge sysclk);
      BD23_19_n = {2'b11, ~i[1], ~i[0], 1'b1};
      IBINPUT_n = ~i[0];
      after_change;
      raise_dbapr;
      check_all;
      @(negedge sysclk);
      BGNT_n = 0;
      after_change;
      check_all;
      @(negedge sysclk);
      BGNT_n = 1;
      after_change;
      drop_dbapr;
      check_all;
    end
    @(negedge sysclk);
    BD23_19_n = 5'b11111;
    IBINPUT_n = 1;
    after_change;

    /*********************************************************************
     ** 3. CLRQ literal walk (base: asserted, then break each literal)   **
     *********************************************************************/
    @(negedge sysclk);
    PPN_23_19 = 5'b00000;
    WRITE = 0;
    IORQ_n = 1;
    after_change;
    raise_ecreq;
    check_all;                       // CLRQ_n = 0 (both PALASM terms merged)
    @(negedge sysclk) IORQ_n = 0;         after_change; check_all;  // IORQ kills
    @(negedge sysclk) IORQ_n = 1;         after_change; check_all;
    @(negedge sysclk) PPN_23_19[4] = 1;   after_change; check_all;  // PPN23 kills
    @(negedge sysclk) PPN_23_19[4] = 0;   after_change; check_all;
    @(negedge sysclk) PPN_23_19[3] = 1;   after_change; check_all;  // PPN22 kills
    @(negedge sysclk) PPN_23_19[3] = 0;   after_change; check_all;
    @(negedge sysclk) PPN_23_19[2] = 1;   after_change; check_all;  // PPN21 kills
    @(negedge sysclk) PPN_23_19[2] = 0;   after_change; check_all;
    @(negedge sysclk) PPN_23_19[1] = 1;   after_change; check_all;  // PPN20 DON'T-CARE
    @(negedge sysclk) PPN_23_19[1] = 0;   after_change; check_all;
    @(negedge sysclk) PPN_23_19[0] = 1;   after_change; check_all;  // PPN19 unused
    @(negedge sysclk) PPN_23_19[0] = 0;   after_change; check_all;
    drop_ecreq;
    check_all;                       // ECREQ literal (deasserted -> CLRQ_n=1)

    /*********************************************************************
     ** 4. CRQ product walk (each set term alone; MOFF term untestable   **
     **    here - MOFF_n tied 1 - covered by the PAL unit tb)            **
     *********************************************************************/
    raise_ecreq;
    check_all;                       // no term -> CRQ_n = 1
    @(negedge sysclk) IORQ_n = 0;         after_change; check_all;  // IOX term
    @(negedge sysclk) IORQ_n = 1;         after_change; check_all;
    @(negedge sysclk) PPN_23_19[4] = 1;   after_change; check_all;  // PPN23 term
    @(negedge sysclk) PPN_23_19[4] = 0;   after_change; check_all;
    @(negedge sysclk) PPN_23_19[3] = 1;   after_change; check_all;  // PPN22 term
    @(negedge sysclk) PPN_23_19[3] = 0;   after_change; check_all;
    @(negedge sysclk) PPN_23_19[2] = 1;   after_change; check_all;  // PPN21 term
    @(negedge sysclk) PPN_23_19[2] = 0;   after_change; check_all;
    drop_ecreq;
    check_all;

    /*********************************************************************
     ** 5. Edge-not-level for UCADEC: data change under held ECREQ       **
     *********************************************************************/
    raise_ecreq;
    check_all;
    @(negedge sysclk) PPN_23_19 = 5'b00110; WRITE = 1; after_change;
    check_all;                       // registers must NOT re-capture
    @(negedge sysclk) CGNT_n = 0; after_change; check_all;  // still the old bank
    @(negedge sysclk) CGNT_n = 1; after_change;
    drop_ecreq;
    @(negedge sysclk) PPN_23_19 = 5'b00000; WRITE = 0; after_change;
    check_all;

    /*********************************************************************
     ** 6. AOK / BLRQ handshake                                          **
     *********************************************************************/
    // aok=1 request sets the flag
    @(negedge sysclk) BMEM_n = 0; after_change;
    raise_dbapr; check_all;               // BLRQ_n = 0
    drop_dbapr;  check_all;               // hold after the strobe drops
    @(negedge sysclk) BGNT_n = 0; after_change; check_all;  // grant clears
    @(negedge sysclk) BGNT_n = 1; after_change; check_all;

    // each AOK-blocking literal alone must keep the flag clear
    @(negedge sysclk) BMEM_n = 1; after_change;
    raise_dbapr; check_all; drop_dbapr; check_all;         // BMEM_n blocks
    @(negedge sysclk) BMEM_n = 0; BD23_19_n[4] = 0; after_change;
    raise_dbapr; check_all; drop_dbapr; check_all;         // BD23 blocks
    @(negedge sysclk) BD23_19_n[4] = 1; BD23_19_n[3] = 0; after_change;
    raise_dbapr; check_all; drop_dbapr; check_all;         // BD22 blocks
    @(negedge sysclk) BD23_19_n[3] = 1; BD23_19_n[2] = 0; after_change;
    raise_dbapr; check_all; drop_dbapr; check_all;         // BD21 blocks
    // BD20 is NOT in AOK (4 MB decode) - active BD20 must still set
    @(negedge sysclk) BD23_19_n[2] = 1; BD23_19_n[1] = 0; after_change;
    raise_dbapr; check_all;
    @(negedge sysclk) BGNT_n = 0; after_change; check_all;
    @(negedge sysclk) BGNT_n = 1; after_change; drop_dbapr;
    // grant-dominant: request under held grant must not set
    @(negedge sysclk) BGNT_n = 0; after_change;
    raise_dbapr; check_all;
    drop_dbapr;
    @(negedge sysclk) BGNT_n = 1; after_change; check_all;
    // edge-not-level: aok becomes true under a HELD strobe - no set
    @(negedge sysclk) BMEM_n = 1; after_change;
    raise_dbapr; check_all;
    @(negedge sysclk) BMEM_n = 0; after_change; check_all;
    drop_dbapr;
    @(negedge sysclk) BMEM_n = 1; BD23_19_n = 5'b11111; after_change;
    check_all;

    /*********************************************************************
     ** 7. RLRQ handshake (PIN-3 rising-edge set)                        **
     *********************************************************************/
    raise_refrq; check_all;               // RLRQ_n = 0
    drop_refrq;  check_all;               // held
    @(negedge sysclk) RGNT_n = 0; after_change; check_all;  // grant clears
    @(negedge sysclk) RGNT_n = 1; after_change; check_all;
    // rise under held grant must not set
    @(negedge sysclk) RGNT_n = 0; after_change;
    raise_refrq; check_all;
    @(negedge sysclk) RGNT_n = 1; after_change; check_all;
    drop_refrq;
    raise_refrq; check_all;               // sets again after release
    @(negedge sysclk) RGNT_n = 0; after_change; check_all;
    @(negedge sysclk) RGNT_n = 1; after_change;
    drop_refrq; check_all;

    /*********************************************************************
     ** 8. PIN-1 both-granted forced value + no-grant gate value         **
     *********************************************************************/
    // load distinct values in both PALs first
    @(negedge sysclk) PPN_23_19 = 5'b00100; WRITE = 1; after_change;  // uc: BANK1
    raise_ecreq; drop_ecreq;
    @(negedge sysclk) BD23_19_n = 5'b11101; IBINPUT_n = 1; after_change; // ub: BANK2
    raise_dbapr; drop_dbapr;
    check_all;                            // no grant: BANK=000, MWRITE_n=0 (PIN-1)
    @(negedge sysclk) BGNT_n = 0; CGNT_n = 0; after_change;
    check_all;                            // both granted: 111 / 1 (PIN-1)
    @(negedge sysclk) BGNT_n = 1; after_change; check_all;  // CPU grant alone
    @(negedge sysclk) CGNT_n = 1; BGNT_n = 0; after_change; check_all;  // bus alone
    @(negedge sysclk) BGNT_n = 1; after_change; check_all;
    @(negedge sysclk) BD23_19_n = 5'b11111; PPN_23_19 = 5'b00000; WRITE = 0;
    after_change;

    /*********************************************************************
     ** 9. Fixed-seed soak: 4000 single-change steps, checked each step  **
     *********************************************************************/
    for (i = 0; i < 4000; i = i + 1) begin
      prng_next;
      case (prng[3:0] % 10)
        0: begin
          if (ECREQ) drop_ecreq;
          else raise_ecreq;
        end
        1: begin
          if (DBAPR) drop_dbapr;
          else raise_dbapr;
        end
        2: begin
          if (REFRQ_n) drop_refrq;
          else raise_refrq;
        end
        3: begin
          @(negedge sysclk) BGNT_n = ~BGNT_n;
          after_change;
        end
        4: begin
          @(negedge sysclk) CGNT_n = ~CGNT_n;
          after_change;
        end
        5: begin
          @(negedge sysclk) RGNT_n = ~RGNT_n;
          after_change;
        end
        6: begin
          @(negedge sysclk) PPN_23_19 = prng[20:16];
          after_change;
        end
        7: begin
          @(negedge sysclk) BD23_19_n = prng[12:8];
          BMEM_n = prng[13];
          after_change;
        end
        8: begin
          @(negedge sysclk) WRITE = prng[6];
          IORQ_n = prng[5];
          IBINPUT_n = prng[4];
          after_change;
        end
        9: begin
          @(negedge sysclk) PD4 = prng[0];  // PIN-4: no observable effect
          after_change;
        end
      endcase
      check_all;
    end

    /*********************************************************************
     ** Verdict                                                          **
     *********************************************************************/
    $display("checks=%0d errors=%0d", checks, errors);
    if (checks != EXPECTED_CHECKS) begin
      $display("TB_RESULT: FAIL (check count %0d != expected %0d)", checks,
               EXPECTED_CHECKS);
    end else if (errors == 0) begin
      $display("TB_RESULT: PASS (%0d checks)", checks);
    end else begin
      $display("TB_RESULT: FAIL (%0d errors)", errors);
    end
    $finish;
  end

endmodule
