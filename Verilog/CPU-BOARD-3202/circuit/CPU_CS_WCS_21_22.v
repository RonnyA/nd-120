/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/CS/WCS                                                            **
** Writable Control Store                                                **
** SHEET 21 and 22 of 50                                                 **
**                                                                       ** 
** This module has 16 RAM CHIPS of type 16K (4Kx4) Static RAM for LUA    **
** (4KByte Microcode)                                                    ** 
**                                                                       ** 
** This module has 16 RAM CHIPS of type 16K (4Kx4) Static RAM for UUA    **
** (4KByte for Writable Control Store?)                                  **
**                                                                       ** 
** Last reviewed: 14-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

module CPU_CS_WCS_21_22(                         
                        input sysclk, // System clock in FPGA
                        input sys_rst_n, // System reset in FPGA

                        input  [63:0] CSBITS_63_0,
                        output [63:0] CSBITS_63_0_OUT,

                        input [11:0] LUA_11_0,
                        input        ELOW_n,
                        input        WW0_n,
                        input        WW1_n,
                        input        WW2_n,
                        input        WW3_n,
                        
                        
                        input [11:0] UUA_11_0,
                        input        EUPP_n,
                        input        WU0_n,
                        input        WU1_n,
                        input        WU2_n,
                        input        WU3_n
                    );

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [63:0] s_lua_csbits;
   wire [11:0] s_lua_address;
   wire        s_elow_n;

   wire        s_ww3_n;
   wire        s_ww2_n;
   wire        s_ww1_n;
   wire        s_ww0_n;

   wire [63:0] s_uua_csbits;   
   wire [11:0] s_uua_address;
   wire        s_eupp_n;
   wire        s_wu3_n;
   wire        s_wu2_n;
   wire        s_wu1_n;
   wire        s_wu0_n;
   
   

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   
   // LUA
   assign s_lua_csbits[63:0]  = CSBITS_63_0;
   assign s_lua_address[11:0] = LUA_11_0;

   assign s_elow_n            = ELOW_n;  // Enable LUA RAM chips
   assign s_ww0_n             = WW0_n;   // Enable write for LUA bits 15-0   
   assign s_ww1_n             = WW1_n;   // Enable write for LUA bits 31-16
   assign s_ww2_n             = WW2_n;   // Enable write for LUA bits 47-32
   assign s_ww3_n             = WW3_n;   // Enable write for LUA bits 63-48


   // UUA
   assign s_uua_csbits[63:0]  = CSBITS_63_0;
   assign s_uua_address[11:0] = UUA_11_0;

   assign s_eupp_n            = EUPP_n; // Enable UUA RAM chips
   assign s_wu0_n             = WU0_n;  // Enable write for UUA bits 15-0
   assign s_wu1_n             = WU1_n;  // Enable write for UUA bits 31-16
   assign s_wu2_n             = WU2_n;  // Enable write for UUA bits 47-32
   assign s_wu3_n             = WU3_n;  // Enable write for UUA bits 63-48


   

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   // ELOW_n = 0 means ENABLE LUA RAM CHIPS
   // EUPP_n = 0 means ENABLE UUA RAM CHIPS

  assign CSBITS_63_0_OUT = (!s_elow_n) ?  s_lua_csbits[63:0] : (!s_eupp_n) ? s_uua_csbits[63:0] : 64'bz;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   IDT6168A_20   CHIP_16C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[63:60]),
                           .WE_n(s_ww3_n));

   IDT6168A_20   CHIP_17C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[59:56]),
                           .WE_n(s_ww3_n));

   IDT6168A_20   CHIP_18C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[55:52]),
                           .WE_n(s_ww3_n));

   IDT6168A_20   CHIP_19C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[51:48]),
                           .WE_n(s_ww3_n));

   IDT6168A_20   CHIP_16D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[63:60]),
                           .WE_n(s_wu3_n));

   IDT6168A_20   CHIP_17D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[59:56]),
                           .WE_n(s_wu3_n));

   IDT6168A_20   CHIP_18D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[55:52]),
                           .WE_n(s_wu3_n));

   IDT6168A_20   CHIP_19D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[51:48]),
                           .WE_n(s_wu3_n));

   IDT6168A_20   CHIP_20C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[47:44]),
                           .WE_n(s_ww2_n));

   IDT6168A_20   CHIP_21C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[43:40]),
                           .WE_n(s_ww2_n));

   IDT6168A_20   CHIP_22C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[39:36]),
                           .WE_n(s_ww2_n));

   IDT6168A_20   CHIP_23C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[35:32]),
                           .WE_n(s_ww2_n));

   IDT6168A_20   CHIP_20D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[47:44]),
                           .WE_n(s_wu2_n));

   IDT6168A_20   CHIP_21D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[43:40]),
                           .WE_n(s_wu2_n));

   IDT6168A_20   CHIP_22D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[39:36]),
                           .WE_n(s_wu2_n));

   IDT6168A_20   CHIP_23D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[35:32]),
                           .WE_n(s_wu2_n));

   IDT6168A_20   CHIP_24C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[31:28]),
                           .WE_n(s_ww1_n));

   IDT6168A_20   CHIP_25C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[27:24]),
                           .WE_n(s_ww1_n));

   IDT6168A_20   CHIP_26C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[23:20]),
                           .WE_n(s_ww1_n));

   IDT6168A_20   CHIP_27C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[19:16]),
                           .WE_n(s_ww1_n));

   IDT6168A_20   CHIP_24D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[31:28]),
                           .WE_n(s_wu1_n));

   IDT6168A_20   CHIP_25D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[27:24]),
                           .WE_n(s_wu1_n));

   IDT6168A_20   CHIP_26D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[23:20]),
                           .WE_n(s_wu1_n));

   IDT6168A_20   CHIP_27D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[19:16]),
                           .WE_n(s_wu1_n));

   IDT6168A_20   CHIP_28C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[15:12]),
                           .WE_n(s_ww0_n));

   IDT6168A_20   CHIP_29C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[11:8]),
                           .WE_n(s_ww0_n));

   IDT6168A_20   CHIP_30C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[7:4]),
                           .WE_n(s_ww0_n));

   IDT6168A_20   CHIP_31C (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_lua_address[11:0]),
                           .CE_n(s_elow_n),
                           .D_3_0(s_lua_csbits[3:0]),
                           .WE_n(s_ww0_n));

   IDT6168A_20   CHIP_28D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[15:12]),
                           .WE_n(s_wu0_n));

   IDT6168A_20   CHIP_29D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[11:8]),
                           .WE_n(s_wu0_n));

   IDT6168A_20   CHIP_30D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[7:4]),
                           .WE_n(s_wu0_n));

   IDT6168A_20   CHIP_31D (
                           .clk(sysclk),
                           .reset_n(sys_rst_n),
                           .A_11_0(s_uua_address[11:0]),
                           .CE_n(s_eupp_n),
                           .D_3_0(s_uua_csbits[3:0]),
                           .WE_n(s_wu0_n));

endmodule
