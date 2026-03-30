
/**************************************************************************
** ND120 SHARED CODE                                                     **
** D FLIP-FLOP                                                           **
**                                                                       **
** ACTIVE_ASYNC=0 (default): Clean synchronous FF for FPGA.             **
** ACTIVE_ASYNC=1: Async preset/reset for instances that need it.       **
**                                                                       **
** Last reviewed: 30-MAR-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module D_FLIPFLOP #(
    parameter integer InvertClockEnable = 1,
    parameter integer ACTIVE_ASYNC = 0      // 0=clean FF (no async), 1=async preset/reset
)(
    input clock,     //! Clock
    input d,         //! D input (DATA)
    input preset,    //! PRESET - Active-high, sets Q to 1 when asserted
    input reset,     //! RESET - Active-high, sets Q to 0 when asserted
    input tick,      //! Tick (not used)

    output q,        //! Q out
    output qBar      //! QBar out
);

   wire s_clock;
   reg s_currentState;

   assign q       = s_currentState;
   assign qBar    = ~s_currentState;
   assign s_clock = (InvertClockEnable == 0) ? clock : ~clock;

   initial begin
      s_currentState = 0;
   end

   generate
      if (ACTIVE_ASYNC == 1) begin : gen_async
         // Async preset/reset -- for instances that use active preset or reset signals.
         // Creates combinational loop warning in Vivado (expected, resolves in one LUT delay).
         always @(posedge s_clock or posedge preset or posedge reset)
         begin
            s_currentState <= preset ? 1'b1 :
                              reset  ? 1'b0 :
                              d;
         end
      end else begin : gen_sync
         // Clean synchronous FF -- no combinational loop, maps to native FPGA FF.
         // Safe when preset and reset are tied to constant 0.
         always @(posedge s_clock)
         begin
            s_currentState <= d;
         end
      end
   endgenerate

endmodule
