/**************************************************************************
** ND120 CPU - unit test                                                 **
** IO_PANCAL_40 with ND120_PANEL_CLOCK: the MC68705 + MM58274 clock path **
** (PANCAL_68705_CLOCK) as the CPU sees it through TRR PANC / TRA PANS.  **
**                                                                       **
** The tb plays the DGA side of sheet 40:                                **
**  - the real FIFO_8BIT (DEPTH 13) clocked like DECODE_DGA.v does it    **
**    (CLK in latch mode, sysclk + CLK_EN in FPGA_FF_MODE), XA_7_0 gated **
**    by RMM_n, XEMN/XFUN as EMP_n/FUL_n;                                **
**  - microcode RPANC (o1045): two LDPANC pushes, A[15:8] then A[7:0];   **
**  - the DECODE_DGA_IDBS A282 VAL/RIWR handshake (VAL = RIWR_n & STAT4, **
**    RIWR set by MAPANS while VAL, held while STAT4) so the STAT4 pulse  **
**    timing is checked against the real acknowledge logic;              **
**  - TRA PANS = EPANS low + MAPANS for one CLK, PANS = IDB_15_0_OUT.    **
**                                                                       **
** Checks (all against the ROM behaviour documented in                   **
** PANCAL_68705_CLOCK.v):                                                **
**  1. reset: PANS = PRES=1, FUL_n=1, READ=0, VAL=1 (PB5=1 at reset),    **
**     STAT=0, byte=0                                                    **
**  2. PFUNC 0-3: STAT2:0 echoed, no answer (VAL never re-arms); the     **
**     WPAN byte is left in the FIFO and read as the next command, as   **
**     the ROM does (0x06D2 RTS after one byte)                          **
**  3. write PFUNC 4..7: each answered with the byte echoed, READ=0,     **
**     STAT2:0=PFUNC, VAL=1; TRA PANS clears VAL; the clock only loads   **
**     on PFUNC 7                                                        **
**  4. read PFUNC 4..7 after N ticks: seconds+N, half-days unchanged;    **
**     READ=1; a tick between the four reads does not split the snapshot **
**  5. wrap: 43199 -> 0 and half-days + 1                                **
**  6. text command 0x0E + 4 bytes and 0x08 + 5 bytes are drained        **
**     (FIFO empty afterwards), PANS byte untouched                      **
**  7. a write with the WPAN byte missing is answered with 0 after the   **
**     wait limit and the FIFO stays in step                             **
**  8. CLEAR_n resets the ports (STAT4=1, READ=0) but not the time       **
**                                                                       **
** Build (CPU-BOARD-3202/circuit/sim):                                   **
**   make test-pancal-clock      latch mode                              **
**   make test-pancal-clock-ff   -DFPGA_FF_MODE                          **
** Self-checking: prints TB_RESULT: PASS / FAIL.                         **
**                                                                       **
** 28-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module IO_PANCAL_40_clock_tb;

  // sysclk 100 MHz-ish (10 ns); CLK = sysclk/4. BOARD_CLK_FREQ and
  // ND120_PANEL_CLOCK_TICK_CYCLES come from the Makefile (-D), see there.
  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg [1:0] r_div = 0;
  reg       clk    = 0;
  reg       clk_en = 0;
  always @(posedge sysclk) begin
    r_div  <= r_div + 2'd1;
    clk    <= (r_div == 2'd3) ? 1'b1 : (r_div == 2'd1) ? 1'b0 : clk;
    clk_en <= (r_div == 2'd2);   // high in the cycle whose ending edge raises clk
  end

  reg        clear_n = 0;
  reg        epans_n = 1;        // IO_PANCAL_40.EPANS is the active-low enable
  reg        mapans  = 0;
  reg        ldpanc  = 0;
  reg  [7:0] idb_lo  = 0;

  wire [15:0] idb;
  wire [4:0]  dp_n;
  wire        rmm_n;
  wire [1:0]  stat_4_3;

  // ---------------- DGA FIFO + XA gating + flags -------------------------
  wire [7:0] ad;
  wire       fifo_full, fifo_empty;
`ifdef FPGA_FF_MODE
  wire fifo_clk = sysclk;
  wire fifo_wr  = ldpanc & clk_en;
  wire fifo_rd  = ~rmm_n & clk_en;
`else
  wire fifo_clk = clk;
  wire fifo_wr  = ldpanc;
  wire fifo_rd  = ~rmm_n;
`endif
  FIFO_8BIT #(.DEPTH(13)) fifo (
      .clk(fifo_clk), .rst(~clear_n), .wr_en(fifo_wr), .rd_en(fifo_rd),
      .data_in(idb_lo), .data_out(ad), .full(fifo_full), .empty(fifo_empty));
  wire [7:0] pa    = rmm_n ? 8'b0 : ad;
  wire       emp_n = ~fifo_empty;
  wire       ful_n = ~fifo_full;

  // ---------------- DGA IDBS A282 handshake (VAL / RIWR) -----------------
  wire stat4 = stat_4_3[1];
  reg  val  = 0;
  reg  riwr = 0;
  always @(posedge clk) begin
    val  <= ~riwr & stat4;
    riwr <= (stat4 & riwr) | (val & stat4 & mapans);
  end

  IO_PANCAL_40 dut (
      .sysclk (sysclk),
      .CLK    (clk),
      .CLK_EN (clk_en),
      .CLEAR_n(clear_n),
      .EMP_n  (emp_n),
      .EPANS  (epans_n),
      .FUL_n  (ful_n),
      .IONI   (1'b0),
      .LEV0   (1'b0),
      .LHIT   (1'b0),
      .PANOSC (1'b0),
      .PA_7_0 (pa),
      .PCR_1_0(2'b00),
      .PONI   (1'b0),
      .VAL    (val),
      .IDB_15_0_OUT(idb),
      .DP_5_1_n(dp_n),
      .RMM_n  (rmm_n),
      .STAT_4_3(stat_4_3)
  );

  // ---------------- helpers ---------------------------------------------
  integer errors = 0;
  integer checks = 0;

  task check(input [15:0] got, input [15:0] want, input [255:0] label);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h (o%06o) expected %04h (o%06o)", label, got, got, want, want);
      end
    end
  endtask

  // one LDPANC: byte on IDB[7:0] for exactly one CLK
  task ldpanc_byte(input [7:0] b);
    begin
      @(negedge clk);
      idb_lo = b;
      ldpanc = 1;
      @(negedge clk);
      ldpanc = 0;
    end
  endtask

  // TRR PANC: RPANC pushes A[15:8] then A[7:0]
  task trr_panc(input [15:0] a);
    begin
      ldpanc_byte(a[15:8]);
      ldpanc_byte(a[7:0]);
    end
  endtask

  // TRA PANS: EPANS + MAPANS for one CLK, PANS sampled at its end
  reg [15:0] pans;
  task tra_pans;
    begin
      @(negedge clk);
      epans_n = 0;
      mapans  = 1;
      @(posedge clk);
      #1 pans = idb;
      @(negedge clk);
      epans_n = 1;
      mapans  = 0;
    end
  endtask

  // Wait for the panel to answer: VAL rises (via STAT4) - or give up.
  task wait_val(input integer limit_cycles);
    integer n;
    begin
      n = 0;
      while (!val && n < limit_cycles) begin
        @(posedge sysclk);
        n = n + 1;
      end
      checks = checks + 1;
      if (!val) begin
        errors = errors + 1;
        $display("FAIL wait_val: no answer within %0d sysclk", limit_cycles);
      end
    end
  endtask

  // Wait until the FIFO has been drained and the panel is idle again.
  task wait_idle(input integer limit_cycles);
    integer n;
    begin
      n = 0;
      while ((!fifo_empty || !rmm_n || dut.CHIP_35C.r_state != 0) && n < limit_cycles) begin
        @(posedge sysclk);
        n = n + 1;
      end
      checks = checks + 1;
      if (!fifo_empty || dut.CHIP_35C.r_state != 0) begin
        errors = errors + 1;
        $display("FAIL wait_idle: FIFO empty=%0d state=%0d after %0d sysclk",
                 fifo_empty, dut.CHIP_35C.r_state, limit_cycles);
      end
    end
  endtask

  // PANC words. High byte = {0,0,RD,0,0,PFUNC}, low byte = WPAN.
  function [15:0] panc_wr(input [2:0] pfunc, input [7:0] wpan);
    panc_wr = {5'b00000, pfunc, wpan};
  endfunction
  function [15:0] panc_rd(input [2:0] pfunc);
    panc_rd = {2'b00, 1'b1, 2'b00, pfunc, 8'h00};
  endfunction

  // One write transaction, checked: echo byte, PFUNC, READ=0, VAL then cleared.
  task write_pfunc(input [2:0] pfunc, input [7:0] b);
    begin
      trr_panc(panc_wr(pfunc, b));
      wait_val(200000);
      tra_pans;
      check(pans[7:0],   b,              "write echo byte");
      check(pans[10:8],  pfunc,          "write STAT2:0 = PFUNC");
      check(pans[13],    1'b0,           "write READ=0");
      check(pans[12],    1'b1,           "write VAL=1 (answered)");
      check(pans[15],    1'b1,           "PRES");
      check(pans[14],    1'b1,           "FUL_n");
      @(negedge clk); @(negedge clk);
      check(val, 1'b0, "VAL cleared by TRA PANS");
    end
  endtask

  // One read transaction, returns the byte.
  task read_pfunc(input [2:0] pfunc, output [7:0] b);
    begin
      trr_panc(panc_rd(pfunc));
      wait_val(200000);
      tra_pans;
      check(pans[10:8], pfunc, "read STAT2:0 = PFUNC");
      check(pans[13],   1'b1,  "read READ=1");
      check(pans[12],   1'b1,  "read VAL=1");
      b = pans[7:0];
    end
  endtask

  task set_time(input [15:0] hd, input [15:0] sec);
    begin
      write_pfunc(3'd4, sec[7:0]);
      write_pfunc(3'd5, sec[15:8]);
      write_pfunc(3'd6, hd[7:0]);
      write_pfunc(3'd7, hd[15:8]);
    end
  endtask

  reg [7:0]  b0, b1, b2, b3;
  reg [15:0] rd_hd, rd_sec;
  task get_time;
    begin
      read_pfunc(3'd4, b0);
      read_pfunc(3'd5, b1);
      read_pfunc(3'd6, b2);
      read_pfunc(3'd7, b3);
      rd_sec = {b1, b0};
      rd_hd  = {b3, b2};
    end
  endtask

  // Let N panel "seconds" pass (TICK = ND120_PANEL_CLOCK_TICK_CYCLES sysclk).
  task ticks(input integer n);
    begin
      repeat (n * `ND120_PANEL_CLOCK_TICK_CYCLES) @(posedge sysclk);
    end
  endtask

  integer k;
  reg [15:0] before_sec;

  initial begin
    // ---- 1. reset state --------------------------------------------------
    repeat (8) @(negedge clk);
    clear_n = 1;
    repeat (8) @(negedge clk);
    // PANS before anything: PRES=1 FUL_n=1 READ=0 VAL=1 STAT=0 byte=0
    @(negedge clk); epans_n = 0; @(posedge clk); #1 pans = idb; @(negedge clk); epans_n = 1;
    check(pans, 16'hD000, "reset PANS (PRES,FUL_n,VAL set; READ,STAT,byte 0)");
    check(dut.CHIP_35C.STAT4, 1'b1, "reset STAT4=1 (PORTB=2F)");

    // ---- 2. PFUNC 0-3: echo on STAT2:0, no answer --------------------------
    // ROM 0x06D2: PFUNC 0-3 return after the command byte alone, so the
    // second RPANC byte (WPAN) is read as the NEXT command. Use WPAN = 02 so
    // that stray "command" is PFUNC 2 again (no answer either).
    trr_panc(panc_wr(3'd2, 8'h02));
    wait_idle(100000);
    tra_pans;                               // clears the reset VAL
    check(pans[10:8], 3'd2, "PFUNC 2 echoed on STAT2:0");
    check(pans[7:0],  8'h00, "PFUNC 2: no answer byte");
    repeat (4) @(negedge clk);
    check(val, 1'b0, "PFUNC 2: VAL stays clear");
    // The reset STAT4 level drops HOLD after the first command.
    repeat (`BOARD_CLK_FREQ / 500 + 64) @(posedge sysclk);
    check(dut.CHIP_35C.STAT4, 1'b0, "STAT4 dropped after first command + hold");

    // ---- 3. write a time ---------------------------------------------------
    // 1995-06-15 12:34:56 -> half-days from 1979-01-01:
    //   days: 16 years (4 leap: 80,84,88,92) = 5844, Jan..May 1995 = 151,
    //   +14 = 6009 days = 12018 half-days, +1 (after noon) = 12019 = 0x2EF3
    //   seconds after noon = 34*60+56 = 2096 = 0x0830
    set_time(16'h2EF3, 16'h0830);
    check(dut.CHIP_35C.TIME_HALFDAYS, 16'h2EF3, "half-days loaded on PFUNC 7");
    check(dut.CHIP_35C.TIME_SECONDS,  16'h0830, "seconds loaded on PFUNC 7");

    // ---- 4. read it back after 3 ticks ------------------------------------
    ticks(3);
    get_time;
    check(rd_hd,  16'h2EF3,  "read half-days");
    check(rd_sec, 16'h0833,  "read seconds = written + 3");
    // snapshot consistency: a tick lands between PFUNC 4 and PFUNC 5..7
    before_sec = dut.CHIP_35C.TIME_SECONDS;
    read_pfunc(3'd4, b0);
    ticks(1);
    read_pfunc(3'd5, b1);
    read_pfunc(3'd6, b2);
    read_pfunc(3'd7, b3);
    check({b1, b0}, before_sec, "snapshot taken on PFUNC 4, not split by a tick");
    check({b3, b2}, 16'h2EF3,   "snapshot half-days");

    // ---- 5. wrap at 43199 --------------------------------------------------
    set_time(16'h0100, 16'd43198);
    ticks(2);
    get_time;
    check(rd_sec, 16'd0,     "wrap: seconds back to 0");
    check(rd_hd,  16'h0101,  "wrap: half-days + 1");

    // ---- 6. text commands are drained, no answer --------------------------
    trr_panc(16'h0E41);                     // cmd 6 + first of 4 bytes
    ldpanc_byte(8'h42); ldpanc_byte(8'h43); ldpanc_byte(8'h44);
    wait_idle(200000);
    trr_panc(16'h0811);                     // cmd 0 + first of 5 bytes
    ldpanc_byte(8'h12); ldpanc_byte(8'h13); ldpanc_byte(8'h14); ldpanc_byte(8'h15);
    wait_idle(200000);
    tra_pans;
    check(pans[7:0], 8'h01, "text commands leave the answer byte alone");
    check(pans[13],  1'b1,  "text commands leave READ alone");
    repeat (4) @(negedge clk);
    check(val, 1'b0, "text commands: no VAL");
    // and the clock still answers correctly afterwards (FIFO in step)
    get_time;
    check(rd_hd, 16'h0101, "clock intact after text commands");

    // ---- 7. a write with its WPAN byte missing ------------------------------
    ldpanc_byte(8'h05);                     // PFUNC 5 write, no second byte
    wait_val(`BOARD_CLK_FREQ / 500 + 100000);
    tra_pans;
    check(pans[7:0],  8'h00, "missing WPAN: answered with 0");
    check(pans[10:8], 3'd5,  "missing WPAN: PFUNC echoed");
    get_time;                               // next commands parse correctly
    check(rd_sec[15:8], 8'h00, "missing WPAN stored 0 in high seconds");
    check(rd_hd, 16'h0101, "FIFO still in step after the short command");

    // ---- 8. CLEAR_n keeps the time -----------------------------------------
    set_time(16'h1234, 16'h0100);
    @(negedge clk); clear_n = 0;
    repeat (4) @(negedge clk);
    check(dut.CHIP_35C.STAT4, 1'b1, "CLEAR_n: STAT4 back to reset value 1");
    check(dut.CHIP_35C.READ,  1'b0, "CLEAR_n: READ back to 0");
    check(dut.CHIP_35C.TIME_HALFDAYS, 16'h1234, "CLEAR_n: half-days kept");
    clear_n = 1;
    repeat (4) @(negedge clk);
    tra_pans;                               // clear the reset VAL
    get_time;
    check(rd_hd, 16'h1234, "time survives CLEAR_n (half-days)");
    check(rd_sec[15:8], 8'h01, "time survives CLEAR_n (seconds high)");

    if (errors == 0)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d checks)", errors, checks);
    $finish;
  end

  // Never hang silently.
  initial begin
    #200_000_000;
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule
