/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC_MASEL_REPEAT testbench                                        **
** DUT: DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL_REPEAT.v (page 20)     **
**                                                                       **
** Golden behavior re-derived from the netlist (independent model):      **
**   13-bit register regRepeat clocked by MCLK.                          **
**   s_mp = ~MPN; at the clock event: MPN=0 -> regRepeat <= 0 (the RTL   **
**   writes a 12-bit zero literal into the 13-bit reg - zero-extended,   **
**   still all-zero), MPN=1 -> regRepeat <= REP_12_0. IW_12_0 mirrors    **
**   the register.                                                       **
**                                                                       **
** PINNED CURRENT BEHAVIOR (differences vs the schematic comments, do    **
** not "fix" the DUT without a schematic audit):                         **
**   - SC5/SC6 have NO effect: the s_hack gating wire that uses them is  **
**     computed but never read (the HACK always-block is commented out). **
**     Phase 3 pins outputs identical across all four SC5/SC6 combos.    **
**   - The MPN clear is SYNCHRONOUS in both build modes (the original    **
**     commented-out block had "or posedge s_mp" async clear). Phase 4   **
**     pins that MPN=0 with no clock event does NOT clear the register.  **
**                                                                       **
**  1. Defining clear pulse (MPN=0 + clock) -> IW must be 0.             **
**  2. Exhaustive load sweep: all 8192 REP values clocked with MPN=1.    **
**  3. SC5/SC6 no-effect sweep (4 combos, distinct loads).               **
**  4. Sync-clear: MPN=0 held with no clock = hold; then clocked = 0.    **
**  5. Hold with no clock event while REP changes.                       **
**  6. 4000-step fixed-seed LFSR soak (random REP, MPN mostly high,      **
**     random SC5/SC6) vs the clocked golden model after every edge.     **
**                                                                       **
** Sequential (MCLK domain): compile once plain (posedge MCLK) and once  **
** with -DFPGA_FF_MODE (sysclk + MCLK_EN capture) - Makefile target      **
** test-mic-repeat runs both.                                            **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent), with a   **
** hard expected-check-count assertion (12201 checks).                   **
**                                                                       **
** 01-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MIC_MASEL_REPEAT_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK = 0;
  reg         MPN = 1;
  reg         SC5 = 0;
  reg         SC6 = 0;
  reg  [12:0] REP_12_0 = 0;
  wire [12:0] IW_12_0;

  integer errors = 0;
  integer checks = 0;
  integer i, k;

  // Golden register state (independent model).
  reg [12:0] grep;

  reg [31:0] lfsr = 32'h5EED1207;

  localparam integer EXPECTED_CHECKS = 12201;

  CGA_MIC_MASEL_REPEAT dut (
      .sysclk  (sysclk),
      .MCLK_EN (MCLK_EN),
      .MCLK    (MCLK),
      .MPN     (MPN),
      .SC5     (SC5),
      .SC6     (SC6),
      .REP_12_0(REP_12_0),
      .IW_12_0 (IW_12_0)
  );

  always #5 sysclk = ~sysclk;

  // One MCLK event, valid in BOTH build modes (house pattern), then update
  // the golden model: MPN=0 -> clear, else load REP.
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
      if (!MPN) grep = 13'b0;
      else grep = REP_12_0;
    end
  endtask

  task check_iw(input [127:0] name);
    begin
      checks = checks + 1;
      if (IW_12_0 !== grep) begin
        errors = errors + 1;
        $display("FAIL %0s: IW=%05o expected %05o (REP=%05o MPN=%b SC5=%b SC6=%b)",
                 name, IW_12_0, grep, REP_12_0, MPN, SC5, SC6);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MIC_MASEL_REPEAT_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MIC_MASEL_REPEAT_tb: latch/CP mode (posedge MCLK capture)");
`endif
    #12;

    // ------------------------------------------------------------------
    // 1. Defining clear pulse: register powers up unknown; MPN=0 + clock
    //    must give a known all-zero state. (1 check)
    // ------------------------------------------------------------------
    MPN      = 0;
    REP_12_0 = 13'o12345;  // must be ignored during clear
    pulse_mclk;
    check_iw("clear");
    MPN = 1;

    // ------------------------------------------------------------------
    // 2. Exhaustive load sweep: all 8192 REP values. (8192 checks)
    // ------------------------------------------------------------------
    for (i = 0; i < 8192; i = i + 1) begin
      REP_12_0 = i[12:0];
      pulse_mclk;
      check_iw("load");
    end

    // ------------------------------------------------------------------
    // 3. SC5/SC6 no-effect: PINS that the selector inputs do not gate the
    //    load in the current RTL (dead s_hack wire). (4 checks)
    // ------------------------------------------------------------------
    for (i = 0; i < 4; i = i + 1) begin
      SC5      = i[0];
      SC6      = i[1];
      REP_12_0 = 13'o05252 ^ {11'b0, i[1:0]};
      pulse_mclk;
      check_iw("sc-no-effect");
    end
    SC5 = 0;
    SC6 = 0;

    // ------------------------------------------------------------------
    // 4. Synchronous clear pin: MPN low WITHOUT a clock event must hold
    //    (1 check), then a clock event with MPN low clears (1 check).
    // ------------------------------------------------------------------
    REP_12_0 = 13'o07531;
    pulse_mclk;
    check_iw("preload");
    MPN = 0;
    #40;
    check_iw("mpn-low-no-clock-holds");
    pulse_mclk;
    check_iw("mpn-low-clocked-clears");
    MPN = 1;

    // ------------------------------------------------------------------
    // 5. Hold with no clock event while REP changes. (1 check)
    // ------------------------------------------------------------------
    REP_12_0 = 13'o06666;
    pulse_mclk;
    REP_12_0 = 13'o01111;
    #40;
    check_iw("hold-no-clock");

    // ------------------------------------------------------------------
    // 6. 4000-step fixed-seed LFSR soak: random REP held across the edge,
    //    MPN low roughly 1 step in 16, random SC5/SC6. (4000 checks)
    // ------------------------------------------------------------------
    for (k = 0; k < 4000; k = k + 1) begin
      lfsr     = lfsr[0] ? (lfsr >> 1) ^ 32'hEDB88320 : lfsr >> 1;
      REP_12_0 = lfsr[12:0];
      MPN      = (lfsr[16:13] != 4'b0000);
      SC5      = lfsr[17];
      SC6      = lfsr[18];
      pulse_mclk;
      check_iw("soak");
    end

    // ------------------------------------------------------------------
    // Verdict. Expected: 1 clear + 8192 load + 4 sc + 1 preload +
    // 1 no-clock-hold + 1 clocked-clear + 1 hold + 4000 soak = 12201.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule
