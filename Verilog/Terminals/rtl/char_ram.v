//============================================================================
//! Character RAM - one 16-bit cell per screen position, true dual port
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! Cell layout:
//!     [ 7:0] character code, indexes the font ROM
//!     [15:8] attributes. Stage A uses only bit 8 (reverse video); the rest
//!            are reserved so the width never has to change when the VT100
//!            attributes arrive (see the plan, Stage B).
//!
//! Port A is the write side, owned by terminal_ctrl. Port B is the read side,
//! owned by the pixel pipeline in text_screen. One clock of read latency,
//! registered output - that is what infers a block RAM rather than LUTs.
//!
//! 80 x 25 x 2 bytes = 4000 bytes. On the Nexys 4 DDR's xc7a100t (~607 KB of
//! block RAM) that is noise; stated here so nobody has to wonder.
//!
//! Both ports are on the same clock (the pixel clock). Bytes arriving from the
//! CPU cross into that domain BEFORE this module - see terminal_top.v.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module char_ram #(
    parameter integer COLS  = 80,
    parameter integer ROWS  = 25,
    parameter integer AWIDTH = 11   //! ceil(log2(80*25 = 2000)) = 11
) (
    input wire clk,

    // Write port (terminal_ctrl)
    input wire              we,
    input wire [AWIDTH-1:0] waddr,
    input wire [      15:0] wdata,

    // Read port (pixel pipeline)
    input  wire [AWIDTH-1:0] raddr,
    output reg  [      15:0] rdata
);

  localparam integer CELLS = COLS * ROWS;

  (* ram_style = "block" *)
  reg [15:0] s_cells[0:CELLS-1];

  // Simulation starts with a blank screen of spaces. On real hardware the
  // power-up contents are whatever the tool put there, so terminal_ctrl clears
  // the screen on reset regardless - this initial block only stops a fresh
  // testbench rendering X's before the first clear finishes.
  integer i;
  initial begin
    for (i = 0; i < CELLS; i = i + 1) s_cells[i] = {8'h00, 8'h20};
  end

  always @(posedge clk) begin
    if (we) s_cells[waddr] <= wdata;
    rdata <= s_cells[raddr];
  end

endmodule

`default_nettype wire
