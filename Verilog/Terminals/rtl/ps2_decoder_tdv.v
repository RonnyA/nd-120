//============================================================================
//! PS/2 scancode stream -> terminal bytes, TDV2200 table. Modifier state
//! and lookup only.
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//! Thin sibling of ps2_decoder.v (VT100) - IDENTICAL logic, the only
//! difference is which ascii table it instantiates. ps2_decoder.v hardcodes
//! the instance name `ps2_ascii_table`, so it cannot be reused directly for
//! a second table without either a compile-time table-select inside that
//! file (risking the tested VT100 path) or this sibling. Per the decision
//! to keep VT100 and TDV2200 as two separate, compile-time-selected
//! modules (not a shared/branching implementation), this is the sibling.
//!
//! Written 31-AUG-2026.
//============================================================================

`default_nettype none

module ps2_decoder_tdv (
    input wire clk,
    input wire rst_n,  //! async reset, active low

    //! One scancode, already framed and stripped of its E0/F0 prefixes.
    input wire       code_valid,     //! strobe, one clock
    input wire [7:0] code_data,      //! the scancode itself
    input wire       code_release,   //! this was a key RELEASE (F0 seen)
    input wire       code_extended,  //! this had the E0 prefix

    //! 0 = US ANSI, 1 = Norwegian. See ps2_ascii_table_tdv.v.
    input wire       layout_no,

    output reg       ascii_valid,  //! one clock per character produced
    output reg [7:0] ascii_data,

    //! Modifier state, exposed because a board may want to light a lamp.
    output wire shift_active,
    output wire ctrl_active,
    output wire caps_active
);

  localparam [7:0] SC_LSHIFT = 8'h12;
  localparam [7:0] SC_RSHIFT = 8'h59;
  localparam [7:0] SC_CTRL   = 8'h14;
  localparam [7:0] SC_CAPS   = 8'h58;

  reg s_lshift, s_rshift, s_ctrl, s_caps;

  assign shift_active = s_lshift | s_rshift;
  assign ctrl_active  = s_ctrl;
  assign caps_active  = s_caps;

  wire s_shifted = s_lshift | s_rshift;

  wire [7:0] s_ascii_unshifted;
  wire [7:0] s_ascii_shifted;
  wire [7:0] s_ascii_extended;

  ps2_ascii_table_tdv TABLE (
      .code     (code_data),
      .layout_no(layout_no),
      .unshifted(s_ascii_unshifted),
      .shifted  (s_ascii_shifted),
      .extended (s_ascii_extended)
  );

  //! Caps lock affects letters only - not digits, not punctuation.
  wire s_is_letter   = (s_ascii_unshifted >= "a") && (s_ascii_unshifted <= "z");
  wire s_use_shifted = s_shifted ^ (s_caps && s_is_letter);

  wire [7:0] s_ascii_plain = s_use_shifted ? s_ascii_shifted : s_ascii_unshifted;

  //! Control characters: CTRL + @A-Z[\]^_ gives 0x00-0x1F. Applied to the
  //! UNSHIFTED letter so ctrl-C and ctrl-shift-C are the same, as on a real
  //! terminal.
  wire [7:0] s_ascii_ctrl = {3'b000, s_ascii_unshifted[4:0]};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_lshift    <= 1'b0;
      s_rshift    <= 1'b0;
      s_ctrl      <= 1'b0;
      s_caps      <= 1'b0;
      ascii_valid <= 1'b0;
      ascii_data  <= 8'h00;
    end else begin
      ascii_valid <= 1'b0;

      if (code_valid) begin
        case (code_data)
          SC_LSHIFT: s_lshift <= !code_release;
          SC_RSHIFT: s_rshift <= !code_release;
          SC_CTRL:   s_ctrl   <= !code_release;
          SC_CAPS:   if (!code_release) s_caps <= !s_caps;

          default: begin
            if (!code_release) begin
              if (code_extended) begin
                if (s_ascii_extended != 8'h00) begin
                  ascii_valid <= 1'b1;
                  ascii_data  <= s_ascii_extended;
                end
              end else if (s_ascii_plain != 8'h00) begin
                ascii_valid <= 1'b1;
                // A sequence MARKER (bit 7) is never ctrl-masked: there is
                // no Ctrl-Fn encoding on a TDV either (the F-key ESC[nn_
                // family already covers Shift; Ctrl is not modeled).
                ascii_data  <= (s_ctrl && !s_ascii_plain[7]) ? s_ascii_ctrl
                                                             : s_ascii_plain;
              end
            end
          end
        endcase
      end
    end
  end

endmodule

`default_nettype wire
