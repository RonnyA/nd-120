/**************************************************************************
** ND120 CPU - unit test                                                 **
** BIF_DPATH_CDLBD_11: CD <-> LBD transceiver sheet (2x TTL_74646).      **
**                                                                       **
** Same vectors must pass in BOTH modes (the Makefile compiles twice):   **
**   plain            - original posedge-ECREQ register clocking         **
**   -DFPGA_FF_MODE   - P1c-2 sysclk edge-capture (USE_SYSCLK_BA=2)      **
**                                                                       **
** Covered: CPU-write capture on ECREQ rise + hold, no re-capture under  **
** a held ECREQ, memory-read real-time path (DSTB_n low), DSTB_n rise    **
** capture + hold, EMD_n output gating, direction gating of LBD_OUT.     **
**                                                                       **
** Run: make test-cdlbd   (CPU-BOARD-3202/circuit/sim)                   **
***************************************************************************/
`timescale 1ns / 1ps

module BIF_DPATH_CDLBD_11_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg         dstb_n = 1;
  reg         ecreq = 0;
  reg         emd_n = 0;
  reg         wlbd_n = 0;
  reg  [15:0] lbd_in = 0;
  reg  [15:0] cd_in = 0;
  wire [15:0] lbd_out;
  wire [15:0] cd_out;

  BIF_DPATH_CDLBD_11 dut (
      .sysclk(sysclk),
      .DSTB_n(dstb_n),
      .ECREQ(ecreq),
      .EMD_n(emd_n),
      .WLBD_n(wlbd_n),
      .LBD_15_0_IN(lbd_in),
      .LBD_15_0_OUT(lbd_out),
      .CD_15_0_IN(cd_in),
      .CD_15_0_OUT(cd_out)
  );

  integer errors = 0;
  integer checks = 0;

  task check_eq(input [15:0] got, input [15:0] want, input [127:0] label);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %o expected %o", label, got, want);
      end
    end
  endtask

  initial begin
    $dumpfile("BIF_DPATH_CDLBD_11_tb.vcd");
    $dumpvars(0, BIF_DPATH_CDLBD_11_tb);

    // ---- 1. CPU write path (CD -> LBD): ECREQ rise captures CD ----
    // DIR = WLBD_n = 0 (B->A), SBA = 1 (stored) => LBD_OUT = registered CD
    @(negedge sysclk); wlbd_n = 0; emd_n = 0; cd_in = 16'o052525;
    @(negedge sysclk); ecreq = 1;                 // strobe rise: capture
    @(negedge sysclk); ecreq = 0;
    @(negedge sysclk);
    check_eq(lbd_out, 16'o052525, "ECREQ capture");

    @(negedge sysclk); cd_in = 16'o012345;        // CD moves on, no strobe
    @(negedge sysclk);
    check_eq(lbd_out, 16'o052525, "hold without strobe");

    @(negedge sysclk); ecreq = 1;                 // next strobe: new value
    @(negedge sysclk); ecreq = 0;
    @(negedge sysclk);
    check_eq(lbd_out, 16'o012345, "second ECREQ capture");

    // ---- 2. no re-capture while ECREQ is HELD high ----
    // (data one cycle before the strobe - real setup time; same-delta
    // strobe+data is the known zero-delay sim race, not a real case)
    @(negedge sysclk); cd_in = 16'o054321;
    @(negedge sysclk); ecreq = 1;
    @(negedge sysclk);
    @(negedge sysclk); cd_in = 16'o077777;        // bus junk under held strobe
    @(negedge sysclk);
    check_eq(lbd_out, 16'o054321, "no re-capture under held ECREQ");
    @(negedge sysclk); ecreq = 0;
    @(negedge sysclk);
    check_eq(lbd_out, 16'o054321, "hold after ECREQ falls");

    // ---- 3. memory read path (LBD -> CD): DSTB_n low = real-time ----
    // DIR = WLBD_n = 1 (A->B), SAB = DSTB_n = 0 => CD_OUT = real-time LBD
    @(negedge sysclk); wlbd_n = 1; dstb_n = 0; lbd_in = 16'o060606;
    @(negedge sysclk);
    check_eq(cd_out, 16'o060606, "DSTB low real-time 1");
    @(negedge sysclk); lbd_in = 16'o017171;
    @(negedge sysclk);
    check_eq(cd_out, 16'o017171, "DSTB low real-time 2");

    // ---- 4. DSTB_n rise captures; stored while DSTB_n high ----
    @(negedge sysclk); dstb_n = 1;                // rise: capture + select stored
    @(negedge sysclk);
    check_eq(cd_out, 16'o017171, "DSTB rise capture");
    @(negedge sysclk); lbd_in = 16'o033333;       // LBD moves on
    @(negedge sysclk);
    check_eq(cd_out, 16'o017171, "stored while DSTB high");

    // ---- 5. EMD_n gates CD_OUT to 0 ----
    @(negedge sysclk); emd_n = 1;
    @(negedge sysclk);
    check_eq(cd_out, 16'o000000, "EMD_n gates CD_OUT");
    @(negedge sysclk); emd_n = 0; dstb_n = 0;
    @(negedge sysclk);
    check_eq(cd_out, 16'o033333, "CD_OUT back after EMD_n");

    // ---- 6. direction gating: LBD_OUT is 0 in A->B direction ----
    check_eq(lbd_out, 16'o000000, "LBD_OUT 0 when WLBD_n=1");

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
