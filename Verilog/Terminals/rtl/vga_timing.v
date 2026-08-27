//============================================================================
//! VGA timing generator - pixel/line counters, sync and blanking
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Plan: Verilog/Terminals/docs/PLAN-vt100-terminal-core.md
//!
//! Defaults are 800x600 @ 60 Hz, "VESA discrete monitor timing":
//!     pixel clock 40.000 MHz
//!     horizontal  800 visible, 40 front porch, 128 sync, 88 back porch = 1056
//!     vertical    600 visible,  1 front porch,   4 sync,  23 back porch =  628
//!     sync polarity POSITIVE on both H and V
//!     40e6 / (1056 * 628) = 60.32 Hz
//!
//! Why 800x600 and not 640x480: on the Nexys 4 DDR the existing MMCM runs a
//! 1000 MHz VCO, so an integer divide of 25 gives EXACTLY 40.000 MHz. The
//! 640x480 pixel clock (25.175 MHz) is not reachable from that VCO - the
//! closest is 25.000 MHz, 0.7% low. See fpga/nexys4ddr/PLAN-vga-console.md.
//!
//! Everything is a parameter, so a board that wants a different mode changes
//! numbers rather than code.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module vga_timing #(
    // Horizontal, in pixel clocks
    parameter integer H_VISIBLE     = 800,
    parameter integer H_FRONT_PORCH = 40,
    parameter integer H_SYNC        = 128,
    parameter integer H_BACK_PORCH  = 88,

    // Vertical, in lines
    parameter integer V_VISIBLE     = 600,
    parameter integer V_FRONT_PORCH = 1,
    parameter integer V_SYNC        = 4,
    parameter integer V_BACK_PORCH  = 23,

    //! 1 = sync pulse is high while active (800x600 wants positive on both).
    //! 640x480 would want 0 on both - the one thing that changes with the mode
    //! besides the counts.
    parameter         H_SYNC_POSITIVE = 1'b1,
    parameter         V_SYNC_POSITIVE = 1'b1
) (
    input wire clk,      //! pixel clock
    input wire rst_n,    //! async reset, active low

    output wire [11:0] x,        //! visible pixel column, 0..H_VISIBLE-1 (only valid while de)
    output wire [11:0] y,        //! visible pixel row,    0..V_VISIBLE-1 (only valid while de)
    output wire        hsync,    //! horizontal sync, polarity per H_SYNC_POSITIVE
    output wire        vsync,    //! vertical sync,   polarity per V_SYNC_POSITIVE
    output wire        de,       //! display enable = in the visible area (~(hblank|vblank))
    output wire        hblank,   //! outside the visible area horizontally
    output wire        vblank,   //! outside the visible area vertically
    output wire        line_end, //! one pulse at the last pixel clock of every line
    output wire        frame_end //! one pulse at the last pixel clock of every frame
);

  localparam integer H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;
  localparam integer V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

  // Sync starts after the front porch and lasts H_SYNC / V_SYNC ticks.
  localparam integer H_SYNC_START = H_VISIBLE + H_FRONT_PORCH;
  localparam integer H_SYNC_END   = H_SYNC_START + H_SYNC;
  localparam integer V_SYNC_START = V_VISIBLE + V_FRONT_PORCH;
  localparam integer V_SYNC_END   = V_SYNC_START + V_SYNC;

  reg [11:0] s_hcount;
  reg [11:0] s_vcount;

  //! last pixel clock of a line / of a frame - used to advance the counters and
  //! exported so the character generator can do its per-line and per-frame work
  //! (cursor blink, row address reload) without re-deriving them.
  assign line_end  = (s_hcount == H_TOTAL - 1);
  assign frame_end = line_end && (s_vcount == V_TOTAL - 1);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_hcount <= 12'd0;
      s_vcount <= 12'd0;
    end else begin
      if (line_end) begin
        s_hcount <= 12'd0;
        s_vcount <= frame_end ? 12'd0 : (s_vcount + 12'd1);
      end else begin
        s_hcount <= s_hcount + 12'd1;
      end
    end
  end

  assign hblank = (s_hcount >= H_VISIBLE);
  assign vblank = (s_vcount >= V_VISIBLE);
  assign de     = !hblank && !vblank;

  // x and y are only meaningful inside the visible area; outside it they keep
  // counting, which costs nothing and makes the counters easy to watch in a
  // waveform. Consumers must gate on `de`.
  assign x = s_hcount;
  assign y = s_vcount;

  // The raw sync window, then the polarity applied. Kept in two steps because
  // getting the polarity backwards is the classic "monitor says no signal" bug
  // and this way the window itself is readable in a waveform.
  wire s_hsync_window = (s_hcount >= H_SYNC_START) && (s_hcount < H_SYNC_END);
  wire s_vsync_window = (s_vcount >= V_SYNC_START) && (s_vcount < V_SYNC_END);

  assign hsync = H_SYNC_POSITIVE ? s_hsync_window : ~s_hsync_window;
  assign vsync = V_SYNC_POSITIVE ? s_vsync_window : ~s_vsync_window;

endmodule

`default_nettype wire
