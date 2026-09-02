/*****************************************************************************
**  console_burst_tb.v                                                      **
**                                                                          **
**  Full path: Verilog/fpga/mister/sim/console_burst_tb.v                   **
**                                                                          **
**  WHY (02-SEP-2026). SINTRAN III booted on the MiSTer for the first time, **
**  and the first dozen lines of its boot text arrived on the screen with   **
**  about every other character missing ("SNAN-VS500M" for "SINTRAN III -   **
**  VSX/500 M"), while everything printed later was clean. The Nexys, which **
**  runs the SAME terminal core, shows those lines clean - but its terminal **
**  runs at a 139.7 MHz pixel clock in 1080p mode, the MiSTer's at 40 MHz.  **
**                                                                          **
**  This bench sends the real banner lines as a back-to-back 115200-baud    **
**  8N1 stream (the fastest thing the CPU's UART can produce) through the   **
**  MiSTer's own receiver instance and console glue, exactly as nd120.sv    **
**  wires them, with the panel line enabled as on the board, and then reads **
**  the character RAM row by row. Every character that was sent must be on   **
**  the screen. -DFAST_PIX runs the identical stream at the Nexys's clock.  **
**                                                                          **
**  Verdict: TB_RESULT: PASS / TB_RESULT: FAIL (N characters lost)          **
*****************************************************************************/

`timescale 1ns / 1ps

module console_burst_tb;

  localparam integer COLS = 80;
`ifdef FAST_PIX
  localparam real    HALF_NS  = 3.579;        // 139.7 MHz, the Nexys 1080p pixel clock
  localparam integer CLK_HZ   = 139_705_882;
