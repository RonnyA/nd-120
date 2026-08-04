/**************************************************************************
** ND120 CPU - unit test                                                 **
** BIF_DPATH_PESPEA_13: BIF PEA/PES error registers (sheet 13) - four    **
** TTL_74534 inverting octal registers: 9A/8A capture the PEA address    **
** (BD15..BD0) on SPEA, 12A captures the PES status byte                 **
** {FETCH, GNT, BD21..BD16} on SPES, and 10A captures the PES low byte   **
** (BD23..BD16, the most significant physical address bits) ALSO on      **
** SPEA. The BD bus is active-low, the 74534 inverts, so the registers   **
** hold TRUE values; EPEA_n / EPES_n gate the two 16-bit words onto a    **
** wired-OR IDB (0 when disabled - FPGA convention, no Z).               **
**                                                                       **
** This sheet is part of the PES/SPEA path validated on silicon          **
** (PAGING 11/11, 30-JUL); this tb locks in the FIXED behavior.          **
**                                                                       **
** PINNED (netlist facts, checked as-is):                                **
**   - CHIP_10A (PES bits 7:0) clocks on SPEA, not SPES: the upper       **
**     address byte is captured together with the PEA address; a later   **
**     SPES with different BD does NOT move PES[7:0]. This matches the   **
**     PES register description (bits 0-7 = MS address bits of the       **
**     failing reference).                                               **
**   - PES[14] = GNT asserted (DUT feeds GNT_n into the inverting        **
**     register, so a LOW GNT_n at SPES reads back as 1 = DMA).          **
**   - PES[15] = FETCH true (double inversion: ~FETCH into ~D).          **
**   - Registers power up X; outputs are only defined 0 while BOTH       **
**     enables are off, so the tb captures all four registers before     **
**     the first enabled read.                                           **
**                                                                       **
** INDEPENDENT golden model: four true-value bytes captured by tb-       **
** controlled capture points, never transliterating the DUT ifdef.       **
**                                                                       **
** TWO BUILD MODES (the Makefile compiles and runs both):                **
**   plain          - TTL_74534 USE_SYSCLK=0, capture on the strobe's    **
**                    own posedge (original hardware)                    **
**   -DFPGA_FF_MODE - USE_SYSCLK=2, sysclk-sampled RISING-EDGE capture   **
**                    (the P3 FPGA-safe strobe form)                     **
** Same stimulus and check counts in both modes; the mode-split capture  **
** instant is checked HEAD-ON in a directed divergence phase (data       **
** changed between the strobe rise and the next sysclk: plain holds the  **
** strobe-time value, FF captures the sysclk-time value).                **
**                                                                       **
**  1. Power-on: both enables off -> IDB=0.                              **
**  2. Directed captures: distinct-constant SPEA + SPES loads, EPEA /    **
**     EPES / both / neither readback (wired-OR proof), FETCH x GNT_n    **
**     status combos, the PINNED 10A-on-SPEA wiring (SPES with changed   **
**     BD leaves PES[7:0]), re-capture on a second strobe rise.          **
**  3. Edge-not-level: strobes HELD high with BD/FETCH/GNT churn and     **
**     sysclk ticking - no re-capture in either mode.                    **
**  4. Mode-divergence directed phase (strobe rise vs sysclk sample,    **
**     per-mode golden).                                                 **
**  5. Walking-1 and walking-0 over all 24 BD_n bits through both        **
**     strobes, read under EPEA and EPES.                                **
**  6. 4000-step fixed-seed xorshift32 soak: random BD/FETCH/GNT_n,      **
**     random strobe pulses and enables, IDB compared every step.        **
**                                                                       **
** Every check event compares the full 16-bit IDB word; the total check  **
** count is asserted exactly (a silent partial run FAILS).               **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-pespea   (CPU-BOARD-3202/circuit/sim)                  **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module BIF_DPATH_PESPEA_13_tb;

  // ---------------------------------------------------------------- clocks
  reg sysclk = 0;
  reg spea = 0, spes = 0;

  // ---------------------------------------------------------------- inputs
  reg [23:0] bd_n = 24'hFFFFFF;
  reg epea_n = 1, epes_n = 1;
  reg fetch = 0, gnt_n = 1;

  // ---------------------------------------------------------------- outputs
  wire [15:0] idb;

  BIF_DPATH_PESPEA_13 dut (
      .sysclk      (sysclk),
      .BD_23_0_n_IN(bd_n),
      .EPEA_n      (epea_n),
      .EPES_n      (epes_n),
      .FETCH       (fetch),
      .GNT_n       (gnt_n),
      .SPEA        (spea),
      .SPES        (spes),
      .IDB_15_0_OUT(idb)
  );

  // ------------------------------------------------------ independent model
  // True (inverted-back) captured values. gvalid tracks which halves have
  // ever been captured so the tb never compares against X by construction
  // (it only enables a read after both loads).
  reg [7:0] gp_hi, gp_lo;  // PEA 15:8 / 7:0     (SPEA)
  reg [7:0] gs_hi;         // PES 15:8           (SPES)
  reg [7:0] gs_lo;         // PES 7:0 = BD23..16 (SPEA - pinned wiring)

  task capture_pea;  // model of a SPEA capture instant
    begin
      gp_hi = ~bd_n[15:8];
      gp_lo = ~bd_n[7:0];
      gs_lo = ~bd_n[23:16];
    end
  endtask

  task capture_pes;  // model of a SPES capture instant
    begin
      gs_hi = {fetch, ~gnt_n, ~bd_n[21:16]};
    end
  endtask

`ifdef FPGA_FF_MODE
  reg g_spea_d = 0, g_spes_d = 0;
`endif

  task tick;  // one sysclk pulse; FF mode samples the strobes here
    begin
      #1 sysclk = 1;
`ifdef FPGA_FF_MODE
      if (spea && !g_spea_d) capture_pea;
      g_spea_d = spea;
      if (spes && !g_spes_d) capture_pes;
      g_spes_d = spes;
`endif
      #1 sysclk = 0;
    end
  endtask

  task raise_spea;  // plain mode captures on the strobe's own rise
    begin
      #1;  // data setup time before the strobe edge (as on the board)
      spea = 1;
`ifndef FPGA_FF_MODE
      capture_pea;
`endif
    end
  endtask

  task raise_spes;
    begin
      #1;  // data setup time before the strobe edge (as on the board)
      spes = 1;
`ifndef FPGA_FF_MODE
      capture_pes;
`endif
    end
  endtask

  task pulse_spea;  // full strobe cycle: identical end state in both modes
    begin
      raise_spea;
      tick;
      tick;
      spea = 0;
      tick;
    end
  endtask

  task pulse_spes;
    begin
      raise_spes;
      tick;
      tick;
      spes = 0;
      tick;
    end
  endtask

  // ---------------------------------------------------------------- checking
  wire [15:0] e_idb = (epea_n ? 16'h0 : {gp_hi, gp_lo})
                    | (epes_n ? 16'h0 : {gs_hi, gs_lo});

  integer checks = 0;
  integer errors = 0;

  task check_idb;
    begin
      checks = checks + 1;
      #1;
      if (idb !== e_idb) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("MISMATCH t=%0t IDB got=%04x exp=%04x", $time, idb, e_idb);
      end
    end
  endtask

  // ---------------------------------------------------------------- soak rng
  reg [31:0] rnd = 32'h5EED0013;
  task next_rnd;
    begin
      rnd = rnd ^ (rnd << 13);
      rnd = rnd ^ (rnd >> 17);
      rnd = rnd ^ (rnd << 5);
    end
  endtask

  // 2 + 13 + 4 + 3 + 96 + 4000 check events (phases 1-6), one full 16-bit
  // bus compare each (plus the two embedded literal checks counted in
  // phase 2's 13).
  localparam EXP_CHECKS = 4118;

  integer i;
  initial begin
    // ---- 1. power-on, both enables off (registers X behind dead gates)
    #1 check_idb;
    tick;
    check_idb;

    // ---- 2. directed captures and readback
    // PEA load: address 0x1234, upper bits (BD23..16) 0xA5
    bd_n = ~24'hA51234;
    pulse_spea;
    // PES load: status byte from FETCH=1, GNT asserted, BD21..16 = 0x25
    fetch = 1;
    gnt_n = 0;
    pulse_spes;
    fetch = 0;
    gnt_n = 1;
    epea_n = 0;
    check_idb;  // PEA = 0x1234
    epea_n = 1;
    epes_n = 0;
    check_idb;  // PES = {1,1,100101, 0xA5} = 0xE5A5
    // pinned single values, belt and braces on top of the model compare:
    checks = checks + 1;
    if (idb !== 16'hE5A5) begin
      errors = errors + 1;
      $display("PES literal mismatch: got=%04x exp=E5A5", idb);
    end
    epea_n = 0;
    check_idb;  // both enables: wired OR
    epea_n = 1;
    epes_n = 1;
    check_idb;  // none: 0
    // FETCH/GNT_n combos into PES 15/14
    fetch = 0;
    gnt_n = 1;
    bd_n  = ~24'h000000;
    pulse_spes;
    epes_n = 0;
    check_idb;
    fetch = 1;
    pulse_spes;
    check_idb;
    fetch = 0;
    gnt_n = 0;
    pulse_spes;
    check_idb;
    fetch = 1;
    pulse_spes;
    check_idb;
    epes_n = 1;
    fetch  = 0;
    gnt_n  = 1;
    // PINNED wiring: SPES with changed BD must NOT move PES[7:0]
    bd_n = ~24'h5A0000;  // BD23..16 = 0x5A
    pulse_spea;
    bd_n = ~24'hC3FFFF;  // would give 0xC3 if 10A clocked on SPES
    pulse_spes;
    epes_n = 0;
    check_idb;  // PES[7:0] still 0x5A (golden gs_lo from the SPEA)
    checks = checks + 1;
    if (idb[7:0] !== 8'h5A) begin
      errors = errors + 1;
      $display("PES[7:0] literal mismatch: got=%02x exp=5A", idb[7:0]);
    end
    epes_n = 1;
    // re-capture on a second rise
    bd_n = ~24'h0FF00F;
    pulse_spea;
    epea_n = 0;
    check_idb;
    epea_n = 1;
    check_idb;

    // ---- 3. edge-not-level: strobes held high, inputs churn, no re-capture
    bd_n = ~24'h111111;
    raise_spea;
    raise_spes;
    tick;
    tick;
    epea_n = 0;
    check_idb;
    bd_n  = ~24'h222222;  // strobes still high
    fetch = 1;
    gnt_n = 0;
    tick;
    tick;
    check_idb;  // PEA unchanged
    epea_n = 1;
    epes_n = 0;
    check_idb;  // PES unchanged
    epes_n = 1;
    spea   = 0;
    spes   = 0;
    fetch  = 0;
    gnt_n  = 1;
    tick;
    check_idb;

    // ---- 4. mode-divergence: data moves between strobe rise and sysclk
    bd_n = ~24'h334455;
    raise_spea;  // plain: captures 334455 NOW; FF: nothing yet
    bd_n = ~24'h667788;
    epea_n = 0;
    check_idb;  // plain: new PEA 4455; FF: previous PEA (111111 load)
    tick;  // FF: captures 667788 here
    check_idb;
    spea = 0;
    tick;
    check_idb;
    epea_n = 1;

    // ---- 5. walking-1 / walking-0 over all 24 BD_n bits
    for (i = 0; i < 24; i = i + 1) begin
      bd_n = ~(24'h1 << i);  // exactly one asserted (low) BD line
      pulse_spea;
      pulse_spes;
      epea_n = 0;
      check_idb;
      epea_n = 1;
      epes_n = 0;
      check_idb;
      epes_n = 1;
      bd_n   = (24'h1 << i);  // all asserted but one
      pulse_spea;
      pulse_spes;
      epea_n = 0;
      check_idb;
      epea_n = 1;
      epes_n = 0;
      check_idb;
      epes_n = 1;
    end

    // ---- 6. randomized soak
    for (i = 0; i < 4000; i = i + 1) begin
      next_rnd;
      bd_n  = {rnd[23:0]};
      fetch = rnd[24];
      gnt_n = rnd[25];
      if (rnd[26]) pulse_spea;
      if (rnd[27]) pulse_spes;
      epea_n = rnd[28];
      epes_n = rnd[29];
      if (rnd[30]) tick;
      check_idb;
    end

    // ---------------------------------------------------------- verdict
    if (checks != EXP_CHECKS) begin
      $display("CHECK-COUNT MISMATCH: ran %0d, expected %0d", checks, EXP_CHECKS);
      errors = errors + 1;
    end
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else $display("TB_RESULT: FAIL (%0d errors in %0d checks)", errors, checks);
    $finish;
  end

endmodule
