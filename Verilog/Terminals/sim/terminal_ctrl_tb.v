//============================================================================
//! Self-checking testbench for terminal_ctrl.v (VT100) + char_ram.v
//!
//! Drives console bytes in - ONE PER HANDSHAKE, the way they really arrive -
//! and reads the character RAM back to check what landed where. Covers:
//!
//!   - power-up clear (the whole screen is spaces before anything is typed)
//!   - printables land at the cursor and advance it; CR, LF, BS, HT
//!   - the VT100 last-column flag: the 80th character IS written, the cursor
//!     does not move until the next printable resolves the wrap
//!   - scroll at the bottom: top_row moves, the new bottom line is blank
//!   - CSI: CUP (with clamping), CUU/CUD/CUF/CUB, ED, EL, SGR attribute bits
//!   - DECSTBM: region scroll through the copy engine, rows outside untouched
//!   - RI at the top of the screen scrolls down
//!   - DECSC/DECRC, RIS
//!   - charset: ESC ( 0 + SO/SI set the DEC-graphics bit per cell
//!   - parser robustness: sequences split across arbitrary gaps, CAN abort,
//!     unknown sequences (ESC=, ESC(B, CSI ?3l) swallowed without output
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Rewritten 30-AUG-2026 for the VT100 controller (was the TDV Stage A tb).
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module terminal_ctrl_tb;

  localparam integer COLS   = 80;
  localparam integer ROWS   = 24;
  localparam integer AWIDTH = 11;

  localparam [7:0] ESC = 8'h1B;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg        byte_valid = 1'b0;
  reg  [7:0] byte_data = 8'h00;
  wire       ready;

  wire              we;
  wire [AWIDTH-1:0] waddr;
  wire [      15:0] wdata;
  wire [AWIDTH-1:0] raddr2;
  wire [      15:0] rdata2;

  wire [7:0] top_row, cursor_col, cursor_row;
  wire       cursor_enable, bell, rev_screen, blink_on;
  wire [3:0] leds;

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

      .ram_we    (we),
      .ram_waddr (waddr),
      .ram_wdata (wdata),
      .ram_raddr2(raddr2),
      .ram_rdata2(rdata2),

      .top_row      (top_row),
      .cursor_col   (cursor_col),
      .cursor_row   (cursor_row),
      .cursor_enable(cursor_enable),
      .rev_screen   (rev_screen),
      .blink_on     (blink_on),

      .frame_end(1'b0),
      .bell     (bell),
      .leds     (leds)
  );

  char_ram #(
      .COLS  (COLS),
      .ROWS  (ROWS),
      .AWIDTH(AWIDTH)
  ) RAM (
      .clk   (clk),
      .we    (we),
      .waddr (waddr),
      .wdata (wdata),
      .raddr2(raddr2),
      .rdata2(rdata2),
      .raddr ({AWIDTH{1'b0}}),
      .rdata ()
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

  //! Send one byte, honouring the handshake - exactly what the FIFO does.
  task send;
    input [7:0] value;
    begin
      @(posedge clk);
      while (!ready) @(posedge clk);
      byte_data  = value;
      byte_valid = 1'b1;
      @(posedge clk);
      byte_valid = 1'b0;
    end
  endtask

  //! Send a string (no NULs inside).
  task send_str;
    input [8*32-1:0] text;
    integer i;
    reg [7:0] ch;
    begin
      for (i = 31; i >= 0; i = i - 1) begin
        ch = text[i*8+:8];
        if (ch != 8'h00) send(ch);
      end
    end
  endtask

  //! Wait until every engine is finished, so the RAM can be inspected.
  task settle;
    begin
      @(posedge clk);
      while (!ready) @(posedge clk);
      repeat (4) @(posedge clk);
    end
  endtask

  //! The stored cell for a SCREEN position, mapped through top_row the way
  //! the hardware does it - doing that here is part of the test.
  function [15:0] cell_at;
    input [7:0] srow;
    input [7:0] scol;
    reg [8:0] sum;
    reg [7:0] stored;
    begin
      sum     = {1'b0, top_row} + {1'b0, srow};
      stored  = (sum >= ROWS) ? (sum[7:0] - ROWS[7:0]) : sum[7:0];
      cell_at = RAM.s_cells[stored * COLS + scol];
    end
  endfunction

  task expect_char;
    input [7:0] srow;
    input [7:0] scol;
    input [7:0] expected;
    input [1023:0] what;
    reg [15:0] cellv;
    begin
      cellv = cell_at(srow, scol);
      if (cellv[7:0] !== expected) begin
        $display("FAIL: %0s - screen(%0d,%0d) = 0x%02x, expected 0x%02x (time %0t)",
                 what, srow, scol, cellv[7:0], expected, $time);
        errors = errors + 1;
      end
    end
  endtask

  task expect_cursor;
    input [7:0] erow;
    input [7:0] ecol;
    input [1023:0] what;
    begin
      if (cursor_row !== erow || cursor_col !== ecol) begin
        $display("FAIL: %0s - cursor at (%0d,%0d), expected (%0d,%0d) (time %0t)",
                 what, cursor_row, cursor_col, erow, ecol, $time);
        errors = errors + 1;
      end
    end
  endtask

  integer r, c;
  reg [15:0] cellv;

  //--------------------------------------------------------------------------

  initial begin
    $dumpfile("terminal_ctrl_tb.vcd");
    $dumpvars(0, terminal_ctrl_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    settle;

    //------------------------------------------------------------------
    // 1. Power-up: every cell is a space with no attributes.
    //------------------------------------------------------------------
    begin : powerup
      integer bad;
      bad = 0;
      for (r = 0; r < ROWS; r = r + 1)
        for (c = 0; c < COLS; c = c + 1)
          if (cell_at(r[7:0], c[7:0]) !== {8'h00, 8'h20}) bad = bad + 1;
      check(bad == 0, "power-up clear left non-blank cells");
      expect_cursor(8'd0, 8'd0, "power-up cursor not home");
    end

    //------------------------------------------------------------------
    // 2. Printables, CR, LF.
    //------------------------------------------------------------------
    send_str("OK");
    settle;
    expect_char(8'd0, 8'd0, "O", "printable row 0");
    expect_char(8'd0, 8'd1, "K", "printable row 0");
    expect_cursor(8'd0, 8'd2, "cursor after OK");

    send(8'h0D);
    send(8'h0A);
    send("2");
    settle;
    expect_char(8'd1, 8'd0, "2", "char after CR LF");
    // LF alone must NOT return the column (LNM is off by default).
    send(8'h0A);
    settle;
    expect_cursor(8'd2, 8'd1, "LF alone must keep the column");

    //------------------------------------------------------------------
    // 3. CUP - ESC [ row ; col H, 1-based, and the clamp.
    //------------------------------------------------------------------
    send(ESC); send_str("[12;40H");
    settle;
    expect_cursor(8'd11, 8'd39, "CUP 12;40");
    send(ESC); send_str("[H");
    settle;
    expect_cursor(8'd0, 8'd0, "CUP no parameters = home");
    send(ESC); send_str("[999;999H");
    settle;
    expect_cursor(ROWS[7:0]-8'd1, COLS[7:0]-8'd1, "CUP clamps to the screen");

    //------------------------------------------------------------------
    // 4. Cursor moves with counts and clamps.
    //------------------------------------------------------------------
    send(ESC); send_str("[H");
    send(ESC); send_str("[5B");   // down 5
    send(ESC); send_str("[3C");   // right 3
    settle;
    expect_cursor(8'd5, 8'd3, "CUD 5 + CUF 3");
    send(ESC); send_str("[2A");   // up 2
    send(ESC); send_str("[D");    // left, default 1
    settle;
    expect_cursor(8'd3, 8'd2, "CUU 2 + CUB");
    send(ESC); send_str("[99A");  // clamps at the top
    send(ESC); send_str("[99D");  // clamps at the left
    settle;
    expect_cursor(8'd0, 8'd0, "CUU/CUB clamp at the edges");

    //------------------------------------------------------------------
    // 5. ED 2 clears, cursor STAYS (VT100 - ED does not home).
    //------------------------------------------------------------------
    send(ESC); send_str("[10;10H");
    send(ESC); send_str("[2J");
    settle;
    expect_cursor(8'd9, 8'd9, "ED 2 must not move the cursor");
    expect_char(8'd0, 8'd0, 8'h20, "ED 2 cleared the screen");

    //------------------------------------------------------------------
    // 6. EL variants on a marked row.
    //------------------------------------------------------------------
    send(ESC); send_str("[3;1H");
    for (c = 0; c < 10; c = c + 1) send("M");
    send(ESC); send_str("[3;5H");
    send(ESC); send_str("[K");    // EL 0: cursor to end of line
    settle;
    expect_char(8'd2, 8'd3, "M",   "EL 0 must keep cells left of the cursor");
    expect_char(8'd2, 8'd4, 8'h20, "EL 0 must clear the cursor cell");
    expect_char(8'd2, 8'd9, 8'h20, "EL 0 must clear to the right margin");
    send(ESC); send_str("[3;3H");
    send(ESC); send_str("[1K");   // EL 1: start of line to cursor
    settle;
    expect_char(8'd2, 8'd0, 8'h20, "EL 1 must clear from the left margin");
    expect_char(8'd2, 8'd2, 8'h20, "EL 1 must clear the cursor cell");
    expect_char(8'd2, 8'd3, "M",   "EL 1 must keep cells right of the cursor");

    //------------------------------------------------------------------
    // 7. SGR writes the attribute bits with each character.
    //------------------------------------------------------------------
    send(ESC); send_str("[5;1H");
    send(ESC); send_str("[7m");  send("R");
    send(ESC); send_str("[0;4m"); send("U");
    send(ESC); send_str("[5m");  send("B");   // underline still on: 4 then 5
    send(ESC); send_str("[0m");  send("N");
    settle;
    cellv = cell_at(8'd4, 8'd0);
    check(cellv[8]  === 1'b1, "SGR 7 must set the reverse bit");
    cellv = cell_at(8'd4, 8'd1);
    check(cellv[8]  === 1'b0 && cellv[10] === 1'b1, "SGR 0;4 = underline only");
    cellv = cell_at(8'd4, 8'd2);
    check(cellv[10] === 1'b1 && cellv[11] === 1'b1, "SGR 5 adds blink to underline");
    cellv = cell_at(8'd4, 8'd3);
    check(cellv[15:8] === 8'h00, "SGR 0 must clear every attribute");

    //------------------------------------------------------------------
    // 8. The last-column flag. The 80th character IS written and the cursor
    //    holds; the 81st resolves the wrap onto the next line.
    //------------------------------------------------------------------
    send(ESC); send_str("[7;1H");
    for (c = 0; c < COLS; c = c + 1) send("W");
    settle;
    expect_char(8'd6, COLS[7:0]-8'd1, "W", "the 80th character must be written");
    expect_cursor(8'd6, COLS[7:0]-8'd1, "cursor holds in the last column");
    send("X");
    settle;
    expect_char(8'd7, 8'd0, "X", "the 81st character wraps to the next line");
    expect_cursor(8'd7, 8'd1, "cursor after the wrapped character");
    // CUP must clear the flag: park in the last column, move, no wrap.
    send(ESC); send_str("[7;80H"); send("Q");
    send(ESC); send_str("[9;1H");  send("Z");
    settle;
    expect_char(8'd8, 8'd0, "Z", "CUP must clear the pending wrap");

    //------------------------------------------------------------------
    // 9. Scroll at the bottom of the (full) screen: the ring moves.
    //------------------------------------------------------------------
    send(ESC); send_str("[2J");
    send(ESC); send_str("[1;1H"); send("T");            // top row marker
    send(ESC); send_str("[24;1H");
    send("V");
    send(8'h0A);                                        // LF at the bottom
    settle;
    check(top_row === 8'd1, "bottom LF must advance top_row");
    expect_char(ROWS[7:0]-8'd2, 8'd0, "V", "old bottom line one up after scroll");
    expect_char(ROWS[7:0]-8'd1, 8'd0, 8'h20, "new bottom line must be blank");
    // The 'T' left the screen. LF does not touch the column ('V' moved it
    // to 1), so the cursor is bottom line, column 1.
    expect_cursor(ROWS[7:0]-8'd1, 8'd1, "cursor stays on the bottom line");

    //------------------------------------------------------------------
    // 10. RI at the top scrolls down.
    //------------------------------------------------------------------
    send(ESC); send_str("[2J");
    send(ESC); send_str("[1;1H"); send("A");
    send(ESC); send_str("[1;1H");
    send(ESC); send("M");                               // RI at the top
    settle;
    expect_char(8'd1, 8'd0, "A", "RI at the top pushes row 0 down");
    expect_char(8'd0, 8'd0, 8'h20, "RI must blank the new top line");

    //------------------------------------------------------------------
    // 11. DECSTBM region scroll - the copy engine. Rows outside stay put.
    //------------------------------------------------------------------
    send(ESC); send_str("[r");                          // full screen first
    send(ESC); send_str("[2J");
    for (r = 0; r < 12; r = r + 1) begin
      send(ESC); send("[");
      if (r + 1 >= 10) send("0" + (r + 1) / 10);
      send("0" + (r + 1) % 10);
      send_str(";1H");
      send("A" + r[7:0]);                               // row r marked 'A'+r
    end
    send(ESC); send_str("[5;10r");                      // region rows 5..10 (idx 4..9)
    settle;
    expect_cursor(8'd0, 8'd0, "DECSTBM homes the cursor");
    send(ESC); send_str("[10;1H");                      // bottom of the region
    send(8'h0A);                                        // scroll the region
    settle;
    expect_char(8'd3, 8'd0, "A" + 8'd3, "row above the region untouched");
    expect_char(8'd4, 8'd0, "A" + 8'd5, "region top gets the old second row");
    expect_char(8'd8, 8'd0, "A" + 8'd9, "region content moved one up");
    expect_char(8'd9, 8'd0, 8'h20,      "region bottom is blank after scroll");
    expect_char(8'd10, 8'd0, "A" + 8'd10, "row below the region untouched");
    check(top_row === 8'd0, "a region scroll must not touch the ring");
    // LF below the region must not scroll anything.
    send(ESC); send_str("[12;1H");
    send(8'h0A);
    settle;
    expect_char(8'd10, 8'd0, "A" + 8'd10, "LF below the region must not scroll");
    send(ESC); send_str("[r");                          // region off again
    settle;

    //------------------------------------------------------------------
    // 12. Charset: ESC ( 0 designates G0 graphics; SO/SI switch G1/G0.
    //------------------------------------------------------------------
    send(ESC); send_str("[2J");
    send(ESC); send_str("[1;1H");
    send(ESC); send_str(")0");                          // G1 = DEC graphics
    send("q");                                          // still G0 = ASCII
    send(8'h0E);                                        // SO -> G1
    send("q");                                          // now a graphics cell
    send(8'h0F);                                        // SI -> G0
    send("q");
    settle;
    cellv = cell_at(8'd0, 8'd0);
    check(cellv[12] === 1'b0, "before SO the cell must be ASCII");
    cellv = cell_at(8'd0, 8'd1);
    check(cellv[12] === 1'b1 && cellv[7:0] === "q", "after SO the cell is graphics");
    cellv = cell_at(8'd0, 8'd2);
    check(cellv[12] === 1'b0, "after SI the cell is ASCII again");

    //------------------------------------------------------------------
    // 13. DECSC / DECRC.
    //------------------------------------------------------------------
    send(ESC); send_str("[6;7H");
    send(ESC); send_str("[7m");
    send(ESC); send("7");                               // save
    send(ESC); send_str("[1;1H");
    send(ESC); send_str("[0m");
    send(ESC); send("8");                               // restore
    send("S");
    settle;
    expect_char(8'd5, 8'd6, "S", "DECRC must restore the position");
    cellv = cell_at(8'd5, 8'd6);
    check(cellv[8] === 1'b1, "DECRC must restore the rendition");
    send(ESC); send_str("[0m");

    //------------------------------------------------------------------
    // 14. Parser robustness: a split sequence, CAN abort, unknowns.
    //------------------------------------------------------------------
    send(ESC);
    repeat (500) @(posedge clk);                        // a byte-time of silence
    send_str("[2;3H");
    settle;
    expect_cursor(8'd1, 8'd2, "a sequence split across a gap must still work");

    send(ESC); send("["); send(8'h18);                  // CAN aborts the CSI
    send("X");
    settle;
    expect_char(8'd1, 8'd2, "X", "after CAN the next byte is plain text");

    send(ESC); send_str("[?3l");                        // DECCOLM off - swallowed
    send(ESC); send("=");                               // DECKPAM - swallowed
    send(ESC); send_str("(B");                          // G0 = ASCII - no output
    send("Y");
    settle;
    expect_char(8'd1, 8'd3, "Y", "unknown sequences must produce no output");
    cellv = cell_at(8'd1, 8'd3);
    check(cellv[12] === 1'b0, "ESC ( B leaves G0 as ASCII");

    //------------------------------------------------------------------
    // 15. DECOM: with origin mode on, CUP is region-relative.
    //------------------------------------------------------------------
    send(ESC); send_str("[10;20r");
    send(ESC); send_str("[?6h");
    settle;
    expect_cursor(8'd9, 8'd0, "DECOM set homes to the region top");
    send(ESC); send_str("[1;1H");
    settle;
    expect_cursor(8'd9, 8'd0, "origin-mode CUP 1;1 is the region top");
    send(ESC); send_str("[99;1H");
    settle;
    expect_cursor(8'd19, 8'd0, "origin-mode CUP clamps to the region bottom");
    send(ESC); send_str("[?6l");
    send(ESC); send_str("[r");
    settle;

    //------------------------------------------------------------------
    // 16. RIS resets everything.
    //------------------------------------------------------------------
    send(ESC); send_str("[7m");
    send(ESC); send_str("[?5h");                        // reverse screen
    send(ESC); send("c");                               // RIS
    settle;
    expect_cursor(8'd0, 8'd0, "RIS homes the cursor");
    check(rev_screen === 1'b0, "RIS clears DECSCNM");
    send("H");
    settle;
    cellv = cell_at(8'd0, 8'd0);
    check(cellv[15:8] === 8'h00, "RIS clears the rendition");
    check(top_row === 8'd0, "RIS resets the ring");

    //------------------------------------------------------------------
    // 17. BEL pulses, DEL is ignored.
    //------------------------------------------------------------------
    begin : bel_check
      integer saw;
      saw = 0;
      fork
        begin : watch
          repeat (40) begin
            @(posedge clk);
            if (bell) saw = saw + 1;
          end
        end
        send(8'h07);
      join
      check(saw == 1, "BEL must pulse bell exactly once");
    end
    send(8'h7F);
    settle;
    expect_cursor(8'd0, 8'd1, "DEL must be ignored");

    //------------------------------------------------------------------
    if (errors == 0) $display("TB_RESULT: PASS (VT100 terminal control)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #80_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire
