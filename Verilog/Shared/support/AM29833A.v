
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
** Last reviewed: 22-MAR-2025                                                    **
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
    output wire       ERR_n,    //! Parity Error
    input  wire       OER_n,    //! Output enable (negated) R
    input  wire       OET_n,    //! Output enable (negated) T
    input  wire       PAR,      //! Parity bit (in)
    output wire       PAR_OUT,  //! Parity bit (0=ODD,1=EVEN)
    input  wire [7:0] R,        //! R in
    output wire [7:0] R_OUT,    //! R out
    input  wire [7:0] T,        //! T in
    output wire [7:0] T_OUT     //! T out
);

  reg regERR;

  // Transmit Mode: Transmits data from R port to T port. Generating parity. Receive path is disabled.
  wire TransmitMode;
  assign TransmitMode = !OET_n & OER_n;

  // Receive Mode: Transmits data from T port to R port with parity test resulting in error flag. Transmit path is disabled
  wire ReceiveMode;
  assign ReceiveMode = OET_n & !OER_n;

  // Both OET_n is low and OER_n is low
  wire ResetMode;
  assign ResetMode = !OET_n & !OER_n;

  // Data path
  assign T_OUT = (TransmitMode) ? R : 8'b0;  // TRANSMIT MODE
  //assign R_OUT = (ReceiveMode) ? T : 8'b0;   // RECEIVE MODE
  assign R_OUT = (ReceiveMode) ? T : 8'b0;   // RECEIVE MODE

  // In receivemode PAR_OUT is high-impediance (we use 0 for that here)
  //
  // ^ (in Verilig) is XOR giving 0=if even, 1=if odd.
  // Invert this so that the PAR signal is according to Am29833A documentation: PAR=L on ODD and PAR=H on EVEN
  assign PAR_OUT = (!ReceiveMode) ? ~(^R) : 1'b0;

  // ERR register logic (latched on CLK)
  always @(posedge CLK or negedge CLR_n) begin
    if (!CLR_n)
    begin
      // Clear error flag
      regERR <= 1'b0;
    end
    else if (!ReceiveMode) // Defaul to transmit mode if ReceiveMode is not active
    begin
        // Store error flag if even parity detected, and error is not already set
        regERR <= ~(^{T, PAR}); // Parity check on T input + incoming PAR. If those 9 bits is EVEN we have an error      
    end
  end

  // ERR output logic (open-collector style)
  assign ERR_n = regERR ? 1'b0 : 1'b1; //open collector is here resulting in an 1 when there is no error

endmodule

