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

  // NOTE: installation_number, the s_high/s_low helpers, oc_select,
  // SEL_TESTMUX and the baud-rate switch moved INTO ND120_CORE.v -- they are
  // CPU-board constants, not board-level I/O.

  wire sys_rst_n;
`ifndef VERILATOR_SIM
  wire mmcm_locked;
`endif

  // input signals
  wire clk1;  //! Clock Signal 1
  //wire clk2;  //! Clock Signal 2

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

  // NOTE: s_test_4_0 / s_dp_5_1_n / s_tp1_intrq_n / s_csbits moved INTO
  // ND120_CORE.v (they are CPU-board debug nets, not board I/O). Verilator
  // hierarchical readers now reach s_csbits at
  // ND120_TOP__DOT__CORE__DOT__s_csbits.

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
  *  The board-independent ND-120 core          *
  *  (ND3202D CPU board + the ND-BUS device     *
  *  chain). Everything board-specific -- POR,  *
  *  MMCM, LED map, 7-seg, heartbeat, and the   *
  *  FPGA bus tie-offs above -- stays here.     *
  *                                             *
  *  The device chain is populated exactly as   *
  *  the old `ifdef ND120_VERILOG_DEVICES did:  *
  *  present for the sim harness, absent        *
  *  otherwise.                                 *
  ***********************************************/

`ifdef ND120_VERILOG_DEVICES
  localparam CORE_INCLUDE_TAPE   = 1;
  localparam CORE_INCLUDE_FLOPPY = 1;
  localparam CORE_INCLUDE_SMD    = 1;
