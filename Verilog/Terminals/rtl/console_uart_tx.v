//============================================================================
//! Console UART transmitter - sends keyboard bytes into the machine's RX line
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! The mirror of console_uart_rx: a key press becomes a serial character on
//! the ND-120's console RX pin, so the machine cannot tell the difference
//! between the local keyboard and the PC terminal.
//!
//! MERGING WITH THE PC'S LINE. Both sources idle HIGH, so two transmitters can
//! share one receive pin by ANDing them - whichever one is sending pulls the
//! line, the idle one contributes 1s. That is exactly the idiom the Nexys top
//! already uses on the way out (`uart_rxd_out = cpu_txd & s_errfa_txd &
//! s_wdiox_txd`). It garbles a character only if somebody types on the
//! keyboard at the same moment the PC sends one, which is a person's problem,
//! not a design flaw.
//!
//! Framing must match console_uart_rx and the machine - see the long note in
//! that file about the SC2661 being software programmable.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module console_uart_tx #(
    parameter integer CLK_HZ    = 40_000_000,
    parameter integer BAUD      = 115200,
    parameter integer DATA_BITS = 7,      //! 7 or 8
    parameter         PARITY    = 1'b1,   //! 1 = send a parity bit
    parameter         PARITY_ODD = 1'b0   //! 0 = even parity, 1 = odd
) (
    input wire clk,
    input wire rst_n,

    input  wire       byte_valid,  //! one clock; ignored unless ready
    input  wire [7:0] byte_data,
    output wire       ready,       //! high when idle

    output reg txd  //! the serial line, idle high
);

  localparam integer DIVISOR = CLK_HZ / BAUD;
  //! start + data + optional parity + stop
  localparam integer FRAME_BITS = 1 + DATA_BITS + (PARITY ? 1 : 0) + 1;

  reg [15:0] s_count;
  reg [ 3:0] s_bit_index;
  reg [11:0] s_frame;   //! the whole frame, shifted out LSB first
  reg        s_busy;

  assign ready = !s_busy;

  //! Build the frame where it is used, inside the clocked block. An earlier
  //! version assembled it in a wide continuous assignment off the byte_data
  //! port; in simulation the frame came out holding the PREVIOUS byte while
  //! byte_data already held the new one, so every character went out one
  //! transmission late. Building it here removes the question entirely - the
  //! frame is made from the byte at the instant the byte is accepted.
  //!
  //! Frame is LSB-first: start(0), data, parity if enabled, stop(1). Unused
  //! high bits are 1 so the line stays idle-high after the stop bit.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_count      <= 16'd0;
      s_bit_index  <= 4'd0;
      s_frame      <= {12{1'b1}};
      s_busy       <= 1'b0;
      txd          <= 1'b1;
    end else begin
      if (!s_busy) begin
        txd <= 1'b1;
        if (byte_valid) begin
          if (PARITY) begin
            s_frame <= {{(12 - (DATA_BITS + 3)){1'b1}},          // idle padding
                        1'b1,                                     // stop
                        (PARITY_ODD ? ~(^byte_data[DATA_BITS-1:0])
                                    :  (^byte_data[DATA_BITS-1:0])),
                        byte_data[DATA_BITS-1:0],                 // data, LSB first
                        1'b0};                                    // start
          end else begin
            s_frame <= {{(12 - (DATA_BITS + 2)){1'b1}},
                        1'b1,
                        byte_data[DATA_BITS-1:0],
                        1'b0};
          end

          s_busy      <= 1'b1;
          s_count     <= 16'd0;
          s_bit_index <= 4'd0;
          txd         <= 1'b0;  // start bit goes out immediately
        end
      end else begin
        if (s_count == DIVISOR - 1) begin
          s_count <= 16'd0;
          if (s_bit_index == FRAME_BITS - 1) begin
            s_busy <= 1'b0;
            txd    <= 1'b1;
          end else begin
            s_bit_index <= s_bit_index + 4'd1;
            s_frame     <= {1'b1, s_frame[11:1]};
            txd         <= s_frame[1];
          end
        end else begin
          s_count <= s_count + 16'd1;
        end
      end
    end
  end

endmodule

`default_nettype wire
