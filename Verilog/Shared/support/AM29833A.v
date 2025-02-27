
/**********************************************************************************
** ND120 Shared                                                                  **
**                                                                               **
** Module AM29833A                                                               **
**                                                                               **
** PARITY BUS TRANSCEIVERS                                                       **
** Documentation:                                                                **
** https://pdf1.alldatasheet.com/datasheet-pdf/view/165880/AMD/AM29833A.html     **
**                                                                               **
**                                                                               **
** Last reviewed: 14-DEC-2024                                                    **
** Ronny Hansen                                                                  **
***********************************************************************************/





// Used on 3202D - Sheet 46 - MEM_DATA

/*
GENERAL DESCRIPTION 
The Am29833A and Am29853A are high-performance parity bus transceivers designed for two-way communications.
Each device can be used as an 8-bit transceiver, as well as a 9-bit parity checker/generator.

In the transmit mode, data is read at the R port and output at the T port with a parity bit.
In the receive mode, data and parity are read at the T port, and the data is output at the R port along with an /ERR flag showing the result of the parity test.

In the Am29833A, the error flag is clocked and stored in a register which is read at the open-collector ERR out-put.

The /CLR input is used to clear the error flag register.

In the Am29853A, a latch replaces this register, and the /EN and /CLR controls are used to pass, store, sample or clear the error flag output.
When both output enables are disabled in the Am29853A and Am29833A, the  parity logic defaults to the transmit mode, so that the ERR pin reflects the parity of the R port. 

The output enables, /OER and /OET, are used to force the port outputs to the high-impedance state so that other devices can drive bus lines directly.
In addition, the user can force a parity error by enabling both OER and OET simultaneously.

This transmission of inverted parity gives the designer more system diagnostic capability.
Each of these devices is produced with AMD's proprietary IMOX bipolar process, and features typical propagation delays of 6 ns, as well as high-capacitive drive capability.

*/


module AM29833A (
    input  wire       CLK,      //! Clock for parity error
    input  wire       CLR_n,    //! Clear error
    output reg        ERR_n,    //! Parity Error
    input  wire       OER_n,    //! Output enable (negated) R
    input  wire       OET_n,    //! Output enable (negated) T
    input  wire       PAR,      //! Parity bit (in)
    output reg        PAR_OUT,  //! Parity bit (out)
    input  wire [7:0] R,        //! R in
    output wire [7:0] R_OUT,    //! R out
    input  wire [7:0] T,        //! T in
    output wire [7:0] T_OUT     //! T out
);

  wire calculated_parity;

  // Sequential logic for registers
  //always @(posedge CLK or negedge CLR_n) begin

  //TODO: Do we need to handle CLR_n specific with a clock signal ?
  always @(posedge CLK) begin
    if (!CLR_n) begin
      // Reset logic
      ERR_n <= 1;
    end else begin
      if (!OET_n && OER_n) begin
        // Receive mode: Compare calculated parity with input parity  
        ERR_n <= !(calculated_parity == PAR);  // Active low error flag
      end else begin
        ERR_n <= 1'b1;  // High impedance when not receiving (here meaning '1' since ERR_n is active low)
      end
    end

    // Parity output for transmit mode
    if (!OER_n && OET_n) begin
      // Transmit mode: Generate parity based on R
      PAR_OUT = calculated_parity;
    end else begin
      PAR_OUT = 1'b0;  // High impedance when not transmitting (here meaning 0)
    end

  end



  assign R_OUT = (OET_n & !OER_n) ? T : 8'b0;  // RECEIVE MODE (Transmits data from T port to R port with parity test resulting in error flag. Transmit path is disabled.)
  assign T_OUT = (!OET_n & OER_n) ? R : 8'b0;  // TRANSMIT MODE (Transmits data from R port to T port, generating parity. Receive path is disabled.)


  // Calculate parity (odd parity)
  assign calculated_parity = ^R;  // XOR all bits in reg_R for odd parity


  //assign ERR_n = 1;  // Error flag logic to be implemented
  //assign PAR_OUT = 0;  // Parity flag logic to be implemented



endmodule

