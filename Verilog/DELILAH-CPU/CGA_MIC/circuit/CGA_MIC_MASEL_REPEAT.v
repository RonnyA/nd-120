/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/MASEL/REPEAT                                                 **
** REPEAT                                                                **
**                                                                       **
** Page 20                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_MASEL_REPEAT (
    input        MCLK,
    input        MPN,
    input        SC5,      //! Selector SC5
    input        SC6,      //! Selector SC6
    input [12:0] REP_12_0,

    output [12:0] IW_12_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [12:0] s_rep_12_0;
  wire        s_mclk;
  wire        s_mp_n;
  wire        s_mp;
  wire        s_sc5;
  wire        s_sc6;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/
  reg  [12:0] regRepeat;




  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_rep_12_0[12:0] = REP_12_0;
  assign s_mp_n           = MPN;
  assign s_mclk           = MCLK;
  assign s_sc5            = SC5;
  assign s_sc6            = SC6;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign IW_12_0          = regRepeat[12:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_mp             = ~s_mp_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/

  // NOTE: Triggering on NEG edge is different from what the schematics say, but it is needed to get the R_REP value clocked correct
  wire s_hack;
  assign s_hack =
        s_mclk
        & !s_sc5
        & !s_sc6
        & (regRepeat == 13'h1FFF | regRepeat == 13'h000)
        & (REP_12_0 == 13'h401)

    ;// Latch if selector changes to jump and current regRepeat is 0. HACK HACK to get boot to work

  always @(posedge s_mclk or posedge s_mp or posedge s_hack) begin
    if (s_mp) begin
      regRepeat <= 12'b000000000000;
    end else begin
      if (s_mclk) begin  // HACK: Allow changes in selector to affect the register values as long clock is high.. (to avoid race conditions)
        regRepeat[12:0] <= s_rep_12_0[12:0];
      end
    end
  end





endmodule
