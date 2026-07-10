/******************************************************************************
 ** Component : TTL_74534                                                    **
 **                                                                          **
 ** 74HC534 Octal D-type Flip-Flop                                           **
 ** (NEGATED OUTPUTS)                                                        **
 *****************************************************************************/

module TTL_74534(
   input sysclk, // FPGA system clock (used only when USE_SYSCLK=2)
   input CK,
   input OE_n,

   input [7:0] D,
   output [7:0] Q_n
);

   // USE_SYSCLK:
   //   0 (default): original posedge CK - matches the real chip.
   //   2: sysclk-sampled RISING-EDGE capture (AM29C821 USE_SYSCLK=2 pattern)
   //      - the FPGA-safe mode when CK is driven by a control strobe
   //      (SPEA, SPES ...), not a clock. One capture per detected rise,
   //      no fabric-routed clock net.
   parameter USE_SYSCLK = 0;

   wire s_ck;
   wire s_oe_n;
   wire [7:0] s_d_n;

   reg [7:0] regQ_n;


   assign s_ck = CK;
   assign s_oe_n = OE_n;
   assign s_d_n = ~D;

   generate
      if (USE_SYSCLK == 2) begin : gen_edge
         reg ck_d = 1'b0;
         always @(posedge sysclk) begin
            ck_d <= s_ck;
            if (s_ck && !ck_d) regQ_n <= s_d_n;
         end
      end else begin : gen_posedge
         always @(posedge s_ck )
         begin
            regQ_n <= s_d_n;
         end
      end
   endgenerate

   assign Q_n = s_oe_n ? 8'b0 : regQ_n;
endmodule
