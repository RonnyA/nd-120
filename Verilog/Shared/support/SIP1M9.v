/******************************************************************************
** RAM CHIP 1 MBYTE (1024KB)                                                  **
**                                                                            **
** This ram has PARITY bit..                                                  **
** THM91020 - http://norsk-data.com/library/libother/extern/THM91020.pdf      **
** THM91070 - http://norsk-data.com/library/libother/extern/THM91070.pdf      **
**                                                                            **
** Last reviewed: 29-JAN-2025                                                 **
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


    // Input signals
    input [7:0] D8,  //! DATA INPUT (8-bit)
    input       D9,  //! DATA INPUT (1-bit)

    // Output signals
    output [7:0] Q8,    //! DATA OUTPUT (8-bit)
    output       Q9,    //! DATA OUTPUT (1-bit)
    output       PRD_n  //! Parity bit

);

  //(* ram_style = "block" *)reg  [7:0] sdram                     [0:65534];
  //(* ram_style = "block" *)reg        sdram_9                   [0:65534];

  (* ram_style = "block" *)reg  [7:0] sdram                     [0:1048575];  //1MB
  (* ram_style = "block" *)reg        sdram_9                   [0:1048575];  //1Mbit

  reg  [9:0] hi_address;

  reg  [7:0] reg_Q8;
  reg        reg_Q9;

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


  wire [19:0] sip_address = (CAS_n == 0) ? {hi_address[9:0], s_address[9:0]} : 20'b0;

  always @(negedge RAS_n) begin
    hi_address <= s_address[9:0];
  end

  always @(negedge CAS_n) begin
    if (!RAS_n) begin
      if (s_W_n) begin  // read
        reg_Q8 <= sdram[sip_address];
        reg_Q9 <= sdram_9[sip_address];
      end else begin  // write
        sdram[sip_address]   <= D8;
        sdram_9[sip_address] <= D9;
      end
    end
  end


  // Data out is valid as long as CAS is active (and its read, not write)
  assign Q8 = ((CAS_n == 0) && (s_W_n)) ? reg_Q8 : 8'b00000000;
  assign Q9 = ((CAS_n == 0) && (s_W_n)) ? reg_Q9 : 0;


  // Even Parity Logic
  assign PRD_n = ~(
    Q8[0] ^
    Q8[1] ^
    Q8[2] ^
    Q8[3] ^
    Q8[4] ^
    Q8[5] ^
    Q8[6] ^
    Q8[7] ^
    Q9
  );

endmodule
