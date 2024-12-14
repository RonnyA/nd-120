/******************************************************************************
** RAM CHIP 1 MBYTE (1024KB)                                                  **
**                                                                            **
** This ram has PARITY bit..                                                  **
** THM91020 - http://norsk-data.com/library/libother/extern/THM91020.pdf      **
** THM91070 - http://norsk-data.com/library/libother/extern/THM91070.pdf      **
**                                                                            **
** Last reviewed: 14-DEC-2024                                                 **
** Ronny Hansen                                                               **
********************************************************************************/

// TODO: Implement access to real RAM inside FPGA

module SIP1M9 (

    // Input signals
    input sysclk,    //! System clock in FPGA
    input sys_rst_n, //! System reset in FPGA

    input [9:0] ADDRESS,  //! Address input
    input       CAS9_n,   //! Column address strobe
    input       CAS_n,    //! Column address strobe
    input       RAS_n,    //! Row address strobe
    input       W_n,      //! Read/Write signal


    // IN and OUT signals
    input [7:0] D8,  //! DATA INPUT
    input       D9,  //! DATA INPUT

    // Output signals
    output reg [7:0] Q8,    //! DATA OUTPUT
    output reg       Q9,    //! DATA OUTPUT
    output           PRD_n  //! Parity bit

);

  //(* ram_style = "block" *)reg  [7:0] sdram                     [0:65534];
  //(* ram_style = "block" *)reg        sdram_9                   [0:65534];

(* ram_style = "block" *)reg  [7:0] sdram                     [0:1048575];  //1MB
(* ram_style = "block" *)reg        sdram_9                   [0:1048575];  //1Mbit

  reg  [9:0] hi_address;


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [9:0] s_address;

  wire [7:0] s_D_7_0;  // DATA IN
  wire [7:0] s_Q_7_0;  // DATA OUT (Q)

  wire       s_d9;
  wire       s_cas_n;
  wire       s_ras_n;
  wire       s_cas9_n;
  wire       s_W_n;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_address[9:0] = ADDRESS;
  assign s_cas_n        = CAS_n;
  assign s_ras_n        = RAS_n;
  assign s_cas9_n       = CAS9_n;
  assign s_W_n          = W_n;
  assign s_D_7_0        = D8;
  assign s_d9           = D9;
  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/


  wire [19:0] sip_address = {hi_address[9:0], s_address[9:0]};

  always @(negedge RAS_n) begin
    hi_address <= s_address[9:0];
  end

  always @(negedge CAS_n) begin
    if (!RAS_n) begin
      if (s_W_n) begin  // read
        Q8 <= sdram[sip_address];
        Q9 <= sdram_9[sip_address];

        if (sdram[sip_address] != 0) begin
          //$display("RAM READ Address %05h Value %4h", sip_address,sdram[sip_address]);
        end
      end else begin  // write
        sdram[sip_address]   <= D8;
        sdram_9[sip_address] <= D9;
        //$display("RAM WRITE Address %05h Value %4h (%02h / %02h)", sip_address, D8, hi_address, s_address);
      end
    end
  end

  // TODO: Assign Q8 from some PSRAM or other RAM
  //assign Q8        = W_n ? 8'b00000011 : 8'b00000000; // Data out is not valid when writing

  assign PRD_n = 1;  // Not connected?


  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/
  
endmodule
