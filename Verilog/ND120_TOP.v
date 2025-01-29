// WaveDrom  documentation: https://wavedrom.com/tutorial.html
// WaveDrom Editor: https://wavedrom.com/editor.html
// TerosHDL:  see https://github.com/TerosTechnology/vscode-terosHDL
// Verible: https://github.com/chipsalliance/verible
// Verible plugin for VS Code: https://marketplace.visualstudio.com/items?itemName=CHIPSAlliance.verible
// Verible Lint: https://chipsalliance.github.io/verible/lint.html
// YoSys: https://github.com/YosysHQ/oss-cad-suite-build

/**************************************************************************
** ND120 CPU, MEMORY MANAGEMENT and MEMORY                               **
**                                                                       **
** TOP LEVEL FOR FPGA IMPLEMENTATION                                     **
**                                                                       **
** Last reviewed: 14-DEC-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/



//! @title ND120 CPU, MEMORY MANAGEMENT and MEMORY.
//! @author Ronny Hansen
//! TOP LEVEL FOR FPGA IMPLEMENTATION OF ND-3202D CPU BOARD

module ND120_TOP
(
    input wire sysclk,    //! System Clock
    input wire btn1,      //! Button 1, mapped to S1 (not labeled) on the board - connected to sys_rst_n
    input wire btn2,      //! Button 2, mapped to S2 (not labeled) on the board
    input wire uartRx,    //! UART Receive pin

    // Outputs
    output wire uartTx,    //! UART Transmit pin
    output wire [5:0] led  //! 6-bit output for controlling LEDs
);

  //TODO: Add signals for BUS-C interface on module input and output (to connect to peripherals as tape-reader)

  // helpers
  wire s_high;
  wire s_low;
  wire sys_rst_n;
  assign s_high = 1'b1;
  assign s_low  = 1'b0;

  // input signals
  wire clk1;  //! Clock Signal 1
  wire clk2;  //! Clock Signal 2
  wire [1:0] oc_select;

  wire [2:0] s_SEL_TESTMUX;
  assign s_SEL_TESTMUX = 2'b000;  // 00=TESTMUX=0

  wire [3:0] s_baud_rate_switch;
  assign s_baud_rate_switch = 4'b1000;  // 8=9600 baud (ref BAUDV page 158 in microcode)

  // output wire from CPU

  wire [5:0] s_cpu_led;  // 6 bit LED signals
  //   0=CPU RED
  //   1=CPU GREEN
  //   2=LED4_RED_PARITY_ERROR
  //   3=LED_CPU_GRANT_INDICATOR
  //   4=LED_BUS_GRANT_INDICATOR
  //   5=LED1 from MMU

  wire s_run;  //! RUN: 1=CPU is running, 0=OPCOM mode
  wire [4:0] s_test_4_0;  //! Test pads
  wire [4:0] s_dp_5_1_n;
  wire s_tp1_intrq_n;
  wire [63:0] s_csbits;  //! Microcode CPU BITS

  reg [32:0] clockTicks;

  // TODO: Modify clock ?
  assign clk1 = sysclk;  // XTAL1 = 39.3216MHZ
  assign clk2 = sysclk;  // XTAL2 = 35 MHZ (for slow operations?)
  assign sys_rst_n = btn1;
  assign oc_select = 2'b11;  // 11= Choose clock input = XTAL1 (full speed)

  // Assign som lights to the LED's (Inverted because the nano is led's are active low)
  //assign led[5:0] =5'b0;

  assign led[1:0] = ~s_cpu_led[1:0];  //  0=RED,1=GREEN
  assign led[2] = !s_run;
  assign led[3] = !s_cpu_led[3];  // LED CPU GRANT INDICATOR
  //assign led[4] = !s_cpu_led[4] // LED BUS GRANT INDICATOR
  assign led[4] = !uartRx;
  assign led[5] = !uartTx;

  // For debugging: shows # of clockticks in GTKWave if needed
  always@(posedge sysclk)
  begin
    clockTicks <= clockTicks+1;
  end


  ND3202D CPU_BOARD (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .CLOCK_1(clk1),  // XTAL1 = 39.3216MHZ
      .CLOCK_2(clk1),  // XTAL2 = 35 MHZ (for slow operations?)

      // Signal from C-PLUG
      .LOAD_n(s_high),  //! Load button
      .BREQ_n(s_high),  //! Bus Request
      .CONTINUE_n(s_high),  //! Continue button
      .STOP_n(s_high),  //! Stop button

      .BINT10_n(1'b1),  //! Bus Interrupt 10
      .BINT11_n(1'b1),  //! Bus Interrupt 11
      .BINT12_n(1'b1),  //! Bus Interrupt 12
      .BINT13_n(1'b1),  //! Bus Interrupt 13
      .BINT15_n(1'b1),  //! Bus Interrupt 15

      .POWSENSE_n(s_high),  //! Power Sense

      // Signals from A-PLUG
      .OSCCL_n  (s_high),     //! Oscillator Clock
      .OC_1_0   (oc_select),  //! Oscillator Clock Select
      .XTR      (s_low),      //! External Transmit/Receive Clock (not used)
      .LOCK_n   (s_high),     //! Lock signal (fromn key)
      .CONSOLE_n(s_high),     //! Console signal (from key)
      .SWMCL_n  (s_high),     //! Software Master Clear (MCL)
      .EAUTO_n  (s_high),     //! External Auto
      .RXD      (uartRx),     //! UART Receive

      /* Configuration switches */
      .SW1_CONSOLE     (s_high),             //! Console switch
      .SEL_TESTMUX     (s_SEL_TESTMUX),      //! Test MUX (select signals to test pads)
      .BAUD_RATE_SWITCH(s_baud_rate_switch), //! Baud rate switch

      // outputs
      .CSBITS     (s_csbits),       //! Microcode CPU BITS
      .DP_5_1_n   (s_dp_5_1_n),     //! Data Path 5-1
      .RUN_n      (s_run),          //! Run
      .TEST_4_0   (s_test_4_0),     //! Test pads
      .TP1_INTRQ_n(s_tp1_intrq_n),  //! TP1 Interrupt
      .TXD        (uartTx),         //! UART Transmit
      .LED        (s_cpu_led[5:0])  //! 6 bit LED signals
  );

endmodule
