/**************************************************************************
** ND120 CPU - unit test                                                 **
** BIF_DPATH_BDLBD_10: BD (active-low bus) <-> LBD transceiver sheet     **
** (3x TTL_74648, inverting).                                            **
**                                                                       **
** Same vectors must pass in BOTH modes (the Makefile compiles twice):   **
**   plain            - original posedge-BGNT_n register clocking        **
**   -DFPGA_FF_MODE   - P1d sysclk edge-capture (USE_SYSCLK_BA=2)        **
**                                                                       **
** Covered: inbound real-time path (BD -> LBD, inverting), EBADR/CLKBD   **
** stored path, outbound real-time path (LBD -> BD_n), BGNT_n rise       **
** capture + hold + no re-capture under held grant, EBD_n gating          **
** (LBD_OUT to 0, BD_OUT_n released to all-ones).                        **
**                                                                       **
** Run: make test-bdlbd   (CPU-BOARD-3202/circuit/sim)                   **
***************************************************************************/
`timescale 1ns / 1ps

module BIF_DPATH_BDLBD_10_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg         bgntcact_n = 0;
  reg         bgnt_n = 0;
  reg         clkbd = 0;
  reg         ebadr = 0;
  reg         ebd_n = 0;
  reg         wbd_n = 1;
  reg  [23:0] bd_n_in = ~24'b0;
  reg  [23:0] lbd_in = 0;
  wire [23:0] bd_n_out;
  wire [23:0] lbd_out;

  BIF_DPATH_BDLBD_10 dut (
      .sysclk(sysclk),
      .BD_23_0_n_IN(bd_n_in),
      .BD_23_0_n_OUT(bd_n_out),
      .LBD_23_0_IN(lbd_in),
      .LBD_23_0_OUT(lbd_out),
      .BGNTCACT_n(bgntcact_n),
      .BGNT_n(bgnt_n),
      .CLKBD(clkbd),
      .EBADR(ebadr),
      .EBD_n(ebd_n),
      .WBD_n(wbd_n)
  );

  integer errors = 0;
  integer checks = 0;

  task check_eq(input [23:0] got, input [23:0] want, input [255:0] label);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %o expected %o", label, got, want);
      end
    end
  endtask

  initial begin
    $dumpfile("BIF_DPATH_BDLBD_10_tb.vcd");
    $dumpvars(0, BIF_DPATH_BDLBD_10_tb);

    // ---- 1. inbound real-time: BD_n -> LBD (inverting), EBADR=0 ----
    // DIR = WBD_n = 1 (A->B), SAB = EBADR = 0 => LBD_OUT = ~BD_n real-time
    @(negedge sysclk); ebd_n = 0; wbd_n = 1; ebadr = 0; bd_n_in = ~24'o00052525;
    @(negedge sysclk);
    check_eq(lbd_out, 24'o00052525, "inbound real-time 1");
    @(negedge sysclk); bd_n_in = ~24'o00012345;
    @(negedge sysclk);
    check_eq(lbd_out, 24'o00012345, "inbound real-time 2");

    // ---- 2. inbound stored: CLKBD rise captures, EBADR=1 selects reg ----
    @(negedge sysclk); clkbd = 1;                 // capture ~00012345
    @(negedge sysclk); clkbd = 0; ebadr = 1;
    @(negedge sysclk); bd_n_in = ~24'o00077777;   // bus moves on
    @(negedge sysclk);
    check_eq(lbd_out, 24'o00012345, "inbound stored via CLKBD/EBADR");

    // ---- 3. outbound real-time: LBD -> BD_n, BGNTCACT_n=0 ----
    // DIR = WBD_n = 0 (B->A), SBA = BGNTCACT_n = 0 => BD_n_OUT = ~LBD real-time
    @(negedge sysclk); wbd_n = 0; bgntcact_n = 0; lbd_in = 24'o00033333;
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00033333, "outbound real-time");

    // ---- 4. BGNT_n rise captures; stored while grant held ----
    @(negedge sysclk); bgntcact_n = 1; lbd_in = 24'o00054321;
    @(negedge sysclk); bgnt_n = 1;                // grant strobe rise: capture
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00054321, "BGNT rise capture");
    @(negedge sysclk); lbd_in = 24'o00070707;     // LBD junk under held grant
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00054321, "no re-capture under held BGNT");
    @(negedge sysclk); bgnt_n = 0;
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00054321, "hold after BGNT falls");

    // ---- 5. second grant captures the new value ----
    @(negedge sysclk); bgnt_n = 1;
    @(negedge sysclk); bgnt_n = 0;
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00070707, "second BGNT capture");

    // ---- 6. EBD_n gating ----
    @(negedge sysclk); ebd_n = 1;
    @(negedge sysclk);
    check_eq(lbd_out, 24'o00000000, "EBD_n gates LBD_OUT to 0");
    check_eq(bd_n_out, ~24'b0, "EBD_n releases BD_n_OUT to ones");
    @(negedge sysclk); ebd_n = 0;
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00070707, "BD_n_OUT back after EBD_n");

    // ---- 7. DIR gating of the A side (the read half of a bus cycle) ----
    // A 74AS648 drives its A pins only when OE~ is LOW **and** DIR selects
    // B->A. Steps 1 and 2 above already sat in ebd_n=0, wbd_n=1 but only ever
    // checked lbd_out, so this state was completely unguarded - and the RTL
    // published 24'h000000 there, which on this ACTIVE-LOW wired-AND net is
    // the BIF asserting all 24 BD lines instead of releasing them. Devices on
    // the ND bus latch ~BD_23_0_n_OUT as the bus address, so they saw
    // 24'hFFFFFF for the whole window. Found by a drawing audit 11-AUG-2026.
    @(negedge sysclk); wbd_n = 1;              // A->B: the A drivers are OFF
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'b0, "WBD_n=1 releases BD_n_OUT to ones");
    @(negedge sysclk); bd_n_in = ~24'o00011111;  // bus traffic must not leak
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'b0, "still released while BD_n moves");
    @(negedge sysclk); wbd_n = 0;              // B->A again: drivers back on
    @(negedge sysclk);
    check_eq(bd_n_out, ~24'o00070707, "BD_n_OUT back after WBD_n");

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #100000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
