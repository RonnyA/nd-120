/**************************************************************************
** ND120 CPU, MM&M                                                       **
** MEM/ADDR                                                              **
** MEM ADDR MUX                                                          **
** SHEET 44 of 50                                                        **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module MEM_ADDR_44 (
    input [19:0] LBD_19_0,  //! LBD  20 bits (including parity 2 bits)

    input BCGNT50, //! Bus cycle grant 50ns delayed CLOCK signal to latch LOW or HIGH bits from memory to AA_9_0
    input LOEN_n,  //! LOEN_n - Low address bits enable (active low)
    input HIEN_n,  //! HIEN_n - High address bits enable (active low)

    input PD4,  //! PD4 - Always true

    output [9:0] AA_9_0  //! Output - 10 bits of LBD (including parity in bit 10)- 10 but input to MEM/RAM
);


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [9:0] s_aa_9_0_out;

  wire [9:0] s_lbd_lo_in;
  wire [9:0] s_lbd_lo_out;

  wire [9:0] s_lbd_hi_in;
  wire [9:0] s_lbd_hi_out;

  wire [9:0] s_data_10;  // or'ed together output values from 3H and 4H

  wire       s_bcgnt50;
  wire       s_hien_n;
  wire       s_loen_n;
  wire       s_pd4;
  wire       s_power;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_bcgnt50   = BCGNT50;
  assign s_hien_n    = HIEN_n;
  assign s_loen_n    = LOEN_n;
  assign s_pd4       = PD4;

  assign s_lbd_lo_in = {LBD_19_0[18], LBD_19_0[8:0]};
  assign s_lbd_hi_in = {LBD_19_0[19], LBD_19_0[17:9]};
  assign s_data_10   = s_lbd_lo_out | s_lbd_hi_out;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign AA_9_0      = s_aa_9_0_out[9:0];


  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power     = 1'b1;


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  AM29861A CHIP_5H (
      .OER_n(s_power),  // Read tied to power through a 2.2Kohm resistor pulling it high.
      .OET_n(s_pd4),
      .D_IN(s_data_10),
      .D_OUT(),  // Not connected, as there is nevere read from Y output D
      .Y_IN(),  // Not connected, as there is nevere read from Y output D
      .Y_OUT(s_aa_9_0_out)
  );

  AM29C821 CHIP_3H_ROW_ADDRESS (
      .CK(s_bcgnt50),
      .D(s_lbd_lo_in),
      .OE_n(s_loen_n),
      .Y(s_lbd_lo_out)
  );

  AM29C821 CHIP_4H_COL_ADDRESS (
      .CK(s_bcgnt50),
      .D(s_lbd_hi_in),
      .OE_n(s_hien_n),
      .Y(s_lbd_hi_out)
  );

endmodule
