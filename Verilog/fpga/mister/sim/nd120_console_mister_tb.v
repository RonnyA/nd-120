//============================================================================
//! Self-checking testbench for nd120_console_mister.v - the MiSTer glue
//!
//! Full path: Verilog/fpga/mister/sim/nd120_console_mister_tb.v
//!
//! WHY THIS EXISTS. The terminal core itself is already tested to death in
//! Verilog/Terminals/sim/. What is NOT tested by any of that is the handful of
//! lines that are specific to THIS board, and those lines are new:
//!
//!   * the toggle -> strobe edge detector on ps2_key[10]. hps_io toggles that
//!     bit per event instead of pulsing it. Get it wrong and you get either no
//!     characters at all or one per clock.
//!   * the polarity flip. hps_io reports `pressed`; ps2_decoder wants
//!     `release`. Invert it the wrong way round and the terminal types on key
//!     UP - which still looks like it works, until you hold a key.
//!   * the source priority between the banner, the machine and the local echo,
//!     including the one-clock window where the banner's `valid` has fallen
//!     but its `done` has not yet risen.
//!
//! Every one of those fails in a way that looks plausible on a screen, which
//! is exactly the kind of bug that survives a "does it show anything" check on
//! real hardware. This is the reason to test glue and not just cores.
//!
//! The screen is inspected by reading the character RAM directly through the
//! hierarchy - that is the terminal's actual state, not a re-derivation of it.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 28-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module nd120_console_mister_tb;

  localparam integer COLS = 80;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg [10:0] ps2_key = 11'd0;

  wire       cpu_ready;
  wire       kbd_valid;
  wire [7:0] kbd_data;
  wire       pixel, hsync, vsync, de, bell;

  integer errors = 0;
  integer i;

  reg [7:0] got;

  always #12.5 clk = ~clk;   // 40 MHz

  nd120_console_mister #(
      .FONT_FILE ("../../../Terminals/font/font8x16.hex"),
      .LOCAL_ECHO(1)
  ) DUT (
      .clk  (clk),
      .rst_n(rst_n),

      .ps2_key(ps2_key),

      .cpu_byte_valid(1'b0),
      .cpu_byte_data (8'h00),
      .cpu_byte_ready(cpu_ready),

      .kbd_valid(kbd_valid),
      .kbd_data (kbd_data),

      .pixel(pixel),
      .hsync(hsync),
      .vsync(vsync),
      .de   (de),
      .bell (bell)
  );

  //--------------------------------------------------------------------------
  // Drive one key event the way hps_io does: flip bit 10, present the
  // scancode, say whether it is a press or a release.
  //--------------------------------------------------------------------------

  task send_key;
    input [7:0] code;
    input       pressed;
    input       extended;
    begin
      @(negedge clk);
      ps2_key = {~ps2_key[10], pressed, extended, code};
      // A real keyboard event lasts far longer than this; a few clocks is
      // plenty for a one-shot strobe, and using more would hide a detector
      // that (wrongly) fires continuously.
      repeat (4) @(negedge clk);
    end
  endtask

  //! What is on the screen at row 0, column c.
  function [7:0] screen_char;
    input integer c;
    begin
      screen_char = DUT.TERMINAL.CHARRAM.s_cells[c][7:0];
    end
  endfunction

  //--------------------------------------------------------------------------

  initial begin
    $dumpfile("nd120_console_mister_tb.vcd");
    $dumpvars(1, nd120_console_mister_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    //------------------------------------------------------------------
    // 1. The machine seam must be shut while the banner owns the screen.
    //------------------------------------------------------------------
    @(negedge clk);
    if (cpu_ready !== 1'b0) begin
      $display("FAIL: cpu_byte_ready is high during the banner - a machine byte could");
      $display("      be printed into the middle of the self-test message");
      errors = errors + 1;
    end else begin
      $display("-- machine seam held closed while the banner runs");
    end

    //------------------------------------------------------------------
    // 2. A keystroke DURING the banner must not corrupt it. Type into the
    //    banner and check the message is still intact afterwards.
    //------------------------------------------------------------------
    send_key(8'h1C, 1'b1, 1'b0);   // 'A' pressed
    send_key(8'h1C, 1'b0, 1'b0);   // 'A' released

    // Let the banner finish. 318 characters, a few clocks each.
    i = 0;
    while (!DUT.FEED.BANNER.done && i < 200000) begin
      @(posedge clk);
      i = i + 1;
    end
    if (!DUT.FEED.BANNER.done) begin
      $display("FAIL: the banner never finished");
      errors = errors + 1;
    end

    if (screen_char(0) !== "N" || screen_char(1) !== "D" ||
        screen_char(2) !== "-" || screen_char(3) !== "1") begin
      $display("FAIL: row 0 starts %c%c%c%c, expected ND-1 - the banner is corrupted",
               screen_char(0), screen_char(1), screen_char(2), screen_char(3));
      errors = errors + 1;
    end else begin
      $display("-- banner intact on screen, and typing during it did not corrupt it");
    end

    //------------------------------------------------------------------
    // 3. The seam opens once the banner is done.
    //
    // Not on the same clock as `done`, and requiring that was wrong: the
    // banner's LAST byte is still crossing the CDC when done rises, so
    // cpu_byte_ready is legitimately low for a few clocks afterwards. The
    // requirement is that it opens promptly, not instantly.
    //------------------------------------------------------------------
    i = 0;
    while (!cpu_ready && i < 100) begin
      @(posedge clk);
      i = i + 1;
    end
    if (!cpu_ready) begin
      $display("FAIL: cpu_byte_ready still low 100 clocks after the banner finished");
      errors = errors + 1;
    end else begin
      $display("-- machine seam open %0d clocks after the banner finished", i);
    end

    //------------------------------------------------------------------
    // 4. A PRESS produces exactly one character, on the press.
    //------------------------------------------------------------------
    got = 8'h00;
    fork
      begin : catch_press
        @(posedge clk);
        while (!kbd_valid) @(posedge clk);
        got = kbd_data;
      end
      begin
        send_key(8'h15, 1'b1, 1'b0);   // 'Q' pressed
        repeat (20) @(posedge clk);
        disable catch_press;
      end
    join

    if (got !== "q") begin
      $display("FAIL: pressing scancode 0x15 gave 0x%02X to the machine, expected 'q'", got);
      $display("      (a zero here usually means the pressed/release polarity is inverted)");
      errors = errors + 1;
    end else begin
      $display("-- a key PRESS produces its character");
    end

    //------------------------------------------------------------------
    // 5. A RELEASE produces nothing. This is the check that catches an
    //    inverted polarity, which check 4 alone cannot: if the sense were
    //    flipped, 4 would simply fire on the release instead and still see
    //    an 's' eventually.
    //------------------------------------------------------------------
    got = 8'hFF;
    fork
      begin : catch_release
        @(posedge clk);
        while (!kbd_valid) @(posedge clk);
        got = kbd_data;
      end
      begin
        send_key(8'h15, 1'b0, 1'b0);   // 'Q' released
        repeat (40) @(posedge clk);
        disable catch_release;
      end
    join

    if (got !== 8'hFF) begin
      $display("FAIL: a key RELEASE produced 0x%02X - releases must be silent", got);
      errors = errors + 1;
    end else begin
      $display("-- a key RELEASE produces nothing");
    end

    //------------------------------------------------------------------
    // 6. Local echo actually reached the screen.
    //
    //    The key under test is 'q' SPECIFICALLY BECAUSE THE BANNER CONTAINS
    //    NO 'q'. The first version of this check typed 's' and then searched
    //    the screen for one - and found it immediately, in the word "this" of
    //    the banner, while the echo path could have been completely dead. A
    //    search for something the screen already contains proves nothing at
    //    all, and it reports PASS while doing it.
    //
    //    Position is searched for rather than assumed, for the same reason:
    //    an assumed position is a test that passes for the wrong reason.
    //------------------------------------------------------------------
    repeat (200) @(posedge clk);
    begin : find_s
      integer r, c;
      reg found;
      found = 1'b0;
      for (r = 0; r < 25 && !found; r = r + 1)
        for (c = 0; c < COLS && !found; c = c + 1)
          if (DUT.TERMINAL.CHARRAM.s_cells[r*COLS + c][7:0] === "q") begin
            found = 1'b1;
            $display("-- local echo: 'q' found on screen at row %0d col %0d (banner has no q)", r, c);
          end
      if (!found) begin
        $display("FAIL: the typed 'q' never reached the screen - local echo is broken");
        errors = errors + 1;
      end
    end

    if (errors == 0) $display("TB_RESULT: PASS (MiSTer console glue)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #50_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
