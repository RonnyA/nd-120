/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F595 - R/S Latch with Gated input                                 **
**                                                                       **
** Truth table from REN_A12213XJ5V1UM00_OTH_19980801.pdf                 **
** Page 6-214. Function RS-LATCH                                         **
**                                                                       **
** Last reviewed: 20-MAY-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module F595 (
    input sysclk,     // System clock (FPGA: used to sample S/R synchronously)
    input sys_rst_n,  // FPGA system reset (active-low): forces latch to idle state (Q=0, Qn=1)
    input H01_S,  // Set
    input H02_R,  // Reset
    input H03_G,  // Gate Enable

    output N01_Q,  // Q
    output N02_QB  // Qn
);

  /* verilator lint_off UNOPTFLAT */

  // Start in idle/reset state: Q=0 (not set), Qn=1 (not set).
  // Vivado maps these initial values to FF INIT attributes (respected after GSR).
  reg regQ  = 1'b0;
  reg regQn = 1'b1;

  /* verilator lint_off LATCH */

`ifdef VERILATOR_SIM
  // Transparent gated latch — matches real NEC F595 RS latch behavior.
  // Required so combinatorial events (e.g. s_continue → s_conn_n → PAN_n → TVEC=016)
  // propagate within the same clock cycle. A 1-cycle posedge delay would cause TVEC=016
  // to miss the first FETCH step after COMM.CONTINUE, producing a wrong CSA jump.
  always @(*) begin
    if (H03_G) begin
      if (H01_S & H02_R) begin
        regQ  = 1'b1;
        regQn = 1'b1;
      end else if (H02_R & !H01_S) begin
        regQ  = 1'b0;
        regQn = 1'b1;
      end else if (!H02_R & H01_S) begin
        regQ  = 1'b1;
        regQn = 1'b0;
      end
      // else: hold (latch behavior — neither S nor R asserted)
    end
    // else: hold (gate closed)
  end
`else
  // FPGA mode: synchronous RS FF sampled on sysclk.
  // sys_rst_n=0 forces idle (Q=0, Qn=1) so all latches start deasserted after FPGA reset.
  always @(posedge sysclk) begin
    if (!sys_rst_n) begin
      regQ  <= 1'b0;
      regQn <= 1'b1;
    end else if (H03_G) begin
      if (H01_S & H02_R) begin
        regQ  <= 1'b1;
        regQn <= 1'b1;
      end else if (H02_R & !H01_S) begin
        regQ  <= 1'b0;
        regQn <= 1'b1;
      end else if (!H02_R & H01_S) begin
        regQ  <= 1'b1;
        regQn <= 1'b0;
      end
    end
  end
`endif

  assign N01_Q  = regQ;
  assign N02_QB = regQn;

endmodule
