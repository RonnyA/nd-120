/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SCAN FLIP-FLOP (Also known as FDIS in the DELILAH schematics)         **
**                                                                       **
** Positive edge triggered D flip-flop with scan                         **
** Its a D flip-flop with a 2-input multiplexer on the D input           **
**                                                                       **
** When TE (T enable) input is negated,                                  **
** the circuit behaves like an ordinary D flip-flop.                     **
**                                                                       **
** When TE is asserted,                                                  **
** it takes its data from TI (T input) instead of from D.                **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module SCAN_FF (
    input CLK,  //! Clock (positive triggered)
    input D,    //! D input
    input TE,   //! T enable
    input TI,   //! T Input

    output Q,  //! Q output
    output QN  //! Q_n output
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_clk;
  wire s_d_and_te_n;
  wire s_d;
  wire s_ff_d_input;
  wire s_q_out;
  wire s_qn_out;
  wire s_te_n;
  wire s_te;
  wire s_ti_and_te;
  wire s_ti;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_clk = CLK;
  assign s_d = D;
  assign s_te = TE;
  assign s_ti = TI;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign Q = s_q_out;
  assign QN = s_qn_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_te_n = ~s_te;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  assign s_d_and_te_n = (s_d & s_te_n);
  assign s_ti_and_te = (s_ti & s_te);
  assign s_ff_d_input = s_d_and_te_n | s_ti_and_te;

  
  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_4 (
      .clock(s_clk),
      .d(s_ff_d_input),
      .preset(1'b0),
      .q(s_q_out),
      .qBar(s_qn_out),
      .reset(1'b0),
      .tick(1'b1)
  );
/*
reg latchD;

assign s_q_out = latchD;
assign s_qn_out = ~s_q_out;

always @(posedge s_clk, s_ff_d_input) begin
    if (s_clk) begin
        latchD <= s_ff_d_input;
    end

end
*/
endmodule
