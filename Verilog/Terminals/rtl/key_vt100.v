//============================================================================
//! VT100 key-sequence expander - markers in, wire bytes out
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! Sits between the keyboard decoder and the console UART TX. Ordinary bytes
//! pass through unchanged; a SEQUENCE MARKER (bit 7 set, written by
//! ps2_ascii_table.v for the arrows and HOME) becomes the three bytes
//! ESC [ f, where f is the marker's low seven bits. This is what makes the
//! keyboard speak VT100 (SINTRAN terminal type 6): one keypress, three bytes
//! on the wire.
//!
//! WHY THE FIFO. The UART needs ~870 us for a byte at 115200-7E1 and this
//! expander hands it three at once - without buffering, two of the three
//! would be lost (which is why the single-byte TDV encoding never needed
//! this module). Eight entries is two full sequences of headroom over the
//! worst case; keypresses are milliseconds apart, so the FIFO in practice
//! never holds more than one sequence.
//!
//! HANDSHAKE, downstream side: console_uart_tx's contract is "byte_valid one
//! clock; ignored unless ready", with ready = idle. So this module pulses
//! out_valid for exactly one clock while out_ready is high, then waits for
//! ready to DROP (the byte was taken) and rise again (the frame finished)
//! before offering the next byte. If ready did not drop - which the current
//! UART cannot do, but a future one might - the byte is offered again rather
//! than lost.
//!
//! Upstream side: key_valid is a one-clock strobe with no backpressure (the
//! PS/2 decoder cannot wait). A marker takes three clocks to push; a key
//! landing INSIDE that window would be dropped - at 40 MHz that window is
//! 75 ns against keypresses milliseconds apart, so it cannot happen from a
//! keyboard. A full FIFO also drops (and a full FIFO from typing means the
//! machine end is wedged, where dropped keys are the least of it).
//!
//! Written 30-AUG-2026.
//============================================================================

`default_nettype none

module key_vt100 (
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
  // The FIFO - 8 bytes, pointers one bit wider than the index so full and
  // empty are distinct (same construction as byte_fifo.v).
  //--------------------------------------------------------------------------
  reg [7:0] s_mem[0:7];
  reg [3:0] s_wptr, s_rptr;

  wire s_empty = (s_wptr == s_rptr);
  wire s_full  = (s_wptr[3] != s_rptr[3]) && (s_wptr[2:0] == s_rptr[2:0]);

  //--------------------------------------------------------------------------
  // Push side - expands a marker over three clocks
  //--------------------------------------------------------------------------
  localparam [1:0] PU_IDLE  = 2'd0;
  localparam [1:0] PU_BRACK = 2'd1;  //! '[' goes in this clock
  localparam [1:0] PU_FINAL = 2'd2;  //! the final byte goes in this clock

  reg [1:0] s_push;
  reg [7:0] s_final;

  //--------------------------------------------------------------------------
  // Pop side - one UART handshake at a time
  //--------------------------------------------------------------------------
  localparam [1:0] PO_IDLE = 2'd0;
  localparam [1:0] PO_TAKE = 2'd1;  //! offered; waiting to see ready drop

  reg [1:0] s_pop;
  reg       s_po_seen;  //! PO_TAKE has been through one full cycle

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_wptr    <= 4'd0;
      s_rptr    <= 4'd0;
      s_push    <= PU_IDLE;
      s_final   <= 8'd0;
      s_pop     <= PO_IDLE;
      out_valid <= 1'b0;
      out_data  <= 8'd0;
    end else begin
      out_valid <= 1'b0;

      // ---- push ----
      case (s_push)
        PU_IDLE: begin
          if (key_valid && !s_full) begin
            if (key_data[7]) begin
              s_mem[s_wptr[2:0]] <= ESC;
              s_wptr  <= s_wptr + 4'd1;
              s_final <= {1'b0, key_data[6:0]};
              s_push  <= PU_BRACK;
            end else begin
              s_mem[s_wptr[2:0]] <= key_data;
              s_wptr <= s_wptr + 4'd1;
            end
          end
        end
        PU_BRACK: begin
          if (!s_full) begin
            s_mem[s_wptr[2:0]] <= "[";
            s_wptr <= s_wptr + 4'd1;
            s_push <= PU_FINAL;
          end
        end
        PU_FINAL: begin
          if (!s_full) begin
            s_mem[s_wptr[2:0]] <= s_final;
            s_wptr <= s_wptr + 4'd1;
            s_push <= PU_IDLE;
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
            out_data  <= s_mem[s_rptr[2:0]];
            s_pop     <= PO_TAKE;
          end
        end
        PO_TAKE: begin
          // TIMING, counted in edges. The offer was committed at edge k, so
          // valid is high during cycle k+1 and the UART accepts at edge k+1;
          // its busy flag is then visible (ready low) during cycle k+2 -
          // which is the SECOND PO_TAKE cycle. So: the first cycle here can
          // never see the drop and is skipped; from the second on, ready low
          // = taken (advance), ready still high = the UART ignored the pulse,
          // and PO_IDLE re-offers the same byte rather than losing it.
          if (!s_po_seen) begin
            s_po_seen <= 1'b1;
          end else begin
            if (!out_ready) s_rptr <= s_rptr + 4'd1;
            s_pop <= PO_IDLE;
          end
        end
        default: s_pop <= PO_IDLE;
      endcase
    end
  end

endmodule

`default_nettype wire
