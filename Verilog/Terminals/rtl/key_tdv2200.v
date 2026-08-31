//============================================================================
//! TDV2200 key-sequence expander - markers in, wire bytes out
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Sibling of key_vt100.v. Ordinary bytes (including the TDV's bare C0
//! cursor/Home/Delete codes - see ps2_ascii_table_tdv.v) pass through
//! unchanged; a SEQUENCE MARKER (bit 7 set) becomes ESC [ <2-digit n> _,
//! per TDV2200KeyRegistry.cs / FINDINGS-2026-08-20.md (ground truth cited
//! in ps2_ascii_table_tdv.v's header). Unlike VT100 this is the ONLY
//! sequence family a TDV keyboard sends - one fixed 5-byte shape, always
//! two ASCII decimal digits, zero-padded (n=0 is "ESC[00_", not "ESC[0_").
//!
//! Same FIFO/handshake reasoning as key_vt100.v: the UART needs ~870 us per
//! byte at 115200-8N1 and this expander hands it up to 5 at once.
//!
//! Written 31-AUG-2026.
//============================================================================

`default_nettype none

module key_tdv2200 (
    input wire clk,
    input wire rst_n,

    // From the keyboard decoder - strobes, no backpressure
    input wire       key_valid,
    input wire [7:0] key_data,

    // To the console UART TX
    output reg        out_valid,  //! one clock, only while out_ready
    output reg  [7:0] out_data,
    input  wire       out_ready   //! the UART's "idle" flag
);

  localparam [7:0] ESC = 8'h1B;

  //--------------------------------------------------------------------------
  // The FIFO - 16 bytes, pointers one bit wider than the index so full and
  // empty are distinct (same construction as byte_fifo.v / key_vt100.v).
  //--------------------------------------------------------------------------
  reg [7:0] s_mem[0:15];
  reg [4:0] s_wptr, s_rptr;

  wire s_empty = (s_wptr == s_rptr);
  wire s_full  = (s_wptr[4] != s_rptr[4]) && (s_wptr[3:0] == s_rptr[3:0]);

  //--------------------------------------------------------------------------
  // Push side - expands a marker over 4 clocks: ESC now, '[' / tens / ones
  // / '_' lined up in s_q0..s_q3 for the next three.
  //--------------------------------------------------------------------------
  localparam PU_IDLE = 1'b0;
  localparam PU_SEQ  = 1'b1;

  reg       s_push;
  reg [7:0] s_q0, s_q1, s_q2;  //! the 3 bytes after ESC: '[', tens, ones - '_' is q2? no, 4 bytes follow ESC
  reg [7:0] s_q3;
  reg [1:0] s_idx;

  //! n is 0..67 by construction (bits[6:0] of the marker); always two ASCII
  //! decimal digits, zero-padded.
  wire [6:0] s_n    = key_data[6:0];
  wire [7:0] s_tens = "0" + (s_n / 7'd10);
  wire [7:0] s_ones = "0" + (s_n % 7'd10);

  //--------------------------------------------------------------------------
  // Pop side - one UART handshake at a time (identical contract/timing to
  // key_vt100.v - see that file's header for the full reasoning).
  //--------------------------------------------------------------------------
  localparam [1:0] PO_IDLE = 2'd0;
  localparam [1:0] PO_TAKE = 2'd1;

  reg [1:0] s_pop;
  reg       s_po_seen;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_wptr    <= 5'd0;
      s_rptr    <= 5'd0;
      s_push    <= PU_IDLE;
      s_q0 <= 8'd0; s_q1 <= 8'd0; s_q2 <= 8'd0; s_q3 <= 8'd0;
      s_idx     <= 2'd0;
      s_pop     <= PO_IDLE;
      out_valid <= 1'b0;
      out_data  <= 8'd0;
    end else begin
      out_valid <= 1'b0;

      // ---- push ----
      case (s_push)
        PU_IDLE: begin
          if (key_valid && !s_full) begin
            if (!key_data[7]) begin
              s_mem[s_wptr[3:0]] <= key_data;
              s_wptr <= s_wptr + 5'd1;
            end else begin
              // A marker: ESC now, "[ tens ones _" lined up for PU_SEQ.
              s_mem[s_wptr[3:0]] <= ESC;
              s_wptr <= s_wptr + 5'd1;
              s_push <= PU_SEQ;
              s_idx  <= 2'd0;
              s_q0   <= "[";
              s_q1   <= s_tens;
              s_q2   <= s_ones;
              s_q3   <= "_";
            end
          end
        end
        PU_SEQ: begin
          if (!s_full) begin
            s_mem[s_wptr[3:0]] <= (s_idx == 2'd0) ? s_q0
                                : (s_idx == 2'd1) ? s_q1
                                : (s_idx == 2'd2) ? s_q2 : s_q3;
            s_wptr <= s_wptr + 5'd1;
            if (s_idx == 2'd3) s_push <= PU_IDLE;
            else s_idx <= s_idx + 2'd1;
          end
        end
        default: s_push <= PU_IDLE;
      endcase

      // ---- pop ----
      case (s_pop)
        PO_IDLE: begin
          s_po_seen <= 1'b0;
          if (!s_empty && out_ready) begin
            out_valid <= 1'b1;
            out_data  <= s_mem[s_rptr[3:0]];
            s_pop     <= PO_TAKE;
          end
        end
        PO_TAKE: begin
          if (!s_po_seen) begin
            s_po_seen <= 1'b1;
          end else begin
            if (!out_ready) s_rptr <= s_rptr + 5'd1;
            s_pop <= PO_IDLE;
          end
        end
        default: s_pop <= PO_IDLE;
      endcase
    end
  end

endmodule

`default_nettype wire
