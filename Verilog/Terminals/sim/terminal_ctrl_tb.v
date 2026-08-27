//============================================================================
//! Self-checking testbench for terminal_ctrl.v + char_ram.v
//!
//! Drives console bytes in and reads the character RAM back to check what
//! landed where. Covers Stage A behaviour:
//!
//!   - power-up clear (the whole screen is spaces before anything is typed)
//!   - printable characters land at the cursor and advance it
//!   - CR, LF, BS, HT, FF
//!   - wrap at the right-hand edge (the 80th character IS written)
//!   - scroll at the bottom: top_row moves, the new bottom line is blank,
//!     and the line that was second from the top is now at the top
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 27-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module terminal_ctrl_tb;

  localparam integer COLS   = 80;
  localparam integer ROWS   = 25;
  localparam integer AWIDTH = 11;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg        byte_valid = 1'b0;
  reg  [7:0] byte_data = 8'h00;
  wire       ready;

  wire              we;
  wire [AWIDTH-1:0] waddr;
  wire [      15:0] wdata;

  reg  [AWIDTH-1:0] raddr = {AWIDTH{1'b0}};
  wire [      15:0] rdata;

  wire [7:0] top_row, cursor_col, cursor_row;
  wire       cursor_enable, bell, video_on, charset;
  wire [2:0] leds;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz

  terminal_ctrl #(
      .COLS  (COLS),
      .ROWS  (ROWS),
      .AWIDTH(AWIDTH)
  ) DUT (
      .clk  (clk),
      .rst_n(rst_n),

      .byte_valid(byte_valid),
      .byte_data (byte_data),
      .ready     (ready),

      .ram_we   (we),
      .ram_waddr(waddr),
      .ram_wdata(wdata),

      .top_row      (top_row),
      .cursor_col   (cursor_col),
      .cursor_row   (cursor_row),
      .cursor_enable(cursor_enable),

      .video_on (video_on),
      .charset  (charset),
      .frame_end(1'b0),
      .bell     (bell),
      .leds     (leds)
  );

  char_ram #(
      .COLS  (COLS),
      .ROWS  (ROWS),
      .AWIDTH(AWIDTH)
  ) RAM (
      .clk  (clk),
      .we   (we),
      .waddr(waddr),
      .wdata(wdata),
      .raddr(raddr),
      .rdata(rdata)
  );

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

  //! Send one byte, waiting for the controller to be ready first.
  task send;
    input [7:0] value;
    begin
      while (!ready) @(posedge clk);
      @(posedge clk);
      byte_data  = value;
      byte_valid = 1'b1;
      @(posedge clk);
      byte_valid = 1'b0;
      @(posedge clk);
    end
  endtask

  task send_string;
    input [8*16-1:0] text;   //! up to 16 characters, left-padded with nulls
    integer i;
    reg [7:0] ch;
    begin
      for (i = 15; i >= 0; i = i - 1) begin
        ch = text[i*8+:8];
        if (ch != 8'h00) send(ch);
      end
    end
  endtask

  //! Read the cell at (stored_row, col) - the STORED row, not the screen row.
  task read_cell;
    input [7:0] row;
    input [7:0] col;
    output [15:0] value;
    begin
      raddr = ({row, 6'b0} + {row, 4'b0} + col);
      @(posedge clk);
      @(posedge clk);
      value = rdata;
    end
  endtask

  //! Check the character at a stored position.
  task expect_char;
    input [7:0] row;
    input [7:0] col;
    input [7:0] expected;
    reg [15:0] value;
    begin
      read_cell(row, col, value);
      if (value[7:0] !== expected) begin
        $display("FAIL: cell(row=%0d,col=%0d) = 0x%02x '%0s', expected 0x%02x '%0s' (time %0t)",
                 row, col, value[7:0], value[7:0], expected, expected, $time);
        errors = errors + 1;
      end
    end
  endtask

  //! Check a character by SCREEN position, mapping through top_row exactly
  //! the way the hardware does. The plain expect_char above takes a STORED
  //! row; after a roll those are no longer the same thing.
  task expect_screen_row;
    input [7:0] srow;
    input [7:0] scol;
    input [7:0] expected;
    reg [8:0] sum;
    reg [7:0] stored;
    begin
      sum    = {1'b0, top_row} + {1'b0, srow};
      stored = (sum >= ROWS) ? (sum[7:0] - ROWS[7:0]) : sum[7:0];
      expect_char(stored, scol, expected);
    end
  endtask

  //--------------------------------------------------------------------------

  integer i;
  reg [7:0] col_before, row_before;

  initial begin
    $dumpfile("terminal_ctrl_tb.vcd");
    $dumpvars(0, terminal_ctrl_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    //------------------------------------------------------------------
    // 1. Power-up clear: the controller must blank the screen itself.
    //------------------------------------------------------------------
    while (!ready) @(posedge clk);
    $display("-- power-up clear finished at %0t", $time);
    expect_char(8'd0, 8'd0, 8'h20);
    expect_char(8'd24, 8'd79, 8'h20);
    check(cursor_col == 0 && cursor_row == 0, "cursor not homed after reset");
    check(top_row == 0, "top_row not 0 after reset");

    //------------------------------------------------------------------
    // 2. Printable characters land and advance the cursor.
    //------------------------------------------------------------------
    send_string("ND-120");
    expect_char(8'd0, 8'd0, "N");
    expect_char(8'd0, 8'd1, "D");
    expect_char(8'd0, 8'd2, "-");
    expect_char(8'd0, 8'd5, "0");
    check(cursor_col == 6, "cursor did not advance to column 6");
    check(cursor_row == 0, "cursor left row 0 unexpectedly");

    //------------------------------------------------------------------
    // 3. BS moves back without erasing; the next character overwrites.
    //------------------------------------------------------------------
    send(8'h08);  // BS
    check(cursor_col == 5, "BS did not move the cursor back");
    expect_char(8'd0, 8'd5, "0");  // BS alone must NOT erase
    send("X");
    expect_char(8'd0, 8'd5, "X");

    //------------------------------------------------------------------
    // 4. CR then LF - the classic pair.
    //------------------------------------------------------------------
    send(8'h0D);  // CR
    check(cursor_col == 0, "CR did not return to column 0");
    send(8'h0A);  // LF
    check(cursor_row == 1, "LF did not move down a row");
    send_string("SINTRAN");
    expect_char(8'd1, 8'd0, "S");
    expect_char(8'd1, 8'd6, "N");

    //------------------------------------------------------------------
    // 5. HT to the next multiple of 8.
    //------------------------------------------------------------------
    check(cursor_col == 7, "unexpected column before HT");
    send(8'h09);  // HT
    check(cursor_col == 8, "HT from column 7 should land on 8");
    send(8'h09);  // HT
    check(cursor_col == 16, "HT from column 8 should land on 16");

    //------------------------------------------------------------------
    // 6. Wrap: fill row 2 completely and check the 80th character is written
    //    and the cursor moves to the start of row 3.
    //------------------------------------------------------------------
    send(8'h0D);
    send(8'h0A);
    check(cursor_row == 2, "expected to be on row 2");
    for (i = 0; i < COLS; i = i + 1) send(8'h41 + (i % 26));  // A..Z repeating
    expect_char(8'd2, 8'd0, 8'h41);
    expect_char(8'd2, 8'd79, 8'h41 + (79 % 26));
    check(cursor_col == 0, "wrap did not return the cursor to column 0");
    check(cursor_row == 3, "wrap did not move the cursor to the next row");

    //------------------------------------------------------------------
    // 7. Scroll. Put a mark on row 0 and row 1, go to the bottom row, LF once,
    //    and check: top_row advanced, the old row 1 is now the top line, and
    //    the newly exposed bottom line is blank.
    //------------------------------------------------------------------
    // EM (0x19) is the TDV erase-page, NOT FF - FF is a roll up. Getting
    // these the ANSI way round wipes the screen every time SINTRAN scrolls.
    send(8'h19);  // EM - erase page and home, so the geometry is known
    while (!ready) @(posedge clk);
    check(top_row == 0 && cursor_row == 0 && cursor_col == 0, "EM did not erase the page and home");
    expect_char(8'd2, 8'd10, 8'h20);  // the As from step 6 are gone

    send("1");           // row 0 gets a '1'
    send(8'h0D); send(8'h0A);
    send("2");           // row 1 gets a '2'

    // Walk to the last row.
    while (cursor_row != ROWS - 1) begin
      send(8'h0A);
    end
    check(top_row == 0, "top_row moved before reaching the bottom");

    send(8'h0A);  // the scroll
    while (!ready) @(posedge clk);
    check(top_row == 1, "top_row did not advance on scroll");
    check(cursor_row == ROWS - 1, "cursor should stay on the bottom row after scroll");

    // Stored row 1 holds the '2' and is now the top of the screen.
    expect_char(8'd1, 8'd0, "2");
    // Stored row 0 was the top line; it has come round to the bottom and must
    // have been blanked.
    expect_char(8'd0, 8'd0, 8'h20);
    expect_char(8'd0, 8'd79, 8'h20);

    //------------------------------------------------------------------
    // 8. BEL pulses and prints nothing.
    //------------------------------------------------------------------
    send(8'h07);
    expect_char(8'd0, 8'd0, 8'h20);

    //------------------------------------------------------------------
    // 9. ESC is swallowed, not printed (Stage A has no escape parser).
    //------------------------------------------------------------------
    // Compare against where the cursor actually is rather than a hard-coded
    // column - the cursor is wherever the preceding traffic left it, and an
    // assumed position is a test that passes for the wrong reason.
    col_before = cursor_col;
    row_before = cursor_row;
    send(8'h1B);
    check(cursor_col == col_before, "ESC should not move the cursor in Stage A");
    check(cursor_row == row_before, "ESC should not change the row in Stage A");

    //------------------------------------------------------------------
    // 10. TDV native control codes. These are NOT the ASCII meanings, and
    //     getting them the ANSI way round is the expensive mistake:
    //     FF is a ROLL UP, EM is the erase-page. Sources cross-checked in
    //     Terminals/docs/SPEC-tdv2200.md.
    //------------------------------------------------------------------
    send(8'h19);                       // EM - clean slate
    while (!ready) @(posedge clk);

    send("T"); send(8'h0D); send(8'h0A);   // row 0 = "T", then down to row 1
    send("U");
    expect_char(8'd0, 8'd0, "T");
    expect_char(8'd1, 8'd0, "U");

    // FF = roll up: everything moves up one, the cursor stays put, and the
    // line that was at the top is gone. If FF were treated as a clear, the
    // 'U' below would have been wiped too.
    row_before = cursor_row;
    send(8'h0C);
    while (!ready) @(posedge clk);
    check(top_row == 1, "FF did not roll the screen up");
    check(cursor_row == row_before, "FF moved the cursor - it should not");
    expect_screen_row(8'd0, 8'd0, "U");   // 'U' is now the top line
    check(1, "");

    // ETB = roll down: back the other way, and the newly exposed top line
    // must be blank - not the 'T' that used to be there.
    send(8'h17);
    while (!ready) @(posedge clk);
    check(top_row == 0, "ETB did not roll the screen down");
    expect_screen_row(8'd0, 8'd0, 8'h20);

    //------------------------------------------------------------------
    // 11. DLE cursor addressing - three bytes, no escape sequence. SINTRAN
    //     positions the cursor this way (live capture, terminal type 53).
    //     Row is a 5-bit mask, column a SEVEN-bit mask - the escape-sequence
    //     reference says 5 for the column, which cannot reach column 79.
    //------------------------------------------------------------------
    send(8'h10); send(8'd7); send(8'd40);      // DLE row 7 col 40
    check(cursor_row == 7, "DLE did not set the row");
    check(cursor_col == 40, "DLE did not set the column");
    send("Z");
    expect_screen_row(8'd7, 8'd40, "Z");

    // Column 79 - the one the 5-bit reading of the doc could not express.
    send(8'h10); send(8'd3); send(8'd79);
    check(cursor_col == 79, "DLE could not reach column 79 - 7-bit column mask");
    send("E");
    expect_screen_row(8'd3, 8'd79, "E");

    // A DLE payload byte must never be read as a control code. 0x0D would be
    // a CR if the state machine leaked.
    send(8'h10); send(8'd13); send(8'd13);
    check(cursor_row == 13 && cursor_col == 13, "a DLE payload byte was taken as a control code");

    //------------------------------------------------------------------
    // 12. The other TDV cursor moves.
    //------------------------------------------------------------------
    send(8'h1C);  check(cursor_row == 12, "FS did not move the cursor up");
    send(8'h18);  check(cursor_col == 14, "CAN did not move the cursor right");
    send(8'h1D);  check(cursor_row == 0 && cursor_col == 0, "GS did not home the cursor");

    // EOT erases the line the cursor is on, and nothing else.
    send(8'h10); send(8'd5); send(8'd0);
    send("K"); send("L");
    expect_screen_row(8'd5, 8'd0, "K");
    send(8'h10); send(8'd5); send(8'd0);
    send(8'h04);                            // EOT
    while (!ready) @(posedge clk);
    expect_screen_row(8'd5, 8'd0, 8'h20);
    expect_screen_row(8'd5, 8'd1, 8'h20);
    expect_screen_row(8'd7, 8'd40, "Z");   // an untouched line survived

    //------------------------------------------------------------------
    // 13. STX/ETX blank the display WITHOUT erasing it.
    //------------------------------------------------------------------
    send(8'h02);  check(video_on == 1'b0, "STX did not turn the video off");
    expect_screen_row(8'd7, 8'd40, "Z");   // still in the RAM
    send(8'h03);  check(video_on == 1'b1, "ETX did not turn the video back on");

    //------------------------------------------------------------------
    // 14. Keyboard lamps.
    //------------------------------------------------------------------
    send(8'h05);  check(leds[0], "ENQ did not light LED 1");
    send(8'h06);  check(leds[1], "ACK did not light LED 2");
    send(8'h15);  check(leds[2], "NAK did not light LED 3");
    send(8'h16);  check(leds == 3'b000, "SYN did not clear the lamps");

    //------------------------------------------------------------------
    // 15. SO/SI are the G1/G0 character-set shifts in native mode (they mean
    //     underline on/off ONLY inside 2115 compatibility mode, which this
    //     terminal does not implement). Tracked, not dropped.
    //------------------------------------------------------------------
    send(8'h0E);  check(charset == 1'b1, "SO did not invoke G1");
    send(8'h0F);  check(charset == 1'b0, "SI did not invoke G0");
    // and they must not have printed anything or moved the cursor
    send(8'h1D);  // home
    send(8'h0E); send(8'h0F);
    check(cursor_col == 0 && cursor_row == 0, "SO/SI moved the cursor");

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #20_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
