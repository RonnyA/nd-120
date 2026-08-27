//============================================================================
//! 8x16 character generator ROM - one pixel row per read
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! 256 characters x 16 rows x 8 pixels = 4096 bytes. Address is
//! {char_code, row}; data is the pixel row, MSB = leftmost pixel.
//!
//! The contents come from Verilog/Terminals/font/font8x16.hex, built by
//! font/make_font.py out of a Linux PSF console font. Regenerate rather than
//! hand-edit. $readmemh resolves the path RELATIVE TO THE .v SOURCE in Vivado
//! (see the project memory note about readmemh search paths), so the default
//! reaches up out of rtl/ into font/. Boards whose tool disagrees can override
//! FONT_FILE rather than move the data.
//!
//! One clock of read latency, registered output - that is what infers a block
//! RAM on both Xilinx and Intel rather than a pile of LUTs.
//!
//! Written 27-AUG-2026.
//============================================================================

`default_nettype none

module font_rom #(
    parameter FONT_FILE = "../font/font8x16.hex"
) (
    input  wire       clk,        //! pixel clock
    input  wire [7:0] char_code,  //! which character
    input  wire [3:0] row,        //! which of its 16 pixel rows
    output reg  [7:0] pixels      //! that row, MSB = leftmost. Valid one clock later
);

  (* rom_style = "block" *)
  reg [7:0] s_rom[0:4095];

  initial begin
    $readmemh(FONT_FILE, s_rom);
  end

  always @(posedge clk) begin
    pixels <= s_rom[{char_code, row}];
  end

endmodule

`default_nettype wire