`else
  localparam CORE_INCLUDE_TAPE   = 0;
  localparam CORE_INCLUDE_FLOPPY = 0;
  localparam CORE_INCLUDE_SMD    = 0;

  // No device chain: the storage seam is unused. Tie the core's source
  // inputs inactive and leave its source outputs unread.
  wire        TAPE_BYTE_REQ;
  wire        TAPE_BYTE_VALID = 1'b0;
  wire [7:0]  TAPE_BYTE_DATA  = 8'd0;
  wire        TAPE_REWIND;

  wire        DMA_REQ   = 1'b0;
  wire        DMA_WR    = 1'b0;
  wire [23:0] DMA_ADDR  = 24'd0;
  wire [15:0] DMA_WDATA = 16'd0;
  wire [15:0] DMA_RDATA;
  wire        DMA_ACK;
  wire        DMA_ERR;
  wire        DMA_BUSY;

  wire        FDISK_REQ;
  wire        FDISK_WR;
  wire [15:0] FDISK_LSECT;
  wire [1:0]  FDISK_FORMAT;
  wire [1:0]  FDISK_DRIVE;
  wire [10:0] FDISK_WORDCOUNT;
  wire        FDISK_DONE       = 1'b0;
  wire        FDISK_ERR        = 1'b0;
  wire [3:0]  FDISK_MEDIA_FMT  = 4'd0;
  wire [9:0]  FDBUF_ADDR       = 10'd0;
  wire [15:0] FDBUF_WDATA      = 16'd0;
  wire        FDBUF_WE         = 1'b0;
  wire [15:0] FDBUF_RDATA;

  wire        SDISK_START;
  wire        SDISK_REQ;
  wire        SDISK_WR;
  wire [15:0] SDISK_BLKADDR1;
  wire [15:0] SDISK_BLKADDR2;
  wire [2:0]  SDISK_UNIT;
  wire [10:0] SDISK_WORDCOUNT;
  wire        SDISK_DONE  = 1'b0;
  wire        SDISK_ERR   = 1'b0;
  wire [9:0]  SDBUF_ADDR  = 10'd0;
  wire [15:0] SDBUF_WDATA = 16'd0;
  wire        SDBUF_WE    = 1'b0;
  wire [15:0] SDBUF_RDATA;
`endif

  ND120_CORE #(
      .INCLUDE_TAPE  (CORE_INCLUDE_TAPE),
      .INCLUDE_FLOPPY(CORE_INCLUDE_FLOPPY),
      .INCLUDE_SMD   (CORE_INCLUDE_SMD)
  ) CORE (
      // (a) clock / reset. clk1 is the CPU+bus+device domain in BOTH
      // branches: sim assigns clk1 = sysclk, FPGA assigns clk1 = clk_cpu.
      .clk_cpu(clk1),
      .sys_rst_n(sys_rst_n),

      // (e) C-PLUG bus: driven by the C harness in sim, tied off above on FPGA
      .BREQ_n(BREQ_n),
      .BINT10_n(BINT10_n),
      .BINT11_n(BINT11_n),
      .BINT12_n(BINT12_n),
      .BINT13_n(BINT13_n),
      .BINT15_n(BINT15_n),
      .POWSENSE_n(POWSENSE_n),

      .BD_23_0_n_IN(BD_23_0_n_IN),
      .BD_23_0_n_OUT(BD_23_0_n_OUT),

      .SEMRQ_n_IN(SEMRQ_n_IN),
      .SEMRQ_n_OUT(SEMRQ_n_OUT),
      .BINPUT_n_IN(BINPUT_n_IN),
      .BINPUT_n_OUT(BINPUT_n_OUT),
      .BDAP_n_IN(BDAP_n_IN),
      .BDAP_n_OUT(BDAP_n_OUT),
      .BDRY_n_IN(BDRY_n_IN),
      .BDRY_n_OUT(BDRY_n_OUT),
      .BAPR_n_IN(BAPR_n_IN),
      .BAPR_n_OUT(BAPR_n_OUT),

      .BREF_n(BREF_n),
      .BERROR_n(BERROR_n),
      .BINACK_n(BINACK_n),
      .BIOXE_n(BIOXE_n),
      .BMEM_n(BMEM_n),
      .OUTGRANT_n(OUTGRANT_n),
      .OUTIDENT_n(OUTIDENT_n),
      .MCL(MCL),

      // (d) UART
      .RXD(uartRx),
      .TXD(uartTx),

      // (c) storage backend: forwarded 1:1 to the ND120_TOP ports, which the
      // C harness serves (BPUN file / FLOPPY.IMG / disk-0 image)
      .TAPE_BYTE_REQ(TAPE_BYTE_REQ),
      .TAPE_BYTE_VALID(TAPE_BYTE_VALID),
      .TAPE_BYTE_DATA(TAPE_BYTE_DATA),
      .TAPE_REWIND(TAPE_REWIND),

      .DMA_REQ(DMA_REQ),
      .DMA_WR(DMA_WR),
      .DMA_ADDR(DMA_ADDR),
      .DMA_WDATA(DMA_WDATA),
      .DMA_RDATA(DMA_RDATA),
      .DMA_ACK(DMA_ACK),
      .DMA_ERR(DMA_ERR),
      .DMA_BUSY(DMA_BUSY),

      .FDISK_REQ(FDISK_REQ),
      .FDISK_WR(FDISK_WR),
      .FDISK_LSECT(FDISK_LSECT),
      .FDISK_FORMAT(FDISK_FORMAT),
      .FDISK_DRIVE(FDISK_DRIVE),
      .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE(FDISK_DONE),
      .FDISK_ERR(FDISK_ERR),
      .FDISK_MEDIA_FMT(FDISK_MEDIA_FMT),
      .FDBUF_ADDR(FDBUF_ADDR),
      .FDBUF_WDATA(FDBUF_WDATA),
      .FDBUF_WE(FDBUF_WE),
      .FDBUF_RDATA(FDBUF_RDATA),

      .SDISK_START(SDISK_START),
      .SDISK_REQ(SDISK_REQ),
      .SDISK_WR(SDISK_WR),
      .SDISK_BLKADDR1(SDISK_BLKADDR1),
      .SDISK_BLKADDR2(SDISK_BLKADDR2),
      .SDISK_UNIT(SDISK_UNIT),
      .SDISK_WORDCOUNT(SDISK_WORDCOUNT),
      .SDISK_DONE(SDISK_DONE),
      .SDISK_ERR(SDISK_ERR),
      .SDBUF_ADDR(SDBUF_ADDR),
      .SDBUF_WDATA(SDBUF_WDATA),
      .SDBUF_WE(SDBUF_WE),
      .SDBUF_RDATA(SDBUF_RDATA),

      // (f) debug / status -> the board's LED map, 7-seg and ILA wires
      .LED(s_cpu_led[6:0]),
      .RUN_n(s_run),
      .CSA_12_0(CSA_12_0),
      .LA_23_10(s_debug_la_23_10),
      .CA_9_0(s_debug_ca_9_0),
      .DEBUG_CC_TERM(s_debug_cc_term),
      .DEBUG_MCLK(s_debug_mclk),
      .DEBUG_LCS_n(s_debug_lcs_n),
      .DEBUG_FETCH(s_debug_fetch),
      .DEBUG_MR_n(s_debug_mr_n),
      .DEBUG_CLEAR_n(s_debug_clear_n),
      .DEBUG_REFRQ_n(s_debug_refrq_n),
      .DEBUG_INTRQ_n(s_debug_intrq_n),
      .DEBUG_POWFAIL_n(s_debug_powfail_n),
      .DEBUG_FIDBO_15_0(s_debug_fidbo)
  );

endmodule
