/**************************************************************************************************
** ND120 CPU                                                                                     **
**                                                                                               **
** AM29C821                                                                                      **
**                                                                                               **
** Bus Driver 10 bits.                                                                           **
** Positive edge-triggered registers with D-type flip-flops and 3-state                          **
**                                                                                               **
** Documentation:                                                                                **
** https://www.digikey.com/en/products/detail/rochester-electronics-llc/AM29C821-BLA/12095382    **
**                                                                                               **
** Last reviewed: 11-NOV-2024                                                                    **
** Ronny Hansen                                                                                  **
***************************************************************************************************/

module AM29C821 (
    input  wire       sysclk, //! FPGA system clock (used only when USE_SYSCLK=1)
    input  wire       CK,     //! Clock input (original: posedge latch)
    input  wire       OE_n,   //! Output Enable (active low)
    input  wire [9:0] D,      //! 10 Bit Data Inputs
    output wire [9:0] Y       //! 10 Bit Data Outputs
);

  // USE_SYSCLK=0 (default): original posedge CK — correct for real clock
  //   signals like s_osc or s_bcgnt50.
  // USE_SYSCLK=1: level-sensitive sysclk capture — required when CK is a
  //   1-sysclk-wide combinational pulse (e.g., s_clk = ~TERM_n) that
  //   rises at the same edge it would be sampled by posedge CK.
  parameter USE_SYSCLK = 0;

  reg [9:0] Y_Latch = 10'b0;

  generate
    if (USE_SYSCLK == 1) begin : gen_sysclk
      always @(posedge sysclk) begin
        if (CK) Y_Latch <= D;
      end
    end else begin : gen_posedge_ck
      always @(posedge CK) begin
        Y_Latch <= D;
      end
    end
  endgenerate

  // Output control
  // When OE_n is low (active), outputs reflect the registered data
  // When OE_n is high, outputs are zero (tri-state equivalent)
  assign Y = (OE_n == 1'b0) ? Y_Latch : 10'b0;

endmodule
