/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component: CMP4 (4 bit comparator)                                    **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CMP4 (
    input A0,  //! A bit 0
    input A1,  //! A bit 1
    input A2,  //! A bit 2
    input A3,  //! A bit 3

    input B0,  //! B bit 0
    input B1,  //! B bit 1
    input B2,  //! B bit 2
    input B3,  //! B bit 3

    output AEB,  //! A EQUAL B
    output AGB,  //! A GREATER THEN B
    output ALB   //! A LESS THAN B
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [3:0] s_data_A;
  wire [3:0] s_data_B;
  wire       s_aeb_out;
  wire       s_agb_out;
  wire       s_alb_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_data_A[0] = A0;
  assign s_data_A[1] = A1;
  assign s_data_A[2] = A2;
  assign s_data_A[3] = A3;

  assign s_data_B[0] = B0;
  assign s_data_B[1] = B1;
  assign s_data_B[2] = B2;
  assign s_data_B[3] = B3;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign AEB = s_aeb_out;
  assign AGB = s_agb_out;
  assign ALB = s_alb_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  Comparator #(
      .nrOfBits(4),
      .twosComplement(1)
  ) ARITH_1 (
      .aEqualsB(s_aeb_out),
      .aGreaterThanB(s_agb_out),
      .aLessThanB(s_alb_out),
      .dataA(s_data_A[3:0]),
      .dataB(s_data_B[3:0])
  );


endmodule
