/****************************************************************************
** Unit testbench for sd_writer (iverilog)                                 **
**                                                                         **
** sd_writer against the behavioral SD card model (64 KB zero image):      **
**   - writes sector 17 with pattern A, then sector 3 with pattern B      **
**     (back-to-back, proving the busy/done handshake re-arms)            **
**   - verifies both sectors landed byte-exact in the card image          **
**   - verifies every OTHER sector is still zero (no misplaced writes)    **
**   - verifies the card counted no CMD CRC7 and no data CRC16 errors     **
**   - verifies done pulses exactly twice and err never                   **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sd_writer_tb;

  localparam CLK_HALF = 18.5;  // ~27 MHz
  localparam IMG_BYTES = 65536;

  reg clk = 0;
  always #CLK_HALF clk = ~clk;

  reg rst_n = 0;

  // ------------------------------------------------------------- DUT
  reg         start = 0;
  reg  [31:0] sector = 0;
  wire        busy, done, err;
  wire [8:0]  rd_addr;
  reg  [7:0]  rd_data;

  wire sd_clk;
  wire sd_cmd;
  wire sd_dat0;
  wire wr_cmd_o, wr_cmd_oe, wr_dat0_o, wr_dat0_oe;

  pullup (sd_cmd);
  pullup (sd_dat0);

  sd_writer #(
      .CLKDIV(8'd2)  // fast bit clock for the unit test (27/4 MHz)
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
      .start     (start),
      .sector    (sector),
      .busy      (busy),
      .done      (done),
      .err       (err),
      .rd_addr   (rd_addr),
      .rd_data   (rd_data)
  );

  // single tristate resolution, as at the board top level
  assign sd_cmd  = wr_cmd_oe ? wr_cmd_o : 1'bz;
  assign sd_dat0 = wr_dat0_oe ? wr_dat0_o : 1'bz;

  sd_card_model #(
      .IMAGE    ("writer_test.img"),
      .MAX_BYTES(IMG_BYTES)
  ) card (
      .sd_clk (sd_clk),
      .sd_cmd (sd_cmd),
      .sd_dat0(sd_dat0)
  );

  // ------------------------------------------------------------- data source
  // pattern selected per write: A = i*31+7, B = i*13+101 (mod 256)
  reg pat_sel = 0;
  always @(posedge clk)
    rd_data <= pat_sel ? ((rd_addr * 13 + 101) & 8'hFF) : ((rd_addr * 31 + 7) & 8'hFF);

  function [7:0] pat(input p, input [8:0] i);
    pat = p ? ((i * 13 + 101) & 8'hFF) : ((i * 31 + 7) & 8'hFF);
  endfunction

  // ------------------------------------------------------------- bookkeeping
  integer done_cnt = 0, err_cnt = 0;
  always @(posedge clk) begin
    if (done) done_cnt = done_cnt + 1;
    if (err) err_cnt = err_cnt + 1;
  end

  task write_sector(input [31:0] sec, input p);
    integer guard;
    begin
      pat_sel = p;
      sector  = sec;
      @(posedge clk);
      start <= 1;
      @(posedge clk);
      start <= 0;
      // wait for busy to ASSERT first (it rises one clock after the start
      // pulse is sampled - polling immediately would race past it)
      guard = 0;
      while (!busy && guard < 100) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (!busy) begin
        $display("TB_RESULT: FAIL write of sector %0d never started", sec);
        $finish;
      end
      guard = 0;
      while (busy && guard < 5_000_000) begin
        @(posedge clk);
        guard = guard + 1;
      end
      if (busy) begin
        $display("TB_RESULT: FAIL write of sector %0d hung", sec);
        $finish;
      end
    end
  endtask

  integer i, s, errors;
  reg [7:0] want;

  initial begin
    repeat (10) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);

    write_sector(17, 0);  // pattern A
    write_sector(3, 1);   // pattern B

    errors = 0;

    // both sectors byte-exact
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
      if (s != 17 && s != 3) begin
        for (i = 0; i < 512; i = i + 1) begin
          if (card.mem[s*512+i] !== 8'h00) begin
            if (errors < 10) $display("FAIL: sector %0d byte %0d modified", s, i);
            errors = errors + 1;
          end
        end
      end
    end

    if (done_cnt !== 2) begin
      $display("FAIL: done pulses = %0d (want 2)", done_cnt);
      errors = errors + 1;
    end
    if (err_cnt !== 0) begin
      $display("FAIL: err pulses = %0d", err_cnt);
      errors = errors + 1;
    end
    if (card.crc_errors !== 0) begin
      $display("FAIL: %0d CMD CRC7 errors", card.crc_errors);
      errors = errors + 1;
    end
    if (card.wr_crc_errors !== 0) begin
      $display("FAIL: %0d data CRC16 errors", card.wr_crc_errors);
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
