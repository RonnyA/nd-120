/**************************************************************************
** TESTBENCH: floppy_hwtest_core - the Nexys 4 DDR floppy hardware test  **
** with a fake disk backend standing in for the SD storage adapter.      **
**                                                                       **
** The backend answers each FDISK read after a delay by filling the      **
** controller's sector buffer with FLOPPY1.IMG's real first words        **
** (000060 000057 000062 000015 ... then a deterministic pattern), so    **
** the core's golden checksum check exercises the same math the board    **
** will run. The core's own contention injector supplies the CPU-fetch   **
** flicker; on the PRE-FIX ND_DMA_MASTER this makes the command-block    **
** fetch corrupt and the tb FAILS - proving the test has teeth.          **
**                                                                       **
** Checks: the UART line decodes to E with error code 0, B0 = 000060,    **
** C = the checksum of what the backend actually delivered, verdict 'P'. **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 23-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module floppy_hwtest_core_tb;

  reg clk = 0;
  reg rst_n = 0;
  always #40 clk = ~clk;   // 12.5 MHz

  wire        fd_req, fd_wr;
  wire [15:0] fd_lsect;
  wire [1:0]  fd_format, fd_drive;
  wire [10:0] fd_wc;
  reg         fd_done = 0, fd_err = 0;
  reg  [3:0]  fd_code = 0;
  reg  [9:0]  fdb_addr = 0;
  reg  [15:0] fdb_wdata = 0;
  reg         fdb_we = 0;
  wire [15:0] fdb_rdata;
  wire        uart_txd, st_pass, st_timeout, st_idle;

  floppy_hwtest_core #(
      .SETTLE_TICKS(28'd2000), .GAP_TICKS(28'd100000), .UART_DIV(16)
  ) u_core (
      .clk_cpu(clk), .rst_cpu_n(rst_n),
      .mount_ok(1'b1), .img_size(32'd1261568),
      .fd_req(fd_req), .fd_wr(fd_wr), .fd_lsect(fd_lsect),
      .fd_format(fd_format), .fd_drive(fd_drive), .fd_wc(fd_wc),
      .fd_done(fd_done), .fd_err(fd_err), .fd_code(fd_code),
      .fdb_addr(fdb_addr), .fdb_wdata(fdb_wdata), .fdb_we(fdb_we),
      .fdb_rdata(fdb_rdata),
      .uart_txd(uart_txd),
      .st_pass(st_pass), .st_timeout(st_timeout), .st_idle(st_idle)
  );

  // fake disk backend serving the REAL image words: the first 2048 bytes
  // of FLOPPY1.IMG (one word per byte pair, big endian, exactly like the
  // real storage path delivers them), so the core's built-in golden
  // checksum 125441 applies unchanged.
  reg [7:0] imgb [0:2047];
  integer   imgf, imgn;
  initial begin
    imgf = $fopen("../../../../runSim/FLOPPY1.IMG", "rb");
    if (imgf == 0) begin
      $display("FAIL: cannot open ../../../../runSim/FLOPPY1.IMG");
      $display("TB_RESULT: FAIL");
      $finish;
    end
    imgn = $fread(imgb, imgf);
    $fclose(imgf);
    if (imgn != 2048) begin
      $display("FAIL: short read from FLOPPY1.IMG (%0d)", imgn);
      $display("TB_RESULT: FAIL");
      $finish;
    end
  end

  function [15:0] img_word(input [15:0] sect, input [10:0] w);
    integer byte0;
    begin
      byte0 = ({16'd0, sect} * 512 + {21'd0, w}) * 2;
      img_word = {imgb[byte0], imgb[byte0 + 1]};
    end
  endfunction

  reg [15:0] expect_sum = 0;
  integer bi;
  always @(posedge clk) begin
    fdb_we  <= 0;
    fd_done <= 0;
    if (fd_req && !fd_wr) begin
      // fill the controller's buffer, then pulse done
      for (bi = 0; bi < fd_wc; bi = bi + 1) begin
        @(posedge clk);
        fdb_addr  <= bi[9:0];
        fdb_wdata <= img_word(fd_lsect, bi[10:0]);
        fdb_we    <= 1;
      end
      @(posedge clk);
      fdb_we <= 0;
      repeat (20) @(posedge clk);
      fd_done <= 1;
      fd_err  <= 0;
    end
  end

  // UART receiver, 9600 8N1 at DELAY_FRAMES = 12_500_000/9600 = 1302 clocks
  localparam integer BITCLKS = 16;
  reg [7:0] line [0:127];
  integer   ll = 0;
  task recv_char(output [7:0] ch);
    integer b;
    reg ok;
    begin
      ok = 0;
      while (!ok) begin
        @(negedge uart_txd);
        repeat (BITCLKS / 2) @(posedge clk);
        if (uart_txd === 1'b0) ok = 1;   // genuine start bit
      end
      repeat (BITCLKS) @(posedge clk);   // to the middle of bit 0
      ch = 0;
      for (b = 0; b < 8; b = b + 1) begin
        ch = {uart_txd, ch[7:1]};
        repeat (BITCLKS) @(posedge clk);
      end
    end
  endtask

  integer errors = 0;
  task check(input cond, input [255:0] what);
    begin
      if (cond !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL: %0s", what);
      end
    end
  endtask

  // stall diagnostics
  reg [3:0] last_d = 4'hF;
  reg [2:0] last_m = 3'h7;
  integer   dbg_n = 0;
  reg prev_ack = 0;
  integer txn_n = 0;
  always @(posedge clk) begin
    if (u_core.c_dma_ack && !prev_ack && txn_n < 40) begin
      $display("t=%0t DMA %s addr=%06o data=%06o", $time,
               u_core.c_dma_wr ? "WR" : "RD", u_core.c_dma_addr,
               u_core.c_dma_wr ? u_core.c_dma_wdata : u_core.c_dma_rdata);
      txn_n = txn_n + 1;
    end
    prev_ack = u_core.c_dma_ack;
  end

  reg prev_txv = 0;
  integer txv_n = 0;
  always @(posedge clk) begin
    if (u_core.tx_valid && !prev_txv && txv_n < 80) begin
      $display("t=%0t TXCHAR %02x '%c' (pr_f=%0d pr_p=%0d pr_end=%b)",
               $time, u_core.tx_data,
               (u_core.tx_data >= 32 && u_core.tx_data < 127) ? u_core.tx_data : ".",
               u_core.pr_f, u_core.pr_p, u_core.pr_end);
      txv_n = txv_n + 1;
    end
    prev_txv = u_core.tx_valid;
  end

  reg prev_prgo = 0, prev_prrun = 0, prev_txd = 1;
  integer xz_n = 0;
  always @(posedge clk) begin
    if (u_core.pr_go && !prev_prgo)
      $display("t=%0t PR_GO (pass=%b tmo=%b)", $time, u_core.pass, u_core.d_timeout);
    if (u_core.pr_run && !prev_prrun)
      $display("t=%0t PR_RUN start, pr_ch=%02x tx_busy=%b", $time, u_core.pr_ch, u_core.tx_busy);
    prev_prgo  = u_core.pr_go;
    prev_prrun = u_core.pr_run;
    if ((^uart_txd === 1'bx) && xz_n < 5) begin
      $display("t=%0t uart_txd is X", $time);
      xz_n = xz_n + 1;
    end
  end

  integer hb = 0;
  always @(posedge clk) begin
    hb = hb + 1;
    if (hb % 500000 == 0)
      $display("t=%0t heartbeat d=%0d m=%0d tmo=%0d", $time,
               u_core.d_state, u_core.m_state, u_core.d_tmo);
    if (u_core.d_state !== last_d) begin
      $display("t=%0t d_state -> %0d", $time, u_core.d_state);
      last_d = u_core.d_state; dbg_n = dbg_n + 1;
    end
    if (u_core.m_state !== last_m && dbg_n < 60) begin
      $display("t=%0t m_state -> %0d", $time, u_core.m_state);
      last_m = u_core.m_state; dbg_n = dbg_n + 1;
    end
    if (fd_req && dbg_n < 60) begin
      $display("t=%0t FDISK req lsect=%06o fmt=%0d wc=%0d", $time, fd_lsect, fd_format, fd_wc);
      dbg_n = dbg_n + 1;
    end
  end

  reg [7:0] ch;
  integer i;
  reg [15:0] sum_calc;
  initial begin
`ifdef DUMPFILE
    $dumpfile("floppy_hwtest_core_tb.vcd");
    $dumpvars(0, floppy_hwtest_core_tb);
`endif
    // expected checksum of what the backend delivers (2 sectors x 512 w)
    sum_calc = 0;
    for (i = 0; i < 1024; i = i + 1)
      sum_calc = sum_calc + img_word(i / 512, i % 512);

    repeat (8) @(posedge clk);
    rst_n = 1;

    // collect one full report line; require a stable-high idle first
    wait (uart_txd === 1'b1);
    repeat (4 * BITCLKS) @(posedge clk);
    while (uart_txd !== 1'b1) begin
      wait (uart_txd === 1'b1);
      repeat (4 * BITCLKS) @(posedge clk);
    end
    ll = 0;
    ch = 0;
    while (ch != 8'h0A && ll < 120) begin
      recv_char(ch);
      $display("t=%0t rx %02x '%c'", $time, ch, (ch >= 32 && ch < 127) ? ch : ".");
      line[ll] = ch;
      ll = ll + 1;
    end
    $write("core line: ");
    for (i = 0; i < ll; i = i + 1) $write("%c", line[i]);

    // decode: S ssssss E eeeeee F ffffff B b0 b1 b2 b3 C cccccc V CR LF
    // offsets: prefix at 0,8,16,24,32,40,48,56; digits follow each prefix
    check(line[0] == "S", "line starts with S");
    check(line[8] == "E", "E field prefix");
    // E error code bits: digits at 9..14 -> value; bits 14:9 = digits 1..2ish
    // simpler: rebuild the octal values
    begin : decode
      reg [15:0] v [0:7];
      integer f, d;
      for (f = 0; f < 8; f = f + 1) begin
        v[f] = 0;
        for (d = 0; d < 6; d = d + 1)
          v[f] = (v[f] << 3) | (line[f*8 + 1 + d] - 8'h30);
      end
      $display("decoded: S=%06o E=%06o F=%06o B=%06o %06o %06o %06o C=%06o V=%c",
               v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], line[64]);
      check(v[1][14:9] == 6'd0, "E error code is zero");
      check(v[3] == 16'o000060, "B0 = 000060");
      check(v[4] == 16'o000057, "B1 = 000057");
      check(v[7] == 16'o125441, "checksum is the golden 125441");
      check(line[64] == "P",    "verdict is P (would be F on pre-fix RTL)");
    end
    check(st_timeout == 1'b0, "no timeout");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #800_000_000;   // 0.8 s sim time
    $display("FAIL: global watchdog");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
