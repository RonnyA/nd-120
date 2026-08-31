//============================================================================
//! 8x16 character generator ROM - one pixel row per read
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! Four 128-glyph pages x 16 rows x 8 pixels = 8192 bytes. Address is
//! {char_code, row}; data is the pixel row, MSB = leftmost pixel. char_code
//! is {page[1:0], code[6:0]}: page 0 = US / ISO 646 IRV, page 1 = Norwegian
//! (NS 4551-1), page 2 = DEC Special Graphics (VT100 line drawing), page 3 =
//! TDV2200 Box (ESC 6 / NDSS6 line drawing).
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
    input  wire [8:0] char_code,  //! {page[1:0], code[6:0]}
    input  wire [3:0] row,        //! which of its 16 pixel rows
    output reg  [7:0] pixels      //! that row, MSB = leftmost. Valid one clock later
);

  (* rom_style = "block" *)
  reg [7:0] s_rom[0:8191];

  initial begin
    $readmemh(FONT_FILE, s_rom);
  end

  always @(posedge clk) begin
    pixels <= s_rom[{char_code, row}];
  end

endmodule

`default_nettype wire
