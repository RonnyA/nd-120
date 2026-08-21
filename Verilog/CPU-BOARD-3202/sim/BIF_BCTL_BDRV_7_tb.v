/**************************************************************************
** BIF_BCTL_BDRV_7 - exhaustive bus driver testbench                     **
** (sheet 7, BUS DRIVER - the gates and the refactored 74F241 chip 3A)   **
**                                                                       **
** This sheet drives the ND bus control lines, including OUTIDENT~ - the **
** line the IDENT PL10 investigation is currently standing on - so it is **
** worth knowing exactly what reaches what. The module is entirely       **
** combinational with 18 inputs, so EVERY ONE of the 262144 input        **
** combinations is evaluated. Nothing here is sampled or inferred.       **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   1. AN INVERTED OR SWAPPED PASS-THROUGH. Three outputs are plain     **
**      board wires: BAPR~ = APR~, BREF~ = REF~, BINPUT~ = CBWRITE~.     **
**      Each is checked on all 262144 vectors, so an inversion or a swap **
**      with a neighbouring signal fails on the first vector that        **
**      distinguishes them.                                              **
**   2. THE TRI-STATE REPLACEMENT RULES. The 74F241 was refactored into  **
**      plain logic and the RTL states the intent in comments: with      **
**      EIOD~ high, OUTIDENT~ / BIOXE~ / BINACK~ read HIGH; with TOUT    **
**      low, IOXERR~ / MOR~ / BERROR~ / BDRY~ read HIGH. These are the   **
**      "pulled up instead of three-stated" decisions and they are       **
**      asserted exhaustively, because getting one of them backwards is  **
**      indistinguishable from working silicon until a bus cycle stalls. **
**   3. OUTIDENT~ AND BIOXE~ MUST BE COMPLEMENTS while enabled - they    **
**      come from MIS0 and ~MIS0 on the same chip. If they were ever     **
**      driven from the same polarity, an IDENT and an IOXE would go out **
**      together.                                                        **
**   4. A DEAD INPUT: exhaustively, every input must be able to change   **
**      at least one output. One that cannot is not connected.           **
**   5. THE INFLUENCE MATRIX (printed): for every input/output pair,     **
**      whether that input can EVER move that output. This is the        **
**      sheet's real wiring, measured rather than read off a drawing,    **
**      and any rewiring of a gate changes it. Two entries are asserted  **
**      by name because they matter to the current bus work:             **
**        - MIS0 must reach OUTIDENT~ and BIOXE~ and nothing else        **
**        - TOUT must reach IOXERR~, MOR~, BERROR~ and BDRY~             **
**                                                                       **
** MEASURED HERE AND REPORTED, NOT SILENTLY ACCEPTED: BDRY~ is           **
** identical to BERROR~ on all 262144 vectors, and the IBDRY~ input      **
** never reaches the BDRY~ output at all (it reaches only BMEM~). That   **
** follows directly from the RTL - BDRY~ = TOUT ? BERROR~ : 1 and        **
** BERROR~ = TOUT ? 0 : 1 - and it is pinned here as the CURRENT         **
** BEHAVIOUR so that a correction to it is a deliberate, visible change. **
** Whether it is what the drawing says is NOT decided by this testbench. **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-bdrv7                 **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module BIF_BCTL_BDRV_7_tb;

  reg APR_n, BDRY25_n, BDRY50_n, BINPUT75_n, CACT_n, CBWRITE_n, DAP_n;
  reg EIOD_n, GNT50_n, IBDRY_n, IBREQ_n, IOD_n, MEM_n, MIS0, REF_n;
  reg SEM_n, SSEMA_n, TOUT;

  wire BAPR_n, BDAP_n, BDRY_n, BERROR_n, BINACK_n, BINPUT_n, BIOXE_n;
  wire BMEM_n, BREF_n, IOXERR_n, MOR_n, OUTGRANT_n, OUTIDENT_n, SEMRQ_n;

  integer errors = 0;
  integer checks = 0;
  integer v, i, j;

  localparam integer NIN  = 18;
  localparam integer NOUT = 14;
  localparam integer NVEC = 262144;   // 2**18, exhaustive

  reg [NOUT-1:0] out_a, out_b;
  reg [NOUT-1:0] influence[0:NIN-1];  // bit j set = input i can move output j
  reg [NOUT-1:0] or_seen  = 0;
  reg [NOUT-1:0] and_seen = {NOUT{1'b1}};
  integer bdry_differs_from_berror = 0;

  BIF_BCTL_BDRV_7 DUT (
      .APR_n(APR_n), .BDRY25_n(BDRY25_n), .BDRY50_n(BDRY50_n),
      .BINPUT75_n(BINPUT75_n), .CACT_n(CACT_n), .CBWRITE_n(CBWRITE_n),
      .DAP_n(DAP_n), .EIOD_n(EIOD_n), .GNT50_n(GNT50_n), .IBDRY_n(IBDRY_n),
      .IBREQ_n(IBREQ_n), .IOD_n(IOD_n), .MEM_n(MEM_n), .MIS0(MIS0),
      .REF_n(REF_n), .SEM_n(SEM_n), .SSEMA_n(SSEMA_n), .TOUT(TOUT),
      .BAPR_n(BAPR_n), .BDAP_n(BDAP_n), .BDRY_n(BDRY_n), .BERROR_n(BERROR_n),
      .BINACK_n(BINACK_n), .BINPUT_n(BINPUT_n), .BIOXE_n(BIOXE_n),
      .BMEM_n(BMEM_n), .BREF_n(BREF_n), .IOXERR_n(IOXERR_n), .MOR_n(MOR_n),
      .OUTGRANT_n(OUTGRANT_n), .OUTIDENT_n(OUTIDENT_n), .SEMRQ_n(SEMRQ_n)
  );

  function [8*12:1] in_name;
    input integer b;
    begin
      case (b)
        0:  in_name = "APR_n       "; 1:  in_name = "BDRY25_n    ";
        2:  in_name = "BDRY50_n    "; 3:  in_name = "BINPUT75_n  ";
        4:  in_name = "CACT_n      "; 5:  in_name = "CBWRITE_n   ";
        6:  in_name = "DAP_n       "; 7:  in_name = "EIOD_n      ";
        8:  in_name = "GNT50_n     "; 9:  in_name = "IBDRY_n     ";
        10: in_name = "IBREQ_n     "; 11: in_name = "IOD_n       ";
        12: in_name = "MEM_n       "; 13: in_name = "MIS0        ";
        14: in_name = "REF_n       "; 15: in_name = "SEM_n       ";
        16: in_name = "SSEMA_n     "; 17: in_name = "TOUT        ";
        default: in_name = "???         ";
      endcase
    end
  endfunction

  function [8*11:1] out_name;
    input integer b;
    begin
      case (b)
        13: out_name = "BAPR_n     "; 12: out_name = "BDAP_n     ";
        11: out_name = "BDRY_n     "; 10: out_name = "BERROR_n   ";
        9:  out_name = "BINACK_n   "; 8:  out_name = "BINPUT_n   ";
        7:  out_name = "BIOXE_n    "; 6:  out_name = "BMEM_n     ";
        5:  out_name = "BREF_n     "; 4:  out_name = "IOXERR_n   ";
        3:  out_name = "MOR_n      "; 2:  out_name = "OUTGRANT_n ";
        1:  out_name = "OUTIDENT_n "; 0:  out_name = "SEMRQ_n    ";
        default: out_name = "???        ";
      endcase
    end
  endfunction

  task apply;
    input [NIN-1:0] s;
    begin
      {APR_n, BDRY25_n, BDRY50_n, BINPUT75_n, CACT_n, CBWRITE_n, DAP_n,
       EIOD_n, GNT50_n, IBDRY_n, IBREQ_n, IOD_n, MEM_n, MIS0, REF_n,
       SEM_n, SSEMA_n, TOUT} = {s[0], s[1], s[2], s[3], s[4], s[5], s[6],
       s[7], s[8], s[9], s[10], s[11], s[12], s[13], s[14], s[15], s[16], s[17]};
    end
  endtask

  function [NOUT-1:0] outs;
    input dummy;
    begin
      outs = {BAPR_n, BDAP_n, BDRY_n, BERROR_n, BINACK_n, BINPUT_n, BIOXE_n,
              BMEM_n, BREF_n, IOXERR_n, MOR_n, OUTGRANT_n, OUTIDENT_n, SEMRQ_n};
    end
  endfunction

  task expect1;
    input [255:0] name;
    input got, want;
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        if (errors < 15)
          $display("FAIL %0s: got %b want %b at vector %0d", name, got, want, v);
      end
    end
  endtask

  initial begin
    $dumpfile("BIF_BCTL_BDRV_7_tb.vcd");
    // full depth on a 262144-vector sweep produces an unreadable file, so
    // dump the port level only - it is a timing diagram, not a database
    $dumpvars(1, BIF_BCTL_BDRV_7_tb);
    // Keep the committed waveform SHORT and readable: this testbench runs
    // 262144 vectors twice, so only the opening 400 ns is recorded. The
    // pass/fail verdict comes from the text output, never from the waveform.
    #400 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" BIF_BCTL_BDRV_7 (sheet 7) exhaustive bus driver test");
    $display(" all %0d input combinations", NVEC);
    $display("=====================================================");

    for (i = 0; i < NIN; i = i + 1) influence[i] = 0;

    for (v = 0; v < NVEC; v = v + 1) begin
      apply(v[NIN-1:0]);
      #1;
      out_a   = outs(0);
      or_seen = or_seen | out_a; and_seen = and_seen & out_a;

      // ---- the three plain board wires
      expect1("BAPR_PASSTHROUGH",   BAPR_n,   APR_n);
      expect1("BREF_PASSTHROUGH",   BREF_n,   REF_n);
      expect1("BINPUT_PASSTHROUGH", BINPUT_n, CBWRITE_n);

      // ---- the 74F241 replacement rules, as the RTL states them
      if (EIOD_n) begin
        expect1("OUTIDENT_PULLED_HIGH", OUTIDENT_n, 1'b1);
        expect1("BIOXE_PULLED_HIGH",    BIOXE_n,    1'b1);
        expect1("BINACK_PULLED_HIGH",   BINACK_n,   1'b1);
      end else begin
        expect1("OUTIDENT_FROM_MIS0",  OUTIDENT_n, MIS0);
        expect1("BIOXE_FROM_MIS0_N",   BIOXE_n,    ~MIS0);
        expect1("BINACK_FROM_BINPUT75", BINACK_n,  BINPUT75_n);
        // the pair must be complements - never both asserted
        checks = checks + 1;
        if (OUTIDENT_n === BIOXE_n) begin
          errors = errors + 1;
          if (errors < 15)
            $display("FAIL IDENT_IOXE_SAME_POLARITY: OUTIDENT_n=%b BIOXE_n=%b",
                     OUTIDENT_n, BIOXE_n);
        end
      end

      if (!TOUT) begin
        expect1("IOXERR_PULLED_HIGH", IOXERR_n, 1'b1);
        expect1("MOR_PULLED_HIGH",    MOR_n,    1'b1);
        expect1("BERROR_PULLED_HIGH", BERROR_n, 1'b1);
        expect1("BDRY_PULLED_HIGH",   BDRY_n,   1'b1);
      end else begin
        expect1("IOXERR_FROM_IOD", IOXERR_n, IOD_n);
        expect1("MOR_FROM_MEM",    MOR_n,    MEM_n);
        expect1("BERROR_ASSERTED", BERROR_n, 1'b0);
      end

      // ---- pinned current behaviour, see the header
      if (BDRY_n !== BERROR_n) bdry_differs_from_berror = bdry_differs_from_berror + 1;

      // ---- nothing may be x
      checks = checks + 1;
      if (^out_a === 1'bx) begin
        errors = errors + 1;
        if (errors < 15) $display("FAIL X_OUTPUT at vector %0d: %b", v, out_a);
      end
    end

    // ---- influence matrix, exhaustive
    for (v = 0; v < NVEC; v = v + 1) begin
      apply(v[NIN-1:0]); #1; out_a = outs(0);
      for (i = 0; i < NIN; i = i + 1) begin
        apply(v[NIN-1:0] ^ ({{(NIN-1){1'b0}}, 1'b1} << i)); #1;
        out_b = outs(0);
        influence[i] = influence[i] | (out_a ^ out_b);
      end
    end

    $display(" influence matrix (which outputs each input can move):");
    for (i = 0; i < NIN; i = i + 1) begin
      $write("   %0s ->", in_name(i));
      for (j = NOUT - 1; j >= 0; j = j - 1)
        if (influence[i][j]) $write(" %0s", out_name(j));
      if (influence[i] == 0) $write(" (NOTHING)");
      $write("\n");
      checks = checks + 1;
      if (influence[i] == 0) begin
        errors = errors + 1;
        $display("FAIL DEAD_INPUT: %0s cannot move any output of this sheet",
                 in_name(i));
      end
    end

    // ---- the two named cones that the current bus work depends on
    checks = checks + 2;
    if (influence[13] !== ((1 << 1) | (1 << 7))) begin
      errors = errors + 1;
      $display("FAIL MIS0_CONE: MIS0 reaches %b, expected exactly OUTIDENT_n and BIOXE_n",
               influence[13]);
    end
    if (influence[17] !== ((1 << 4) | (1 << 3) | (1 << 10) | (1 << 11))) begin
      errors = errors + 1;
      $display("FAIL TOUT_CONE: TOUT reaches %b, expected exactly IOXERR_n, MOR_n, BERROR_n and BDRY_n",
               influence[17]);
    end

    // ---- pinned: BDRY~ currently tracks BERROR~ exactly, and IBDRY~ never
    // ---- reaches BDRY~. Reported plainly; a change makes this fail.
    $display(" vectors where BDRY_n differs from BERROR_n: %0d (currently expected 0)",
             bdry_differs_from_berror);
    checks = checks + 2;
    if (bdry_differs_from_berror != 0) begin
      errors = errors + 1;
      $display("FAIL BDRY_BERROR_SPLIT: BDRY_n and BERROR_n are no longer identical - if that is the intended fix, update this testbench and the note in its header");
    end
    if (influence[9][11] !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL IBDRY_NOW_REACHES_BDRY: IBDRY_n can now move BDRY_n - if that is the intended fix, update this testbench");
    end

    // ---- output liveness
    for (j = 0; j < NOUT; j = j + 1) begin
      checks = checks + 2;
      if (or_seen[j] === 1'b0) begin
        errors = errors + 1;
        $display("FAIL STUCK_LOW: %0s never went high", out_name(j));
      end
      if (and_seen[j] === 1'b1) begin
        errors = errors + 1;
        $display("FAIL STUCK_HIGH: %0s never went low", out_name(j));
      end
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
