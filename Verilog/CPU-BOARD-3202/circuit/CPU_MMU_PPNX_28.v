/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/MMU/PPNX                                                          **
** PPN TO IDB                                                            **
** SHEET 28 of 50                                                        **
**                                                                       ** 
** Last reviewed: 14-FEB-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CPU_MMU_PPNX_28( 
   input EIPL_n,
   input EIPUR_n,
   input EIPU_n,
   input ESTOF_n,

   inout [15:0] IDB_15_0,
   inout [15:0] PPN_25_10
);   


wire DIR = ESTOF_n;
wire OE_U_n = EIPU_n;
wire OE_L_n = EIPL_n;

reg [15:0] PPN_reg;
reg [15:0] IDB_reg;

always @(*) begin
   IDB_reg = IDB_15_0;
   PPN_reg = PPN_25_10;

   if (EIPUR_n==0)
   begin
      PPN_reg[15:8] = {7'b0,IDB_15_0[8]};
      PPN_reg[7:0] = PPN_25_10[7:0]; 
   end


// 2x 74245 (CHIP 10B (UPPER) and 9B (LOWER))
//always @(*) begin
   

   // Upper 8 bits - CHIP 10B
   if (EIPU_n==0)
   begin
      if (DIR) begin
         // Data flows from A to B
         IDB_reg[15:8] = PPN_reg[15:8]; 
      end else begin
         // Data flows from B to A

         if (EIPUR_n==0) begin
            PPN_reg[15:8] = {7'b0,IDB_15_0[8]};
         end else begin
            PPN_reg[15:8] = IDB_15_0[15:8]; 
         end
      end
   /*end else begin
       PPN_reg[15:8] = PPN_25_10[15:8];
       IDB_reg[15:8] = IDB_15_0[15:8];
   */
   end

   // Lower 8 bits - CHIP 9B
   if (EIPL_n==0)
   begin
      if (DIR) begin
         IDB_reg[7:0] = PPN_reg[7:0]; // Data flows from A to B
      end else begin
         PPN_reg[7:0] = IDB_15_0[7:0]; // Data flows from B to A
      end
   /*
   end else begin
       PPN_reg[7:0] = PPN_25_10[7:0];
       IDB_reg[7:0] = IDB_15_0[7:0];
   */
   end   
end

// Assign the bidirectional bus with respect to OE
assign IDB_15_0 = IDB_reg;
assign PPN_25_10 = PPN_reg;


// Output to A when receiving from B with respect to OE (OE_n==1 means "isolated". Don't write to A or B)
//assign A = (OE_n == 0 && DIR == 0) ? internalBus : 8'bz;





// Below is the original code from the Logisim generated file

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 **                                                                          **
 *****************************************************************************/

`ifdef _OLD_CODE_


   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus17;
   wire [15:0] s_logisimBus50;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet18 = ESTOF_n;
   assign s_logisimNet19 = EIPL_n;
   assign s_logisimNet20 = EIPU_n;
   assign s_logisimNet40 = EIPUR_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign IDB_15_0  = s_logisimBus50[15:0];
   assign PPN_25_10 = s_logisimBus17[15:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet37  =  1'b0;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74245   CHIP_10B (.A1(s_logisimBus17[15]),
                         .A2(s_logisimBus17[14]),
                         .A3(s_logisimBus17[13]),
                         .A4(s_logisimBus17[12]),
                         .A5(s_logisimBus17[11]),
                         .A6(s_logisimBus17[10]),
                         .A7(s_logisimBus17[9]),
                         .A8(s_logisimBus17[8]),
                         .B1(s_logisimBus50[15]),
                         .B2(s_logisimBus50[14]),
                         .B3(s_logisimBus50[13]),
                         .B4(s_logisimBus50[12]),
                         .B5(s_logisimBus50[11]),
                         .B6(s_logisimBus50[10]),
                         .B7(s_logisimBus50[9]),
                         .B8(s_logisimBus50[8]),
                         .DIR(s_logisimNet18),
                         .G_n(s_logisimNet20));

   TTL_74245   CHIP_9B (.A1(s_logisimBus17[7]),
                        .A2(s_logisimBus17[6]),
                        .A3(s_logisimBus17[5]),
                        .A4(s_logisimBus17[4]),
                        .A5(s_logisimBus17[3]),
                        .A6(s_logisimBus17[2]),
                        .A7(s_logisimBus17[1]),
                        .A8(s_logisimBus17[0]),
                        .B1(s_logisimBus50[7]),
                        .B2(s_logisimBus50[6]),
                        .B3(s_logisimBus50[5]),
                        .B4(s_logisimBus50[4]),
                        .B5(s_logisimBus50[3]),
                        .B6(s_logisimBus50[2]),
                        .B7(s_logisimBus50[1]),
                        .B8(s_logisimBus50[0]),
                        .DIR(s_logisimNet18),
                        .G_n(s_logisimNet19));

   TTL_74244   CHIP_8B (.I0_1A1(s_logisimNet37),
                        .I1_1A2(s_logisimNet37),
                        .I2_1A3(s_logisimNet37),
                        .I3_1A4(s_logisimNet37),
                        .I4_2A1(s_logisimNet37),
                        .I5_2A2(s_logisimNet37),
                        .I6_2A3(s_logisimNet37),
                        .I7_2A4(s_logisimBus50[8]),
                        .O0_1Y1(s_logisimBus17[15]),
                        .O1_1Y2(s_logisimBus17[14]),
                        .O2_1Y3(s_logisimBus17[13]),
                        .O3_1Y4(s_logisimBus17[12]),
                        .O4_2Y1(s_logisimBus17[11]),
                        .O5_2Y2(s_logisimBus17[10]),
                        .O6_2Y3(s_logisimBus17[9]),
                        .O7_2Y4(s_logisimBus17[8]),
                        .OE1_1G_n(s_logisimNet40),
                        .OE2_2G_n(s_logisimNet40));


`endif

endmodule
