/**************************************************************************
** ND120 CPU - unit test                                                 **
** IO_PANCAL_40: panel processor + calendar sheet (sheet 40).            **
**                                                                       **
** The MC68705 CPU and MM58274 RTC are NOT implemented (module header    **
** says "Module not working") - this tb pins the CURRENT stub contract   **
** so any later 68705/RTC implementation shows up as a deliberate diff:  **
**                                                                       **
**  1. CHIP_32B (74374): CK is tied to the constant s_wmm_n = 1, so the  **
**     edge-detect in TTL_74374 fires exactly ONCE, at the FIRST sysclk  **
**     posedge - IDB[7:0] is frozen at the PA_7_0 value present then     **
**     (0xC3 here) and NEVER re-captures. Checked across the whole sweep.**
**  2. CHIP_33B (74244): IDB[11:8] = STAT[3:0] = 0000,                   **
**     IDB[15:12] = {PRES=1, FUL_n, READ=0, VAL}. EPANS=1 forces the     **
**     whole IDB_15_0_OUT bus to 0 (FPGA no-Z convention).               **
**  3. DP_5_1_n = 5'b11111, RMM_n = 1, STAT_4_3 = 00 (constant stubs).   **
**                                                                       **
** Exhaustive over the live input cone: {EPANS, FUL_n, VAL} x PA_7_0     **
** (8 x 256 = 2048 vectors, 4 checks each) + one-shot-capture check +    **
** running checksum acc = acc*31 + IDB vs the independent Python model   **
** gen_pancal_golden.py (scratchpad, not in repo).                       **
**                                                                       **
** No ifdef build split applies to this sheet (no VERILATOR_SIM /        **
** FPGA_FF_MODE / USE_TRANSPARENT_LATCHES branch in the DUT or in        **
** TTL_74374 / TTL_74244) - single iverilog build.                       **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-pancal   (CPU-BOARD-3202/circuit/sim)                  **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module IO_PANCAL_40_tb;

  reg         sysclk = 0;
  reg         clear_n = 1;
  reg         emp_n = 1;
  reg         epans = 0;
  reg         ful_n = 0;
  reg         ioni = 0;
  reg         lev0 = 0;
  reg         lhit = 0;
  reg         panosc = 0;
  reg  [7:0]  pa = 8'hC3;   // value that must be captured at the FIRST edge
  reg  [1:0]  pcr = 0;
  reg         poni = 0;
  reg         val = 0;

  wire [15:0] idb;
  wire [4:0]  dp_n;
  wire        rmm_n;
  wire [1:0]  stat;

  IO_PANCAL_40 dut (
      .sysclk (sysclk),
      .CLEAR_n(clear_n),
      .EMP_n  (emp_n),
      .EPANS  (epans),
      .FUL_n  (ful_n),
      .IONI   (ioni),
      .LEV0   (lev0),
      .LHIT   (lhit),
      .PANOSC (panosc),
      .PA_7_0 (pa),
      .PCR_1_0(pcr),
      .PONI   (poni),
      .VAL    (val),
      .IDB_15_0_OUT(idb),
      .DP_5_1_n(dp_n),
      .RMM_n  (rmm_n),
      .STAT_4_3(stat)
  );

  always #5 sysclk = ~sysclk;

  integer errors = 0;
  integer checks = 0;
  integer e, f, v, p;
  reg [31:0] acc = 0;
  reg [15:0] expect_idb;

  // Expected IDB words, index = {EPANS,FUL_n,VAL}; constants from
  // gen_pancal_golden.py (independent model of the sheet wiring).
  reg [15:0] golden[0:7];
  initial begin
    golden[0] = 16'h80C3;  // E=0 F=0 V=0
    golden[1] = 16'h90C3;  // E=0 F=0 V=1
    golden[2] = 16'hC0C3;  // E=0 F=1 V=0
    golden[3] = 16'hD0C3;  // E=0 F=1 V=1
    golden[4] = 16'h0000;  // E=1 (bus disabled)
    golden[5] = 16'h0000;
    golden[6] = 16'h0000;
    golden[7] = 16'h0000;
  end

  task check(input [15:0] got, input [15:0] want, input [127:0] label);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h expected %04h (E=%0d F=%0d V=%0d PA=%02h)",
                 label, got, want, e, f, v, p[7:0]);
      end
    end
  endtask

  initial begin
    // PA = C3 across the first sysclk posedge: the one and only 74374
    // capture (CK = constant WMM_n = 1, edge-detected against CK_d = 0).
    repeat (2) @(negedge sysclk);

    // initial capture check: EPANS=0, FUL_n=0, VAL=0 -> 80C3
    check(idb, 16'h80C3, "initial capture");

    // Exhaustive sweep of the live cone; PA wiggles over all 256 values
    // and must NEVER re-enter IDB[7:0] (frozen at C3).
    for (e = 0; e < 2; e = e + 1)
      for (f = 0; f < 2; f = f + 1)
        for (v = 0; v < 2; v = v + 1)
          for (p = 0; p < 256; p = p + 1) begin
            @(negedge sysclk);
            epans = e[0];
            ful_n = f[0];
            val   = v[0];
            pa    = p[7:0];
            @(posedge sysclk);
            #1;
            expect_idb = golden[{e[0], f[0], v[0]}];
            acc = (acc << 5) - acc + {16'h0000, idb};
            check(idb, expect_idb, "IDB");
            check({11'b0, dp_n}, 16'h001F, "DP_5_1_n");
            check({15'b0, rmm_n}, 16'h0001, "RMM_n");
            check({14'b0, stat}, 16'h0000, "STAT_4_3");
          end

    // Whole-sweep checksum vs gen_pancal_golden.py.
    checks = checks + 1;
    if (acc !== 32'hC2C8C000) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08h expected C2C8C000", acc);
    end

    // Verdict. Expected: 1 + 2048*4 + 1 = 8194.
    if (errors == 0 && checks == 8194)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 8194 checks)",
               errors, checks);
    $finish;
  end

endmodule
