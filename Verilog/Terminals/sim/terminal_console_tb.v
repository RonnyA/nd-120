//============================================================================
//! End-to-end testbench for the whole console loop
//!
//! This is the console the Nexys build wires up (ND120_CONSOLE_VGA), with the
//! board pins removed. Everything between the machine's serial line and the
//! character RAM, and between a keyboard and the machine's serial line:
//!
//!   MACHINE_TX --serial--> console_uart_rx --> terminal_top --> char RAM
//!   ps2 model --> ps2_keyboard --> console_uart_tx --serial--> MACHINE_RX
//!
//! The two "machine" ends are themselves console_uart_tx/rx instances, which
//! is fair: those two are proven against each other in console_uart_tb.v, so
//! here they are a known-good stand-in for the SC2661 at the other end.
//!
//! WHY THIS EXISTS. Every piece already has its own passing testbench, and
//! that proves nothing about them being wired together the right way round -
//! which is exactly the class of mistake that costs a bitstream build and a
//! trip to the hardware. A byte has to survive: serialization, framing,
//! deserialization, a clock-domain crossing, the control state machine, and
//! the address arithmetic into the character RAM. This checks it does.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 27-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module terminal_console_tb;

  localparam integer CLK_HZ    = 40_000_000;
  localparam integer BAUD      = 115200;
  localparam integer DATA_BITS = 7;
  localparam         PARITY    = 1'b1;

  localparam integer COLS = 80;
  //! 80x25 - TDV2200 geometry, confirmed by retroterm-09 from RetroTerm's
  //! EmulatorFactory. NOT 80x24; that is a whole row of difference.
  localparam integer ROWS = 25;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz - the pixel clock on the Nexys

  //--------------------------------------------------------------------------
  // The machine's console transmitter -> our receiver -> the terminal
  //--------------------------------------------------------------------------

  reg        mach_valid = 1'b0;
  reg  [7:0] mach_data = 8'h00;
  wire       mach_ready;
  wire       mach_line;   //! what the machine drives, i.e. cpu_txd

  console_uart_tx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(DATA_BITS), .PARITY(PARITY)
  ) MACHINE_TX (
      .clk(clk), .rst_n(rst_n),
      .divisor_ovr(16'd0),   // use the CLK_HZ/BAUD parameters
      .byte_valid(mach_valid), .byte_data(mach_data), .ready(mach_ready),
      .txd(mach_line)
  );

  wire       con_valid;
  wire [7:0] con_data;

  console_uart_rx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(DATA_BITS), .PARITY(PARITY)
  ) CONSOLE_RX (
      .clk(clk), .rst_n(rst_n),
      .divisor_ovr(16'd0),   // use the CLK_HZ/BAUD parameters
      .rxd(mach_line),
      .byte_valid(con_valid), .byte_data(con_data)
  );

  wire pixel, hsync, vsync, de, bell;

  terminal_top #(
      .FONT_FILE("../font/font8x16.hex")
  ) TERMINAL (
      .byte_clk(clk), .byte_rst_n(rst_n),
      .byte_valid(con_valid), .byte_data(con_data), .byte_ready(),

      // US font page, mode 0 (800x600, 1x glyphs). Both must be driven: an
      // unconnected `mode` is X, and X into the sync comparators means no
      // hsync and no vsync at all - which is exactly how this testbench failed
      // when the ports were added and this instance was not updated.
      .national(1'b0),
      .mode(1'b0),

      // Panel off: this testbench is about the console text path. The panel
      // has its own checks.
      .panel_enable(1'b0),
      .panel_pil(4'd0),
      .panel_lev0(1'b0),
      .panel_hit(1'b0),
      .panel_ring(2'd0),
      .panel_paging_on(1'b0),
      .panel_interrupt_on(1'b0),
      .panel_running(1'b0),
      .panel_hdd_rd(1'b0), .panel_hdd_wr(1'b0),
      .panel_flp_rd(1'b0), .panel_flp_wr(1'b0),
      .colour(),

      .pix_clk(clk), .pix_rst_n(rst_n),
      .pixel(pixel), .hsync(hsync), .vsync(vsync), .de(de),
      .bell(bell), .leds()
  );

  //--------------------------------------------------------------------------
  // A keyboard -> the machine's console receiver
  //--------------------------------------------------------------------------

  reg ps2_clk_r = 1'b1;
  reg ps2_dat_r = 1'b1;

  wire       key_valid;
  wire [7:0] key_data;

  ps2_keyboard KEYBOARD (
      .clk(clk), .rst_n(rst_n),
      .ps2_clk_in(ps2_clk_r), .ps2_data_in(ps2_dat_r),
      .ascii_valid(key_valid), .ascii_data(key_data),
      .code_valid(), .code_data(), .code_release(), .code_extended()
  );

  wire kbd_line;

  console_uart_tx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(DATA_BITS), .PARITY(PARITY)
  ) CONSOLE_TX (
      .clk(clk), .rst_n(rst_n),
      .divisor_ovr(16'd0),   // use the CLK_HZ/BAUD parameters
      .byte_valid(key_valid), .byte_data(key_data), .ready(),
      .txd(kbd_line)
  );

  //! The merge the board does: the PC's line (idle high here) ANDed with the
  //! keyboard's. If the AND were wrong, nothing would arrive.
  wire pc_line = 1'b1;
  wire machine_rxd = pc_line & kbd_line;

  wire       mrx_valid;
  wire [7:0] mrx_data;

  console_uart_rx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(DATA_BITS), .PARITY(PARITY)
  ) MACHINE_RX (
      .clk(clk), .rst_n(rst_n),
      .divisor_ovr(16'd0),   // use the CLK_HZ/BAUD parameters
      .rxd(machine_rxd),
      .byte_valid(mrx_valid), .byte_data(mrx_data)
  );

  reg [7:0] got_at_machine = 8'h00;
  integer   n_at_machine = 0;

  always @(posedge clk) if (mrx_valid) begin
    got_at_machine = mrx_data;
    n_at_machine   = n_at_machine + 1;
  end

  //--------------------------------------------------------------------------
  // Helpers
  //--------------------------------------------------------------------------

  task check;
    input condition;
    input [1023:0] what;
    begin
      if (!condition) begin
        $display("FAIL: %0s (time %0t)", what, $time);
        errors = errors + 1;
      end
    end
  endtask

  //! Send one byte from the "machine" and wait for the line to go idle again.
  task machine_send;
    input [7:0] value;
    begin
      while (!mach_ready) @(posedge clk);
      @(posedge clk);
      mach_data  = value;
      mach_valid = 1'b1;
      @(posedge clk);
      mach_valid = 1'b0;
      @(posedge clk);
      while (!mach_ready) @(posedge clk);
      repeat (20) @(posedge clk);   // let the terminal finish writing
    end
  endtask

  //! Check the character stored at a screen position. The screen scrolls by
  //! moving top_row, so a screen row has to be mapped to a stored row exactly
  //! the way the hardware does it - doing that here is part of the test.
  task expect_screen;
    input [7:0] srow;
    input [7:0] scol;
    input [7:0] expected;
    reg [7:0] stored;
    reg [15:0] cellv;
    reg [8:0] sum;
    begin
      sum    = {1'b0, TERMINAL.CTRL.top_row} + {1'b0, srow};
      stored = (sum >= ROWS) ? (sum[7:0] - ROWS[7:0]) : sum[7:0];
      cellv  = TERMINAL.CHARRAM.s_cells[stored * COLS + scol];
      if (cellv[7:0] !== expected) begin
        $display("FAIL: screen(row=%0d,col=%0d) = 0x%02x '%0s', expected 0x%02x '%0s' (time %0t)",
                 srow, scol, cellv[7:0], cellv[7:0], expected, expected, $time);
        errors = errors + 1;
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // A modelled PS/2 keyboard, 15 kHz
  //--------------------------------------------------------------------------

  localparam integer HALF_BIT = 33_333;  // ns

  task ps2_bit;
    input value;
    begin
      ps2_dat_r = value;
      #HALF_BIT;
      ps2_clk_r = 1'b0;
      #HALF_BIT;
      ps2_clk_r = 1'b1;
    end
  endtask

  task ps2_send;
    input [7:0] value;
    integer b;
    begin
      ps2_bit(1'b0);
      for (b = 0; b < 8; b = b + 1) ps2_bit(value[b]);
      ps2_bit(~(^value));
      ps2_bit(1'b1);
      #HALF_BIT;
    end
  endtask

  //--------------------------------------------------------------------------

  integer n_start;

  initial begin
    $dumpfile("terminal_console_tb.vcd");
    $dumpvars(0, terminal_console_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;

    // Let the terminal's power-up screen clear finish (1920 writes).
    repeat (2200) @(posedge clk);

    //------------------------------------------------------------------
    // 1. Machine -> screen. A byte has to survive serialization, framing,
    //    deserialization, the CDC, the state machine and the addressing.
    //------------------------------------------------------------------
    machine_send("N");
    machine_send("D");
    machine_send("-");
    machine_send("1");
    machine_send("2");
    machine_send("0");

    expect_screen(8'd0, 8'd0, "N");
    expect_screen(8'd0, 8'd1, "D");
    expect_screen(8'd0, 8'd2, "-");
    expect_screen(8'd0, 8'd3, "1");
    expect_screen(8'd0, 8'd4, "2");
    expect_screen(8'd0, 8'd5, "0");

    //------------------------------------------------------------------
    // 2. CR/LF through the whole chain, then text on the second line.
    //------------------------------------------------------------------
    machine_send(8'h0D);
    machine_send(8'h0A);
    machine_send("O");
    machine_send("K");
    expect_screen(8'd1, 8'd0, "O");
    expect_screen(8'd1, 8'd1, "K");

    //------------------------------------------------------------------
    // 3. Keyboard -> machine. A key press has to come out of the machine's
    //    own receiver as the right character, THROUGH the AND merge.
    //------------------------------------------------------------------
    n_start = n_at_machine;
    ps2_send(8'h1C);              // 'a' press
    ps2_send(8'hF0); ps2_send(8'h1C);  // and its release

    // Wait for the serial character to finish arriving.
    begin : wait_key
      integer guard;
      guard = 0;
      while (n_at_machine == n_start && guard < 500_000) begin
        @(posedge clk);
        guard = guard + 1;
      end
    end

    if (n_at_machine == n_start) begin
      $display("FAIL: a key press never reached the machine (time %0t)", $time);
      errors = errors + 1;
    end else begin
      check(got_at_machine == "a", "key press arrived as the wrong character");
      check(n_at_machine == n_start + 1, "a key press produced more than one character");
    end

    //------------------------------------------------------------------
    // 4. Shifted key, the whole way round.
    //------------------------------------------------------------------
    n_start = n_at_machine;
    ps2_send(8'h12);              // left shift
    ps2_send(8'h1C);              // 'A'
    ps2_send(8'hF0); ps2_send(8'h1C);
    ps2_send(8'hF0); ps2_send(8'h12);

    begin : wait_key2
      integer guard;
      guard = 0;
      while (n_at_machine == n_start && guard < 500_000) begin
        @(posedge clk);
        guard = guard + 1;
      end
    end
    check(got_at_machine == "A", "a shifted key did not arrive as upper case");

    //------------------------------------------------------------------
    // 5. Video is alive: sync must be toggling. A terminal that renders
    //    nothing is indistinguishable from a dead one at the pin.
    //------------------------------------------------------------------
    begin : check_video
      integer guard;
      reg seen_hs, seen_vs;
      seen_hs = 1'b0;
      seen_vs = 1'b0;
      guard   = 0;
      // One 800x600 frame is 663168 pixel clocks; give it a bit over one.
      while (guard < 700_000 && !(seen_hs && seen_vs)) begin
        @(posedge clk);
        if (hsync) seen_hs = 1'b1;
        if (vsync) seen_vs = 1'b1;
        guard = guard + 1;
      end
      check(seen_hs, "hsync never asserted - no video");
      check(seen_vs, "vsync never asserted - no video");
    end

    if (errors == 0) $display("TB_RESULT: PASS (console loop end to end)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #200_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
