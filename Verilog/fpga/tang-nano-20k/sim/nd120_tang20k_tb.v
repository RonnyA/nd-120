/****************************************************************************
** Full-build testbench for ND120_TANG20K_TOP                              **
**                                                                         **
** Simulates the ACTUAL Tang Nano 20K ND-120 configuration - the same      **
** defines as the Gowin project (GOWIN, SKIP_WCS_LOAD, MAIN_RAM_SDRAM,     **
** FPGA_FF_MODE, TANG_SLOW_BRINGUP) - against the behavioral SDRAM model.  **
** Boots the CPU (preloaded WCS), waits for the OPCOM '#' prompt on the    **
** UART, then runs the examine/deposit sequence and checks the echoes.     **
**                                                                         **
** This is the pre-synth validation for the whole Tang build: run it       **
** BEFORE gowin_build.ps1 after any RTL change.                            **
**                                                                         **
** UART runs fast in sim (UART_BAUD_RATE define -> 16 clk_cpu per bit).    **
** Prints "TB_RESULT: PASS" on success.                                    **
**                                                                         **
** Last reviewed: 8-JUL-2026                                               **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd120_tang20k_tb;

  // sys_clk plays the 2x clock (SIM bypass in the top): 13.5 MHz -> 74 ns
  localparam CLK2X_PERIOD = 74;
  // UART bit time: DELAY_FRAMES = BOARD_CLK_FREQ/UART_BAUD_RATE clk_cpu
  // cycles; the Makefile overrides UART_BAUD_RATE so this is 16 clk_cpu
  // = 32 clk2x cycles per bit.
  localparam BITP = 32 * CLK2X_PERIOD;

  reg clk = 0;
  always #(CLK2X_PERIOD / 2.0) clk = ~clk;

  reg s1 = 0;
  reg rxd = 1;
  wire txd;

  wire sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
  wire [31:0] sd_dq;
  wire [10:0] sd_addr;
  wire [1:0] sd_ba;
  wire [3:0] sd_dqm;
  wire [5:0] led;

  ND120_TANG20K_TOP dut (
      .sys_clk(clk),
      .s1(s1),
      .s2(1'b0),
      .uart_rxp(rxd),
      .uart_txp(txd),
      .O_sdram_clk(sd_clk),
      .O_sdram_cke(sd_cke),
      .O_sdram_cs_n(sd_cs_n),
      .O_sdram_cas_n(sd_cas_n),
      .O_sdram_ras_n(sd_ras_n),
      .O_sdram_wen_n(sd_wen_n),
      .IO_sdram_dq(sd_dq),
      .O_sdram_addr(sd_addr),
      .O_sdram_ba(sd_ba),
      .O_sdram_dqm(sd_dqm),
      .led(led)
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

  // ---- UART TX decoder: echo every byte, keep the last few ----
  reg [7:0] ch;
  reg [31:0] last4 = 0;
  reg [127:0] last16 = 0;  // 16-char ring for the readback check
  integer bi;
  integer rx_count = 0;
  initial begin
    forever begin
      @(negedge txd);
      #(BITP * 1.5);
      ch = 0;
      for (bi = 0; bi < 8; bi = bi + 1) begin
        ch[bi] = txd;
        #(BITP);
      end
      rx_count = rx_count + 1;
      if (ch >= 8'h20 && ch < 8'h7F) $write("%c", ch);
      else $write("<%02x>", ch);
      $fflush;
      last4 = {last4[23:0], ch};
      last16 = {last16[119:0], ch};
    end
  end

  task send_char(input [7:0] c);
    integer k;
    begin
      rxd = 0;
      #(BITP);
      for (k = 0; k < 8; k = k + 1) begin
        rxd = c[k];
        #(BITP);
      end
      rxd = 1;
      #(BITP * 4);
    end
  endtask

  // paced send: MOPC polls the console once per RTC tick (~120 ms of sim
  // time at BOARD_CLK_FREQ calibration), so pace one char per 130 ms.
  // NOTE this makes the tb Verilator-only in practice (seconds of sim
  // time); iverilog cannot get there in reasonable wall time.
  localparam CHAR_GAP = 130_000_000;  // ns = 130 ms
  task send_str(input [8*8-1:0] s, input integer len);
    integer i;
    reg [7:0] c;
    begin
      for (i = 0; i < len; i = i + 1) begin
        c = s[8*(len-1-i)+:8];
        send_char(c);
        #(CHAR_GAP);
      end
    end
  endtask

  integer errors = 0;

  task expect_last(input [7:0] c, input [127:0] what);
    if (last4[7:0] !== c) begin
      errors = errors + 1;
      $display("");
      $display("FAIL: %0s (last=%02x expected %02x)", what, last4[7:0], c);
    end
  endtask

  initial begin
    repeat (20) @(posedge clk);

    // Wait for the OPCOM prompt '#' (boot: MCL + self-test on preloaded WCS).
    // Polling loop instead of fork/disable-by-name (Verilator --timing does
    // not support named-fork disable): 30000 x 100 us = 3 s timeout.
    $display("TB: booting (waiting for '#')...");
    begin : waitboot
      integer boot_poll;
      boot_poll = 0;
      while (last4[7:0] != "#" && boot_poll < 30000) begin
        #100_000;
        boot_poll = boot_poll + 1;
      end
      if (last4[7:0] != "#") begin
        $display("");
        $display("TB_RESULT: TIMEOUT waiting for OPCOM prompt");
        $finish;
      end
    end
    $display("");
    $display("TB: OPCOM prompt seen (%0d chars so far)", rx_count);
    #(BITP * 100);

    // CR -> new '#' prompt
    send_char(8'h0D);
    #(CHAR_GAP * 2);
    expect_last("#", "CR re-echoes the prompt");

    // deposit 054321 at 22, read back
    send_str("22/", 3);
    #(CHAR_GAP * 2);
    send_str({"054321", 8'h0D}, 7);
    #(CHAR_GAP * 2);
    send_str("22/", 3);
    #(CHAR_GAP * 3);
    $display("");
    $display("TB: done (%0d chars total)", rx_count);

    // HARD readback check: the tail of the received stream must contain
    // "22/054321" - the echo of the final examine followed by the value
    // OPCOM printed for address 22. On the board-failure signature this
    // reads "22/000000" instead.
    begin : rbcheck
      integer j;
      reg found;
      found = 0;
      for (j = 0; j <= 7; j = j + 1)
        if (last16[8*j+:72] == "22/054321") found = 1;
      if (!found) begin
        errors = errors + 1;
        $display("FAIL: readback of 054321 not seen (tail=%s)", last16);
      end
    end

    if (errors == 0) $display("TB_RESULT: PASS (deposit 22/054321 readback verified)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  // global watchdog
  initial begin
    #4_000_000_000;  // 4 s sim time
    $display("");
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
