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
** Last reviewed: 22-MAR-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/



// Define USE_TRANSPARENT_LATCHES for latch behavior in PALs.
// Active when: VERILATOR_SIM is set (sim build) AND FPGA_FF_MODE is NOT set.
// This allows sim builds to test FF mode with: make compile USE_LATCHES=0
`ifdef VERILATOR_SIM
  `ifndef FPGA_FF_MODE
    `define USE_TRANSPARENT_LATCHES
  `endif
`endif

//! @title ND120 CPU, MEMORY MANAGEMENT and MEMORY.
//! @author Ronny Hansen
//! TOP LEVEL FOR FPGA IMPLEMENTATION OF ND-3202D CPU BOARD

module ND120_TOP
(
    // Core FPGA pins (always present)
    input wire sysclk,    //! System Clock
    input wire btn1,      //! Button 1 - connected to sys_rst_n
    input wire btn2,      //! Button 2
`ifndef VERILATOR_SIM
    input wire btn3,      //! SW5 - (unused since 2026-07-06; CPU now fixed at clk_cpu ~16.67MHz)
`endif
    input wire uartRx,    //! UART Receive pin
    output wire uartTx,   //! UART Transmit pin
`ifdef VERILATOR_SIM
    output wire [5:0] led //! 6-bit LED output (simulation)
`else
    output wire [15:0] led, //! 16 LEDs on Basys3 (LD0-LD15)
    // 7-segment display (active LOW, Basys3)
    output wire [6:0] seg,  //! 7-segment segments (a-g, active LOW)
    output wire [3:0] an    //! 7-segment digit anodes (active LOW)
`endif

`ifdef VERILATOR_SIM
    // Simulation-only ports: full bus interface for device emulation
    ,
    input wire DEBUGFLAG,  // DEBUG FLAG
    output wire [12:0] CSA_12_0,  //! Microcode Address (for debugging)

    // C-PLUG bus signals
    input wire BREQ_n,      // Bus Request
    input wire BINT10_n,    // Bus Interrupt 10
    input wire BINT11_n,    // Bus Interrupt 11
    input wire BINT12_n,    // Bus Interrupt 12
    input wire BINT13_n,    // Bus Interrupt 13
    input wire BINT15_n,    // Bus Interrupt 15
    input wire POWSENSE_n,  // Power Sense

    // BUS data in/out
    input wire [23:0] BD_23_0_n_IN,
    output wire [23:0] BD_23_0_n_OUT,

    // Bidirectional bus signals
    input  SEMRQ_n_IN,
    output SEMRQ_n_OUT,
    input  BINPUT_n_IN,
    output BINPUT_n_OUT,
    input  BDAP_n_IN,
    output BDAP_n_OUT,
    input  BDRY_n_IN,
    output BDRY_n_OUT,
    input  BAPR_n_IN,
    output BAPR_n_OUT,

    // Bus control outputs
    output wire BREF_n,
    output wire BERROR_n,
    output wire BINACK_n,
    output wire BIOXE_n,
    output wire BMEM_n,
    output wire OUTGRANT_n,
    output wire OUTIDENT_n,
    output wire MCL

`ifdef ND120_VERILOG_DEVICES
    // Byte source for the Verilog papertape device (ND-BUS-DEVICES/TAPE-400):
    // the sim harness serves a BPUN file; hardware serves an SD-FAT stream.
    ,
    output wire       TAPE_BYTE_REQ,   // pulse: fetch next tape byte
    input  wire       TAPE_BYTE_VALID, // pulse: TAPE_BYTE_DATA is the byte
    input  wire [7:0] TAPE_BYTE_DATA,
    output wire       TAPE_REWIND,    // pulse: rewind the tape source

    // DMA test client (full-RTL DMA gate: ND_DMA_MASTER against the
    // real bus arbiter and RAM; the sim harness drives these)
    input  wire        DMA_REQ,        // pulse: one word transfer
    input  wire        DMA_WR,         // 0 = memory read, 1 = memory write
    input  wire [23:0] DMA_ADDR,       // physical memory address
    input  wire [15:0] DMA_WDATA,
    output wire [15:0] DMA_RDATA,
    output wire        DMA_ACK,
    output wire        DMA_ERR,
    output wire        DMA_BUSY,

    // Floppy disk-image backend for the DMA-flavor controller
    // (sim harness serves FLOPPY.IMG; hardware later serves the
    // SDRAM-cached image). Position = logical sector * sector size.
    output wire        FDISK_REQ,
    output wire        FDISK_WR,
    output wire [15:0] FDISK_LSECT,
    output wire [1:0]  FDISK_FORMAT,
    output wire [1:0]  FDISK_DRIVE,
    output wire [10:0] FDISK_WORDCOUNT,
    input  wire        FDISK_DONE,
    input  wire        FDISK_ERR,
    // media format from the image size (deviceFloppyDMA.c READ FORMAT):
    // {doubleDensity, doubleSided, bytesPerSector[1:0]}; 4'b0000 = 8-inch
    // 315392-byte image, 4'b1111 = 5.25" 1.2MB image (drive default)
    input  wire [3:0]  FDISK_MEDIA_FMT,
    input  wire [9:0]  FDBUF_ADDR,
    input  wire [15:0] FDBUF_WDATA,
    input  wire        FDBUF_WE,
    output wire [15:0] FDBUF_RDATA,

    // SMD disk backend (sim harness serves the disk-0 image; the
    // backend owns the block-address-to-image mapping)
    output wire        SDISK_START,
    output wire        SDISK_REQ,
    output wire        SDISK_WR,
    output wire [15:0] SDISK_BLKADDR1,
    output wire [15:0] SDISK_BLKADDR2,
    output wire [2:0]  SDISK_UNIT,
    output wire [10:0] SDISK_WORDCOUNT,
    input  wire        SDISK_DONE,
    input  wire        SDISK_ERR,
    input  wire [9:0]  SDBUF_ADDR,
    input  wire [15:0] SDBUF_WDATA,
    input  wire        SDBUF_WE,
    output wire [15:0] SDBUF_RDATA