`else
  localparam real    HALF_NS  = 12.5;         // 40 MHz, the MiSTer clk_sys
  localparam integer CLK_HZ   = 40_000_000;
`endif
  localparam real    BIT_NS   = 8680.556;     // 115200 baud

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  always #(HALF_NS) clk = ~clk;

  reg txd = 1'b1;                              // the CPU's serial line, idle high

  wire       cpu_byte_valid;
  wire [7:0] cpu_byte_data;
  wire       cpu_ready, kbd_valid;
  wire [7:0] kbd_data;
  wire       pixel, hsync, vsync, de, bell;

  // the MiSTer's receiver, as instantiated in nd120.sv: 7 data bits + parity.
  // SINTRAN's boot text carries SOFTWARE parity in bit 7 (measured on the
  // board's /dev/ttyS1, 02-SEP-2026: CR = 8D, space = A0); an 8N1 receiver
  // hands those bytes to a terminal that drops everything >= 7F.
  console_uart_rx #(
      .CLK_HZ   (CLK_HZ),
      .BAUD     (115_200),
      .DATA_BITS(7),
      .PARITY   (1'b1)
  ) RX (
      .clk        (clk),
      .rst_n      (rst_n),
      .divisor_ovr(16'd0),
      .rxd        (txd),
      .byte_valid (cpu_byte_valid),
      .byte_data  (cpu_byte_data)
  );

  nd120_console_mister #(
      .FONT_FILE ("../../../Terminals/font/font8x16.hex"),
      .LOCAL_ECHO(0)
  ) DUT (
      .clk  (clk),
      .rst_n(rst_n),
      .ps2_key(11'd0),
      .cpu_byte_valid(cpu_byte_valid),
      .cpu_byte_data (cpu_byte_data),
      .cpu_byte_ready(cpu_ready),
      // panel ON, as on the board: it shares the character RAM
      .panel_enable      (1'b1),
      .panel_pil         (4'd0),
      .panel_actlv       (16'd0),
      .panel_mips        (16'd106),
      .panel_cpu_red     (1'b0),
      .panel_cpu_green   (1'b1),
      .panel_lev0        (1'b0),
      .panel_hit         (1'b0),
      .panel_ring        (2'd2),
      .panel_paging_on   (1'b1),
      .panel_interrupt_on(1'b1),
      .panel_running     (1'b1),
      .panel_hdd_rd      (1'b0),
      .panel_hdd_wr      (1'b0),
      .panel_flp_rd      (1'b0),
      .panel_flp_wr      (1'b0),
      .kbd_valid(kbd_valid),
      .kbd_data (kbd_data),
      .pixel(pixel), .hsync(hsync), .vsync(vsync), .de(de), .bell(bell)
  );

  // ---- 8N1 bit-bang, no inter-byte gap ---------------------------------------
  integer rx_count = 0;
  always @(posedge clk) if (cpu_byte_valid) rx_count = rx_count + 1;

  // SINTRAN's boot printer sets bit 7 to EVEN parity over the 7-bit character
  // (measured: 0D -> 8D, 20 -> A0, 34 -> B4, 31 -> B1; 30, 39, 2E, 35 unchanged).
  // The later, interrupt-driven output sends plain 7-bit bytes; both must show.
  function [7:0] par(input [7:0] b);
    par = {^b[6:0], b[6:0]};
  endfunction

  task send_byte(input [7:0] b);
    integer k;
    begin
      txd = 1'b0;  #(BIT_NS);
      for (k = 0; k < 8; k = k + 1) begin txd = b[k]; #(BIT_NS); end
      txd = 1'b1;  #(BIT_NS);
    end
  endtask

  // the boot text, as the Nexys serial transcript records it
  localparam integer NLINES = 5;
  reg [8*80-1:0] line[0:NLINES-1];
  integer sent = 0;

  task send_line(input integer n);
    integer k, len;
    reg [7:0] c;
    begin
      len = 0;
      for (k = 0; k < 80; k = k + 1) if (line[n][8*(79-k) +: 8] != 8'h00) len = k + 1;
      for (k = 0; k < len; k = k + 1) begin
        c = line[n][8*(79-k) +: 8];
        send_byte(par(c)); sent = sent + 1;
      end
      send_byte(par(8'h0D)); send_byte(par(8'h0A)); sent = sent + 2;
    end
  endtask

  function [7:0] scr(input integer r, input integer c);
    scr = DUT.TERMINAL.CHARRAM.s_cells[r*COLS + c][7:0];
  endfunction

  integer r, c, len, lost, errors, first_row;
  reg [7:0] want, got;
  reg [8*80-1:0] shown;

  initial begin
    line[0] = " 09.45.15     16 SEPTEMBER   1994";
    line[1] = " SINTRAN III - VSX/500 M";
    line[2] = "--- MISTER FPGA ---";
    line[3] = " CPU TYPE:      102      CPU NUMBER:    120";
    line[4] = "SINTRAN III RUNNING -";
    // a string literal lands RIGHT-justified in a wide reg; shift each line
    // left so character k sits at byte k (the indexing below assumes that)
    for (r = 0; r < NLINES; r = r + 1) begin
      len = 0;
      for (c = 0; c < 80; c = c + 1) if (line[r][8*c +: 8] != 8'h00) len = len + 1;
      line[r] = line[r] << (8 * (80 - len));
    end

    repeat (20) @(posedge clk);
    rst_n = 1'b1;
    // let the power-on banner finish (it owns the screen first)
    #(2_000_000);

    // which row the machine text starts on: the first row after the banner
    first_row = 0;
    for (r = 0; r < 24; r = r + 1) if (scr(r, 0) != 8'h20 || scr(r, 1) != 8'h20) first_row = r + 1;
    $display("banner occupies rows 0..%0d, machine text expected from row %0d", first_row - 1, first_row);

    for (r = 0; r < NLINES; r = r + 1) send_line(r);
    // drain: give the terminal time to finish whatever it is doing
    #(3_000_000);

    $display("sent %0d bytes, receiver delivered %0d", sent, rx_count);
    errors = 0; lost = 0;
    for (r = 0; r < NLINES; r = r + 1) begin
      len = 0;
      for (c = 0; c < 80; c = c + 1) if (line[r][8*(79-c) +: 8] != 8'h00) len = c + 1;
      for (c = 0; c < 80; c = c + 1) shown[8*(79-c) +: 8] = scr(first_row + r, c);
      for (c = 0; c < len; c = c + 1) begin
        want = line[r][8*(79-c) +: 8];
        got  = scr(first_row + r, c);
        if (want != got) begin errors = errors + 1; if (got == 8'h20) lost = lost + 1; end
      end
      $display("row %0d: %0s", first_row + r, shown);
    end
    if (rx_count != sent) $display("  receiver lost %0d of %0d bytes before the terminal", sent - rx_count, sent);
    if (errors == 0) $display("TB_RESULT: PASS (%0d bytes at %0d Hz)", sent, CLK_HZ);
    else             $display("TB_RESULT: FAIL (%0d characters wrong, %0d of them missing, at %0d Hz)", errors, lost, CLK_HZ);
    $finish;
  end

  initial begin
    #200_000_000;
    $display("TB_RESULT: FAIL (watchdog)");
    $finish;
  end

endmodule
