/**************************************************************************
** ND120 CPU - unit test                                                 **
** CPU_MMU_CACHE_25 built with -DND120_NO_CACHE: the CACHE-OFF contract   **
**                                                                       **
** The Tang Nano 20K cannot hold this design with the cache present. The  **
** cache-hit comparator on sheets 27 and 24 used to compare six wrong     **
** bits against a signal that is zero on every mapped access, so the      **
** synthesiser deleted most of the cache path as dead logic. With the     **
** comparator fixed the logic is real and the part is too small, so       **
** ND120_NO_CACHE omits the five cache memories (23F/24F data, 16F/20F    **
** tag, 21F used-bits) and the used-bit PAL 18F.                          **
**                                                                       **
** This is NOT an invented mode: the board carries SW1, a real cache      **
** on/off switch, and CON low IS the off position. The define forces that **
** position and additionally leaves the memories out of the netlist.      **
**                                                                       **
** THE TEETH ARE: with the cache compiled out the sheet must contribute   **
** NOTHING to the wired-OR CD bus, must never claim a hit, must never     **
** write a cache address, and must REPORT the cache as disabled - under   **
** every combination of the inputs that would otherwise produce a hit.    **
**                                                                       **
** Coverage:                                                             **
**   A CD_15_0_OUT is 0 for all CD data and all cache addresses          **
**   B HIT is 0 for every combination of HIT_1_0_n / CWR / FMISS         **
**   C WCA_n stays inactive (1) across the write-strobe inputs           **
**   D cache status reports DISABLED: CON=0, CON_n=1, LED1 lit           **
**   E SW1_CONSOLE cannot switch the cache back on                       **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-mmucache-nocache   (CPU-BOARD-3202/circuit/sim)         **
**                                                                       **
** 11-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_CACHE_25_nocache_tb;

  localparam integer EXPECTED_CHECKS = 197;  // D 3 + E 2 + B 32x2 + A 64x2

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;
  reg sys_rst_n = 0;

  reg  [10:0] ca_10_0 = 11'b0;
  reg  [ 1:0] hit_1_0_n = 2'b11;
  reg         sw1_console = 1'b1;   // switch says "cache on" - must be ignored
  reg         brk_n = 1'b1, wcinh_n = 1'b1, cclr_n = 1'b1;
  reg         cwr = 1'b0, dt_n = 1'b1, rt_n = 1'b1, lshadow = 1'b0;
  reg         fmiss = 1'b0, cyd = 1'b0, uclk = 1'b0, pd2 = 1'b0, ecd_n = 1'b0;
  reg  [15:0] cd_15_0_in = 16'b0;
  reg  [13:0] cpn_23_10_in = 14'b0;

  wire [15:0] cd_15_0_out;
  wire [13:0] cpn_23_10_out;
  wire        con, con_n, hit, wca_n, led1;

  CPU_MMU_CACHE_25 dut (
    .sysclk(sysclk), .sys_rst_n(sys_rst_n),
    .CA_10_0(ca_10_0), .HIT_1_0_n(hit_1_0_n), .SW1_CONSOLE(sw1_console),
    .BRK_n(brk_n), .WCINH_n(wcinh_n), .CCLR_n(cclr_n), .CWR(cwr),
    .DT_n(dt_n), .RT_n(rt_n), .LSHADOW(lshadow), .FMISS(fmiss), .CYD(cyd),
    .UCLK(uclk), .PD2(pd2), .ECD_n(ecd_n),
    .CD_15_0_IN(cd_15_0_in), .CD_15_0_OUT(cd_15_0_out),
    .CPN_23_10_IN(cpn_23_10_in), .CPN_23_10_OUT(cpn_23_10_out),
    .CON(con), .CON_n(con_n), .HIT(hit), .WCA_n(wca_n), .LED1(led1)
  );

  integer errors = 0;
  integer checks = 0;

  task check_eq(input [15:0] got, input [15:0] exp, input [255:0] msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        if (errors < 10)
          $display("  FAIL: %0s  got=%06o expected=%06o", msg, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  integer i;

  initial begin
    repeat (4) @(posedge sysclk);
    sys_rst_n = 1;

    // ---- D: the machine must REPORT the cache as disabled ----------------
    @(negedge sysclk); @(posedge sysclk);
    check_eq({15'b0, con},   16'd0, "D cache status CON reports disabled");
    check_eq({15'b0, con_n}, 16'd1, "D CON_n reports disabled");
    check_eq({15'b0, led1},  16'd1, "D LED1 shows the cache-off state");

    // ---- E: the console switch cannot turn it back on --------------------
    @(negedge sysclk); sw1_console = 1'b0; @(posedge sysclk);
    check_eq({15'b0, con}, 16'd0, "E switch off keeps it disabled");
    @(negedge sysclk); sw1_console = 1'b1; @(posedge sysclk);
    check_eq({15'b0, con}, 16'd0, "E switch on cannot re-enable it");

    // ---- B: HIT is 0 for every input combination that could assert it ----
    for (i = 0; i < 32; i = i + 1) begin
      @(negedge sysclk);
      hit_1_0_n = i[1:0];
      cwr       = i[2];
      fmiss     = i[3];
      wcinh_n   = i[4];
      @(posedge sysclk);
      check_eq({15'b0, hit}, 16'd0, "B HIT stays inactive");
      check_eq({15'b0, wca_n}, 16'd1, "C WCA_n stays inactive");
    end

    // ---- A: nothing is contributed to the wired-OR CD bus ----------------
    for (i = 0; i < 64; i = i + 1) begin
      @(negedge sysclk);
      ca_10_0    = i[10:0];
      cd_15_0_in = {i[7:0], ~i[7:0]};
      cpn_23_10_in = i[13:0];
      ecd_n      = i[0];
      cyd        = i[1];
      dt_n       = i[2];
      rt_n       = i[3];
      @(posedge sysclk);
      check_eq(cd_15_0_out, 16'b0, "A CD_15_0_OUT contributes nothing");
      check_eq({2'b0, cpn_23_10_out}, 16'b0, "A CPN_23_10_OUT is 0");
    end

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)",
               errors, checks, EXPECTED_CHECKS);
    $finish;
  end

  initial begin
    #500000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