`endif
`endif
);
 

  /**********************************************
  *    ND-100 BUS Wires                         *
  ***********************************************/

`ifndef VERILATOR_SIM
  // FPGA mode: bus signals tied to safe defaults (no external bus)
  wire DEBUGFLAG = 1'b0;
  wire [12:0] CSA_12_0;

  wire BREQ_n = 1'b1;
  wire BINT10_n = 1'b1;
  wire BINT11_n = 1'b1;
  wire BINT12_n = 1'b1;
  wire BINT13_n = 1'b1;
  wire BINT15_n = 1'b1;
  wire POWSENSE_n = 1'b1;

  wire [23:0] BD_23_0_n_IN = 24'hFFFFFF;  // Pulled high (inactive)
  wire [23:0] BD_23_0_n_OUT;

  wire SEMRQ_n_IN = 1'b1;
  wire SEMRQ_n_OUT;
  wire BINPUT_n_IN = 1'b1;
  wire BINPUT_n_OUT;
  wire BDAP_n_IN = 1'b1;
  wire BDAP_n_OUT;
  wire BDRY_n_IN = 1'b1;
  wire BDRY_n_OUT;
  wire BAPR_n_IN = 1'b1;
  wire BAPR_n_OUT;

  wire BREF_n;
  wire BERROR_n;
  wire BINACK_n;
  wire BIOXE_n;
  wire BMEM_n;
  wire OUTGRANT_n;
  wire OUTIDENT_n;
  wire MCL;
`endif

  // Installation number.
  wire [7:0] installation_number = 8'd123;

  // helpers
  wire s_high= 1'b1;
  wire s_low= 1'b0;
  wire sys_rst_n;
`ifndef VERILATOR_SIM
  wire mmcm_locked;
`endif

  // input signals
  wire clk1;  //! Clock Signal 1
  //wire clk2;  //! Clock Signal 2
  wire [1:0] oc_select;

  wire [2:0] s_SEL_TESTMUX;
  assign s_SEL_TESTMUX = 2'b000;  // 00=TESTMUX=0

  wire [3:0] s_baud_rate_switch;
  assign s_baud_rate_switch = 4'b1000;  // 8=9600 baud (ref BAUDV page 158 in microcode)

  // output wire from CPU

  wire [6:0] s_cpu_led;  // 7 bit LED signals (ND3202D outputs 7 bits)
  //   0=CPU RED
  //   1=CPU GREEN
  //   2=LED4_RED_PARITY_ERROR
  //   3=LED_CPU_GRANT_INDICATOR
  //   4=LED_BUS_GRANT_INDICATOR
  //   5=LED1 from MMU
  //   6=LED5_RED_DISABLE_PARITY

  // Debug signals -- mark_debug lets Vivado ILA probe these in Hardware Manager.
  // After synthesis, in Vivado: Open Synthesized Design -> Set Up Debug -> add these nets.
  // Then re-run Implementation and Generate Bitstream.
  (* mark_debug = "true" *) wire s_run;
  (* mark_debug = "true", DONT_TOUCH = "true" *) wire [12:0] s_debug_csa;
  (* mark_debug = "true" *) wire s_debug_uartTx;
  (* mark_debug = "true" *) wire s_debug_uartRx;
  (* mark_debug = "true" *) wire [6:0] s_debug_cpu_led;

  assign s_debug_csa = CSA_12_0;
  assign s_debug_uartTx = uartTx;
  assign s_debug_uartRx = uartRx;
  assign s_debug_cpu_led = s_cpu_led;

  // MAC (Memory Access Controller) address debug wires
  (* mark_debug = "true" *) wire [13:0] s_debug_la_23_10;  // LA 23:10
  (* mark_debug = "true" *) wire [9:0]  s_debug_ca_9_0;    // CA 9:0

  // Cycle state machine debug
  (* mark_debug = "true" *) wire [4:0] s_debug_cc_term;    // {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}
  (* mark_debug = "true" *) wire       s_debug_mclk;       // Memory clock
  (* mark_debug = "true" *) wire       s_debug_lcs_n;      // LCS_n: 0=loading, 1=loaded
  (* mark_debug = "true" *) wire       s_debug_fetch;      // Fetch signal
  (* mark_debug = "true" *) wire       s_debug_mr_n;       // Master Reset
  (* mark_debug = "true" *) wire       s_debug_clear_n;    // Clear
  (* mark_debug = "true" *) wire       s_debug_refrq_n;    // Refresh Request
  (* mark_debug = "true" *) wire       s_debug_intrq_n;    // Interrupt Request
  (* mark_debug = "true" *) wire       s_debug_powfail_n;  // Power Fail
  (* mark_debug = "true", DONT_TOUCH = "true" *) wire [15:0] s_debug_fidbo;  // FIDBO internal data bus

  // ALU debug probes: mark_debug applied directly in submodule source files:
  //   CGA_ALU.v:  s_q_15_0 (Q reg), s_f_15_0 (F result)
  //   CGA.v:      s_zf (zero flag), s_cry (carry), s_cond (condition)

  (* keep = "true", DONT_TOUCH = "true" *)  wire [4:0] s_test_4_0;  // Test pads
  (* keep = "true", DONT_TOUCH = "true" *)  wire [4:0] s_dp_5_1_n;  // Datapath 5-1
  (* keep = "true", DONT_TOUCH = "true" *)  wire s_tp1_intrq_n;     // TP1 INTRQ_n
  (* keep = "true", DONT_TOUCH = "true" *)  wire [63:0] s_csbits;   // Microcode CPU BITS

  reg [32:0] clockTicks;

