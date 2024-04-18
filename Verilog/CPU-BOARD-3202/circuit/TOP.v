module TopModule (
    input sys_clk,
    input sys_rst_n, // mapped to button 4 on the board (s1, not labled)
    output [5:0] led,
    input uartRx,
    output uartTx    
);


//TODO: Add signals for SD CARD interface

// helpers
wire s_high;
wire s_low;
assign s_high = 1'b1;
assign s_low = 1'b0;

// input signals
wire clk1;
wire clk2;
wire [1:0] oc_select;

// output wire
wire [1:0] s_led;
wire s_run;
wire [4:0] s_test_4_0;
wire [5:0] s_dp_5_1_n;
wire s_tp1_intrq_n;


// TODO: Modify clock ? 
assign clk1 = sys_clk;  // XTAL1 = 39.3216MHZ
assign clk2 = sys_clk;  // XTAL2 = 35 MHZ (for slow operations?)

assign oc_select = 2'b11; // 11= Choose clock input = XTAL1 (full speed)
wire [63:0] s_csbits;


// Assign som lights to the LED's (Inverted because the nano is led's are active low)

assign led[1:0]=~s_led;  //  0=RED,1=GREEN 
assign led[2] = !s_run;
assign led[3] = !s_tp1_intrq_n;
assign led[4] = !uartTx;
assign led[5] = !uartRx;

ND3202D CPU_BOARD (
   .sysclk(sys_clk),
   .sys_rst_n(sys_rst_n),
   .BINT10_n(s_high),
   .BINT11_n(s_high),
   .BINT12_n(s_high),
   .BINT13_n(s_high),
   .BINT15_n(s_high),
   .BREQ_n(s_high),
   .CLOCK_1(clk1),
   .CLOCK_2(clk1),
   .CONSOLE_n (s_high),
   .CONTINUE_n(s_high),
   .EAUTO_n (s_high),
   .LOAD_n(s_high),
   .LOCK_n(s_high),
   .OC_1_0(oc_select),
   .OSCCL_n(s_high),
   .RXD(uartRx),   
   .STOP_n (s_high),
   .SW1_CONSOLE(s_high),
   .SWMCL_n(s_high),
   .XTR(s_low),

    // outputs
   .CSBITS(s_csbits),
   .DP_5_1_n(s_dp_5_1_n ),
   .RUN_n(s_run),
   .TEST_4_0(s_test_4_0),
   .TP1_INTRQ_n(s_tp1_intrq_n),
   .TXD(uartTx),
   .LED(s_led) // 0=RED,1=GREEN
);

endmodule