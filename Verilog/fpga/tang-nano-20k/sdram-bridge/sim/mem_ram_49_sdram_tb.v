/****************************************************************************
** Testbench for MEM_RAM_49_SDRAM (ND-120 sheet-49 SDRAM backend)          **
**                                                                         **
** Replays the MEASURED ND-120 DRAM protocol (docs/nd120-dram-memory.md    **
** section 4) against the bridge + behavioral SDRAM model:                 **
**   N: RAS rise, row on AA   N+1: column   N+2: CAS rise (+write data)    **
**   read data sampled LATE in cycles N+4 and N+5 (hold check)             **
**   RAS falls N+5, CAS N+6, next access >= N+11                           **
**                                                                         **
** Checks: directed first/last-word per bank, unpopulated BANK2, parity    **
** round-trip (including deliberately wrong parity bits), 2000-access      **
** random soak against a mirror model, idle-watchdog refresh, refresh      **
** cadence (avg interval < 16 us).                                         **
**                                                                         **
** Compile modes (one source, three registry targets):                     **
**   (none)             legacy 18-bit word-per-location; stored parity     **
**                      round-trips, including deliberately BAD parity     **
**   -DND_SDRAM_PACK16  packed 16-bit mode: two ND words per location,     **
**                      DQM lane-masked writes. Pinned contract            **
**                      (docs/nd120-parity-analysis.md section 6):         **
**                      adjacent-word independence, computed parity on     **
**                      read (CORR_n always 1), bad-parity writes absorbed **
**   + -DTB_PART_ROWS=n reduced CPU partition: rows >= n report ABSENT     **
**                      (reads 0, writes dropped), like an empty bank      **
**                                                                         **
** Prints "TB_RESULT: PASS" on success.                                    **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module mem_ram_49_sdram_tb;

  localparam OSC_PERIOD = 37;  // ~27 MHz

  // CPU partition size in 1K-word rows ({bank, row}); 2048 = full 4 MB
`ifdef TB_PART_ROWS
  localparam TB_ROWS = `TB_PART_ROWS;
`else
  localparam TB_ROWS = 2048;
`endif

  // OSC and 2x clock, edge-aligned (posedge osc == every other posedge clk2x)
  reg clk2x = 1;
  always #(OSC_PERIOD / 4.0) clk2x = ~clk2x;
  reg osc = 1;
  always @(clk2x) if (clk2x) osc = ~osc;  // divide by 2, aligned on clk2x rises

  wire clk2x_sdram = ~clk2x;

  reg sys_rst_n = 0;

  // sheet-49 interface (OSC domain)
  reg [9:0] AA = 0;
  reg BANK0 = 0, BANK1 = 0, BANK2 = 0;
  reg RAS = 0, CAS = 0;
  reg MW_n = 1;
  reg [17:0] DD_IN = 0;
  wire [17:0] DD_OUT;
  wire CORR_n;

  // SDRAM pins
  wire sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
  wire [31:0] sd_dq;
  wire [10:0] sd_addr;
  wire [1:0] sd_ba;
  wire [3:0] sd_dqm;

  MEM_RAM_49_SDRAM #(
      .CLK2X_FREQ(54_000_000),
      .CPU_PART_ROWS(TB_ROWS)
  ) dut (
      .sysclk(osc),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(AA),
      .BANK0(BANK0),
      .BANK1(BANK1),
      .BANK2(BANK2),
      .CAS(CAS),
      .RAS(RAS),
      .MWRITE50_n(MW_n),
      .DD_17_0_IN(DD_IN),
      .DD_17_0_OUT(DD_OUT),
      .CORR_n(CORR_n),

      .clk2x(clk2x),
      .clk2x_sdram(clk2x_sdram),

      .O_sdram_clk(sd_clk),
      .O_sdram_cke(sd_cke),
      .O_sdram_cs_n(sd_cs_n),
      .O_sdram_cas_n(sd_cas_n),
      .O_sdram_ras_n(sd_ras_n),
      .O_sdram_wen_n(sd_wen_n),
      .IO_sdram_dq(sd_dq),
      .O_sdram_addr(sd_addr),
      .O_sdram_ba(sd_ba),
      .O_sdram_dqm(sd_dqm)
  );

  sdram_model u_model (
      .clk(sd_clk),
      .cke(sd_cke),
      .cs_n(sd_cs_n),
      .ras_n(sd_ras_n),
      .cas_n(sd_cas_n),
      .we_n(sd_wen_n),
      .a(sd_addr),
      .ba(sd_ba),
      .dqm(sd_dqm),
      .dq(sd_dq)
  );

  // ---- mirror model (banks 0/1 only) ----
  reg [17:0] mirror[0:2097151];
  reg        written[0:2097151];
  integer wi;
  initial for (wi = 0; wi < 2097152; wi = wi + 1) written[wi] = 0;

  // ---- refresh cadence monitor ----
  integer refresh_count = 0;
  realtime last_refresh = 0;
  realtime max_refresh_gap = 0;
  always @(posedge clk2x)
    if (dut.s_refresh) begin
      if (refresh_count > 0 && ($realtime - last_refresh) > max_refresh_gap)
        max_refresh_gap = $realtime - last_refresh;
      last_refresh  = $realtime;
      refresh_count = refresh_count + 1;
    end

  integer errors = 0;

  task check(input cond, input [127:0] what);
    if (!cond) begin
      errors = errors + 1;
      $display("FAIL at %0t: %0s", $time, what);
    end
  endtask

  // expected readback of a written 18-bit word
`ifdef ND_SDRAM_PACK16
  // packed mode: 16 data bits stored, parity REGENERATED as odd parity on
  // read - a deliberately-bad stored parity bit is absorbed
  function [17:0] exp_rd(input [17:0] w);
    exp_rd = {~(^w[16:9]), w[16:9], ~(^w[7:0]), w[7:0]};
  endfunction
`else
  // legacy 18-bit mode: all 18 bits (incl. bad parity) round-trip verbatim
  function [17:0] exp_rd(input [17:0] w);
    exp_rd = w;
  endfunction
`endif

  // does this ND address belong to a populated bank AND the CPU partition?
  function present(input [1:0] bank, input [9:0] row);
    present = (bank < 2) && ({1'b0, bank[0], row} < TB_ROWS[11:0]);
  endfunction

  // ---- one access with the measured 6-cycle signature ----
  // bank: 0/1/2. For reads, samples DD_OUT/CORR_n late in N+4 AND N+5.
  task access(input [1:0] bank, input [9:0] row, input [9:0] col, input wn,
              input [17:0] wdata);
    reg [17:0] s4, s5, exp;
    reg c4, c5;
    reg [20:0] idx;
    begin
      idx = {bank[0], row, col};
      @(posedge osc);  // N
      RAS   <= 1;
      AA    <= row;
      MW_n  <= wn;
      BANK0 <= (bank == 0);
      BANK1 <= (bank == 1);
      BANK2 <= (bank == 2);
      @(posedge osc);  // N+1
      AA <= col;
      @(posedge osc);  // N+2: CAS rises. On silicon the write data appears on
      CAS <= 1;        // DD only as a BRIEF mid-window pulse (the AM29833A
      if (!wn) begin   // transceiver drive window); hard zeros otherwise
        #10 DD_IN = wdata;   // pulse start, mid cycle N+2
        #18 DD_IN = 18'b0;   // pulse end (~18 ns, narrower than one clk2x)
      end
      @(posedge osc);  // N+3
      @(posedge osc);  // N+4
      #(OSC_PERIOD - 5);  // late in cycle N+4
      s4 = DD_OUT;
      c4 = CORR_n;
      @(posedge osc);  // N+5
      RAS <= 0;
      #(OSC_PERIOD - 5);  // late in cycle N+5 (CAS tail - hold check)
      s5 = DD_OUT;
      c5 = CORR_n;
      @(posedge osc);  // N+6
      CAS   <= 0;
      AA    <= 0;
      MW_n  <= 1;
      BANK0 <= 0;
      BANK1 <= 0;
      BANK2 <= 0;
      DD_IN <= 0;
      // enforce minimum RAS-to-RAS spacing of 11 (6 so far) + random jitter
      repeat (5 + ({$random} % 8)) @(posedge osc);

      if (wn) begin  // read: verify
        if (!present(bank, row)) begin
          check(s4 === 18'b0, "absent read not 0 (N+4)");
          check(c4 === 1'b1, "absent CORR_n not 1");
        end else if (written[idx]) begin
          exp = exp_rd(mirror[idx]);
          check(s4 === exp, "read data wrong (N+4)");
          check(s5 === exp, "read data not held (N+5)");
          check(c4 === ((^exp[8:0]) & (^exp[17:9])), "CORR_n wrong (N+4)");
          check(c5 === c4, "CORR_n not held (N+5)");
        end
      end else begin  // write: track mirror, DD_OUT must stay 0
        if (present(bank, row)) begin
          mirror[idx]  = wdata;
          written[idx] = 1;
        end
        check(s4 === 18'b0, "DD_OUT not 0 during write");
        check(c4 === 1'b1, "CORR_n not 1 during write");
      end
    end
  endtask

  task wr18(input [1:0] bank, input [9:0] row, input [9:0] col, input [17:0] d);
    access(bank, row, col, 1'b0, d);
  endtask
  task rd18(input [1:0] bank, input [9:0] row, input [9:0] col);
    access(bank, row, col, 1'b1, 18'b0);
  endtask

  integer i;
  reg [1:0] rb;
  reg [9:0] rrow, rcol;
  reg [17:0] rdat;
  realtime soak_start;

  initial begin
    // reset + SDRAM init (200 us at 54 MHz)
    repeat (10) @(posedge osc);
    sys_rst_n = 1;
    $display("TB: waiting for SDRAM init...");
    wait (dut.u_sdram.busy === 1'b0);
    repeat (4) @(posedge osc);
    $display("TB: init done at %0t", $time);

    // ---- directed: first/last word of each populated bank ----
    wr18(0, 10'h000, 10'h000, 18'h00001);
    wr18(0, 10'h3FF, 10'h3FF, 18'h2AAAA);
    wr18(1, 10'h000, 10'h000, 18'h15555);
    wr18(1, 10'h3FF, 10'h3FF, 18'h3FFFE);
    rd18(0, 10'h000, 10'h000);
    rd18(0, 10'h3FF, 10'h3FF);
    rd18(1, 10'h000, 10'h000);
    rd18(1, 10'h3FF, 10'h3FF);

    // ---- unpopulated BANK2: write is dropped, read returns 0 ----
    access(2, 10'h012, 10'h034, 1'b0, 18'h12345);
    rd18(2, 10'h012, 10'h034);

    // ---- parity round-trip: even and (deliberately) odd parity words ----
    // legacy mode: stored parity (incl. BAD parity) round-trips verbatim;
    // pack16 mode: parity is recomputed on read, bad parity is absorbed
    // (exp_rd encodes the mode's contract - nd120-parity-analysis.md sec. 6)
    wr18(0, 10'h010, 10'h001, 18'b000000000_000000011);  // BAD low parity (correct = 1)
    wr18(0, 10'h010, 10'h002, 18'b000000001_000000001);  // good parity halves
    rd18(0, 10'h010, 10'h001);
    rd18(0, 10'h010, 10'h002);

`ifdef ND_SDRAM_PACK16
    // ---- pack16: adjacent ND words (even/odd col) share one location ----
    // lane-mask contract: writing one half must NEVER disturb the other
    $display("TB: pack16 adjacent-word independence...");
    wr18(0, 10'h020, 10'h000, 18'h3FFFF);  // even half: all-ones data
    wr18(0, 10'h020, 10'h001, 18'h00000);  // odd half: all-zeros data
    rd18(0, 10'h020, 10'h000);             // even survived the odd write
    rd18(0, 10'h020, 10'h001);
    wr18(0, 10'h020, 10'h000, 18'h00000);  // overwrite even with zeros
    rd18(0, 10'h020, 10'h001);             // odd untouched
    rd18(0, 10'h020, 10'h000);
    wr18(0, 10'h020, 10'h3FF, 18'h15555);  // odd half first this time
    wr18(0, 10'h020, 10'h3FE, 18'h2AAAA);
    rd18(0, 10'h020, 10'h3FF);
    rd18(0, 10'h020, 10'h3FE);
    // read-after-write of the SAME location's other half (stale-DQM check:
    // the write's lane mask must not blank the following read's data window)
    wr18(1, 10'h021, 10'h004, 18'h12345);
    rd18(1, 10'h021, 10'h005);
    rd18(1, 10'h021, 10'h004);

    // ---- partition boundary (reduced-CPU builds): last CPU row present,
    // first storage-reserved row absent (write dropped, reads 0) ----
    if (TB_ROWS < 2048) begin
      $display("TB: pack16 partition boundary at row %0d...", TB_ROWS);
      rb   = (TB_ROWS - 1) / 1024;
      rrow = (TB_ROWS - 1) % 1024;
      wr18(rb, rrow, 10'h005, 18'h12345);
      rd18(rb, rrow, 10'h005);
      rb   = TB_ROWS / 1024;
      rrow = TB_ROWS % 1024;
      wr18(rb, rrow, 10'h005, 18'h0AAAA);
      rd18(rb, rrow, 10'h005);
    end
`endif

    // ---- random soak ----
    $display("TB: random soak (2000 accesses)...");
    soak_start = $realtime;
    for (i = 0; i < 2000; i = i + 1) begin
      rb   = {$random} % 2;
      rrow = $random;
      rcol = $random;
      rdat = $random;
      if (({$random} % 10) < 4) wr18(rb, rrow, rcol, rdat);
      else rd18(rb, rrow, rcol);
    end

    // ---- idle stretch: watchdog refresh must keep firing ----
    $display("TB: idle stretch 200 us...");
    #200_000;
    rd18(0, 10'h000, 10'h000);   // still correct after idle
    rd18(1, 10'h3FF, 10'h3FF);

    // ---- refresh cadence ----
    $display("TB: %0d refreshes, max gap %0t ns", refresh_count, max_refresh_gap);
    check(refresh_count > 50, "too few refreshes");
    check(max_refresh_gap < 20_000, "refresh gap exceeded 20 us");

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  // watchdog
  initial begin
    #20_000_000;  // 20 ms
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
