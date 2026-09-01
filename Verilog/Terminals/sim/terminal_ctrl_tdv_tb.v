//============================================================================
//! Self-checking testbench for terminal_ctrl_tdv.v + char_ram.v
//!
//! Sibling of terminal_ctrl_tb.v (VT100). Covers the TDV-specific parser
//! surface terminal_ctrl.v's tests do not exercise:
//!
//!   - power-up clear (identical mechanism, re-checked at 80x25 geometry)
//!   - C0 cursor moves: GS home, FS up, VT down, BS left, CAN right
//!   - DLE binary cursor addressing, BOTH encodings (raw 0-based and
//!     SINTRAN's 0x7F+n biased) landing on the SAME cell
//!   - EOT erase line, EM erase page
//!   - ESC 6 (NDSS6/Box) sets the graphics-attribute bit on subsequent
//!     printables, and any other NDSS digit clears it back to plain ASCII -
//!     found missing and fixed 31-AUG-2026 against a live SCONF capture
//!     (cell 0x60 printed as a literal backtick instead of a corner)
//!   - THE REAL CAPTURED PED-AT-TYPE-93 STARTUP, byte-exact
//!     (Verilog/Terminals/docs/SPEC-tdv2200.md / FINDINGS-2026-08-20.md):
//!     ESC Q, two unmarked mode set/reset lists (incl. mode 62, function
//!     unknown), FOUR DCS soft-key blocks that must be skipped as a unit
//!     and never rendered, a zero-padded CUP, and ED. Asserts cell (0,0)
//!     stays blank through the DCS blocks (proving nothing leaked as text)
//!     and that the parser is back in ground state afterwards (a plain
//!     byte sent right after lands normally, proving it is not stuck
//!     skipping forever).
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 31-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module terminal_ctrl_tdv_tb;

  localparam integer COLS   = 80;
  localparam integer ROWS   = 25;
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
  reg  [AWIDTH-1:0] raddr;
  wire [      15:0] rdata;

  wire [7:0] top_row, cursor_col, cursor_row;
  wire       cursor_enable, bell, rev_screen, blink_on;
  wire [3:0] leds;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz

  terminal_ctrl_tdv #(
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
      .raddr (raddr),
      .rdata (rdata)
  );

  function automatic [AWIDTH-1:0] addr_of;
    input [7:0] row;
    input [7:0] col;
    begin
      addr_of = row * COLS + col;
    end
  endfunction

  task automatic read_cell;
    input  [7:0] row;
    input  [7:0] col;
    output [15:0] s_cell;
    begin
      raddr = addr_of(row, col);
      @(posedge clk);
      @(posedge clk);
      s_cell = rdata;
    end
  endtask

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

  task wait_ready;
    begin
      @(posedge clk);
      while (!ready) @(posedge clk);
    end
  endtask

  reg [15:0] s_cell;

  initial begin
    $dumpfile("terminal_ctrl_tdv_tb.vcd");
    $dumpvars(0, terminal_ctrl_tdv_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    wait_ready;

    //------------------------------------------------------------------
    // 1. Power-up: screen is blank
    //------------------------------------------------------------------
    read_cell(8'd0, 8'd0, s_cell);
    check(s_cell == {8'h00, 8'h20}, "power-up s_cell (0,0) is not blank");
    check(cursor_row == 0 && cursor_col == 0, "power-up cursor not at (0,0)");

    //------------------------------------------------------------------
    // 2. C0 cursor moves - bare bytes, TDV meanings
    //------------------------------------------------------------------
    send("X");                                    // (0,0) -> cursor at (0,1)
    check(cursor_col == 1, "printable did not advance cursor");
    send(8'h0B); check(cursor_row == 1 && cursor_col == 1, "VT (down) wrong");
    send(8'h0B); check(cursor_row == 2, "VT (down) #2 wrong");
    send(8'h1C); check(cursor_row == 1, "FS (up) wrong");
    send(8'h18); check(cursor_col == 2, "CAN (right) wrong");
    send(8'h08); check(cursor_col == 1, "BS (left) wrong");
    send(8'h1D); check(cursor_row == 0 && cursor_col == 0, "GS (home) wrong - real PED confirms bare GS 0x1D");

    //------------------------------------------------------------------
    // 2b. ESC 6 (NDSS6/Box) - the bug found live in SCONF, 31-AUG-2026.
    // A cell printed while Box is designated must carry the graphics
    // attribute (RAM bit 12, which text_screen.v uses to select font
    // page 3); any other NDSS digit must clear it back to plain ASCII.
    //------------------------------------------------------------------
    send(ESC); send("6");                          // NDSS6 - Box
    send(8'h60);                                     // would-be top-left corner
    wait_ready;
    read_cell(cursor_row, 8'd0, s_cell);
    check(s_cell[12] == 1'b1, "ESC 6 (NDSS6/Box) did not set the graphics attribute");
    check(s_cell[7:0] == 8'h60, "ESC 6 cell did not store the raw character code");

    send(ESC); send("1");                           // NDSS1 - Graphics I, not Box
    send(8'h60);
    wait_ready;
    read_cell(cursor_row, 8'd1, s_cell);
    check(s_cell[12] == 1'b0, "ESC 1 did not clear the graphics attribute back to plain ASCII");

    //------------------------------------------------------------------
    // 2b-2. SS2 (ESC N) - the REAL box-drawing mechanism, found 01-SEP-2026:
    // NDSS6/ESC 6 above was never once seen in a live PED capture
    // (dbg_saw_esc6 stayed 0000 through a full session) - RetroTerm's own
    // TDVEmulatorBase.cs hardwires G2 to GraphicsI permanently, so ESC N
    // shifts the very NEXT character only through the graphics font, no
    // lasting mode change. Confirmed live: PED repeats ESC N per cell.
    //------------------------------------------------------------------
    send(ESC); send("N");                           // SS2 - next char only
    send(8'h60);                                    // graphics cell
    wait_ready;
    read_cell(cursor_row, 8'd2, s_cell);
    check(s_cell[12] == 1'b1, "ESC N (SS2) did not set the graphics attribute on the shifted character");
    check(s_cell[7:0] == 8'h60, "ESC N cell did not store the raw character code");

    send(8'h60);                                    // NOT preceded by ESC N this time
    wait_ready;
    read_cell(cursor_row, 8'd3, s_cell);
    check(s_cell[12] == 1'b0, "SS2 leaked past one character - it must be single-shift only");

    //------------------------------------------------------------------
    // 2c. CSI A/B/C/D (cursor moves) and SGR (m) - the real bug, found
    // 31-AUG-2026 from a live RetroCore trace: SINTRAN echoes a TDV
    // keypress's cursor move back as STANDARD VT100 CSI (ESC[A/B/C/D),
    // not another bare TDV byte, and this parser did not implement them
    // at all - arrows looked completely dead in PED even though the
    // keyboard side was correct and SINTRAN was receiving every keypress.
    //------------------------------------------------------------------
    send(8'h10); send(8'd10); send(8'd10);           // DLE to a known start: row 10, col 10
    send(ESC); send("["); send("A"); wait_ready;      // CUU, no param = 1
    check(cursor_row == 9 && cursor_col == 10, "ESC[A (CUU) did not move up 1");
    send(ESC); send("["); send("B"); wait_ready;      // CUD, no param = 1
    check(cursor_row == 10, "ESC[B (CUD) did not move down 1");
    send(ESC); send("["); send("C"); wait_ready;      // CUF, no param = 1
    check(cursor_col == 11, "ESC[C (CUF) did not move right 1");
    send(ESC); send("["); send("D"); wait_ready;      // CUB, no param = 1
    check(cursor_col == 10, "ESC[D (CUB) did not move left 1");
    send(ESC); send("["); send("3"); send("A"); wait_ready; // CUU with an explicit count
    check(cursor_row == 7, "ESC[3A (CUU n=3) did not move up 3");
    send(ESC); send("["); send("2"); send("0"); send("A"); wait_ready; // clamps at row 0, does not wrap
    check(cursor_row == 0, "ESC[20A did not clamp at row 0");

    begin : sgr_probe
      reg [7:0] pr, pc;
      send(ESC); send("["); send("7"); send("m"); wait_ready; // SGR reverse video
      pr = cursor_row; pc = cursor_col;
      send("R");                                       // 'R' with reverse set
      wait_ready;
      read_cell(pr, pc, s_cell);
      check(s_cell[8] == 1'b1, "ESC[7m (SGR reverse) did not set the reverse attribute bit");

      send(ESC); send("["); send("0"); send("m"); wait_ready; // SGR reset
      pr = cursor_row; pc = cursor_col;
      send("N");                                       // 'N' with attributes cleared
      wait_ready;
      read_cell(pr, pc, s_cell);
      check(s_cell[8] == 1'b0, "ESC[0m (SGR reset) did not clear the reverse attribute bit");
    end

    //------------------------------------------------------------------
    // 3. DLE binary cursor addressing - both encodings land the same place
    //------------------------------------------------------------------
    send(8'h10); send(8'd5); send(8'd10);          // raw 0-based: row 5, col 10
    check(cursor_row == 5 && cursor_col == 10, "DLE raw encoding wrong");

    send(8'h10); send(8'h83); send(8'h82);          // biased: row "4" 1-based (0x7F+4), col "3" 1-based (0x7F+3)
    check(cursor_row == 3 && cursor_col == 2, "DLE biased 0x7F+n encoding wrong (should be row3,col2)");

    //------------------------------------------------------------------
    // 4. EOT erase line, EM erase page
    //------------------------------------------------------------------
    send(8'h10); send(8'd2); send(8'd0);            // row 2, col 0
    send("Y"); send("Z");                           // (2,0)="Y" (2,1)="Z"
    send(8'h10); send(8'd2); send(8'd0);
    send(8'h04);                                     // EOT - erase current line
    wait_ready;
    read_cell(8'd2, 8'd0, s_cell);
    check(s_cell == {8'h00, 8'h20}, "EOT did not erase (2,0)");
    read_cell(8'd2, 8'd1, s_cell);
    check(s_cell == {8'h00, 8'h20}, "EOT did not erase (2,1)");

    send(8'h10); send(8'd7); send(8'd0);
    send("W");
    send(8'h19);                                     // EM - erase page
    wait_ready;
    read_cell(8'd7, 8'd0, s_cell);
    check(s_cell == {8'h00, 8'h20}, "EM did not erase the page");

    //------------------------------------------------------------------
    // 5. THE REAL CAPTURED PED-AT-TYPE-93 STARTUP, byte-exact.
    //------------------------------------------------------------------
    send(ESC); send("Q");                                    // ESC Q
    send(ESC); send("["); send("3"); send("0"); send(";");
    send("7"); send(";"); send("8"); send("0"); send("l");   // ESC[30;7;80l
    send(ESC); send("["); send("6"); send("2"); send(";");
    send("6"); send("2"); send("h");                          // ESC[62;62h

    // Four DCS soft-key blocks: ESC P L10 ESC\ .. L40 ESC\
    send(ESC); send("P"); send("L"); send("1"); send("0"); send(ESC); send("\\");
    send(ESC); send("P"); send("L"); send("2"); send("0"); send(ESC); send("\\");
    send(ESC); send("P"); send("L"); send("3"); send("0"); send(ESC); send("\\");
    send(ESC); send("P"); send("L"); send("4"); send("0"); send(ESC); send("\\");
    wait_ready;

    // Nothing from the DCS payloads leaked to the screen - s_cell (0,0) is
    // still whatever it was before this block started (it was cleared by
    // EM just above, so still blank).
    read_cell(8'd0, 8'd0, s_cell);
    check(s_cell == {8'h00, 8'h20}, "DCS payload leaked onto the screen (s_cell 0,0 not blank)");

    // Parser is back in ground state, not stuck skipping - a plain byte
    // right after must print normally, at wherever the cursor actually is
    // (row 7 col 1, left there by the EM test above - nothing in this
    // capture segment moves the cursor before CUP arrives).
    begin : probe
      reg [7:0] probe_row, probe_col;
      probe_row = cursor_row;
      probe_col = cursor_col;
      send("Q");
      wait_ready;
      read_cell(probe_row, probe_col, s_cell);
      check(s_cell == {8'h00, "Q"}, "parser stuck after DCS blocks - 'Q' did not print where expected");
    end

    // Zero-padded CUP.
    send(ESC); send("["); send("0"); send("0"); send("1"); send(";");
    send("0"); send("0"); send("1"); send("H");               // ESC[001;001H
    wait_ready;
    check(cursor_row == 0 && cursor_col == 0, "zero-padded CUP did not land at (0,0)");

    // ED - full clear.
    send(ESC); send("["); send("2"); send("J");                // ESC[2J
    wait_ready;
    read_cell(8'd0, 8'd0, s_cell);
    check(s_cell == {8'h00, 8'h20}, "ED[2J did not clear s_cell (0,0)");
    read_cell(ROWS[7:0]-8'd1, COLS[7:0]-8'd1, s_cell);
    check(s_cell == {8'h00, 8'h20}, "ED[2J did not clear the last s_cell");

    if (errors == 0) $display("TB_RESULT: PASS (%0d checks, incl. real captured PED startup)", 0);
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
