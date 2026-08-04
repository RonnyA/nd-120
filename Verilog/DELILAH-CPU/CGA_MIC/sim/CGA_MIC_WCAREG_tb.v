/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC_WCAREG testbench                                              **
**                                                                       **
** Exhaustive verification of the writeable-control-store address        **
** register. Golden behavior re-derived pin-by-pin from the netlist:     **
**                                                                       **
**   13x SCAN_FF: TE = ~LWCAN, TI = CD[14:2], D = own Q (hold).          **
**     -> MCLK with LWCAN=0 loads WCA[12:0] <= CD[14:2]; LWCAN=1 holds.  **
**   WCSNFF: TI = CD[15], QN = s_wca13_n.                                **
**   WCSN = NOR with BubblesMask 2'b11 (BOTH inputs inverted first):     **
**     WCSN = ~(~wca13_n | ~LCSN) = wca13_n & LCSN = ~stored_CD15 & LCSN **
**     (combinational in LCSN, registered in CD15).                      **
**                                                                       **
**  1. Exhaustive load sweep: all 65536 CD values loaded (LWCAN=0);      **
**     after each load WCA is checked against CD[14:2] and WCSN is       **
**     checked for BOTH LCSN values (3 checks per load). CD[1:0] must    **
**     not leak anywhere.                                                **
**  2. Running checksum of the golden (WCA, WCSN@LCSN=1, WCSN@LCSN=0)    **
**     sweep vs the constant from gen_mic_stack_golden.py.               **
**  3. Hold: 8 LFSR-picked CD values clocked with LWCAN=1 must leave     **
**     WCA and the stored CD15 (via WCSN) unchanged.                     **
**  4. Hold with no clock event.                                         **
**                                                                       **
** Sequential: 14x SCAN_FF_EN on MCLK. Compile once plain (posedge       **
** MCLK) and once with -DFPGA_FF_MODE (sysclk + MCLK_EN capture) - the   **
** Makefile target test-mic-wcareg runs both.                            **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 31-JUL-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CGA_MIC_WCAREG_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK = 0;
  reg  [15:0] CD_15_0 = 0;
  reg         LCSN = 1;
  reg         LWCAN = 1;
  wire [12:0] WCA_12_0;
  wire        WCSN;

  integer errors = 0;
  integer checks = 0;
  integer cd, k;

  // Golden register state.
  reg [12:0] gwca;
  reg        gq15;  // stored CD15 (WCSNFF Q)

  reg [31:0] lfsr = 32'hCAFEB00B;
  reg [31:0] cksum = 0;
  localparam [31:0] WCAREG_CKS = 32'hD98F0000;  // gen_mic_stack_golden.py

  CGA_MIC_WCAREG dut (
      .sysclk  (sysclk),
      .MCLK_EN (MCLK_EN),
      .CD_15_0 (CD_15_0),
      .LCSN    (LCSN),
      .LWCAN   (LWCAN),
      .MCLK    (MCLK),
      .WCA_12_0(WCA_12_0),
      .WCSN    (WCSN)
  );

  always #5 sysclk = ~sysclk;

  // One MCLK event, valid in BOTH build modes (INCOUNT house pattern).
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK    = 0;
      MCLK_EN = 0;
      if (!LWCAN) begin
        gwca = CD_15_0[14:2];
        gq15 = CD_15_0[15];
      end
    end
  endtask

  task check_wca(input [127:0] name);
    begin
      checks = checks + 1;
      if (WCA_12_0 !== gwca) begin
        errors = errors + 1;
        $display("FAIL %0s: WCA=%05o expected %05o (CD=%06o)",
                 name, WCA_12_0, gwca, CD_15_0);
      end
    end
  endtask

  // WCSN = ~stored_CD15 & LCSN, checked for both LCSN values.
  task check_wcsn_both(input [127:0] name);
    begin
      LCSN = 1;
      #2;
      checks = checks + 1;
      if (WCSN !== ~gq15) begin
        errors = errors + 1;
        $display("FAIL %0s (LCSN=1): WCSN=%b expected %b", name, WCSN, ~gq15);
      end
      LCSN = 0;
      #2;
      checks = checks + 1;
      if (WCSN !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL %0s (LCSN=0): WCSN=%b expected 0", name, WCSN);
      end
      LCSN = 1;
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MIC_WCAREG_tb: FPGA_FF_MODE (sysclk+MCLK_EN capture)");
`else
    $display("CGA_MIC_WCAREG_tb: latch/CP mode (posedge MCLK capture)");
`endif
    gwca = 13'b0;
    gq15 = 1'b0;
    #12;

    // ------------------------------------------------------------------
    // 1+2. Exhaustive load sweep of all 65536 CD values, with running
    //      golden checksum.
    // ------------------------------------------------------------------
    for (cd = 0; cd < 65536; cd = cd + 1) begin
      LWCAN   = 0;
      CD_15_0 = cd[15:0];
      pulse_mclk;
      check_wca("load");
      check_wcsn_both("load");
      cksum = cksum * 33 + {17'b0, gwca, ~gq15, 1'b0};
    end

    checks = checks + 1;
    if (cksum !== WCAREG_CKS) begin
      errors = errors + 1;
      $display("FAIL checksum: got %08x expected %08x", cksum, WCAREG_CKS);
    end

    // ------------------------------------------------------------------
    // 3. Hold: clocked with LWCAN=1, CD noise must not load.
    // ------------------------------------------------------------------
    LWCAN   = 0;
    CD_15_0 = 16'o125252;  // known state: WCA=CD[14:2], stored15=CD[15]
    pulse_mclk;
    for (k = 0; k < 8; k = k + 1) begin
      lfsr    = lfsr[0] ? (lfsr >> 1) ^ 32'hEDB88320 : lfsr >> 1;
      LWCAN   = 1;
      CD_15_0 = lfsr[15:0];
      pulse_mclk;
      check_wca("hold-clocked");
      check_wcsn_both("hold-clocked");
    end

    // ------------------------------------------------------------------
    // 4. Hold with no clock event (load inputs armed but no MCLK).
    // ------------------------------------------------------------------
    LWCAN   = 0;
    CD_15_0 = 16'o052525;
    #40;
    check_wca("hold-no-clock");
    check_wcsn_both("hold-no-clock");

    // ------------------------------------------------------------------
    // Verdict. Expected: 65536*3 sweep + 1 checksum + 8*3 hold +
    // 3 no-clock = 196636.
    // ------------------------------------------------------------------
    if (errors == 0 && checks == 196636)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of 196636 checks)",
               errors, checks);
    $finish;
  end

endmodule
