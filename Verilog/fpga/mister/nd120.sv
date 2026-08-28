//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"ND120;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
	"O[6],Keyboard,US,Norwegian;",
	"-;",
	// Build 1 has no ND-120 in it, so there is nothing here to configure yet.
	// Resisting the urge to leave the template's demo options in place: an
	// option that does nothing is worse than no option, because the first
	// thing anyone does with a new core is turn things on to see what happens.
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,0;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),
	
	.ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

// 50 MHz in -> 40.000 MHz out: the pixel clock for 800x600@60. See the note
// at the top of rtl/pll.v - the frequency is a string parameter in the
// generated IP, changed there rather than through the Quartus GUI.
wire clk_sys;
wire pll_locked;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////   RESET, TIED TO PLL LOCK   ///////////////////////////

// Hold the console in reset until the PLL has locked AND a few thousand
// clocks have passed. Releasing logic onto a clock that is still moving is a
// good way to get a design that works on one board and not the next, and it
// costs one counter to rule out.
reg [11:0] rst_cnt = 0;
reg        pix_rst_n = 0;
always @(posedge clk_sys) begin
	if (reset || !pll_locked) begin
		rst_cnt   <= 0;
		pix_rst_n <= 0;
	end else if (!rst_cnt[11]) begin
		rst_cnt   <= rst_cnt + 1'd1;
		pix_rst_n <= 0;
	end else begin
		pix_rst_n <= 1;
	end
end

////////////////////////////   CONSOLE   /////////////////////////////////////

// BUILD 1: the terminal only. No ND3202D, deliberately - see the header of
// rtl/nd120_console_mister.v. Type and the characters appear; that proves the
// clock, the video timing, the font ROM, the character RAM, the scroll
// mapping and the keyboard with nothing of the CPU able to be blamed.

wire con_pixel, con_hs, con_vs, con_de, con_bell;
wire [2:0] con_colour;

nd120_console_mister #(
	.FONT_FILE("font8x16.hex"),   // found via SEARCH_PATH or the make font copy
	.LOCAL_ECHO(1)          // build 2 sets this to 0 - the ND-120 echoes
) CONSOLE (
	.clk  (clk_sys),
	.rst_n(pix_rst_n),

	.ps2_key(ps2_key),

	// Keyboard/font national variant, from the OSD. One bit drives both, which
	// is the point - see Terminals/rtl/ps2_ascii_table.v.
	.layout_no(status[6]),

	// The machine seam. Nothing drives it in build 1.
	.cpu_byte_valid(1'b0),
	.cpu_byte_data (8'h00),
	.cpu_byte_ready(),

	.kbd_valid(),
	.kbd_data (),

	.colour(con_colour),
	.pixel(con_pixel),
	.hsync(con_hs),
	.vsync(con_vs),
	.de   (con_de),
	.bell (con_bell)
);

assign CLK_VIDEO = clk_sys;

// One pixel per clock: the terminal generates real 800x600@60 timing from the
// 40 MHz clock, so there is nothing to gate. CE_PIXEL exists for cores whose
// pixel rate is a fraction of their system clock; ours is not.
assign CE_PIXEL = 1'b1;

assign VGA_DE = con_de;
assign VGA_HS = con_hs;
assign VGA_VS = con_vs;

// The core says WHICH of eight things a pixel is; this board picks the colour.
// Panel colours are sampled from the photograph of the real folio panel.
reg [23:0] rgb;
always @(*) begin
	case (con_colour)
		3'd0: rgb = 24'h000000;   // black
		3'd1: rgb = 24'hFFFFFF;   // console text
		3'd2: rgb = 24'h191b19;   // panel fascia
		3'd3: rgb = 24'hd6d9d2;   // silkscreen
		3'd4: rgb = 24'hb6c2a4;   // LCD ground
		3'd5: rgb = 24'h2a3226;   // LCD segment
		3'd6: rgb = 24'he04a63;   // lit legend
		3'd7: rgb = 24'h444444;   // unlit legend
		default: rgb = 24'h000000;
	endcase
end

assign VGA_R = con_de ? rgb[23:16] : 8'h00;
assign VGA_G = con_de ? rgb[15:8]  : 8'h00;
assign VGA_B = con_de ? rgb[7:0]   : 8'h00;

// Heartbeat off the PLL output. This is the ONE signal that still means
// something when the screen is black: if it breathes, the PLL locked and
// clk_sys is running, so the fault is in the video logic and not the clock.
reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

endmodule
