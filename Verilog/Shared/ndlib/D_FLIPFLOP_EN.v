/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** D_FLIPFLOP_EN - D_FLIPFLOP with an optional clock-enable mode.        **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original D_FLIPFLOP - posedge       **
**   clock, original behaviour.                                          **
** USE_ENABLE=1: posedge sysclk, captures when EN is high (P2 clock-     **
**   domain conversion mode - see SCAN_FF_EN.v / the plan doc).          **
**                                                                       **
** ASYNC_RESET=0 (default): preset/reset must be tied 0 (clean sync      **
**   flop, InvertClockEnable=0).                                         **
** ASYNC_RESET=1: preset/reset are async active-high set/clear with      **
**   preset priority, like the original D_FLIPFLOP with ACTIVE_ASYNC(1). **
**                                                                       **
** tick is unused (tie 1).                                               **
**                                                                       **
** Last reviewed: 10-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module D_FLIPFLOP_EN #(
    parameter integer USE_ENABLE  = 0,
    parameter integer ASYNC_RESET = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input clock,   //! Clock (used only when USE_ENABLE=0)
    input d,       //! D input
    input preset,  //! Must be tied 0
    input reset,   //! Async active-high clear when ASYNC_RESET=1, else tie 0
                   //! (preset likewise an async set, priority over reset)
    input tick,    //! Not used (tie 1)

    output q,
    output qBar
);

  generate
    if (USE_ENABLE == 1 && ASYNC_RESET == 1) begin : gen_enable_arst
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused = clock & tick;
      /* verilator lint_on UNUSEDSIGNAL */
      reg q_r = 1'b0;
      always @(posedge sysclk or posedge preset or posedge reset) begin
        if (preset) q_r <= 1'b1;
        else if (reset) q_r <= 1'b0;
        else if (EN) q_r <= d;
      end
      assign q    = q_r;
      assign qBar = ~q_r;
    end else if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused = clock & preset & reset & tick;
      /* verilator lint_on UNUSEDSIGNAL */
      reg q_r = 1'b0;
      always @(posedge sysclk) begin
        if (EN) q_r <= d;
      end
      assign q    = q_r;
      assign qBar = ~q_r;
    end else if (ASYNC_RESET == 1) begin : gen_orig_arst
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      D_FLIPFLOP #(
          .ACTIVE_ASYNC(1),
          .InvertClockEnable(0)
      ) FF (
          .clock (clock),
          .d     (d),
          .preset(preset),
          .reset (reset),
          .tick  (tick),
          .q     (q),
          .qBar  (qBar)
      );
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      D_FLIPFLOP #(
          .InvertClockEnable(0)
      ) FF (
          .clock (clock),
          .d     (d),
          .preset(preset),
          .reset (reset),
          .tick  (tick),
          .q     (q),
          .qBar  (qBar)
      );
    end
  endgenerate

endmodule