`ifdef VERILATOR_SIM
  // Simulation: testbench controls btn1 directly (0 for 100 cycles, then 1)
  assign sys_rst_n = btn1;
`else
  // FPGA: Power-on reset holds sys_rst_n LOW for 256 cycles after configuration
  // or after btn1 (SW0) goes low. Ensures a clean reset-release transition
  // every time the switch is toggled, re-triggering the full CPU boot sequence.
  //
  // Clocked on clk_cpu (the CPU domain), NOT sysclk: sys_rst_n fans out to
  // hundreds of CPU-register reset/enable pins. On sysclk that made 462
  // sys_clk->clk_cpu crossings that could not meet the tight related-clock
  // window. On clk_cpu they are intra-domain (60 ns) and meet easily. clk_cpu
  // only runs once the MMCM locks, so before lock the counter is frozen at 0 and
  // sys_rst_n = por_done & mmcm_locked holds reset asserted anyway. 256 clk_cpu
  // cycles ~= 15 us reset pulse.
  reg [7:0] por_count = 8'd0;
  reg       por_done  = 1'b0;
  always @(posedge clk_cpu) begin
    if (!btn1) begin
      // SW0 down: reset the POR counter
      por_count <= 8'd0;
      por_done  <= 1'b0;
    end else if (!por_done) begin
      if (por_count == 8'hFF)
        por_done <= 1'b1;
      else
        por_count <= por_count + 1'b1;
    end
  end
  assign sys_rst_n = por_done & mmcm_locked;
`endif

`ifdef VERILATOR_SIM
  assign clk1 = sysclk;  // Simulation: always full speed
`else
  // FPGA: the whole ND-120 CPU + bus domain runs on ONE clock, clk_cpu, at
  // ~16.67 MHz (100 MHz / 6 = 60 ns period). Rationale (2026-07-06 timing study):
  // the microengine's deepest path -- reading the microcode word out of the WCS
  // control-store BRAM and propagating it through the decode/next-address/FSM
  // logic -- is ~49 ns (76 logic levels). It CANNOT close at 100 MHz (10 ns) or
  // even 39 MHz (25.6 ns); those paths legitimately span a whole microcycle on
  // the real machine. 60 ns closes it with margin and no risky multicycle
  // constraints. clk_cpu also feeds CLOCK_1/CLOCK_2 (the OSC/bus inputs) so the
  // cycle controller and bus arbiter share the same domain -- no internal CDC.
  // sysclk (100 MHz pin) still clocks the POR, 7-seg, heartbeat and ILA only.
  //
  // NOTE: the original SW5 runtime 100/12.5 MHz mux is removed -- 100 MHz never
  // closed timing, so a runtime-selectable fast mode was dead. Push clk_cpu
  // faster (or add validated multicycle paths for a 39 MHz bus) as a follow-up.

  wire clk_cpu_pre, clkfb_out, clkfb_in;
  wire clk_cpu;

`ifdef TARGET_CMOD_A7
  // Cmod A7: 12 MHz crystal. VCO = 12 x 63 = 756 MHz (in the 600-1200 MHz
  // MMCM range); clk_cpu = 756 / 28 = 27.000 MHz EXACTLY - the same CPU
  // speed as the Tang Nano 20K full-speed build, so BOARD_CLK_FREQ=27000000
  // and every derived count matches. Fallback if 27 MHz does not close
  // timing: pass -verilog_define ND120_CMOD_MMCM_DIV=56.0 for 13.5 MHz
  // (or 42.0 for 18 MHz) - same VCO, one divider change.
  `ifndef ND120_CMOD_MMCM_DIV
    `define ND120_CMOD_MMCM_DIV 28.0
  `endif
  MMCME2_BASE #(
    .BANDWIDTH        ("OPTIMIZED"),
    .CLKFBOUT_MULT_F  (63.0),    // VCO = 12 * 63 = 756 MHz
    .CLKIN1_PERIOD    (83.333),  // 12 MHz input
    .CLKOUT0_DIVIDE_F (`ND120_CMOD_MMCM_DIV),  // 756 / 28 = 27 MHz (CPU/bus clock)
    .DIVCLK_DIVIDE    (1),
    .STARTUP_WAIT     ("FALSE")
  ) mmcm_cpu_clk (
`else
  MMCME2_BASE #(
    .BANDWIDTH        ("OPTIMIZED"),
    .CLKFBOUT_MULT_F  (10.0),   // VCO = 100 * 10 = 1000 MHz
    .CLKIN1_PERIOD    (10.0),   // 100 MHz input
    .CLKOUT0_DIVIDE_F (60.0),   // CLKOUT0 = 1000 / 60 = 16.667 MHz (CPU/bus clock)
    .DIVCLK_DIVIDE    (1),
    .STARTUP_WAIT     ("FALSE")
  ) mmcm_cpu_clk (
`endif
    .CLKIN1   (sysclk),
    .CLKFBIN  (clkfb_in),
    .CLKFBOUT (clkfb_out),
    .CLKOUT0  (clk_cpu_pre),
    .LOCKED   (mmcm_locked),
    .PWRDWN   (1'b0),
    .RST      (1'b0)
  );
  BUFG bufg_fb  (.I(clkfb_out),   .O(clkfb_in));
  BUFG bufg_cpu (.I(clk_cpu_pre), .O(clk_cpu));

  assign clk1 = clk_cpu;  // CLOCK_1/CLOCK_2 (OSC/bus) run at CPU speed
`endif
  //assign clk2 = sysclk;  // XTAL2 = 35 MHZ (for slow operations?)
  assign oc_select = 2'b11;  // 11= Choose clock input = XTAL1 (full speed)

`ifdef VERILATOR_SIM
  // Simulation: original 6-bit LED mapping (active low, matching Run120.cpp)
  assign led[1:0] = ~s_cpu_led[1:0];  // 0=RED, 1=GREEN
  assign led[2] = !s_run;
  assign led[3] = !s_cpu_led[3];      // CPU GRANT INDICATOR
  assign led[4] = !s_cpu_led[4];      // BUS GRANT INDICATOR
  assign led[5] = !s_cpu_led[5];      // LED1 from MMU
`else
  // FPGA: 16-bit LED mapping for Basys3 (active HIGH)
  //
  // LD0 = led[0] = CPU RED LED        (ON = error/halt)
  // LD1 = led[1] = CPU GREEN LED      (ON = running)
  // LD2 = led[2] = RUN indicator      (ON = CPU NOT running/OPCOM, OFF = running)
  // LD3 = led[3] = sys_rst_n state    (ON = reset released, OFF = in reset)
  // LD4 = led[4] = UART TX activity   (blinks when transmitting)
  // LD5 = led[5] = Heartbeat          (blinks ~1.5Hz if clock running)
  //                To restore LED1 from MMU: assign led[5] = !s_cpu_led[5];

  // RIGHT SIDE: CPU status (LD0-LD5)
  // s_cpu_led[0] = s_emcl_n  (negative-logic from CHIP_28A_IOC in IO_REG_41)
  // s_cpu_led[1] = s_led3_green_n (negative-logic from CHIP_28A_IOC)
  // Both are active-low chip outputs; invert for active-high Basys3 LEDs.
  // (The Verilator branch above already does this with ~s_cpu_led[1:0].)
  assign led[0]  = ~s_cpu_led[0];      // LD0:  CPU RED   (ON when s_emcl_n=0       = master clear active)
  assign led[1]  = ~s_cpu_led[1];      // LD1:  CPU GREEN (ON when s_led3_green_n=0 = init complete)
  assign led[2]  = ~s_run;             // LD2:  ON when CPU running
  assign led[3]  = sys_rst_n;          // LD3:  ON when reset released
  assign led[4]  = ~uartTx;            // LD4:  UART TX activity
  assign led[5]  = clockTicks[26];     // LD5:  Heartbeat ~1.5Hz
  assign led[6]  = s_debug_mclk;       // LD6:  Memory clock
  assign led[7]  = ~s_debug_lcs_n;     // LD7:  LCS (ON=microcode loaded)
  assign led[8]  = s_debug_mr_n;       // LD8:  MR_n (ON=not in reset)
  assign led[9]  = 1'b0;               // LD9:  (spare)
  assign led[10] = 1'b0;               // LD10: (spare)

  // LEFT SIDE: Cycle state machine (LD11-LD15)
  assign led[11] = ~s_debug_cc_term[0]; // LD11: CC0  (inverted: ON=active)
  assign led[12] = ~s_debug_cc_term[1]; // LD12: CC1
  assign led[13] = ~s_debug_cc_term[2]; // LD13: CC2
  assign led[14] = ~s_debug_cc_term[3]; // LD14: CC3
  assign led[15] = ~s_debug_cc_term[4]; // LD15: TERM (leftmost)
`endif

  // Free-running clock counter (no reset needed)
  always @(posedge sysclk)
  begin
    clockTicks <= clockTicks + 1;
  end

`ifndef VERILATOR_SIM
  // 7-segment display: shows CPU addresses in hex (FPGA only).
  // SW1 (btn2) selects what to display:
  //   SW1 OFF (DOWN): MIC address = CSA_12_0 (microcode address, 13 bits)
  //   SW1 ON  (UP):   MAC address = LA_23_10 (memory logical address, 14 bits)
  // If display shows changing values, the CPU is executing.
  // If stuck at 0000, the CPU is not running.
  wire [15:0] seg_display_value = btn2
      ? {2'b0, s_debug_la_23_10}
      : {3'b0, CSA_12_0};

  SevenSegDebug SEVEN_SEG (
      .clk(sysclk),
      .value(seg_display_value),
      .seg(seg),
      .an(an)
  );
`endif

  /**********************************************
  *  Verilog external-bus devices (optional)    *
  *  ND-BUS-DEVICES: bus slave + papertape 400  *
  *  Wired-AND onto the active-low bus inputs.  *
  ***********************************************/

`ifdef ND120_VERILOG_DEVICES
`ifdef VERILATOR_SIM
  wire s_dev_clk = sysclk;
`else
  wire s_dev_clk = clk1;
`endif

  wire [23:0] s_dev_bd_n;
  wire s_dev_binput_n, s_dev_bdap_n, s_dev_bdry_n;
  wire s_dev_bint10_n, s_dev_bint11_n, s_dev_bint12_n, s_dev_bint13_n;

  wire [15:0] s_dev_iox_addr, s_dev_iox_wdata;
  wire        s_dev_iox_wr, s_dev_iox_rd;
  wire        s_dev_ident_strobe;
  wire [3:0]  s_dev_ident_level;
  // OR-bus contributions per device core (tape, floppy)
  wire [15:0] s_tape_rdata, s_flp_rdata, s_smd_rdata;
  wire [3:0]  s_tape_intp, s_flp_intp, s_smd_intp;
  wire        s_tape_hit, s_flp_hit, s_smd_hit;
  wire [15:0] s_tape_code, s_flp_code, s_smd_code;
  wire        s_grant_tape_flp;  // ident chain: tape -> floppy
  wire        s_grant_flp_smd;   // ident chain: floppy -> SMD
  wire [15:0] s_dev_iox_rdata   = s_tape_rdata | s_flp_rdata | s_smd_rdata;
  wire [3:0]  s_dev_int_pending = s_tape_intp | s_flp_intp | s_smd_intp;
  wire        s_dev_ident_hit   = s_tape_hit | s_flp_hit | s_smd_hit;
  wire [15:0] s_dev_ident_code  = s_tape_code | s_flp_code | s_smd_code;

  ND_BUS_SLAVE BUS_SLAVE (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .BD_23_0_n_OUT(BD_23_0_n_OUT),
      .BD_23_0_n_IN(s_dev_bd_n),
      .BAPR_n(BAPR_n_OUT),
      .BIOXE_n(BIOXE_n),
      .BINACK_n(BINACK_n),
      .OUTIDENT_n(OUTIDENT_n),
      .BINPUT_n(s_dev_binput_n),
      .BDAP_n(s_dev_bdap_n),
      .BDRY_n(s_dev_bdry_n),
      .BINT10_n(s_dev_bint10_n),
      .BINT11_n(s_dev_bint11_n),
      .BINT12_n(s_dev_bint12_n),
      .BINT13_n(s_dev_bint13_n),
      .iox_addr(s_dev_iox_addr),
      .iox_wr(s_dev_iox_wr),
      .iox_wdata(s_dev_iox_wdata),
      .iox_rd(s_dev_iox_rd),
      .iox_rdata(s_dev_iox_rdata),
      .int_pending(s_dev_int_pending),
      .ident_strobe(s_dev_ident_strobe),
      .ident_level(s_dev_ident_level),
      .ident_hit(s_dev_ident_hit),
      .ident_code(s_dev_ident_code)
  );

  ND_TAPE_400 #(
      .BASE_ADDR (16'o000400),
      .IDENT_CODE(16'o000002),
      .INT_LEVEL (4'd12)
  ) TAPE_400 (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .iox_addr(s_dev_iox_addr),
      .iox_wr(s_dev_iox_wr),
      .iox_wdata(s_dev_iox_wdata),
      .iox_rd(s_dev_iox_rd),
      .iox_rdata(s_tape_rdata),
      .int_pending(s_tape_intp),
      .ident_strobe(s_dev_ident_strobe),
      .ident_level(s_dev_ident_level),
      .ident_grant_in(1'b1),
      .ident_grant_out(s_grant_tape_flp),
      .ident_hit(s_tape_hit),
      .ident_code(s_tape_code),
      .byte_req(TAPE_BYTE_REQ),
      .byte_valid(TAPE_BYTE_VALID),
      .byte_data(TAPE_BYTE_DATA),
      .source_rewind(TAPE_REWIND)
  );

  // Floppy 1560, DMA flavor (Ronny's choice 11-JUL): the controller
  // masters the bus through its own ND_DMA_MASTER, second in the grant
  // chain behind the DMA test master.
  wire        s_fdma_req, s_fdma_wr;
  wire [23:0] s_fdma_addr;
  wire [15:0] s_fdma_wdata, s_fdma_rdata;
  wire        s_fdma_ack, s_fdma_err, s_fdma_busy;

  ND_FLOPPY_DMA #(
      .BASE_ADDR (16'o001560),
      .IDENT_CODE(16'o000021),
      .INT_LEVEL (4'd11)
  ) FLOPPY_1560 (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .iox_addr(s_dev_iox_addr),
      .iox_wr(s_dev_iox_wr),
      .iox_wdata(s_dev_iox_wdata),
      .iox_rd(s_dev_iox_rd),
      .iox_rdata(s_flp_rdata),
      .int_pending(s_flp_intp),
      .ident_strobe(s_dev_ident_strobe),
      .ident_level(s_dev_ident_level),
      .ident_grant_in(s_grant_tape_flp),
      .ident_grant_out(s_grant_flp_smd),
      .ident_hit(s_flp_hit),
      .ident_code(s_flp_code),
      .dma_req(s_fdma_req),
      .dma_wr(s_fdma_wr),
      .dma_addr(s_fdma_addr),
      .dma_wdata(s_fdma_wdata),
      .dma_rdata(s_fdma_rdata),
      .dma_ack(s_fdma_ack),
      .dma_err(s_fdma_err),
      .dma_busy(s_fdma_busy),
      .disk_req(FDISK_REQ),
      .disk_wr(FDISK_WR),
      .disk_lsect(FDISK_LSECT),
      .disk_format(FDISK_FORMAT),
      .disk_drive(FDISK_DRIVE),
      .disk_wordcount(FDISK_WORDCOUNT),
      .disk_done(FDISK_DONE),
      .disk_err_in(FDISK_ERR),
      .disk_media_fmt(FDISK_MEDIA_FMT),
      .dbuf_addr(FDBUF_ADDR),
      .dbuf_wdata(FDBUF_WDATA),
      .dbuf_we(FDBUF_WE),
      .dbuf_rdata(FDBUF_RDATA)
  );

  wire [23:0] s_fdmam_bd_n;
  wire s_fdmam_breq_n, s_fdmam_bapr_n, s_fdmam_binput_n, s_fdmam_bdap_n;
  wire s_grant_dma_fdma_n;  // grant chain: test DMA master -> floppy master

  ND_DMA_MASTER #(
      .TIMEOUT_TICKS(16'd8192)
  ) FLOPPY_DMA_MASTER (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .dma_req(s_fdma_req),
      .dma_wr(s_fdma_wr),
      .dma_addr(s_fdma_addr),
      .dma_wdata(s_fdma_wdata),
      .dma_rdata(s_fdma_rdata),
      .dma_ack(s_fdma_ack),
      .dma_err(s_fdma_err),
      .dma_busy(s_fdma_busy),
      .BREQ_n(s_fdmam_breq_n),
      .INGRANT_n(s_grant_dma_fdma_n),
      .OUTGRANT_n(s_grant_fdma_smdm_n),
      .BMEM_n(BMEM_n),
      .BD_23_0_n_OUT(s_fdmam_bd_n),
      .BD_23_0_n_IN(BD_23_0_n_OUT),
      .BAPR_n(s_fdmam_bapr_n),
      .BINPUT_n(s_fdmam_binput_n),
      .BDAP_n(s_fdmam_bdap_n),
      .BDRY_n(BDRY_n_OUT)
  );

  // SMD disk controller at 1540 with its own bus master, third in the
  // grant chain (test master -> floppy master -> SMD master).
  wire        s_smd_req, s_smd_wr;
  wire [23:0] s_smd_addr;
  wire [15:0] s_smd_wdata, s_smd_rdata_dma;
  wire        s_smd_ack, s_smd_err, s_smd_busy;

  ND_SMD #(
      .BASE_ADDR (16'o001540),
      .IDENT_CODE(16'o000017),
      .INT_LEVEL (4'd11)
  ) SMD_1540 (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .iox_addr(s_dev_iox_addr),
      .iox_wr(s_dev_iox_wr),
      .iox_wdata(s_dev_iox_wdata),
      .iox_rd(s_dev_iox_rd),
      .iox_rdata(s_smd_rdata),
      .int_pending(s_smd_intp),
      .ident_strobe(s_dev_ident_strobe),
      .ident_level(s_dev_ident_level),
      .ident_grant_in(s_grant_flp_smd),
      .ident_grant_out(),
      .ident_hit(s_smd_hit),
      .ident_code(s_smd_code),
      .dma_req(s_smd_req),
      .dma_wr(s_smd_wr),
      .dma_addr(s_smd_addr),
      .dma_wdata(s_smd_wdata),
      .dma_rdata(s_smd_rdata_dma),
      .dma_ack(s_smd_ack),
      .dma_err(s_smd_err),
      .dma_busy(s_smd_busy),
      .disk_start(SDISK_START),
      .disk_req(SDISK_REQ),
      .disk_wr(SDISK_WR),
      .disk_blkaddr1(SDISK_BLKADDR1),
      .disk_blkaddr2(SDISK_BLKADDR2),
      .disk_unit(SDISK_UNIT),
      .disk_wordcount(SDISK_WORDCOUNT),
      .disk_done(SDISK_DONE),
      .disk_err_in(SDISK_ERR),
      .dbuf_addr(SDBUF_ADDR),
      .dbuf_wdata(SDBUF_WDATA),
      .dbuf_we(SDBUF_WE),
      .dbuf_rdata(SDBUF_RDATA)
  );

  wire [23:0] s_smdm_bd_n;
  wire s_smdm_breq_n, s_smdm_bapr_n, s_smdm_binput_n, s_smdm_bdap_n;
  wire s_grant_fdma_smdm_n;  // grant chain: floppy master -> SMD master

  ND_DMA_MASTER #(
      .TIMEOUT_TICKS(16'd8192)
  ) SMD_DMA_MASTER (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .dma_req(s_smd_req),
      .dma_wr(s_smd_wr),
      .dma_addr(s_smd_addr),
      .dma_wdata(s_smd_wdata),
      .dma_rdata(s_smd_rdata_dma),
      .dma_ack(s_smd_ack),
      .dma_err(s_smd_err),
      .dma_busy(s_smd_busy),
      .BREQ_n(s_smdm_breq_n),
      .INGRANT_n(s_grant_fdma_smdm_n),
      .OUTGRANT_n(),
      .BMEM_n(BMEM_n),
      .BD_23_0_n_OUT(s_smdm_bd_n),
      .BD_23_0_n_IN(BD_23_0_n_OUT),
      .BAPR_n(s_smdm_bapr_n),
      .BINPUT_n(s_smdm_binput_n),
      .BDAP_n(s_smdm_bdap_n),
      .BDRY_n(BDRY_n_OUT)
  );

  // DMA bus master (full-RTL DMA validation): requests the bus from the
  // REAL arbiter (PAL_44801A via BIF) and runs real memory cycles.
  // Chain head is the CPU's OUTGRANT.
  wire [23:0] s_dma_bd_n;
  wire s_dma_breq_n, s_dma_bapr_n, s_dma_binput_n, s_dma_bdap_n;

  ND_DMA_MASTER #(
      .TIMEOUT_TICKS(16'd8192)
  ) DMA_MASTER (
      .sysclk(s_dev_clk),
      .sys_rst_n(sys_rst_n),
      .dma_req(DMA_REQ),
      .dma_wr(DMA_WR),
      .dma_addr(DMA_ADDR),
      .dma_wdata(DMA_WDATA),
      .dma_rdata(DMA_RDATA),
      .dma_ack(DMA_ACK),
      .dma_err(DMA_ERR),
      .dma_busy(DMA_BUSY),
      .BREQ_n(s_dma_breq_n),
      .INGRANT_n(OUTGRANT_n),
      .OUTGRANT_n(s_grant_dma_fdma_n),
      .BMEM_n(BMEM_n),
      .BD_23_0_n_OUT(s_dma_bd_n),
      .BD_23_0_n_IN(BD_23_0_n_OUT),
      .BAPR_n(s_dma_bapr_n),
      .BINPUT_n(s_dma_binput_n),
      .BDAP_n(s_dma_bdap_n),
      .BDRY_n(BDRY_n_OUT)
  );

  // Wired-AND with the external (C-harness / tie-off) bus inputs
  wire [23:0] s_bus_bd_in_n     = BD_23_0_n_IN & s_dev_bd_n & s_dma_bd_n & s_fdmam_bd_n & s_smdm_bd_n;
  wire        s_bus_breq_n      = BREQ_n & s_dma_breq_n & s_fdmam_breq_n & s_smdm_breq_n;
  wire        s_bus_bapr_in_n   = BAPR_n_IN & s_dma_bapr_n & s_fdmam_bapr_n & s_smdm_bapr_n;
  wire        s_bus_binput_in_n = BINPUT_n_IN & s_dev_binput_n & s_dma_binput_n & s_fdmam_binput_n & s_smdm_binput_n;
  wire        s_bus_bdap_in_n   = BDAP_n_IN & s_dev_bdap_n & s_dma_bdap_n & s_fdmam_bdap_n & s_smdm_bdap_n;
  wire        s_bus_bdry_in_n   = BDRY_n_IN & s_dev_bdry_n;
  wire        s_bus_bint10_n    = BINT10_n & s_dev_bint10_n;
  wire        s_bus_bint11_n    = BINT11_n & s_dev_bint11_n;
  wire        s_bus_bint12_n    = BINT12_n & s_dev_bint12_n;
  wire        s_bus_bint13_n    = BINT13_n & s_dev_bint13_n;
`else
  wire [23:0] s_bus_bd_in_n     = BD_23_0_n_IN;
  wire        s_bus_breq_n      = BREQ_n;
  wire        s_bus_bapr_in_n   = BAPR_n_IN;
  wire        s_bus_binput_in_n = BINPUT_n_IN;
  wire        s_bus_bdap_in_n   = BDAP_n_IN;
  wire        s_bus_bdry_in_n   = BDRY_n_IN;
  wire        s_bus_bint10_n    = BINT10_n;
  wire        s_bus_bint11_n    = BINT11_n;
  wire        s_bus_bint12_n    = BINT12_n;
  wire        s_bus_bint13_n    = BINT13_n;
`endif

  ND3202D CPU_BOARD (
`ifdef VERILATOR_SIM
      .sysclk(sysclk),      // sim: single full-speed clock (clk1 == sysclk)
`else
      .sysclk(clk1),        // FPGA: CPU core runs on clk_cpu (~16.67 MHz), same net as OSC
`endif
      .sys_rst_n(sys_rst_n),
      .CLOCK_1(clk1),  // XTAL1 = 39.3216MHZ
      .CLOCK_2(clk1),  // XTAL2 = 35 MHZ (for slow operations?)

      // Signal from C-PLUG to CPU Board (and some signals dupliacted on A-PLUG)
      .LOAD_n(s_high),      // Load button  C-B12, A-C15
      .BREQ_n(s_bus_breq_n),  // Bus Request  C-C12 (wired-AND with DMA master)
      .CONTINUE_n(s_high),  // Continue button C-B15
      .STOP_n(s_high),      // Stop button C-B16, A-C17

      .BINT10_n(s_bus_bint10_n),  // Bus Interrupt 10 C-A15 (wired-AND with Verilog devices)
      .BINT11_n(s_bus_bint11_n),  // Bus Interrupt 11 C-C15
      .BINT12_n(s_bus_bint12_n),  // Bus Interrupt 12 C-A16
      .BINT13_n(s_bus_bint13_n),  // Bus Interrupt 13 C-A16
      .BINT15_n(BINT15_n),  // Bus Interrupt 15 C-C17

      .POWSENSE_n(POWSENSE_n),  // Power Sense

      .BD_23_0_n_IN(s_bus_bd_in_n), // Bus address and data from bus. Pulled high (wired-AND with Verilog devices)
      .BD_23_0_n_OUT(BD_23_0_n_OUT),

      // Bidirectional signals
      .SEMRQ_n_IN(SEMRQ_n_IN),     //! Input-signal from "C PLUG", signal A17 SEMREQ~ (SEMaphore REQest)
      .SEMRQ_n_OUT(SEMRQ_n_OUT),   //! Output-signal to "C PLUG", signal A17 SEMREQ~ (SEMaphore REQest)
      .BINPUT_n_IN(s_bus_binput_in_n), //! Input-signal from "C PLUG", signal A18 BINPUT~ (Bus INPUT)
      .BINPUT_n_OUT(BINPUT_n_OUT), //! Output-signal to "C PLUG", signal A18 BINPUT~ (Bus INPUT)
      .BDAP_n_IN(s_bus_bdap_in_n), //! Input-signal from "C PLUG", signal C18 BDAP~ (Bus DAta Present)
      .BDAP_n_OUT(BDAP_n_OUT),     //! Output-signal to "C PLUG", signal C18 BDAP~ (Bus DAta Present)
      .BDRY_n_IN(s_bus_bdry_in_n), //! Input-signal from "C PLUG", signal A19 BDRY~ (Bus Data ReadY)
      .BDRY_n_OUT(BDRY_n_OUT),     //! Output-signal to "C PLUG", signal A19 BDRY~ (Bus Data ReadY)
      .BAPR_n_IN(s_bus_bapr_in_n), //! Input-signal from "C PLUG", signal A20 BAPR~ (Bus Address PResent)
      .BAPR_n_OUT(BAPR_n_OUT),     //! Output-signal to "C PLUG", signal A20 BAPR~ (Bus Address PResent)

      // Signals from CPU board to C-PLUG
      .BREF_n(BREF_n),           // Output-signal to "C PLIG", signal B12 BREF~
      .BERROR_n(BERROR_n),       // Output-signal to "C PLIG", signal B21 BERROR~
      .BINACK_n(BINACK_n),       // Output-signal to "C PLIG", signal B19 BINACK~
      .BIOXE_n(BIOXE_n),         // Output-signal to "C PLIG", signal C19 BIOXE~
      .BMEM_n(BMEM_n),           // Output-signal to "C PLIG", signal C28 BMEM~
      .OUTGRANT_n(OUTGRANT_n),   // Output-signal to "C PLIG", signal C23 OUTGRANT~
      .OUTIDENT_n(OUTIDENT_n),   // Output-signal to "C PLIG", signal C22 OUTIDENT~
      .MCL(MCL),                 // Output-signal to "C PLIG", signal B20 MCL~ (after negation)


      // Signals from B-PLUG to CPU Board
      .INR_7_0(installation_number), // INR 7:0, signal B-> B15, B4, B5, B17, B8, B7, B13, B6. (Installation number, read using IDB Source = 035)
      .EBUS(1'b1),     // EBUS, signal B-B3 (Pulled high with through resistor network RN13)
      .SEL5MS_n(1'b1), // SEL 5ms, signal B-B14 (Pulled high with 1kohm resistor R4)

      // Signals from CPU to B-PLUG
      .PIL(),         // XPIL3=B-C8, PIL2=B-B12. PIL1=B-B10, PIL0=B-B9
      .LUA_12_0(),    // XLUA 12:0
      .IDB_15_0(),    // XIDB 15:0
      .CSCOMM_4_0(),  //
      .MIS_1_0(),     // MIS1=B-C14, MIS0=B-A14
      .CD_15_0(),     // CD 15:0
      .LBD_15_0(),    // LBD 15:0
      .LA_23_10(s_debug_la_23_10),  // XLA 23:10 (MAC upper address)
      .CA_9_0(s_debug_ca_9_0),     // CA 9:0 (MAC lower address)


      // Signals from A-PLUG to CPU board
      .OSCCL_n  (s_high),     // Oscillator Clock
      .OC_1_0   (oc_select),  // Oscillator Clock Select
      .XTR      (s_low),      // External Transmit/Receive Clock (not used)
      .LOCK_n   (s_high),     // Lock signal (from key)
      .CONSOLE_n(s_high),     // Console signal (from key)
      .SWMCL_n  (s_high),     // Software Master Clear (MCL)
      .EAUTO_n  (s_high),     // External Auto
      .RXD      (uartRx),     // UART Receive A-C8

      // Signals from CPU Board to C-PLUG
      .RUN_n      (s_run),    // Run C-B14 (driven by Stop flip-flop: low while CPU is running)

      // Signals from CPU Board to A-PLUG
      .TXD        (uartTx),   // UART Transmit TXD A-C7
      .DP_5_1_n   (s_dp_5_1_n),     // Data Path 5-1 A-> 1=C25, 2=C26, 3=C27, 4=C28, 5=C29


      /* Configuration switches (input to ND3202D board) */
      .SW1_CONSOLE     (s_high),             // Console switch
      .SEL_TESTMUX     (s_SEL_TESTMUX),      // Test MUX (select signals to test pads)
      .BAUD_RATE_SWITCH(s_baud_rate_switch), // Baud rate switch

      // outputs
      .CSBITS     (s_csbits),       // Microcode CPU BITS
      .TEST_4_0   (s_test_4_0),     // Test pads
      .TP1_INTRQ_n(s_tp1_intrq_n),  // TP1 Interrupt
      .CSA_12_0    (CSA_12_0),      // Microcode Address (for debugging)
      .LED        (s_cpu_led[6:0]),  // 7 bit LED signals
      .DEBUG_CC_TERM(s_debug_cc_term), // {TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}
      .DEBUG_MCLK(s_debug_mclk),      // Memory clock
      .DEBUG_LCS_n(s_debug_lcs_n),    // LCS_n: 0=loading, 1=loaded
      .DEBUG_FETCH(s_debug_fetch),
      .DEBUG_MR_n(s_debug_mr_n),
      .DEBUG_CLEAR_n(s_debug_clear_n),
      .DEBUG_REFRQ_n(s_debug_refrq_n),
      .DEBUG_INTRQ_n(s_debug_intrq_n),
      .DEBUG_POWFAIL_n(s_debug_powfail_n),
      .DEBUG_FIDBO_15_0(s_debug_fidbo)
  );

endmodule
