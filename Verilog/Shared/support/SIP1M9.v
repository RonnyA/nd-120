/******************************************************************************
** RAM CHIP 1 MBYTE (1024KB)                                                  **
**                                                                            **
** This ram has PARITY bit..                                                  **
** THM91020 - http://norsk-data.com/library/libother/extern/THM91020.pdf      **
** THM91070 - http://norsk-data.com/library/libother/extern/THM91070.pdf      **
**                                                                            **
** Last reviewed: 9-FEB-2025                                                  **
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
    output       PRD_n  //! Parity Data Output

);

  wire parity_calculation;

  // Parameters are declared here
  parameter ramSize = 0; // 0 = Disabled, 1=64KB, 2=1MB

  
// Convert ramSize into a memory depth. 
// Feel free to tweak default 1 if "disabled" should do something else.
  localparam integer MEM_DEPTH = (ramSize == 2) ? 1048575 :   // 1 MB
                                 (ramSize == 1) ? 65535   :   // 64 KB
                                                  1;          // Disabled = 1 word (or 0, if desired)

// Now use that for your memory declarations.
(* ram_style = "block" *) reg [7:0] sdram   [0:MEM_DEPTH-1];
(* ram_style = "block" *) reg       sdram_9 [0:MEM_DEPTH-1];


  //(* ram_style = "block" *)reg  [7:0] sdram                     [0:65534];
  //(* ram_style = "block" *)reg        sdram_9                   [0:65534];

  //(* ram_style = "block" *)reg  [7:0] sdram                     [0:1048575];  //1MB
  //(* ram_style = "block" *)reg        sdram_9                   [0:1048575];  //1Mbit

  reg  [9:0] hi_address;

  reg  [7:0] reg_Q8;
  reg        reg_Q9;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/

  wire [19:0] sip_address = (CAS_n == 0) ? {hi_address[9:0], ADDRESS[9:0]} : 20'b0;

  always @(negedge RAS_n) begin
    hi_address <= ADDRESS[9:0];
  end

  always @(negedge CAS_n) begin
    if (!RAS_n) begin
      if (W_n) begin  // read
        reg_Q8 <= sdram[sip_address];
        reg_Q9 <= sdram_9[sip_address];
      end else begin  // write
        sdram[sip_address]   <= D8;
        sdram_9[sip_address] <= D9;
      end
    end
  end


  // Data out is valid as long as CAS is active (and its read, not write)
  assign Q8 = ((CAS_n == 0) && (W_n)) ? reg_Q8 : 8'b00000000;
  assign Q9 = ((CAS_n == 0) && (W_n)) ? reg_Q9 : 0;


  // Even Parity Logic
    // ^ (in Verilig) is XOR giving 0=if even, 1=if odd.
  // Invert this so that the PAR signal is according to Am29833A documentation: PAR=L on ODD and PAR=H on EVEN
  assign parity_calculation =  (^{Q8, Q9});

  assign PRD_n = ((CAS_n == 0) && (W_n))  ? parity_calculation : 1;
  /*
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
  */

endmodule
