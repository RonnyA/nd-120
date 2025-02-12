/****************************************************************************
** SC2661 UART                                                             **
**                                                                         **
** The SC2661 is a UART (Universal Asynchronous Receiver/Transmitter) chip **
**                                                                         **
** Last reviewed: 9-FEB-2025                                               **
** Ronny Hansen                                                            **
*****************************************************************************/

//
// Documentation
//
// http://www.norsk-data.com/hardware/nd-100/nd-350104.html
//
// SCN2661A UART
// http://www.norsk-data.com/library/libother/extern/SCN2661.pdf
//
// Enhanced Programmable Communication Interface EPCI
// https://datasheetspdf.com/pdf-file/1412058/SMSC/COM2661-3/1
//
// Note: Not all functionality is implemented. Just enough to have a simple UART interface for the ND-120 CPU

module SC2661_UART (
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    input [1:0] ADDRESS,  // Address lines (used to select internal EPCI registers)
    input BRCLK,  // Baud rate clock - Comes from the IO_DCD module. 4.9152Mhz
    input CE_n,  // Chip enable (negated)
    input CTS_n,  // Clear to send (negated)
    input DCD_n,  // Data Carrier Detect (negated)
    input DSR_n,  // Data Set Ready (negated)
    input READ_n,  // Write /Read
    input RESET,  // Reset - A high on this performs a master reset of the chip
    input RXC_n,  // Receiver Clock (used for SYNC, and not implemented)
    input RXD,  // Receive Data
    input TXC_n,  // Transmitter Clock (used for SYNC, and not implemented)

    input  [7:0] D,
    output [7:0] D_OUT,

    output DTR_n,     // Data Terminal Ready
    output RTS_n,     // Request to Send
    output RXDRDY_n,  // Receive Data Ready (complement of status register bit SR1)
    output TXD,       // Transmit Data
    output TXDRDY_n,  // Transmit Data Ready
    output TXEMT_n    // Transmit Empty (complement of status register bit SR2)
);


  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/

  /* verilator lint_off UNUSEDSIGNAL */
  wire s_brkclk;
  wire s_txc_n;
  wire s_rxc_n;
  wire s_cts_n;
  /* verilator lint_on UNUSEDSIGNAL */

  wire s_ce_n;

  wire s_dcd_n;
  wire s_dsr_n;
  wire s_dtr_n;
  wire s_read_n;
  wire s_reset;
  wire s_rts_n;

  wire s_rxd;
  wire s_rxrdy_n;

  wire s_txd;
  wire s_txemt_n;
  wire s_txrdy_n;

  wire [1:0] s_address;
  wire [7:0] s_data_in;



  /*******************************************************************************
   ** Command register bits                                                      **
   *******************************************************************************/

  wire cmd_txEnabled;
  wire cmd_forceDTRLow;
  wire cmd_rxEnabled;

  /* verilator lint_off UNUSEDSIGNAL */
  wire cmd_CR3;  // ASYNC: 0=Normal, 1=Force Break. SYNC: 0=Normal, 1=Send DLE (not implemented)
  /* verilator lint_on UNUSEDSIGNAL */

  wire cmd_resetError;
  wire cmd_forceRTSLow;
  wire [1:0] cmd_OperatingMode;

  //localparam cmd_OperatingMode_NORMAL = 2'b00; // not used..in code.. yet
  //localparam cmd_OperatingMode_ASYNC = 2'b01;  // not used..in code.. yet

  localparam cmd_OperatingMode_LocalLoopback = 2'b10;
  localparam cmd_OperatingMode_RemoteLoopback = 2'b11;




  /*******************************************************************************
   ** Mode register 1 and 2 bits                                                 **
   *******************************************************************************/
  // Not implemented, we use constant 9600 8N1, or later 115200 8N1

  /*******************************************************************************
   ** State machine for the receiver and transmitter                             **
   *******************************************************************************/

  localparam RX_STATE_IDLE = 3'b000;  // 0 
  localparam RX_STATE_START_BIT = 3'b001;  // 1
  localparam RX_STATE_READ_WAIT = 3'b010;  // 2
  localparam RX_STATE_READ = 3'b011;  // 3
  localparam RX_STATE_STOP_BIT = 3'b101;  // 4
  localparam RX_STATE_DONE = 3'b110;  // 5

  localparam TX_STATE_IDLE = 3'b000;  //  0 
  localparam TX_STATE_START_BIT = 3'b001;  // 1
  localparam TX_STATE_WRITE = 3'b010;  // 2
  localparam TX_STATE_STOP_BIT = 3'b011;  // 3
  localparam TX_STATE_DONE = 3'b100;  //  4


  //Later, refactor clock to use higher FPGA clock to allow for 115200 baud rate.
  //localparam DELAY_FRAMES = 42; //  4.915.200  (100Mhz) / 115200 Baud rate

  //  localparam integer DELAY_FRAMES = 16;  // 4.915.200 / 9600 = 512; // use 256 frames for 19.200 baud.
  //  localparam integer HALF_DELAY_WAIT = (DELAY_FRAMES / 2);

  localparam DELAY_FRAMES = 32'd16;  // 16 frames
  localparam HALF_DELAY_WAIT = (DELAY_FRAMES >> 1);  // Equivalent to DELAY_FRAMES / 2


  // Chip Registers
  reg  [ 7:0] regDataOut;
  reg  [ 7:0] regReceiveHoldingRegister;
  reg  [ 7:0] regTransmitHoldingRegister;
  reg  [ 7:0] regStatusRegister;
  reg  [ 7:0] regModeRegister;
  reg  [ 7:0] regCommandRegister;


  // Transmitter local variables
  reg  [ 2:0] txState;
  reg  [31:0] txCounter;
  reg  [ 2:0] txBitNumber;
  reg         txBit;
  reg         regDataInSendRegister;  // 1=Data in send register (=>TxEmpty =0)

  // Receiver local variables
  reg  [ 2:0] rxState = 0;
  reg  [31:0] rxCounter = 0;
  reg  [ 2:0] rxBitNumber = 0;

  wire        receiver_input;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_address = ADDRESS;
  assign s_data_in = D;

  assign s_brkclk = BRCLK;
  assign s_ce_n = CE_n;
  assign s_cts_n = CTS_n;
  assign s_dcd_n = DCD_n;
  assign s_dsr_n = DSR_n;
  assign s_read_n = READ_n;
  assign s_reset = RESET;
  assign s_rxc_n = RXC_n;
  assign s_rxd = RXD;
  assign s_txc_n = TXC_n;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/

  // output pins
  assign s_dtr_n = !cmd_forceDTRLow;
  assign s_rts_n = !cmd_forceRTSLow;

  assign DTR_n = s_dtr_n;
  assign RTS_n = s_rts_n;
  assign RXDRDY_n = s_rxrdy_n;
  assign TXD = s_txd;
  assign TXDRDY_n = s_txrdy_n;
  assign TXEMT_n = s_txemt_n;



  assign D_OUT = (!s_ce_n & !s_read_n) ? regDataOut : 8'b0;
  /*
    /TxRDY

    This output is the complement of status register bit SR0.
    When Low, it indicates that the transmit data holding register (THR) is ready to accept a data character from the CPU.
    It goes High when the data character is loaded.
    This output is valid only when the transmitter is enabled. It is an open-drain output which can be used as an interrupt to the CPU.
   */
  assign s_txrdy_n = cmd_txEnabled ? ~regStatusRegister[0] : 1'b1;
  /*
    /RxRDY

    This output is the complement of status register bit SR1.

    When Low, it indicates that the receive data holding register (RHR) has a character ready for input to the CPU.
    It goes High when the RHR is read by the CPU, and also when the receiver is disabled.
    It is an open-drain output which can be used as an interrupt to the CPU

   */
  assign s_rxrdy_n = cmd_rxEnabled ? ~regStatusRegister[1] : 1'b1;

  //assign s_txemt_n = regDataInSendRegister;
  assign s_txemt_n = ~regStatusRegister[2];  // When SR2 is set, the /TxEMT/DSCHG output is Low


  // In Local Loopback - The transmitter output is connected to the receiver input.
  assign receiver_input = (cmd_OperatingMode == cmd_OperatingMode_LocalLoopback) ? s_txd : s_rxd;


  // Command Register helper bits
  assign cmd_txEnabled       = regCommandRegister[0];      // Transmit Control bit: 0 = Disable transmitter, 1 = Enable transmitter
  assign cmd_forceDTRLow     = regCommandRegister[1];      // 0 = Force /DTR output high, 1= Force /DTR output low
  assign cmd_rxEnabled       = regCommandRegister[2];      // Receive Control bit: 0 = Disable receiver, 1 = Enable receiver
  assign cmd_CR3             = regCommandRegister[3];      // Not used?
  assign cmd_resetError      = regCommandRegister[4];      // 1=Reset error flag in status (FE;OD; PE/DLE detect), 0=normal (no effect?)
  assign cmd_forceRTSLow     = regCommandRegister[5];      // 0 = Force /RTS output high, 1= Force /RTS output low
  assign cmd_OperatingMode   = regCommandRegister[7:6];    // Operating Mode bits. 00 = Normal operation, 01= Async (Automatic Echo mode), Synch: SYN AND/OR DLE STRIPPING MODE, 01 = LOCAL LOOPBACK, 11=REMOTE LOOPBACK


  reg regCommandExecuted;  // Flag set when read/write operation has been executed


  wire uart_sysclk = ~sysclk;

  assign s_txd = txBit;

  // Clear everything on reset
  //always @(posedge RESET or posedge BRCLK) begin
  always @(posedge uart_sysclk) begin

    // Reset UART ?
    if (RESET | !sys_rst_n) begin
        //$display("Time: %0t | UART RESET!", $time);  //  debug

        regReceiveHoldingRegister <= 8'b0;
        regTransmitHoldingRegister <= 8'b0;
        regStatusRegister <= 8'b00000001; // TX empty
        regModeRegister <= 8'b0;
        regCommandRegister <= 8'b0;
        regDataOut <= 8'b0;
        regDataInSendRegister <= 0;
        rxState <= RX_STATE_IDLE;
        txState <= TX_STATE_IDLE;
        regCommandExecuted <=0;
        txBit <= 1; // After reset, set TX signl to MARK
      end else begin
      // Latch Address and Data
        if (CE_n) begin
          // Chip is not enabled
          regCommandExecuted <= 0;  // Clear signal that address & data is latched
        end else begin

          //if (!RESET && !CE_n && !regCommandExecuted) begin  // _NOT RESET_ AND _CHIP ENABLED_ (and command not already executed)        
          if (!regCommandExecuted) begin
            // Read and Write to registers
            if (cmd_rxEnabled|cmd_txEnabled) begin // Only update status register SR2 if RX or TX is enabled              
                if ((regStatusRegister[6] == s_dcd_n) | (regStatusRegister[7] == s_dsr_n))
                regStatusRegister[2] <= 1; // Detected change in DSR or DCD   //SR2: 0=Normal, 1=Change in /DSR or /DCD or transmit shift register is empty
            end

            regStatusRegister[6] <= !s_dcd_n;  // DCD - 0=/DCD input is high. 1=/DCD input is low
            regStatusRegister[7] <= !s_dsr_n;  // DSR - 0=/DSR input is high. 1=/DSR input is low


            if (s_read_n) begin  // write to registers
              //$display("Time: %0t | UART Write=> Address: %h | Data: %h", $time, s_address, D);

              case (s_address)
                2'b00: begin
                  //Write to transmit holding register
                  regTransmitHoldingRegister <= s_data_in;  // Write transmit holding register
                  regDataInSendRegister <= 1;  // Send data to transmitter
                end

                2'b01: begin
                  regStatusRegister <= s_data_in;  // Write SYN1/SYN2/DLE registers
                end

                2'b10: begin
                  regModeRegister <= s_data_in;  // Write mode register 1 and 2
                end

                2'b11: begin
                  regCommandRegister <= s_data_in;  // Write command register

                  if (!cmd_rxEnabled) begin
                    regStatusRegister[1] <= 0;     // 0=Receive Holding Register Empty (Cleared if RX is disabled)
                  end

                  if (cmd_resetError)
                  begin
                    regStatusRegister[3] <= 0;  // 0=Clear Parity Error
                    regStatusRegister[4] <= 0;  // 0=Clear Overrun Error
                    regStatusRegister[5] <= 0;  // 0=Clear Frame Error
                  end
                end
                  default: ;  // Undefined state
              endcase
            end else begin
              // read
              regDataOut <=
                  (s_address == 2'b00) ? regReceiveHoldingRegister :
                  (s_address == 2'b01) ? regStatusRegister         :
                  (s_address == 2'b10) ? regModeRegister           :
                  (s_address == 2'b11) ? regCommandRegister        : 8'b0;

              case (s_address)
                  2'b00: begin
                    //regDataOut = regReceiveHoldingRegister;  // Read receive holding register  (data out)
                    regStatusRegister[1] <= 0;  // 0=Receive Holding Register Empty
                  end
                  2'b01: begin
                    //regDataOut = regStatusRegister;  // Read status register
                    regStatusRegister[2] <= 0;  // Clear register SR2
                  end
                  //2'b10:   regDataOut = regModeRegister;  // Read mode register 1 and 2
                  //2'b11:   regDataOut = regCommandRegister;  // Read command register
                  default: ;  // Undefined state
              endcase
              //$display("Time: %0t | UART READ <= Address: %h | Data: %h", $time, s_address, regDataOut);
            end
          end

          // Mark this command as executed until next Chip Select
          regCommandExecuted <=1;
        end



        // Receiver state machine
        // ----------------------
        // The 68661 is conditioned to receiver data when the DCD input is Low and the RxEN bit in the commands register is true.
        // In this code we just receive when the RxEN bit is set. (Ignore DCD input)
        if (!cmd_rxEnabled) begin
          rxState <= RX_STATE_IDLE;
        end else begin
          case (rxState)
            RX_STATE_IDLE: begin
              if (receiver_input == 0) begin
                if (regStatusRegister[1] == 1) begin
                  //regStatusRegister[1] <= 0;  // Clear status register bit RxRDY  -- SET OVERRUN?
                  regStatusRegister[4] <= 1;  // Overrun: 0=Normal, 1=Overrun
                end

                rxState              <= RX_STATE_START_BIT;
                //$display("-> RX START BIT");

                regReceiveHoldingRegister <=0;
                rxCounter            <= 1;
                rxBitNumber          <= 0;
              end
            end
            RX_STATE_START_BIT: begin
              if (rxCounter == HALF_DELAY_WAIT) begin
                rxState   <= RX_STATE_READ_WAIT;
                //$display("-> RX READ WAIT");
                rxCounter <= 1;
              end else rxCounter <= rxCounter + 1;
            end
            RX_STATE_READ_WAIT: begin
              rxCounter <= rxCounter + 1;
              if ((rxCounter + 1) == DELAY_FRAMES) begin
                rxState <= RX_STATE_READ;
                //$display("-> RX STATE READ");
              end
            end
            RX_STATE_READ: begin
              rxCounter <= 1;
              regReceiveHoldingRegister <= {
                receiver_input, regReceiveHoldingRegister[7:1]
              };  // Shift right and insert s_rxt at MSB.
              rxBitNumber <= rxBitNumber + 1;
              //$display("-> RX STATE READ bit %d",receiver_input);

              if (rxBitNumber == 3'b111) begin
                rxState <= RX_STATE_STOP_BIT;
                //$display("-> RX STATE STOP BIT");
              end else begin
                rxState <= RX_STATE_READ_WAIT;
                //$display("-> RX STATE READ WAIT");
              end
            end
            RX_STATE_STOP_BIT: begin
              rxCounter <= rxCounter + 1;
              if ((rxCounter + 1) == DELAY_FRAMES) begin
                rxState <= RX_STATE_DONE;
                //$display("-> RX STATE DONE");
                rxCounter <= 0;
                regStatusRegister[1] <= 1;  // Set RXRDY
              end
            end
            RX_STATE_DONE: begin
              rxState <= RX_STATE_IDLE;
              //$display("-> RX STATE IDLE %h", regReceiveHoldingRegister);
              //$display("-> RX READY_n FLAG %d",  s_rxrdy_n);

              // LOOPBACK?
              if (cmd_OperatingMode == cmd_OperatingMode_RemoteLoopback) begin
                // Data assembled by the receiver are automatically placed in the
                // transmit holding register and retransmitted by the transmitter on the TxD output.
                //$display("RX -> TX LOOPBACK");
                regTransmitHoldingRegister <= regReceiveHoldingRegister; // Write rx holding register
                regDataInSendRegister <= 1;  // Send data to transmitter
              end
            end
            default: begin
              rxState <= RX_STATE_IDLE;  // Very unexpected, go to IDLE
            end
          endcase
        end
  

  // Transmitter state machine
  // -------------------------
  // The EPCI is conditioned to transmit data when the CTS input is Low and the TxEN command register bit is set.
  // In this code we just transmit when the TxEN command register bit is set. (Ignore CTS input)

    
        if (!cmd_txEnabled) begin
          txState <= TX_STATE_IDLE;
          txBit <= 1;
          txBitNumber <= 0;
          regDataInSendRegister <= 0;
          txCounter <= 0;
        end else begin
          case (txState)
            TX_STATE_IDLE: begin
              if (regDataInSendRegister) begin
                regStatusRegister[0] <= 0;  // 0=Transmit Holding Register BUSY
                txState              <= TX_STATE_START_BIT;
                txCounter            <= 0;
              end else begin
                txBit <= 1;
                regStatusRegister[0] <= 1; // tx empty
              end
            end
            TX_STATE_START_BIT: begin
              txBit <= 0;
              if ((txCounter + 1) == DELAY_FRAMES) begin
                txState <= TX_STATE_WRITE;
                txBitNumber <= 0;
                txCounter <= 0;
              end else txCounter <= txCounter + 1;
            end
            TX_STATE_WRITE: begin
              txBit <= regTransmitHoldingRegister[txBitNumber];
              if ((txCounter + 1) == DELAY_FRAMES) begin
                if (txBitNumber == 3'b111) begin
                  txState <= TX_STATE_STOP_BIT;
                end else begin
                  txState <= TX_STATE_WRITE;
                  txBitNumber <= txBitNumber + 1;
                end
                txCounter <= 0;
              end else txCounter <= txCounter + 1;
            end
            TX_STATE_STOP_BIT: begin
              txBit <= 1;
              if ((txCounter + 1) == DELAY_FRAMES) begin
                txState   <= TX_STATE_DONE;
                txCounter <= 0;
              end else txCounter <= txCounter + 1;
            end
            TX_STATE_DONE: begin
              regDataInSendRegister <= 0;
              regStatusRegister[0] <= 1;  //1=Transmit Holding Register Empty
              regStatusRegister[2] <= 1;  // TxEMT: 1=Transmit shift register empty
              txState <= TX_STATE_IDLE;
            end
            default: begin
              txState <= TX_STATE_IDLE;  // Very unexpected, go to IDLE
            end
          endcase
        end
    end
  end

endmodule
