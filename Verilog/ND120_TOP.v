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


  // Installation number.
  // TODO: Find out what is valid values
  wire [7:0] installation_number = 8'd100;

  // helpers
  wire s_high= 1'b1;
  wire s_low= 1'b0;
  wire sys_rst_n;

  // input signals
  wire clk1;  //! Clock Signal 1
  //wire clk2;  //! Clock Signal 2
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

  wire s_run;  // RUN: 1=CPU is running, 0=OPCOM mode
  (* keep = "true", DONT_TOUCH = "true" *)  wire [4:0] s_test_4_0;  // Test pads
  (* keep = "true", DONT_TOUCH = "true" *)  wire [4:0] s_dp_5_1_n;  // Datapath 5-1
  (* keep = "true", DONT_TOUCH = "true" *)  wire s_tp1_intrq_n;     // TP1 INTRQ_n
  (* keep = "true", DONT_TOUCH = "true" *)  wire [63:0] s_csbits;   // Microcode CPU BITS

  reg [32:0] clockTicks;

  // TODO: Modify clock ?
  assign clk1 = sysclk;  // XTAL1 = 39.3216MHZ
  //assign clk2 = sysclk;  // XTAL2 = 35 MHZ (for slow operations?)
  assign sys_rst_n = btn1;
  assign oc_select = 2'b11;  // 11= Choose clock input = XTAL1 (full speed)

  // Assign som lights to the LED's (Inverted because the nano is led's are active low)
  //assign led[5:0] =5'b0;

  assign led[1:0] = ~s_cpu_led[1:0];  //  0=RED,1=GREEN
  assign led[2] = !s_run;
  assign led[3] = !s_cpu_led[3]; // LED CPU GRANT INDICATOR
  assign led[4] = !s_cpu_led[4]; // LED BUS GRANT INDICATOR
  assign led[5] = !s_cpu_led[5]; // LED1 from MMU

  //assign led[4] = !uartRx;
  //assign led[5] = !uartTx;

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

      // Signal from C-PLUG to CPU Board (and some signals dupliacted on A-PLUG)
      .LOAD_n(s_high),      // Load button  C-B12, A-C15
      .BREQ_n(s_high),      // Bus Request  C-C12
      .CONTINUE_n(s_high),  // Continue button C-B15
      .STOP_n(s_high),      // Stop button C-B16, A-C17

      .BINT10_n(1'b1),  // Bus Interrupt 10 C-A15
      .BINT11_n(1'b1),  // Bus Interrupt 11 C-C15
      .BINT12_n(1'b1),  // Bus Interrupt 12 C-A16
      .BINT13_n(1'b1),  // Bus Interrupt 13 C-A16
      .BINT15_n(1'b1),  // Bus Interrupt 15 C-C17

      .POWSENSE_n(s_high),  // Power Sense

      // Signals from CPU board to C-PLUG
      .BREF_n(),      // Output-signal to "C PLIG", signal B12 BREF~
      .BERROR_n(),    // Output-signal to "C PLIG", signal B21 BERROR~
      .BINACK_n(),    // Output-signal to "C PLIG", signal B19 BINACK~
      .BIOEX_n(),     // Output-signal to "C PLIG", signal C19 BIOXE~
      .BMEM_n(),      // Output-signal to "C PLIG", signal C28 BMEM~
      .OUTGRANT_n(),  // Output-signal to "C PLIG", signal C23 OUTGRANT~
      .OUTIDEN_n(),   // Output-signal to "C PLIG", signal C22 OUTIDENT~
      .MCL(),         // Output-signal to "C PLIG", signal B20 MCL~ (after negation)


      // Signals from B-PLUG to CPU Board
      .INR_7_0(installation_number), // INR 7:0, signal B-> B15, B4, B5, B17, B8, B7, B13, B6. (Installation number, read using IDB Source = 035)
      .EBUS(1),       // EBUS, signal B-B3 (Pulled high with through resistor network RN13)
      .SEL5MS_n(1),   // SEL 5ms, signal B-B14 (Pulled high with 1kohm resistor R4)

      // Signals from CPU to B-PLUG
      .PIL(),         // XPIL3=B-C8, PIL2=B-B12. PIL1=B-B10, PIL0=B-B9
      .LUA_12_0(),    // XLUA 12:0
      .IDB_15_0(),    // XIDB 15:0
      .CSCOMM_4_0(),  //
      .MIS_1_0(),     // MIS1=B-C14, MIS0=B-A14
      .CD_15_0(),     // CD 15:0
      .LBD_15_0(),    // LBD 15:0
      .LA_23_10(),    // XLA 23:10
      .CA_9_0(),      // CA 9:0


      // Signals from A-PLUG to CPU board
      .OSCCL_n  (s_high),     // Oscillator Clock
      .OC_1_0   (oc_select),  // Oscillator Clock Select
      .XTR      (s_low),      // External Transmit/Receive Clock (not used)
      .LOCK_n   (s_high),     // Lock signal (from key)
      .CONSOLE_n(s_high),     // Console signal (from key)
      .SWMCL_n  (s_high),     // Software Master Clear (MCL)
      .EAUTO_n  (s_high),     // External Auto
      .RXD      (uartRx),     // UART Receive A-C8

      // Signals from CPU Board to A-PLUG
      .TXD        (uartTx),   // UART Transmit TXD A-C7
      .RUN_n      (s_run),    // Run A-C18
      .DP_5_1_n   (s_dp_5_1_n),     // Data Path 5-1 A-> 1=C25, 2=C26, 3=C27, 4=C28, 5=C29


      /* Configuration switches (input to ND3202D board) */
      .SW1_CONSOLE     (s_high),             // Console switch
      .SEL_TESTMUX     (s_SEL_TESTMUX),      // Test MUX (select signals to test pads)
      .BAUD_RATE_SWITCH(s_baud_rate_switch), // Baud rate switch

      // outputs
      .CSBITS     (s_csbits),       // Microcode CPU BITS
      .TEST_4_0   (s_test_4_0),     // Test pads
      .TP1_INTRQ_n(s_tp1_intrq_n),  // TP1 Interrupt
      .LED        (s_cpu_led[5:0])  // 6 bit LED signals
  );

endmodule
