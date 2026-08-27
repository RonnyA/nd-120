//============================================================================
//! Terminal control - the TDV native control set ("Stage A")
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Plan: Verilog/Terminals/docs/PLAN-vt100-terminal-core.md
//! Spec: Verilog/Terminals/docs/SPEC-tdv2200.md
//!
//! Takes one byte at a time and turns it into character-RAM writes and cursor
//! movement.
//!
//! READ THIS BEFORE CHANGING ANY CODE BELOW: the TDV C0 codes are NOT the
//! ASCII/ANSI meanings. This module first implemented the ANSI ones and was
//! wrong in ways that matter. From RetroTerm's own reference documents
//! (docs/TDV-COMPLETE-ESCAPE-SEQUENCE-REFERENCE.md and
//! docs/TDV-COMPREHENSIVE-REFERENCE.md, cross-checked against each other):
//!
//!     0x02 STX  video OFF                    0x03 ETX  video ON
//!     0x04 EOT  ERASE LINE
//!     0x05 ENQ  LED 1 on                     0x06 ACK  LED 2 on
//!     0x07 BEL  bell
//!     0x08 BS   cursor LEFT
//!     0x09 HT   tab to the next tab stop
//!     0x0A LF   cursor down (scrolls at the bottom line)
//!     0x0B VT   cursor down - same as LF here
//!     0x0C FF   ROLL UP    <-- NOT "form feed / clear screen"
//!     0x0D CR   cursor to column 0
//!     0x0E SO   invoke G1 (character set) - see the SO/SI note below
//!     0x0F SI   invoke G0 (character set) - see the SO/SI note below
//!     0x10 DLE  DIRECT LINE ENTRY - binary cursor addressing, 2 bytes follow
//!     0x15 NAK  LED 3 on                     0x16 SYN  all LEDs off
//!     0x17 ETB  ROLL DOWN
//!     0x18 CAN  cursor RIGHT
//!     0x19 EM   ERASE PAGE  <-- this is the "clear screen", not FF
//!     0x1C FS   cursor UP
//!     0x1D GS   cursor HOME
//!     0x20-0x7E printable, written at the cursor
//!     0x7F DEL  ignored
//!
//! The two costly ones: **FF is a scroll, not a clear** (an ANSI terminal
//! would wipe the screen every time SINTRAN rolled the page), and **EM is the
//! clear**. Both were wrong here until the reference documents were read.
//!
//! DLE - CURSOR ADDRESSING WITHOUT ESCAPE SEQUENCES. `DLE row col`, three
//! bytes total: row is the next byte masked with 0b0001_1111, column the byte
//! after masked with 0b0111_1111, both 0-based. This matters more than it
//! looks: SINTRAN positions the cursor with DLE, confirmed by a live RX
//! capture of terminal type 53 (RetroTerm docs/TDV-DLE-CURSOR-BUG-FIX.md), so
//! full-screen addressing costs a three-state machine here and no escape
//! parser at all.
//!
//! !! DOC CONFLICT, recorded rather than guessed: the escape-sequence
//! !! reference calls the COLUMN mask 5 bits, which cannot express the
//! !! documented range 0-79. RetroTerm's code uses 7 bits and its bug-fix
//! !! report calls the 5-bit figure a doc defect. 7 bits is used here.
//!
//! SO/SI - RESOLVED 27-AUG-2026, and the answer was "both":
//! TDV-COMPLETE-ESCAPE-SEQUENCE-REFERENCE.md (underline on/off) and
//! TDV-COMPREHENSIVE-REFERENCE.md (ISO G1/G0 shifts) are BOTH correct - they
//! describe different MODES, and neither names the mode it applies in, which
//! is why they read as a contradiction. RetroTerm implements both:
//!   native TDV2200/2215 : G1/G0 shifts  (TDV2200Emulator.cs:303-306)
//!   2115 compatibility  : underline on/off (TDV2115CompatibilityHandler.cs:218-234)
//! 2115 mode is entered by ND private mode 66, which ALSO swaps the whole
//! keyboard encoding - so the two meanings travel together.
//!
//! We do not implement 2115 mode, so the G1/G0 reading is correct for every
//! case this module can reach. The charset output tracks it. Rendering a G1 glyph needs
//! a second font page, which font8x16.hex does not have yet - so the state is
//! carried and exported rather than silently dropped, and the day a second
//! font page lands the wiring is already here.
//!
//! ESC (0x1B) is ignored, not printed. The escape sequences are Stage B/C
//! (SPEC-tdv2200.md); ignoring the byte leaves the following letters visible
//! as text, which looks wrong in a way that tells you immediately what
//! happened - better than a screenful of graphics characters that hides it.
//!
//! SCROLLING moves the top-of-screen pointer, not the data: `top_row` says
//! which stored row is displayed at the top, so a scroll is one increment
//! plus blanking the row that has come round. That blank takes COLS clocks,
//! during which `ready` drops.
//!
//! CLOCK DOMAIN: everything here runs on the pixel clock, the same as the
//! character RAM and the screen. Bytes cross into this domain BEFORE they
//! arrive here - see terminal_top.v.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module terminal_ctrl #(
    parameter integer COLS     = 80,
    //! 80x25 is TDV 2200/2215 geometry (RetroTerm EmulatorFactory). NOT 24.
    parameter integer ROWS     = 25,
    parameter integer AWIDTH   = 11,
    parameter integer TAB_STOP = 8,
    //! Cursor blink period in frames. 30 frames at ~60 Hz is a ~1 Hz blink.
    parameter integer BLINK_FRAMES = 30
) (
    input wire clk,    //! pixel clock
    input wire rst_n,  //! async reset, active low

    // Byte in, already in this clock domain
    input  wire       byte_valid,  //! one clock per byte
    input  wire [7:0] byte_data,
    output wire       ready,       //! low while clearing - hold off the source

    // Character RAM write port
    output reg               ram_we,
    output reg  [AWIDTH-1:0] ram_waddr,
    output reg  [      15:0] ram_wdata,

    // Screen state, consumed by text_screen
    output reg  [7:0] top_row,
    output reg  [7:0] cursor_col,
    output reg  [7:0] cursor_row,
    output wire       cursor_enable,
    output reg        video_on,    //! STX/ETX blank the display without erasing
    //! Active ISO character set: 0 = G0 (SI), 1 = G1 (SO). See the SO/SI note
    //! in the header. Nothing renders differently yet - there is only one font
    //! page - but the state is tracked so it is not lost.
    output reg        charset,

    input  wire frame_end,  //! one pulse per video frame, for the blink
    output reg  bell,       //! one clock per BEL
    output reg  [2:0] leds  //! ENQ/ACK/NAK set, SYN clears. Board may ignore.
);

  localparam [15:0] BLANK_CELL = {8'h00, 8'h20};  //! space, no attributes

  localparam [1:0] ST_RUN       = 2'd0;
  localparam [1:0] ST_CLEAR_ALL = 2'd1;
  localparam [1:0] ST_CLEAR_ROW = 2'd2;

  reg [1:0] s_state;
  reg [7:0] s_clear_col;
  reg [7:0] s_clear_row;

  //! DLE takes the next two bytes as row and column. While this is non-zero
  //! the incoming byte is DATA, never a control code.
  reg [1:0] s_dle;

  assign ready = (s_state == ST_RUN);

  //--------------------------------------------------------------------------
  // Address arithmetic
  //--------------------------------------------------------------------------

  //! stored row for a given screen row = (top_row + screen_row) mod ROWS
  //! automatic, not the Verilog default: task and function locals are STATIC
  //! unless you say otherwise, and this one is called from two places in the
  //! same always block. Static locals shared between call sites are a real
  //! synthesis hazard, not a style point.
  function automatic [7:0] stored_row;
    input [7:0] top;
    input [7:0] screen;
    reg [8:0] sum;
    begin
      sum = {1'b0, top} + {1'b0, screen};
      stored_row = (sum >= ROWS) ? (sum[7:0] - ROWS[7:0]) : sum[7:0];
    end
  endfunction

  //! address = row * COLS + col. COLS = 80 = 64 + 16, so two shifts and an add
  //! - no multiplier inferred.
  function automatic [AWIDTH-1:0] cell_addr;
    input [7:0] row;
    input [7:0] col;
    begin
      cell_addr = {row, 6'b0} + {row, 4'b0} + col;
    end
  endfunction

  //--------------------------------------------------------------------------
  // Cursor blink - free-running off the frame pulse
  //--------------------------------------------------------------------------

  reg [7:0] s_blink_count;
  reg       s_blink_on;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_blink_count <= 8'd0;
      s_blink_on    <= 1'b1;
    end else if (frame_end) begin
      if (s_blink_count == BLINK_FRAMES - 1) begin
        s_blink_count <= 8'd0;
        s_blink_on    <= ~s_blink_on;
      end else begin
        s_blink_count <= s_blink_count + 8'd1;
      end
    end
  end

  assign cursor_enable = s_blink_on;

  //--------------------------------------------------------------------------
  // The three ways the screen moves. Written as tasks because LF, FF, ETB and
  // the right-margin wrap all need them and they are the fiddly part.
  //--------------------------------------------------------------------------

  //! Scroll up one line: the top line leaves, a blank line appears at the
  //! bottom. The cursor does not move.
  task automatic roll_up;
    begin
      top_row     <= (top_row == ROWS - 1) ? 8'd0 : (top_row + 8'd1);
      // The row to blank is the one leaving the top, i.e. the CURRENT
      // top_row - the new value has not taken effect at this point.
      s_clear_row <= top_row;
      s_clear_col <= 8'd0;
      s_state     <= ST_CLEAR_ROW;
    end
  endtask

  //! Scroll down one line: a blank line appears at the top, the bottom line
  //! leaves. The newly exposed row IS the new top_row.
  task automatic roll_down;
    reg [7:0] new_top;
    begin
      new_top     = (top_row == 8'd0) ? (ROWS[7:0] - 8'd1) : (top_row - 8'd1);
      top_row     <= new_top;
      s_clear_row <= new_top;
      s_clear_col <= 8'd0;
      s_state     <= ST_CLEAR_ROW;
    end
  endtask

  //! Cursor down; at the bottom line this scrolls instead.
  task automatic line_feed;
    begin
      if (cursor_row == ROWS - 1) roll_up;
      else cursor_row <= cursor_row + 8'd1;
    end
  endtask

  //--------------------------------------------------------------------------
  // Main sequencer
  //--------------------------------------------------------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Power-up: blank the whole screen. On a real FPGA the character RAM
      // holds whatever the tool loaded, so this is not optional.
      s_state     <= ST_CLEAR_ALL;
      s_clear_col <= 8'd0;
      s_clear_row <= 8'd0;
      s_dle       <= 2'd0;
      top_row     <= 8'd0;
      cursor_col  <= 8'd0;
      cursor_row  <= 8'd0;
      ram_we      <= 1'b0;
      ram_waddr   <= {AWIDTH{1'b0}};
      ram_wdata   <= BLANK_CELL;
      bell        <= 1'b0;
      leds        <= 3'b000;
      video_on    <= 1'b1;
      charset     <= 1'b0;
    end else begin
      // Defaults - overridden below where something actually happens.
      ram_we <= 1'b0;
      bell   <= 1'b0;

      case (s_state)

        //--------------------------------------------------------------------
        ST_CLEAR_ALL: begin
          ram_we    <= 1'b1;
          ram_waddr <= cell_addr(s_clear_row, s_clear_col);
          ram_wdata <= BLANK_CELL;

          if (s_clear_col == COLS - 1) begin
            s_clear_col <= 8'd0;
            if (s_clear_row == ROWS - 1) s_state <= ST_RUN;
            else s_clear_row <= s_clear_row + 8'd1;
          end else begin
            s_clear_col <= s_clear_col + 8'd1;
          end
        end

        //--------------------------------------------------------------------
        ST_CLEAR_ROW: begin
          ram_we    <= 1'b1;
          ram_waddr <= cell_addr(s_clear_row, s_clear_col);
          ram_wdata <= BLANK_CELL;

          if (s_clear_col == COLS - 1) begin
            s_clear_col <= 8'd0;
            s_state     <= ST_RUN;
          end else begin
            s_clear_col <= s_clear_col + 8'd1;
          end
        end

        //--------------------------------------------------------------------
        ST_RUN: begin
          if (byte_valid) begin

            //----------------------------------------------------------------
            // DLE payload. These two bytes are POSITION DATA - they must not
            // be looked at as control codes, which is why this test comes
            // before everything else.
            //----------------------------------------------------------------
            if (s_dle == 2'd1) begin
              // Row: 5-bit mask, 0-based. Clamped so a bad byte cannot put the
              // cursor off-screen and corrupt an address.
              cursor_row <= (byte_data[4:0] < ROWS) ? {3'b000, byte_data[4:0]}
                                                    : (ROWS[7:0] - 8'd1);
              s_dle      <= 2'd2;
            end else if (s_dle == 2'd2) begin
              // Column: SEVEN-bit mask. The escape-sequence reference says 5,
              // which cannot reach column 79 - see the header note.
              cursor_col <= (byte_data[6:0] < COLS) ? {1'b0, byte_data[6:0]}
                                                    : (COLS[7:0] - 8'd1);
              s_dle      <= 2'd0;
            end else begin

              case (byte_data)

                8'h02: video_on <= 1'b0;   // STX - video off, screen kept
                8'h03: video_on <= 1'b1;   // ETX - video on

                8'h04: begin               // EOT - erase line
                  s_clear_row <= stored_row(top_row, cursor_row);
                  s_clear_col <= 8'd0;
                  s_state     <= ST_CLEAR_ROW;
                end

                8'h05: leds[0] <= 1'b1;    // ENQ - LED 1
                8'h06: leds[1] <= 1'b1;    // ACK - LED 2
                8'h15: leds[2] <= 1'b1;    // NAK - LED 3
                8'h16: leds    <= 3'b000;  // SYN - all lamps off

                8'h07: bell <= 1'b1;       // BEL

                8'h08: if (cursor_col != 0) cursor_col <= cursor_col - 8'd1;  // BS

                8'h09: begin               // HT
                  if (cursor_col + TAB_STOP[7:0] >= COLS - 1)
                    cursor_col <= COLS[7:0] - 8'd1;
                  else
                    cursor_col <= ((cursor_col / TAB_STOP) + 8'd1) * TAB_STOP;
                end

                8'h0A, 8'h0B: line_feed;   // LF, VT - cursor down

                8'h0C: roll_up;            // FF - ROLL UP, not a clear

                8'h0D: cursor_col <= 8'd0; // CR

                8'h0E: charset <= 1'b1;    // SO - invoke G1
                8'h0F: charset <= 1'b0;    // SI - invoke G0

                8'h10: s_dle <= 2'd1;      // DLE - two position bytes follow

                8'h17: roll_down;          // ETB - roll down

                8'h18: if (cursor_col < COLS - 1) cursor_col <= cursor_col + 8'd1;  // CAN

                8'h19: begin               // EM - erase page, cursor home
                  s_state     <= ST_CLEAR_ALL;
                  s_clear_col <= 8'd0;
                  s_clear_row <= 8'd0;
                  top_row     <= 8'd0;
                  cursor_col  <= 8'd0;
                  cursor_row  <= 8'd0;
                end

                8'h1C: if (cursor_row != 0) cursor_row <= cursor_row - 8'd1;  // FS

                8'h1D: begin               // GS - cursor home
                  cursor_col <= 8'd0;
                  cursor_row <= 8'd0;
                end

                default: begin
                  // Printable. 0x7F (DEL) and any unhandled control code is
                  // dropped rather than printed as a graphic.
                  if (byte_data >= 8'h20 && byte_data < 8'h7F) begin
                    ram_we    <= 1'b1;
                    ram_waddr <= cell_addr(stored_row(top_row, cursor_row), cursor_col);
                    ram_wdata <= {8'h00, byte_data};

                    if (cursor_col == COLS - 1) begin
                      // The character IS written in the last column, then the
                      // cursor moves to the start of the next line. Holding it
                      // on the last column instead silently eats every 81st
                      // character.
                      cursor_col <= 8'd0;
                      line_feed;
                    end else begin
                      cursor_col <= cursor_col + 8'd1;
                    end
                  end
                end

              endcase
            end
          end
        end

        //--------------------------------------------------------------------
        default: s_state <= ST_RUN;

      endcase
    end
  end

endmodule

`default_nettype wire
