//============================================================================
//! Terminal control - TDV2200 (terminal type 93, Tandberg TDV-2200/9S
//! ND-NOTIS)
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Sibling of terminal_ctrl.v (VT100, type 6) - same engine (clear/scroll/
//! copy/apply state machines, cursor-move arithmetic, address functions are
//! IDENTICAL, terminal-type-agnostic screen mechanics), different PARSER:
//! a TDV does not speak ECMA-48 C0 meanings or DEC CSI cursor letters for
//! input, and neither does SINTRAN when it thinks it is talking to one.
//!
//! GROUND TRUTH (see ps2_ascii_table_tdv.v's header for the full source
//! list) and the REAL CAPTURED PED-at-type-93 startup this parser is built
//! to survive byte-exact (Verilog/Terminals/docs/SPEC-tdv2200.md has the
//! full account):
//!   ESC Q                          exit/enable EC switch - swallowed
//!   ESC[30;7;80l  ESC[62;62h       mode set/reset, UNMARKED (no '?'),
//!                                  function unknown - swallowed generically
//!   ESC P L10 ESC\  (x4)           DCS soft-key programming - SKIPPED AS A
//!                                  UNIT, never rendered (matches RetroTerm's
//!                                  own TDV2200Emulator, which does not
//!                                  implement DCS soft-key programming either)
//!   ESC[001;001H                   CUP, ZERO-PADDED parameters
//!   ESC[2J                         ED, standard
//!
//! C0 CONTROL CODES have TDV-native meanings, not ASCII/ECMA-48 ones - this
//! is the single biggest difference from terminal_ctrl.v. Cursor movement is
//! C0 bytes (BS=left, VT=down, CAN=right, FS=up, GS=home), NOT escape
//! sequences - confirmed on real hardware (FINDINGS-2026-08-20.md: SENDKEY
//! HOME transmitted GS 0x1D, cursor landed on the PED: line, "exactly the
//! documented behaviour").
//!
//! DLE (0x10) starts 2-byte BINARY cursor addressing: row byte masked to 5
//! bits (0-24), column byte masked to 7 bits (0-79) - 7, not 5: 5 bits
//! cannot address column 79, and the RetroTerm source code comment disputes
//! the 5-bit claim some docs make on exactly this basis. The same masking
//! is tolerant of BOTH a raw 0-based encoding and SINTRAN's 0x7F+n 1-based
//! biased encoding - masking off the low 5/7 bits collapses both cases to
//! the same result, so no mode flag is needed to pick which one arrived.
//!
//! DEFERRED, NOT IMPLEMENTED (no evidence PED/LED use them; add only if a
//! live capture shows otherwise): ND private rectangle ops (z { } u v ~ | p
//! q s t), Tektronix/ND graphics, DCS soft-key/PUSH-key PROGRAMMING (only
//! skip-and-discard is implemented), 132-column mode (no TDV terminal type
//! supports it), character-set rendering beyond the existing DEC-graphics
//! font page (charset DESIGNATION bytes are still consumed correctly, just
//! do not change what is drawn - same conservative choice terminal_ctrl.v
//! makes for anything beyond page 0/DEC-graphics).
//!
//! CELL LAYOUT, clock domain, blink: identical to terminal_ctrl.v - see
//! that file's header.
//!
//! Written 31-AUG-2026.
//============================================================================

`default_nettype none

module terminal_ctrl_tdv #(
    parameter integer COLS     = 80,
    //! 80x25 is TDV2200 geometry - one more row than VT100's 80x24, the
    //! 25th row PED's status line uses (confirmed: FINDINGS-2026-08-20.md,
    //! "PED as a TDV gets one more text line... Line: 1-21... 25th row").
    parameter integer ROWS     = 25,
    parameter integer AWIDTH   = 11,
    parameter integer TAB_STOP = 8,
    parameter integer BLINK_FRAMES = 30
) (
    input wire clk,
    input wire rst_n,

    input  wire       byte_valid,
    input  wire [7:0] byte_data,
    output wire       ready,

    output reg               ram_we,
    output reg  [AWIDTH-1:0] ram_waddr,
    output reg  [      15:0] ram_wdata,
    output wire [AWIDTH-1:0] ram_raddr2,
    input  wire [      15:0] ram_rdata2,

    output reg  [7:0] top_row,
    output reg  [7:0] cursor_col,
    output reg  [7:0] cursor_row,
    output wire       cursor_enable,
    output reg        rev_screen,
    output wire       blink_on,

    input  wire frame_end,
    output reg  bell,
    output reg  [3:0] leds
);

  localparam [15:0] BLANK_CELL = {8'h00, 8'h20};

  //--------------------------------------------------------------------------
  // Engine states - identical shape to terminal_ctrl.v (terminal-type-
  // agnostic screen mechanics).
  //--------------------------------------------------------------------------
  localparam [2:0] ST_RUN     = 3'd0;
  localparam [2:0] ST_CLEAR   = 3'd1;
  localparam [2:0] ST_COPY_RD = 3'd2;
  localparam [2:0] ST_COPY_WR = 3'd3;
  localparam [2:0] ST_APPLY   = 3'd4;

  reg [2:0] s_state;

  //--------------------------------------------------------------------------
  // Parser states. P_DLE1/P_DLE2 (binary cursor addressing) and P_DCS/
  // P_DCS_ESC (skip a soft-key programming block) are new; P_ESC/P_ESCINT/
  // P_CSI carry the same shape as terminal_ctrl.v, dispatching different
  // finals.
  //--------------------------------------------------------------------------
  localparam [2:0] P_GROUND  = 3'd0;
  localparam [2:0] P_ESC     = 3'd1;
  localparam [2:0] P_ESCINT  = 3'd2;
  localparam [2:0] P_CSI     = 3'd3;
  localparam [2:0] P_DLE1    = 3'd4;  //! DLE seen, awaiting the row byte
  localparam [2:0] P_DLE2    = 3'd5;  //! row byte seen, awaiting the column byte
  localparam [2:0] P_DCS     = 3'd6;  //! inside ESC P ... - discard until ESC \
  localparam [2:0] P_DCS_ESC = 3'd7;  //! saw ESC while skipping a DCS block

  reg [2:0] p_state;
  reg [7:0] s_par  [0:3];
  reg [2:0] s_npar;
  reg       s_priv;
  reg       s_ign;
  reg [7:0] s_escint;
  reg [4:0] s_dle_row;  //! latched between P_DLE1 and P_DLE2

  //--------------------------------------------------------------------------
  // Terminal modes and rendition state - the subset TDV mode actually uses.
  // No DECOM/DECAWM/DECSTBM/LNM: not confirmed in any TDV capture, and an
  // unimplemented mode already swallows safely (see dispatch_csi).
  //--------------------------------------------------------------------------
  reg s_cursor_vis;

  reg s_at_rev, s_at_bold, s_at_ul, s_at_blink;
  reg s_shift;
  reg s_g0_gfx;
  reg s_g1_gfx;

  reg s_pending;  //! last-column flag - same VT100-derived autowrap behavior;
                  //! a TDV wraps too, and nothing in the captures says otherwise.

  reg [7:0] s_cl_row, s_cl_col, s_cl_erow, s_cl_ecol;

  reg [7:0] s_cp_dst;
  reg [7:0] s_cp_col;
  reg       s_cp_down;

  //! Deferred CUP commit - same two-phase reasoning as terminal_ctrl.v
  //! (latch operands one cycle, commit the next) to keep the combinational
  //! cone off the cursor registers short. TDV has no scroll region, so
  //! there is no floor/ceiling clamp to register separately - CUP clamps
  //! straight to the screen edges.
  reg       s_ap_cup;      //! 1 = a deferred CUP is in flight
  reg       s_ap_phase;
  reg [7:0] s_ap_row_q;
  reg [7:0] s_ap_col_q;

  assign ready = (s_state == ST_RUN) && !s_wr_hold;

  reg       s_wr_hold;
  reg [7:0] s_wr_char;

  //--------------------------------------------------------------------------
  // Address arithmetic - identical to terminal_ctrl.v.
  //--------------------------------------------------------------------------

  function automatic [7:0] stored_row;
    input [7:0] top;
    input [7:0] screen;
    reg [8:0] sum;
    begin
      sum = {1'b0, top} + {1'b0, screen};
      stored_row = (sum >= ROWS) ? (sum[7:0] - ROWS[7:0]) : sum[7:0];
    end
  endfunction

  function automatic [AWIDTH-1:0] cell_addr;
    input [7:0] row;
    input [7:0] col;
    begin
      cell_addr = {row, 6'b0} + {row, 4'b0} + col;
    end
  endfunction

  function automatic [7:0] dig_acc;
    input [7:0] cur;
    input [7:0] digit;
    reg [11:0] wide;
    begin
      wide = {4'd0, cur} * 12'd10 + {8'd0, digit[3:0]};
      dig_acc = (wide > 12'd255) ? 8'd255 : wide[7:0];
    end
  endfunction

  wire [7:0] s_cp_src = s_cp_down ? (s_cp_dst - 8'd1) : (s_cp_dst + 8'd1);
  assign ram_raddr2 = cell_addr(stored_row(top_row, s_cp_src), s_cp_col);

  //--------------------------------------------------------------------------
  // Cursor / attribute blink - identical to terminal_ctrl.v.
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

  assign cursor_enable = s_blink_on && s_cursor_vis;
  assign blink_on      = s_blink_on;

  //--------------------------------------------------------------------------
  // Screen movers - identical mechanics to terminal_ctrl.v, no DECSTBM
  // region (a TDV capture has never shown one; the ring always covers the
  // whole screen, which is the same code path terminal_ctrl.v uses for its
  // no-region case).
  //--------------------------------------------------------------------------

  task automatic start_clear;
    input [7:0] r1; input [7:0] c1;
    input [7:0] r2; input [7:0] c2;
    begin
      s_cl_row  <= r1;
      s_cl_col  <= c1;
      s_cl_erow <= r2;
      s_cl_ecol <= c2;
      s_state   <= ST_CLEAR;
    end
  endtask

  task automatic scroll_up;
    begin
      top_row <= (top_row == ROWS - 1) ? 8'd0 : (top_row + 8'd1);
      start_clear(ROWS[7:0] - 8'd1, 8'd0, ROWS[7:0] - 8'd1, COLS[7:0] - 8'd1);
    end
  endtask

  task automatic scroll_down;
    begin
      top_row <= (top_row == 8'd0) ? (ROWS[7:0] - 8'd1) : (top_row - 8'd1);
      start_clear(8'd0, 8'd0, 8'd0, COLS[7:0] - 8'd1);
    end
  endtask

  //! Cursor down (VT/LF); scrolls at the bottom row.
  task automatic do_index;
    begin
      if (cursor_row == ROWS - 1) scroll_up;
      else cursor_row <= cursor_row + 8'd1;
    end
  endtask

  //! Cursor up (FS); scrolls at the top row.
  task automatic do_rev_index;
    begin
      if (cursor_row == 8'd0) scroll_down;
      else cursor_row <= cursor_row - 8'd1;
    end
  endtask

  task automatic put_char;
    input [7:0] ch;
    begin
      ram_we    <= 1'b1;
      ram_waddr <= cell_addr(stored_row(top_row, cursor_row), cursor_col);
      ram_wdata <= {3'b000, (s_shift ? s_g1_gfx : s_g0_gfx),
                    s_at_blink, s_at_ul, s_at_bold, s_at_rev, ch};
      if (cursor_col == COLS - 1) begin
        s_pending <= 1'b1;
      end else begin
        cursor_col <= cursor_col + 8'd1;
      end
    end
  endtask

  task automatic reset_modes;
    begin
      top_row      <= 8'd0;
      cursor_col   <= 8'd0;
      cursor_row   <= 8'd0;
      s_cursor_vis <= 1'b1;
      rev_screen   <= 1'b0;
      s_at_rev     <= 1'b0;
      s_at_bold    <= 1'b0;
      s_at_ul      <= 1'b0;
      s_at_blink   <= 1'b0;
      s_shift      <= 1'b0;
      s_g0_gfx     <= 1'b0;
      s_g1_gfx     <= 1'b0;
      s_pending    <= 1'b0;
      leds         <= 4'b0000;
      p_state      <= P_GROUND;
    end
  endtask

  //--------------------------------------------------------------------------
  // CSI final dispatch. Only H/f (CUP), J (ED) and K (EL) are implemented -
  // the three confirmed in the captured PED startup plus EL for symmetry
  // with ED (both are ECMA-48 basics, cheap, and PED almost certainly uses
  // EL to redraw its status line the same way it does under VT100). Every
  // other final, INCLUDING every h/l mode set/reset (mode 62 among them,
  // "function unknown" per the real TDV2200 termcap's own init string) is
  // the existing `default: ;` - swallowed, never printed, never corrupts
  // parser state. That is deliberate: it is what lets an unknown mode
  // number arrive safely instead of needing to be enumerated first.
  //--------------------------------------------------------------------------

  task automatic dispatch_csi;
    input [7:0] fin;
    begin
      case (fin)
        "H", "f": begin
          s_pending  <= 1'b0;
          s_ap_cup   <= 1'b1;
          s_ap_phase <= 1'b0;
          s_state    <= ST_APPLY;
        end

        "J": begin
          s_pending <= 1'b0;
          case (s_par[0])
            8'd1: start_clear(8'd0, 8'd0, cursor_row, cursor_col);
            8'd2: start_clear(8'd0, 8'd0, ROWS[7:0] - 8'd1, COLS[7:0] - 8'd1);
            default: start_clear(cursor_row, cursor_col,
                                 ROWS[7:0] - 8'd1, COLS[7:0] - 8'd1);
          endcase
        end

        "K": begin
          s_pending <= 1'b0;
          case (s_par[0])
            8'd1: start_clear(cursor_row, 8'd0, cursor_row, cursor_col);
            8'd2: start_clear(cursor_row, 8'd0, cursor_row, COLS[7:0] - 8'd1);
            default: start_clear(cursor_row, cursor_col,
                                 cursor_row, COLS[7:0] - 8'd1);
          endcase
        end

        default: ;  // every h/l mode, every ND-private final: swallowed

      endcase
    end
  endtask

  //--------------------------------------------------------------------------
  // Main sequencer
  //--------------------------------------------------------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_state   <= ST_CLEAR;
      s_cl_row  <= 8'd0;
      s_cl_col  <= 8'd0;
      s_cl_erow <= ROWS[7:0] - 8'd1;
      s_cl_ecol <= COLS[7:0] - 8'd1;
      ram_we    <= 1'b0;
      ram_waddr <= {AWIDTH{1'b0}};
      ram_wdata <= BLANK_CELL;
      bell      <= 1'b0;
      s_wr_hold <= 1'b0;
      s_wr_char <= 8'd0;
      s_npar    <= 3'd0;
      s_priv    <= 1'b0;
      s_ign     <= 1'b0;
      s_escint  <= 8'd0;
      s_dle_row <= 5'd0;
      s_par[0]  <= 8'd0; s_par[1] <= 8'd0; s_par[2] <= 8'd0; s_par[3] <= 8'd0;
      s_cp_dst  <= 8'd0; s_cp_col <= 8'd0; s_cp_down <= 1'b0;
      s_ap_cup  <= 1'b0; s_ap_phase <= 1'b0;
      s_ap_row_q <= 8'd0; s_ap_col_q <= 8'd0;
      reset_modes;
    end else begin
      ram_we <= 1'b0;
      bell   <= 1'b0;

      case (s_state)

        //----------------------------------------------------------------
        ST_CLEAR: begin
          ram_we    <= 1'b1;
          ram_waddr <= cell_addr(stored_row(top_row, s_cl_row), s_cl_col);
          ram_wdata <= BLANK_CELL;

          if (s_cl_row == s_cl_erow && s_cl_col == s_cl_ecol) begin
            s_state <= ST_RUN;
          end else if (s_cl_col == COLS - 1) begin
            s_cl_col <= 8'd0;
            s_cl_row <= s_cl_row + 8'd1;
          end else begin
            s_cl_col <= s_cl_col + 8'd1;
          end
        end

        //----------------------------------------------------------------
        ST_COPY_RD: begin
          s_state <= ST_COPY_WR;
        end

        ST_COPY_WR: begin
          ram_we    <= 1'b1;
          ram_waddr <= cell_addr(stored_row(top_row, s_cp_dst), s_cp_col);
          ram_wdata <= ram_rdata2;

          if (s_cp_col != COLS - 1) begin
            s_cp_col <= s_cp_col + 8'd1;
            s_state  <= ST_COPY_RD;
          end else begin
            s_cp_col <= 8'd0;
            s_cp_dst <= s_cp_dst + 8'd1;
            s_state  <= ST_COPY_RD;
          end
        end

        //----------------------------------------------------------------
        // Deferred CUP commit - see the s_ap_cup declaration for why this
        // is two phases.
        //----------------------------------------------------------------
        ST_APPLY: begin
          if (!s_ap_phase) begin
            s_ap_row_q <= s_par[0];
            s_ap_col_q <= s_par[1];
            s_ap_phase <= 1'b1;
          end else begin
            s_ap_cup <= 1'b0;
            s_state  <= ST_RUN;
            cursor_row <= (s_ap_row_q == 8'd0) ? 8'd0
                        : (s_ap_row_q >= ROWS) ? (ROWS[7:0] - 8'd1)
                        : (s_ap_row_q - 8'd1);
            cursor_col <= (s_ap_col_q == 8'd0) ? 8'd0
                        : (s_ap_col_q >= COLS) ? (COLS[7:0] - 8'd1)
                        : (s_ap_col_q - 8'd1);
          end
        end

        //----------------------------------------------------------------
        ST_RUN: begin
          if (s_wr_hold) begin
            s_wr_hold <= 1'b0;
            put_char(s_wr_char);
          end else if (byte_valid) begin

            //--------------------------------------------------------------
            // RAW-BYTE-CAPTURE states first: P_DLE1/P_DLE2 (the two binary
            // cursor-addressing bytes) and P_DCS (the soft-key programming
            // payload) must see EVERY byte value literally, including ones
            // below 0x20 - a row/column byte or a payload byte is routinely
            // < 0x20 and must NOT be reinterpreted as a C0 control. This is
            // checked before the general C0 dispatch below, which otherwise
            // would steal those bytes (found by the testbench: DLE's own
            // row/col bytes, and the DCS terminator's own ESC, were both
            // being caught here first).
            //--------------------------------------------------------------
            if (p_state == P_DLE1) begin
              s_dle_row <= byte_data[4:0];
              p_state   <= P_DLE2;
            end else if (p_state == P_DLE2) begin
              p_state    <= P_GROUND;
              s_pending  <= 1'b0;
              cursor_row <= (s_dle_row >= ROWS[4:0]) ? (ROWS[7:0]-8'd1) : {3'b000, s_dle_row};
              cursor_col <= (byte_data[6:0] >= COLS[6:0]) ? (COLS[7:0]-8'd1) : {1'b0, byte_data[6:0]};
            end else if (p_state == P_DCS) begin
              if (byte_data == 8'h1B) p_state <= P_DCS_ESC;
              // else: still inside the DCS payload, discard the byte.
            end else if (p_state == P_DCS_ESC) begin
              if (byte_data == "\\") p_state <= P_GROUND;  // ST - done
              else p_state <= P_DCS;  // not the terminator, keep skipping

            //--------------------------------------------------------------
            // C0 controls - TDV-NATIVE meanings, not ASCII ones. This block
            // is the core difference from terminal_ctrl.v. DLE and ESC hand
            // off to their own parser states; everything else executes
            // immediately without disturbing whatever state p_state is in
            // (matching terminal_ctrl.v's "an executable C0 arriving inside
            // a sequence executes without abandoning it" rule - real hosts
            // do this, and nothing here has evidence it does NOT apply to
            // a TDV too).
            //--------------------------------------------------------------
            end else if (byte_data < 8'h20) begin
              case (byte_data)
                8'h02, 8'h03: ;                                          // STX/ETX video off/on - not modeled
                8'h04: start_clear(cursor_row, 8'd0, cursor_row, COLS[7:0]-8'd1);  // EOT erase line
                8'h05: leds[0] <= 1'b1;                                  // ENQ LED1 on
                8'h06: leds[1] <= 1'b1;                                  // ACK LED2 on
                8'h07: bell <= 1'b1;                                     // BEL
                8'h08: begin s_pending <= 1'b0; if (cursor_col != 0) cursor_col <= cursor_col - 8'd1; end  // BS cursor left
                8'h09: begin                                             // HT
                  s_pending <= 1'b0;
                  if (((cursor_col / TAB_STOP) + 8'd1) * TAB_STOP >= COLS)
                    cursor_col <= COLS[7:0] - 8'd1;
                  else
                    cursor_col <= ((cursor_col / TAB_STOP) + 8'd1) * TAB_STOP;
                end
                8'h0A: begin s_pending <= 1'b0; do_index; end            // LF cursor down
                8'h0B: begin s_pending <= 1'b0; do_index; end            // VT cursor down
                8'h0C: begin s_pending <= 1'b0; do_rev_index; end        // FF roll up (scroll back)
                8'h0D: begin s_pending <= 1'b0; cursor_col <= 8'd0; end  // CR
                8'h0E: s_shift <= 1'b1;                                  // SO -> G1
                8'h0F: s_shift <= 1'b0;                                  // SI -> G0
                8'h10: p_state <= P_DLE1;                                // DLE - binary cursor addressing
                8'h15: leds[2] <= 1'b1;                                  // NAK LED3 on
                8'h16: leds <= 4'b0000;                                  // SYN all lamps off
                8'h17: begin s_pending <= 1'b0; do_index; end            // ETB roll down (scroll forward)
                8'h18: begin s_pending <= 1'b0; if (cursor_col != COLS-1) cursor_col <= cursor_col + 8'd1; end  // CAN cursor right
                8'h19: start_clear(8'd0, 8'd0, ROWS[7:0]-8'd1, COLS[7:0]-8'd1);  // EM erase page
                8'h1B: begin                                             // ESC
                  p_state <= P_ESC;
                  s_npar  <= 3'd0;
                  s_priv  <= 1'b0;
                  s_ign   <= 1'b0;
                  s_par[0] <= 8'd0; s_par[1] <= 8'd0;
                  s_par[2] <= 8'd0; s_par[3] <= 8'd0;
                end
                8'h1C: begin s_pending <= 1'b0; do_rev_index; end        // FS cursor up
                8'h1D: begin                                             // GS cursor home
                  s_pending  <= 1'b0;
                  cursor_row <= 8'd0;
                  cursor_col <= 8'd0;
                end
                default: ;  // NUL and anything else: dropped
              endcase

            end else begin
              case (p_state)

                //--------------------------------------------------------
                P_GROUND: begin
                  if (byte_data < 8'h7F) begin
                    if (s_pending) begin
                      s_pending  <= 1'b0;
                      cursor_col <= 8'd0;
                      s_wr_hold  <= 1'b1;
                      s_wr_char  <= byte_data;
                      do_index;
                    end else begin
                      put_char(byte_data);
                    end
                  end
                  // 0x7F DEL as a display byte, and 0x80-0xFF: dropped.
                end

                // P_DLE1/P_DLE2/P_DCS/P_DCS_ESC are handled in the
                // raw-byte-capture branch above, before this switch is
                // ever reached - they cannot appear here.

                //--------------------------------------------------------
                P_ESC: begin
                  p_state <= P_GROUND;
                  case (byte_data)
                    "[": p_state <= P_CSI;
                    "P": p_state <= P_DCS;             // DCS - see above
                    8'h20, "#", "(", ")", "*", "+", "%": begin
                      s_escint <= byte_data;
                      p_state  <= P_ESCINT;
                    end
                    "c": begin                          // RIS-equivalent full reset
                      reset_modes;
                      start_clear(8'd0, 8'd0, ROWS[7:0] - 8'd1, COLS[7:0] - 8'd1);
                    end
                    // "Q" (exit/enable EC switch) and anything else
                    // unrecognised: swallowed.
                    default: ;
                  endcase
                end

                //--------------------------------------------------------
                // ESC + intermediate - character-set DESIGNATION bytes are
                // consumed correctly (so they never leak as garbage text)
                // but only the existing DEC-graphics font page actually
                // renders differently, same conservative choice
                // terminal_ctrl.v makes - see the header.
                //--------------------------------------------------------
                P_ESCINT: begin
                  if (byte_data >= 8'h20 && byte_data <= 8'h2F) begin
                    s_escint <= byte_data;
                  end else begin
                    p_state <= P_GROUND;
                    case (s_escint)
                      "(": s_g0_gfx <= (byte_data == "0");
                      ")": s_g1_gfx <= (byte_data == "0");
                      default: ;
                    endcase
                  end
                end

                //--------------------------------------------------------
                P_CSI: begin
                  if (byte_data >= "0" && byte_data <= "9") begin
                    if (s_npar == 3'd0) begin
                      s_npar   <= 3'd1;
                      s_par[0] <= dig_acc(s_par[0], byte_data);
                    end else if (s_npar <= 3'd4) begin
                      s_par[s_npar[1:0] - 2'd1]
                        <= dig_acc(s_par[s_npar[1:0] - 2'd1], byte_data);
                    end
                  end else if (byte_data == ";") begin
                    if (s_npar == 3'd0) s_npar <= 3'd2;
                    else if (s_npar < 3'd4) s_npar <= s_npar + 3'd1;
                    else s_ign <= 1'b1;
                  end else if (byte_data >= 8'h3C && byte_data <= 8'h3F) begin
                    s_priv <= 1'b1;
                  end else if (byte_data >= 8'h20 && byte_data <= 8'h2F) begin
                    s_ign <= 1'b1;
                  end else if (byte_data >= 8'h40 && byte_data <= 8'h7E) begin
                    p_state <= P_GROUND;
                    if (!s_ign) dispatch_csi(byte_data);
                  end else begin
                    p_state <= P_GROUND;
                  end
                end

                default: p_state <= P_GROUND;

              endcase
            end
          end
        end

        //----------------------------------------------------------------
        default: s_state <= ST_RUN;

      endcase
    end
  end

endmodule

`default_nettype wire
