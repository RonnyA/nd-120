/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/MMU/CSR                                                           **
** CACHE STATUS REGISER                                                  **
** SHEET 26 of 50                                                        **
**                                                                       ** 
** Last reviewed: 19-FEB-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/
module CPU_MMU_CSR_26(
   input STP,
   input EMPID_n,
   input EDO_n,
   input LCS_n,
   input PD2, // OE1_1G_n

   input CUP,
   input CON,   
   input ECSR_n, // OE2_2G_n

   output       BSTP,
   output       BEMPID_n,
   output       BEDO_n,   
   output       BLCS_n,
   
   output [3:0] IDB_3_0
);



// This code replaces one 74244 (CHIP 27H)
// 74LS244 (NONE negated outputs)
// Octal Buffers and Line Drivers With 3-State Outputs


  assign BSTP = PD2 ? 1'bz : STP;
  assign BEMPID_n = PD2 ? 1'bz : EMPID_n;
  assign BEDO_n = PD2 ? 1'bz : EDO_n;
  assign BLCS_n = PD2 ? 1'bz : LCS_n;

  wire [3:0] idb = {1'b1, ~CON, CON, CUP};   

  assign IDB_3_0 = ECSR_n ? 4'bz : idb;

// Below is the original code from the Logisim generated file

`ifdef _OLD_CODE_

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [3:0] s_logisimBus1;
   wire       s_logisimNet0;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet2;
   wire       s_logisimNet3;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;
   wire       s_logisimNet8;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet12 = STP;
   assign s_logisimNet13 = EMPID_n;
   assign s_logisimNet14 = EDO_n;
   assign s_logisimNet15 = LCS_n;
   assign s_logisimNet16 = PD2;
   assign s_logisimNet17 = CUP;
   assign s_logisimNet18 = ECSR_n;
   assign s_logisimNet2  = CON;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BEDO_n   = s_logisimNet5;
   assign BEMPID_n = s_logisimNet4;
   assign BLCS_n   = s_logisimNet6;
   assign BSTP     = s_logisimNet3;
   assign IDB_3_0  = s_logisimBus1[3:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet11  =  1'b1;


   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet2;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74244   CHIP_27H (.I0_1A1(s_logisimNet12),
                         .I1_1A2(s_logisimNet13),
                         .I2_1A3(s_logisimNet14),
                         .I3_1A4(s_logisimNet15),
                         .I4_2A1(s_logisimNet17),
                         .I5_2A2(s_logisimNet2),
                         .I6_2A3(s_logisimNet0),
                         .I7_2A4(s_logisimNet11),
                         .O0_1Y1(s_logisimNet3),
                         .O1_1Y2(s_logisimNet4),
                         .O2_1Y3(s_logisimNet5),
                         .O3_1Y4(s_logisimNet6),
                         .O4_2Y1(s_logisimBus1[0]),
                         .O5_2Y2(s_logisimBus1[1]),
                         .O6_2Y3(s_logisimBus1[2]),
                         .O7_2Y4(s_logisimBus1[3]),
                         .OE1_1G_n(s_logisimNet16),
                         .OE2_2G_n(s_logisimNet18));

`endif


endmodule
