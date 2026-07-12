/****************************************************************************
** Unit testbench for sd_writer (iverilog)                                 **
**                                                                         **
** sd_writer against the behavioral SD card model (64 KB zero image):      **
**                                                                         **
** Single-sector path (must stay identical to the original engine):        **
**   - writes sector 17 with pattern A, then sector 3 with pattern B      **
**     (back-to-back, proving the busy/done handshake re-arms)            **
**   - reads sector 17 back through the CMD17 path and compares           **
**   - burst_len=1 write (sector 30): must behave exactly like the old    **
**     single-sector CMD24 path (equivalence case)                        **
**                                                                         **
** Burst path (CMD18/CMD25 + ACMD23 + CMD12):                              **
**   - CMD25 burst of 8 sectors at 40..47: every sector byte-exact,       **
**     block_next pulsed 7 times, ACMD23 count = 8 recorded by the card   **
**   - CMD18 burst readback of the same 8 sectors: byte-exact             **
**   - mid-burst injected CRC-status failure (fail_sector = 63): err      **
**     (not done), CMD12 issued, blocks 0..2 of the burst committed and   **
**     blocks 3..7 untouched (partial-write state verified)               **
**   - a single write AFTER the failed burst proves the engine re-arms    **
**                                                                         **
** 4-bit bus phase (use_4bit=1, after the full 1-bit suite = regression):  **
**   - single 4-bit write (sector 70) + CMD17 4-bit readback: byte-exact  **
**   - CMD25 4-bit burst of 4 at 80..83 + CMD18 4-bit readback            **
**   - injected CRC error on DAT2 (card model corrupt_line): the block    **
**     is rejected with "101", err (not done) pulses, the sector stays    **
**     zero, and a following write proves the engine re-arms              **
**   - DAT1-3 monitor: throughout every 4-bit WRITE op, DAT1-3 are only   **
**     ever low while the HOST drives them (data phase) - the card's CRC  **
**     status token and busy must stay on DAT0 alone                      **
**   - randomized CMD18 inter-block gaps (0..16 SD clocks, card model     **
**     rgap_rand; default gap is the spec-minimum region): burst reads    **
**     must tolerate back-to-back blocks in BOTH bus widths - real cards  **
**     stream with as little as N_AC = 2 clocks between blocks            **
**                                                                         **
** Global checks: every untouched sector still zero, done/err pulse       **
** counts exact, CMD12 count exact, no CMD CRC7 / data CRC16 errors.      **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sd_writer_tb #(
    // default 2 = 27/4 MHz; override with -P sd_writer_tb.TB_CLKDIV=1 to
    // exercise the 13.5 MHz case (sdclk toggling every clk)
    parameter [7:0] TB_CLKDIV = 8'd2
);

  localparam CLK_HALF = 18.5;  // ~27 MHz
  localparam IMG_BYTES = 65536;

  reg clk = 0;
  always #CLK_HALF clk = ~clk;

  reg rst_n = 0;

  // ------------------------------------------------------------- DUT
  reg         start = 0;
  reg         rd_mode = 0;
  reg  [31:0] sector = 0;
  reg  [8:0]  burst_len = 0;
  wire        busy, done, err, block_next;
  wire [8:0]  rd_addr;
  reg  [7:0]  rd_data;
  wire        rx_we;
  wire [8:0]  rx_addr;
  wire [7:0]  rx_data;

  // burst block counter: reset at start, advanced by block_next (this is
  // exactly the caller contract - the context advances WITH block k>=1,
  // never before block 0)
  reg [3:0] cur_blk = 0;
  always @(posedge clk) begin
    if (start) cur_blk <= 0;
    else if (block_next) cur_blk <= cur_blk + 4'd1;
  end

  // capture of single-sector read-back data
  reg [7:0] rxbuf[0:511];
  // capture of burst read-back data (8 blocks)
  reg [7:0] rxcap[0:4095];
  always @(posedge clk)
    if (rx_we) begin
      rxbuf[rx_addr] <= rx_data;
      rxcap[{cur_blk[2:0], rx_addr}] <= rx_data;
    end

  wire sd_clk;
  wire sd_cmd;
  wire sd_dat0, sd_dat1, sd_dat2, sd_dat3;
  wire wr_cmd_o, wr_cmd_oe, wr_dat0_o, wr_dat0_oe;
  wire wr_dat1_o, wr_dat1_oe, wr_dat2_o, wr_dat2_oe, wr_dat3_o, wr_dat3_oe;
  reg  tb_use4 = 0;

  pullup (sd_cmd);
  pullup (sd_dat0);
  pullup (sd_dat1);
  pullup (sd_dat2);
  pullup (sd_dat3);

  sd_writer #(
      .CLKDIV(TB_CLKDIV)
  ) dut (
      .clk       (clk),
      .rst_n     (rst_n),
      .sd_clk_o  (sd_clk),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (wr_cmd_o),
      .sd_cmd_oe (wr_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (wr_dat0_o),
      .sd_dat0_oe(wr_dat0_oe),
      .sd_dat1_i (sd_dat1),
      .sd_dat1_o (wr_dat1_o),
      .sd_dat1_oe(wr_dat1_oe),
      .sd_dat2_i (sd_dat2),
      .sd_dat2_o (wr_dat2_o),
      .sd_dat2_oe(wr_dat2_oe),
      .sd_dat3_i (sd_dat3),
      .sd_dat3_o (wr_dat3_o),
      .sd_dat3_oe(wr_dat3_oe),
      .use_4bit  (tb_use4),
      .start     (start),
      .rd_mode   (rd_mode),
      .sector    (sector),
      .busy      (busy),
      .done      (done),
      .err       (err),
      .burst_len (burst_len),
      .rca       (16'h0001),  // the model's CMD3 response assigns RCA 0x0001
      .block_next(block_next),
      .rd_addr   (rd_addr),
      .rd_data   (rd_data),
      .rx_we     (rx_we),
      .rx_addr   (rx_addr),
      .rx_data   (rx_data)
  );

  // single tristate resolution, as at the board top level
  assign sd_cmd  = wr_cmd_oe ? wr_cmd_o : 1'bz;
  assign sd_dat0 = wr_dat0_oe ? wr_dat0_o : 1'bz;
  assign sd_dat1 = wr_dat1_oe ? wr_dat1_o : 1'bz;
  assign sd_dat2 = wr_dat2_oe ? wr_dat2_o : 1'bz;
  assign sd_dat3 = wr_dat3_oe ? wr_dat3_o : 1'bz;

  sd_card_model #(
      .IMAGE    ("writer_test.img"),
      .MAX_BYTES(IMG_BYTES)
  ) card (
      .sd_clk (sd_clk),
      .sd_cmd (sd_cmd),
      .sd_dat0(sd_dat0),
      .sd_dat1(sd_dat1),
      .sd_dat2(sd_dat2),
      .sd_dat3(sd_dat3)
  );

  // DAT1-3 discipline monitor (enabled around 4-bit WRITE ops): the card's
  // CRC status token and busy stay on DAT0 alone, so DAT1-3 may only ever
  // be low while the HOST is driving them (the 4-bit data phase)
  reg mon4 = 0;
  integer d123_viol = 0;
  always @(posedge sd_clk)
    if (mon4 && !wr_dat1_oe) begin
      if (sd_dat1 === 1'b0 || sd_dat2 === 1'b0 || sd_dat3 === 1'b0)
        d123_viol = d123_viol + 1;
    end

  // bus-contention assertion (always on): the card model and the DUT must
  // NEVER drive the same line simultaneously - on silicon (12-JUL-2026) a
  // collapsed pad tristate fought the card through every 4-bit read while
  // z-resolution hid it in simulation; any overlap here is a fatal FAIL
  always @(posedge sd_clk) begin
    if ((card.dat_oe && wr_dat0_oe) ||
        (card.datx_oe && (wr_dat1_oe || wr_dat2_oe || wr_dat3_oe)) ||
        (card.cmd_drive && wr_cmd_oe)) begin
      $display("TB_RESULT: FAIL bus contention: card and host driving the same SD line at %0t", $time);
      $finish;
    end
  end

  // ------------------------------------------------------------- data source
  // single-sector patterns: A = i*31+7, B = i*13+101 (mod 256)
  // burst pattern: per-block distinct, bpat(blk,i) = blk*7 + i*5 + 13
  reg pat_sel = 0;
  reg burst_src = 0;
  always @(posedge clk)
    rd_data <= burst_src ? ((cur_blk * 7 + rd_addr * 5 + 13) & 8'hFF)
             : pat_sel ? ((rd_addr * 13 + 101) & 8'hFF) : ((rd_addr * 31 + 7) & 8'hFF);

  function [7:0] pat(input p, input [8:0] i);
    pat = p ? ((i * 13 + 101) & 8'hFF) : ((i * 31 + 7) & 8'hFF);
  endfunction

  function [7:0] bpat(input [3:0] blk, input [8:0] i);
    bpat = ((blk * 7 + i * 5 + 13) & 8'hFF);
  endfunction

  // ------------------------------------------------------------- bookkeeping
  integer done_cnt = 0, err_cnt = 0, bn_cnt = 0;
  always @(posedge clk) begin
    if (done) done_cnt = done_cnt + 1;
    if (err) err_cnt = err_cnt + 1;
    if (block_next) bn_cnt = bn_cnt + 1;
  end

  // start one engine operation (single or burst) and wait for completion:
  // busy must RISE first (it asserts one clock after the start pulse is
  // sampled - polling low immediately would race past the operation)
  task run_op(input [31:0] sec, input [8:0] blen, input rd);
    integer guard;
    begin
      sector    = sec;
      burst_len = blen;
      rd_mode   = rd;
      @(posedge clk);
      start <= 1;
      @(posedge clk);
      start <= 0;
      guard = 0;
      while (!busy && guard < 100) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (!busy) begin
        $display("TB_RESULT: FAIL op at sector %0d never started", sec);
        $finish;
      end
      guard = 0;
      while (busy && guard < 10_000_000) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (busy) begin
        $display("TB_RESULT: FAIL op at sector %0d hung", sec);
        $finish;
      end
      burst_len = 0;
      rd_mode   = 0;
    end
  endtask

  task write_sector(input [31:0] sec, input p);
    begin
      pat_sel = p;
      run_op(sec, 9'd0, 1'b0);
    end
  endtask

  // is sector s one of the sectors this test legitimately writes?
  // (70, 80..83 and 91 belong to the 4-bit phase; 90 is REJECTED there)
  function is_written(input [31:0] s);
    is_written = (s == 3) || (s == 5) || (s == 17) || (s == 30) ||
                 (s >= 40 && s <= 47) || (s >= 60 && s <= 62) ||
                 (s == 70) || (s >= 80 && s <= 83) || (s == 91);
  endfunction

  integer i, s, b, errors;

  initial begin
    repeat (10) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    errors = 0;

    // ---- single-sector path (original behavior) ------------------------
    write_sector(17, 0);  // pattern A
    write_sector(3, 1);   // pattern B

    // read sector 17 back through the engine (CMD17 path)
    run_op(17, 9'd0, 1'b1);

    // read-back must equal pattern A
    for (i = 0; i < 512; i = i + 1) begin
      if (rxbuf[i] !== pat(0, i[8:0])) begin
        if (errors < 5)
          $display("FAIL: readback byte %0d: got %02x want %02x", i, rxbuf[i], pat(0, i[8:0]));
        errors = errors + 1;
      end
    end

    // ---- burst_len=1 equivalence: same engine, same CMD24 --------------
    burst_src = 1;
    run_op(30, 9'd1, 1'b0);  // cur_blk = 0 -> bpat(0, i)
    for (i = 0; i < 512; i = i + 1) begin
      if (card.mem[30*512+i] !== bpat(4'd0, i[8:0])) begin
        if (errors < 5)
          $display("FAIL: burst_len=1 sector 30 byte %0d: got %02x want %02x",
                   i, card.mem[30*512+i], bpat(4'd0, i[8:0]));
        errors = errors + 1;
      end
    end
    if (bn_cnt !== 0) begin
      $display("FAIL: burst_len=1 pulsed block_next (%0d)", bn_cnt);
      errors = errors + 1;
    end
    if (card.cmd12_count !== 0) begin
      $display("FAIL: burst_len=1 sent CMD12 (%0d)", card.cmd12_count);
      errors = errors + 1;
    end

    // ---- CMD25 burst: 8 sectors at 40..47 ------------------------------
    run_op(40, 9'd8, 1'b0);
    for (b = 0; b < 8; b = b + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        if (card.mem[(40+b)*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: CMD25 sector %0d byte %0d: got %02x want %02x",
                     40 + b, i, card.mem[(40+b)*512+i], bpat(b[3:0], i[8:0]));
          errors = errors + 1;
        end
      end
    end
    if (bn_cnt !== 7) begin
      $display("FAIL: CMD25 x8 block_next pulses = %0d (want 7)", bn_cnt);
      errors = errors + 1;
    end
    if (card.cmd12_count !== 1) begin
      $display("FAIL: CMD25 x8 CMD12 count = %0d (want 1)", card.cmd12_count);
      errors = errors + 1;
    end
    if (card.acmd23_count !== 23'd8) begin
      $display("FAIL: ACMD23 count = %0d (want 8)", card.acmd23_count);
      errors = errors + 1;
    end

    // ---- CMD18 burst readback of the same 8 sectors ---------------------
    run_op(40, 9'd8, 1'b1);
    for (b = 0; b < 8; b = b + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        if (rxcap[b*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: CMD18 block %0d byte %0d: got %02x want %02x",
                     b, i, rxcap[b*512+i], bpat(b[3:0], i[8:0]));
          errors = errors + 1;
        end
      end
    end
    if (bn_cnt !== 14) begin
      $display("FAIL: after CMD18 x8 block_next pulses = %0d (want 14)", bn_cnt);
      errors = errors + 1;
    end
    if (card.cmd12_count !== 2) begin
      $display("FAIL: after CMD18 x8 CMD12 count = %0d (want 2)", card.cmd12_count);
      errors = errors + 1;
    end
    if (done_cnt !== 6 || err_cnt !== 0) begin
      $display("FAIL: before injection done=%0d err=%0d (want 6/0)", done_cnt, err_cnt);
      errors = errors + 1;
    end

    // ---- mid-burst CRC-status failure -----------------------------------
    // block 3 of the burst at 60..67 (sector 63) is rejected with "101":
    // the engine must stop with CMD12, pulse err (not done), and leave the
    // partial-write state: blocks 0..2 committed, 3..7 untouched
    card.fail_sector = 32'd63;
    run_op(60, 9'd8, 1'b0);
    if (err_cnt !== 1) begin
      $display("FAIL: injected failure err pulses = %0d (want 1)", err_cnt);
      errors = errors + 1;
    end
    if (done_cnt !== 6) begin
      $display("FAIL: injected failure pulsed done (done=%0d, want 6)", done_cnt);
      errors = errors + 1;
    end
    if (card.cmd12_count !== 3) begin
      $display("FAIL: aborted burst CMD12 count = %0d (want 3)", card.cmd12_count);
      errors = errors + 1;
    end
    for (b = 0; b < 3; b = b + 1) begin  // committed blocks
      for (i = 0; i < 512; i = i + 1) begin
        if (card.mem[(60+b)*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: partial burst sector %0d byte %0d wrong", 60 + b, i);
          errors = errors + 1;
        end
      end
    end
    for (s = 63; s <= 67; s = s + 1) begin  // rejected + never-sent blocks
      for (i = 0; i < 512; i = i + 1) begin
        if (card.mem[s*512+i] !== 8'h00) begin
          if (errors < 5)
            $display("FAIL: sector %0d modified after aborted burst", s);
          errors = errors + 1;
        end
      end
    end

    // ---- recovery: the engine re-arms after the aborted burst -----------
    burst_src = 0;
    write_sector(5, 1);  // pattern B
    for (i = 0; i < 512; i = i + 1) begin
      if (card.mem[5*512+i] !== pat(1, i[8:0])) begin
        if (errors < 5) $display("FAIL: post-abort sector 5 byte %0d wrong", i);
        errors = errors + 1;
      end
    end

    // ---- global checks ---------------------------------------------------
    // both original sectors byte-exact
    for (i = 0; i < 512; i = i + 1) begin
      if (card.mem[17*512+i] !== pat(0, i[8:0])) begin
        if (errors < 5)
          $display("FAIL: sector 17 byte %0d: got %02x want %02x", i, card.mem[17*512+i],
                   pat(0, i[8:0]));
        errors = errors + 1;
      end
      if (card.mem[3*512+i] !== pat(1, i[8:0])) begin
        if (errors < 5)
          $display("FAIL: sector 3 byte %0d: got %02x want %02x", i, card.mem[3*512+i],
                   pat(1, i[8:0]));
        errors = errors + 1;
      end
    end

    // every other sector untouched (zero image)
    for (s = 0; s < IMG_BYTES / 512; s = s + 1) begin
      if (!is_written(s)) begin
        for (i = 0; i < 512; i = i + 1) begin
          if (card.mem[s*512+i] !== 8'h00) begin
            if (errors < 10) $display("FAIL: sector %0d byte %0d modified", s, i);
            errors = errors + 1;
          end
        end
      end
    end

    if (done_cnt !== 7) begin
      $display("FAIL: done pulses = %0d (want 7)", done_cnt);
      errors = errors + 1;
    end
    if (err_cnt !== 1) begin
      $display("FAIL: err pulses = %0d (want 1)", err_cnt);
      errors = errors + 1;
    end
    if (bn_cnt !== 17) begin  // 7 + 7 + 3 (aborted burst advanced 3 times)
      $display("FAIL: block_next pulses = %0d (want 17)", bn_cnt);
      errors = errors + 1;
    end

    // =================== 4-bit bus phase (use_4bit = 1) ===================
    // the entire 1-bit suite above ran with use_4bit=0 = the regression
    tb_use4   = 1;
    burst_src = 1;

    // ---- single 4-bit write + 4-bit readback ---------------------------
    mon4 = 1;
    run_op(70, 9'd0, 1'b0);  // cur_blk = 0 -> bpat(0, i)
    mon4 = 0;
    for (i = 0; i < 512; i = i + 1) begin
      if (card.mem[70*512+i] !== bpat(4'd0, i[8:0])) begin
        if (errors < 5)
          $display("FAIL: 4-bit sector 70 byte %0d: got %02x want %02x",
                   i, card.mem[70*512+i], bpat(4'd0, i[8:0]));
        errors = errors + 1;
      end
    end
    run_op(70, 9'd0, 1'b1);  // CMD17 in 4-bit mode
    for (i = 0; i < 512; i = i + 1) begin
      if (rxbuf[i] !== bpat(4'd0, i[8:0])) begin
        if (errors < 5)
          $display("FAIL: 4-bit readback byte %0d: got %02x want %02x",
                   i, rxbuf[i], bpat(4'd0, i[8:0]));
        errors = errors + 1;
      end
    end

    // ---- CMD25 4-bit burst: 4 sectors at 80..83 -------------------------
    mon4 = 1;
    run_op(80, 9'd4, 1'b0);
    mon4 = 0;
    for (b = 0; b < 4; b = b + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        if (card.mem[(80+b)*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: 4-bit CMD25 sector %0d byte %0d: got %02x want %02x",
                     80 + b, i, card.mem[(80+b)*512+i], bpat(b[3:0], i[8:0]));
          errors = errors + 1;
        end
      end
    end
    if (bn_cnt !== 20) begin
      $display("FAIL: after 4-bit CMD25 x4 block_next pulses = %0d (want 20)", bn_cnt);
      errors = errors + 1;
    end
    if (card.acmd23_count !== 23'd4) begin
      $display("FAIL: 4-bit ACMD23 count = %0d (want 4)", card.acmd23_count);
      errors = errors + 1;
    end
    if (card.cmd12_count !== 4) begin
      $display("FAIL: after 4-bit CMD25 x4 CMD12 count = %0d (want 4)", card.cmd12_count);
      errors = errors + 1;
    end

    // ---- CMD18 4-bit burst readback of the same 4 sectors ---------------
    run_op(80, 9'd4, 1'b1);
    for (b = 0; b < 4; b = b + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        if (rxcap[b*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: 4-bit CMD18 block %0d byte %0d: got %02x want %02x",
                     b, i, rxcap[b*512+i], bpat(b[3:0], i[8:0]));
          errors = errors + 1;
        end
      end
    end
    if (bn_cnt !== 23) begin
      $display("FAIL: after 4-bit CMD18 x4 block_next pulses = %0d (want 23)", bn_cnt);
      errors = errors + 1;
    end
    if (card.cmd12_count !== 5) begin
      $display("FAIL: after 4-bit CMD18 x4 CMD12 count = %0d (want 5)", card.cmd12_count);
      errors = errors + 1;
    end
    if (done_cnt !== 11 || err_cnt !== 1) begin
      $display("FAIL: before 4-bit injection done=%0d err=%0d (want 11/1)",
               done_cnt, err_cnt);
      errors = errors + 1;
    end

    // ---- injected CRC error on DAT2: reject, no commit, DAT0-only status
    card.corrupt_line = 3'd2;
    mon4 = 1;
    run_op(90, 9'd0, 1'b0);
    mon4 = 0;
    if (err_cnt !== 2) begin
      $display("FAIL: 4-bit CRC injection err pulses = %0d (want 2)", err_cnt);
      errors = errors + 1;
    end
    if (done_cnt !== 11) begin
      $display("FAIL: 4-bit CRC injection pulsed done (done=%0d, want 11)", done_cnt);
      errors = errors + 1;
    end
    for (i = 0; i < 512; i = i + 1) begin
      if (card.mem[90*512+i] !== 8'h00) begin
        if (errors < 5) $display("FAIL: rejected 4-bit sector 90 modified (byte %0d)", i);
        errors = errors + 1;
      end
    end

    // ---- recovery: the engine re-arms in 4-bit mode ----------------------
    mon4 = 1;
    run_op(91, 9'd0, 1'b0);
    mon4 = 0;
    for (i = 0; i < 512; i = i + 1) begin
      if (card.mem[91*512+i] !== bpat(4'd0, i[8:0])) begin
        if (errors < 5) $display("FAIL: post-injection 4-bit sector 91 byte %0d wrong", i);
        errors = errors + 1;
      end
    end

    // ---- randomized CMD18 inter-block gaps (0..16 SD clocks) -------------
    // real cards stream back-to-back (spec N_AC minimum 2): the start-bit
    // hunt must be armed from the clock after the previous end bit, in
    // BOTH bus widths; gap 0 is stricter than the spec allows
    card.rgap_rand = 1'b1;
    run_op(80, 9'd4, 1'b1);  // 4-bit CMD18 x4, random gaps
    for (b = 0; b < 4; b = b + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        if (rxcap[b*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: rand-gap 4-bit CMD18 block %0d byte %0d: got %02x want %02x",
                     b, i, rxcap[b*512+i], bpat(b[3:0], i[8:0]));
          errors = errors + 1;
        end
      end
    end
    tb_use4 = 0;
    card.bus4 = 1'b0;  // as after a re-init (CMD0): card back in 1-bit mode
    run_op(40, 9'd8, 1'b1);  // 1-bit CMD18 x8, random gaps
    for (b = 0; b < 8; b = b + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        if (rxcap[b*512+i] !== bpat(b[3:0], i[8:0])) begin
          if (errors < 5)
            $display("FAIL: rand-gap 1-bit CMD18 block %0d byte %0d: got %02x want %02x",
                     b, i, rxcap[b*512+i], bpat(b[3:0], i[8:0]));
          errors = errors + 1;
        end
      end
    end
    card.rgap_rand = 1'b0;
    if (card.cmd12_count !== 7) begin
      $display("FAIL: after rand-gap bursts CMD12 count = %0d (want 7)", card.cmd12_count);
      errors = errors + 1;
    end
    if (bn_cnt !== 33) begin
      $display("FAIL: after rand-gap bursts block_next pulses = %0d (want 33)", bn_cnt);
      errors = errors + 1;
    end

    // ---- 4-bit phase global checks ---------------------------------------
    if (d123_viol !== 0) begin
      $display("FAIL: DAT1-3 driven low outside the host data phase (%0d samples) - CRC status/busy must stay on DAT0", d123_viol);
      errors = errors + 1;
    end
    if (done_cnt !== 14) begin
      $display("FAIL: total done pulses = %0d (want 14)", done_cnt);
      errors = errors + 1;
    end
    if (err_cnt !== 2) begin
      $display("FAIL: total err pulses = %0d (want 2)", err_cnt);
      errors = errors + 1;
    end
    // every untouched sector still zero (incl. after the 4-bit phase)
    for (s = 0; s < IMG_BYTES / 512; s = s + 1) begin
      if (!is_written(s)) begin
        for (i = 0; i < 512; i = i + 1) begin
          if (card.mem[s*512+i] !== 8'h00) begin
            if (errors < 10) $display("FAIL: sector %0d byte %0d modified (4-bit phase)", s, i);
            errors = errors + 1;
          end
        end
      end
    end

    if (card.crc_errors !== 0) begin
      $display("FAIL: %0d CMD CRC7 errors", card.crc_errors);
      errors = errors + 1;
    end
    if (card.wr_crc_errors !== 0) begin
      $display("FAIL: %0d data CRC16 errors", card.wr_crc_errors);
      errors = errors + 1;
    end
    if (card.illegal_writes !== 0) begin
      $display("FAIL: %0d illegal writes counted", card.illegal_writes);
      errors = errors + 1;
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #500_000_000;  // 0.5 s absolute watchdog
    $display("TB_RESULT: FAIL absolute watchdog");
    $finish;
  end

endmodule
