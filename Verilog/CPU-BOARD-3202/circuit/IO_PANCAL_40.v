/**************************************************************************
** ND120 CPU, MM&M                                                       **
** IO/PANCAL                                                             **
** PANEL PROC & CALENDAR                                                 **
** SHEET 40 of 50                                                        **
**                                                                       ** 
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

// Statis: Module not working.
// TODO: Implement logic for the MC68705 - 6805 Embedded CPU and the MM58274  - Real Time Clock

module IO_PANCAL_40(
   // Input signals
   input       CLEAR_n,
   input       EMP_n,
   input       EPANS,
   input       FUL_n,
   input       IONI,
   input       LEV0,
   input       LHIT,
   input       PANOSC,
   input [7:0] PA_7_0,
   input [1:0] PCR_1_0,
   input       PONI,
   input       VAL,

   // Output and Input signals
   input  [15:0] IDB_15_0_IN,
   output [15:0] IDB_15_0_OUT,

   // Output signals
   output [4:0]  DP_5_1_n,  
   output        RMM_n,
   output [1:0]  STAT_4_3               
);

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/


   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0]  s_dp_5_1_n;
   wire [4:0]  s_logisimBus2;
   wire [3:0]  s_logisimBus20;
   wire [1:0]  s_stat_4_3;
   wire [1:0]  s_pcr_1_0;
   wire [15:0] s_IDB_15_0_out;
   wire [7:0]  s_pa_7_0;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_ck;
   wire        s_logisimNet45;
   wire        s_EPANS;
   wire        s_rmm_n;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   wire [7:0] s_IDB_7_0_chip32_out;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_pcr_1_0[1:0]      = PCR_1_0;
   assign s_pa_7_0[7:0]       = PA_7_0;
   assign s_logisimNet29      = FUL_n;
   assign s_logisimNet39      = CLEAR_n;
   assign s_logisimNet4       = PONI;
   assign s_logisimNet45      = VAL;
   assign s_EPANS             = EPANS;
   assign s_logisimNet5       = IONI;
   assign s_logisimNet6       = LHIT;
   assign s_logisimNet7       = LEV0;
   assign s_logisimNet8       = EMP_n;
   assign s_logisimNet9       = PANOSC;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign DP_5_1_n         = s_dp_5_1_n[4:0];
   assign IDB_15_0_OUT     = s_IDB_15_0_out[15:0];
   assign RMM_n            = s_rmm_n;
   assign STAT_4_3         = s_stat_4_3[1:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimBus2[4:0]  =  {1'b0, 4'h0};


   // NOT Gate
   assign s_dp_5_1_n = ~s_logisimBus2;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/


   // TTL_74244 CHIP_33B (simplified..)
   assign s_IDB_15_0_out[15:8] = s_EPANS  ? 8'b0 : {s_logisimNet1,s_logisimNet29,s_logisimNet0,s_logisimNet45,s_logisimBus20[3:1]};

   
// TTL_74374 CHIP_32B 
   TTL_74374   CHIP_32B(
                          .CK(s_ck),
                          .OE_n(s_EPANS),
                          .D(s_pa_7_0[7:0]),
                          .Q(s_IDB_7_0_chip32_out[7:0])
                       );

// TODO:
//  ADD  - MM58274  - Real Time Clock
// ADD - MC68705 - 6805 Embedded CPU

   assign IDB_15_0_OUT = 16'b0;  //TODO: or in s_IDB_7_0_chip32_out[7:0] 
endmodule
