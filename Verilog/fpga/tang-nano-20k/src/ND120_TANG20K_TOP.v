/**************************************************************************
** ND120 CPU, MEMORY MANAGEMENT and MEMORY                               **
**                                                                       **
** TOP LEVEL FOR THE TANG NANO 20K (Gowin GW2AR-18)                      **
**                                                                       **
** Sibling of ND120_TOP.v (the Basys3/Verilator top) - the Basys3 top    **
** is untouched by this file. Board decisions (8-JUL-2026):              **
**   - one rPLL: 27 MHz CPU/bus/OSC + 54 MHz SDRAM clock pair            **
**   - main memory = embedded 8 MB SDRAM (MEM_RAM_49_SDRAM, 2 banks)     **
**   - microcode: SKIP_WCS_LOAD bitstream-preloaded WCS, PROM dropped    **
**   - console: OPCOM UART 9600 on the BL616 USB serial (pins 69/70)     **
**   - S1 = Master Clear (power-on-reset retrigger), S2 spare            **
** Build defines come from src/tang20k_defines.v (first file in the      **
** Gowin project).                                                       **
**                                                                       **
** Last reviewed: 8-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module ND120_TANG20K_TOP (
    input wire sys_clk,   //! 27 MHz crystal (pin 4)
    input wire s1,        //! S1 push button (pin 88) - Master Clear / reset
    input wire s2,        //! S2 push button (pin 87) - spare
    input wire uart_rxp,  //! UART receive (from BL616, pin 70)
    output wire uart_txp, //! UART transmit (to BL616, pin 69)

    output wire [5:0] led,  //! 6 board LEDs, ACTIVE LOW (pins 15-20)

    // Embedded SDRAM ("magic" port names - Gowin EDA connects these to the
    // on-package SDRAM die automatically; the OSS flow pins them in a cst)
    output        O_sdram_clk,
    output        O_sdram_cke,
    output        O_sdram_cs_n,
    output        O_sdram_cas_n,
    output        O_sdram_ras_n,
    output        O_sdram_wen_n,
    inout  [31:0] IO_sdram_dq,
    output [10:0] O_sdram_addr,
    output [ 1:0] O_sdram_ba,
    output [ 3:0] O_sdram_dqm
);

  /**********************************************
  *  Clocks: 27 MHz CPU/bus + 54 MHz SDRAM pair *
  ***********************************************/
  wire clk2x;        // 54 MHz - SDRAM controller
  wire clk2x_sdram;  // 54 MHz shifted - SDRAM chip
  wire pll_lock;

`ifdef SIM
  // Simulation (iverilog testbench): no rPLL primitive. sys_clk plays the
  // 2x clock; clk_cpu is an edge-aligned divide-by-2, clk2x_sdram is the
  // 180-degree inversion - same relationships the PLL provides.
  reg clk_cpu_div = 0;
  always @(posedge sys_clk) clk_cpu_div <= ~clk_cpu_div;
  assign clk2x = sys_clk;
  assign clk2x_sdram = ~sys_clk;
  wire clk_cpu = clk_cpu_div;
  assign pll_lock = 1'b1;
`else
  wire clk_cpu;      // 27 MHz - CPU / bus / OSC domain

  Gowin_rPLL_ND120 pll (
      .clkout (clk2x),
      .clkoutp(clk2x_sdram),
      .clkoutd(clk_cpu),
      .lock   (pll_lock),
      .clkin  (sys_clk)
  );
`endif

  /**********************************************
  *  Reset: power-on + S1 (Master Clear)        *
  ***********************************************/
  // Same scheme as ND120_TOP's FPGA branch: hold sys_rst_n low for 256
  // clk_cpu cycles after PLL lock; pressing S1 (active high) restarts the
  // counter, retriggering the full CPU boot sequence.
  reg s1_r1, s1_r2;
  always @(posedge clk_cpu) begin
    s1_r1 <= s1;
    s1_r2 <= s1_r1;
  end

  reg [7:0] por_count = 8'd0;
  reg       por_done = 1'b0;
  always @(posedge clk_cpu) begin
    if (s1_r2) begin  // S1 pressed: Master Clear
      por_count <= 8'd0;
      por_done  <= 1'b0;
    end else if (!por_done) begin
      if (por_count == 8'hFF) por_done <= 1'b1;
      else por_count <= por_count + 1'b1;
    end
  end
  wire sys_rst_n = por_done & pll_lock;

  /**********************************************
  *  ND-100 bus: tied off (no external bus)     *
  ***********************************************/
  wire [12:0] CSA_12_0;

  wire BREQ_n = 1'b1;
  wire BINT10_n = 1'b1;
  wire BINT11_n = 1'b1;
  wire BINT12_n = 1'b1;
  wire BINT13_n = 1'b1;
  wire BINT15_n = 1'b1;
  wire POWSENSE_n = 1'b1;

  wire [23:0] BD_23_0_n_IN = 24'hFFFFFF;  // pulled high (inactive)

  wire SEMRQ_n_IN = 1'b1;
  wire BINPUT_n_IN = 1'b1;
  wire BDAP_n_IN = 1'b1;
  wire BDRY_n_IN = 1'b1;
  wire BAPR_n_IN = 1'b1;

  // Installation number (read via IDB source 035)
  wire [7:0] installation_number = 8'd123;

  wire s_high = 1'b1;
  wire s_low = 1'b0;

  wire [2:0] s_SEL_TESTMUX = 3'b000;

  // Baud rate thumbwheel: 8 = 9600 baud (BAUDV, microcode page 158).
  // UART_BAUD_RATE in tang20k_defines.v must match.
  wire [3:0] s_baud_rate_switch = 4'b1000;

  /**********************************************
  *  Status / debug wires                       *
  ***********************************************/
  wire [6:0] s_cpu_led;  // ND3202D LED bundle, see ND3202D.v port comment
  wire s_run;            // RUN_n: low while the CPU is running
  wire [4:0] s_debug_cc_term;
  wire s_debug_mclk, s_debug_lcs_n, s_debug_fetch;
  wire s_debug_mr_n, s_debug_clear_n, s_debug_refrq_n;
  wire s_debug_intrq_n, s_debug_powfail_n;
  wire [15:0] s_debug_fidbo;
  wire [13:0] s_debug_la_23_10;
  wire [9:0] s_debug_ca_9_0;
  wire [4:0] s_test_4_0;
  wire [4:0] s_dp_5_1_n;
  wire s_tp1_intrq_n;
  wire [63:0] s_csbits;

  reg [26:0] clockTicks;
  always @(posedge clk_cpu) clockTicks <= clockTicks + 1'b1;

  /* verilator lint_off UNUSEDSIGNAL */
  wire unused_s2 = s2;
  /* verilator lint_on UNUSEDSIGNAL */

  /**********************************************
  *  LEDs (ACTIVE LOW): agreed bring-up set     *
  ***********************************************/
  // s_cpu_led[3] = LED_CPU_GRANT_INDICATOR (= CGNT_n, low when granted)
  // s_cpu_led[4] = LED_BUS_GRANT_INDICATOR (= BGNT_n, low when granted)
  // s_cpu_led[2] = LED4_RED_PARITY_ERROR (polarity: verify on first light)
  // WRITE-GENERATION ANALYZER BUILD (8-JUL-2026 late): bus retargeted at
  // the DGA WRITE chain (see ND3202D.v DBG_MEMW assign for the bit map).
  // [7] = wdec (F924 A160 D3 decode input), [6] = WRITE (registered out).
  wire [15:0] s_dbg_memw;
  wire dbg_dumping;
  reg wdec_seen, write_seen;         // sticky since arm
  assign led[0] = ~s_dbg_memw[6];    // ON = WRITE high right now
  assign led[1] = ~write_seen;       // ON = WRITE asserted at least once since arm
  assign led[2] = ~wdec_seen;        // ON = write DECODE fired at least once since arm
  assign led[3] = ~dbg_dumping;      // ON = trigger hit, dump ran (new-build marker)
  assign led[4] = ~s_cpu_led[2];     // parity error indicator
  assign led[5] = clockTicks[24];    // heartbeat ~0.8 Hz (clock alive)

  /**********************************************
  *  The CPU board                              *
  ***********************************************/
  /**********************************************
  *  On-chip write-path analyzer (clk2x domain) *
  ***********************************************/
  // 512 samples of the 16-bit bus at clk2x; trigger = first rising edge of
  // the write DECODE (bit [7], the F924 D3 input) after a ~2.5 s arm delay
  // (skips boot; deposit at the console fires it). 64 pre-trigger + 448
  // post, so the whole decode -> WRITE -> ECREQ -> grant -> RAS/CAS
  // sequence lands after the trigger. Then dumps "hhhh\r\n" x512 over the
  // UART at 9600 (taking the TX pin over from the CPU console).
  // If LED3 (decode seen) never lights, the decode itself never fires on
  // silicon - that is a result too.
  reg [15:0] cap_mem[0:511];
  reg [8:0] cap_wptr;
  reg [8:0] cap_post;
  reg [24:0] arm_cnt;
  reg cap_armed, cap_trig, cap_done;
  reg wdec_d2;
  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      cap_wptr <= 0; cap_post <= 0; arm_cnt <= 0;
      cap_armed <= 0; cap_trig <= 0; cap_done <= 0; wdec_d2 <= 0;
      wdec_seen <= 0; write_seen <= 0;
    end else begin
      if (!cap_armed) begin
        arm_cnt <= arm_cnt + 1'b1;
        if (arm_cnt == 25'h1FFFFFF) cap_armed <= 1;  // ~2.5 s at 13.5 MHz
      end
      wdec_d2 <= s_dbg_memw[7];
      if (cap_armed && s_dbg_memw[7]) wdec_seen <= 1;
      if (cap_armed && s_dbg_memw[6]) write_seen <= 1;
      if (!cap_done) begin
        cap_mem[cap_wptr] <= s_dbg_memw;
        cap_wptr <= cap_wptr + 1'b1;
        if (!cap_trig && cap_armed && !wdec_d2 && s_dbg_memw[7]) begin
          cap_trig <= 1;
          cap_post <= 9'd448;
        end else if (cap_trig) begin
          cap_post <= cap_post - 1'b1;
          if (cap_post == 0) cap_done <= 1;
        end
      end
    end
  end

  // hex dumper: 512 lines of 4 hex digits, oldest sample first
  function [7:0] hexd(input [3:0] n);
    hexd = (n < 4'd10) ? (8'h30 + {4'b0, n}) : (8'h37 + {4'b0, n});
  endfunction
  // Separate registered read port (simple-dual-port BRAM; write happens
  // only during capture, read only during dump - Gowin PA2122 otherwise)
  reg [8:0] cap_raddr;
  reg [15:0] cap_rd;
  always @(posedge clk2x) cap_rd <= cap_mem[cap_raddr];

  reg [9:0] dump_i;
  reg [2:0] dump_c;
  reg dump_run, dump_fin;
  reg [26:0] hold_cnt;  // ~10 s at 13.5 MHz: keep the console on the CPU
                        // after the trigger so the deposit echo and a
                        // post-deposit examine get through before the dump
  reg d_tx_valid;
  reg [7:0] d_tx_data;
  wire d_tx_busy, dbg_txd;
  assign dbg_dumping = dump_run | dump_fin;
  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      dump_i <= 0; dump_c <= 0; dump_run <= 0; dump_fin <= 0; d_tx_valid <= 0;
      cap_raddr <= 0; hold_cnt <= 0;
    end else begin
      d_tx_valid <= 0;
      if (cap_done && !dump_run && !dump_fin && hold_cnt != 27'h7FFFFFF)
        hold_cnt <= hold_cnt + 1'b1;
      if (cap_done && !dump_run && !dump_fin && hold_cnt == 27'h7FFFFFF) begin
        dump_run <= 1; dump_i <= 0; dump_c <= 0;
        cap_raddr <= cap_wptr;  // oldest sample first (cap_rd valid next cycle)
      end else if (dump_run && !d_tx_busy && !d_tx_valid) begin
        case (dump_c)
          3'd0: d_tx_data <= hexd(cap_rd[15:12]);
          3'd1: d_tx_data <= hexd(cap_rd[11:8]);
          3'd2: d_tx_data <= hexd(cap_rd[7:4]);
          3'd3: d_tx_data <= hexd(cap_rd[3:0]);
          3'd4: d_tx_data <= 8'h0D;
          default: d_tx_data <= 8'h0A;
        endcase
        d_tx_valid <= 1;
        if (dump_c == 3'd5) begin
          dump_c <= 0;
          dump_i <= dump_i + 1'b1;
          cap_raddr <= cap_raddr + 1'b1;  // settled long before next char
          if (dump_i == 10'd511) begin dump_run <= 0; dump_fin <= 1; end
        end else dump_c <= dump_c + 1'b1;
      end
    end
  end
  uart_tx #(
      .DELAY_FRAMES(1406)  // 13.5 MHz / 9600
  ) u_dbg_tx (
      .clk(clk2x),
      .rst_n(sys_rst_n),
      .tx_data(d_tx_data),
      .tx_valid(d_tx_valid),
      .tx_busy(d_tx_busy),
      .txd(dbg_txd)
  );
  wire cpu_txd;
  assign uart_txp = dbg_dumping ? dbg_txd : cpu_txd;

  ND3202D CPU_BOARD (
      .sysclk(clk_cpu),  // CPU core, OSC and bus all on 27 MHz
      .sys_rst_n(sys_rst_n),
      .CLOCK_1(clk_cpu),
      .CLOCK_2(clk_cpu),

      // C-PLUG inputs
      .LOAD_n(s_high),
      .BREQ_n(BREQ_n),
      .CONTINUE_n(s_high),
      .STOP_n(s_high),

      .BINT10_n(BINT10_n),
      .BINT11_n(BINT11_n),
      .BINT12_n(BINT12_n),
      .BINT13_n(BINT13_n),
      .BINT15_n(BINT15_n),

      .POWSENSE_n(POWSENSE_n),

      .BD_23_0_n_IN(BD_23_0_n_IN),
      .BD_23_0_n_OUT(),

      // Bidirectional bus signals (unused outputs left open)
      .SEMRQ_n_IN(SEMRQ_n_IN),
      .SEMRQ_n_OUT(),
      .BINPUT_n_IN(BINPUT_n_IN),
      .BINPUT_n_OUT(),
      .BDAP_n_IN(BDAP_n_IN),
      .BDAP_n_OUT(),
      .BDRY_n_IN(BDRY_n_IN),
      .BDRY_n_OUT(),
      .BAPR_n_IN(BAPR_n_IN),
      .BAPR_n_OUT(),

      // CPU board -> C-PLUG (no external bus: open)
      .BREF_n(),
      .BERROR_n(),
      .BINACK_n(),
      .BIOXE_n(),
      .BMEM_n(),
      .OUTGRANT_n(),
      .OUTIDENT_n(),
      .MCL(),

      // B-PLUG
      .INR_7_0(installation_number),
      .EBUS(1'b1),
      .SEL5MS_n(1'b1),

      .PIL(),
      .LUA_12_0(),
      .IDB_15_0(),
      .CSCOMM_4_0(),
      .MIS_1_0(),
      .CD_15_0(),
      .LBD_15_0(),
      .LA_23_10(s_debug_la_23_10),
      .CA_9_0(s_debug_ca_9_0),

      // A-PLUG
      .OSCCL_n(s_high),
      .OC_1_0(2'b11),   // clock select = XTAL1 (full speed)
      .XTR(s_low),
      .LOCK_n(s_high),
      .CONSOLE_n(s_high),
      .SWMCL_n(s_high),
      .EAUTO_n(s_high),
      .RXD(uart_rxp),

      .RUN_n(s_run),

      .TXD(cpu_txd),
      .DP_5_1_n(s_dp_5_1_n),

      // Configuration switches
      .SW1_CONSOLE(s_high),
      .SEL_TESTMUX(s_SEL_TESTMUX),
      .BAUD_RATE_SWITCH(s_baud_rate_switch),

      // Outputs
      .CSBITS(s_csbits),
      .TEST_4_0(s_test_4_0),
      .TP1_INTRQ_n(s_tp1_intrq_n),
      .CSA_12_0(CSA_12_0),
      .LED(s_cpu_led[6:0]),
      .DEBUG_CC_TERM(s_debug_cc_term),
      .DEBUG_MCLK(s_debug_mclk),
      .DEBUG_LCS_n(s_debug_lcs_n),
      .DEBUG_FETCH(s_debug_fetch),
      .DEBUG_MR_n(s_debug_mr_n),
      .DEBUG_CLEAR_n(s_debug_clear_n),
      .DEBUG_REFRQ_n(s_debug_refrq_n),
      .DEBUG_INTRQ_n(s_debug_intrq_n),
      .DEBUG_POWFAIL_n(s_debug_powfail_n),
      .DEBUG_FIDBO_15_0(s_debug_fidbo),

      // SDRAM main memory (MAIN_RAM_SDRAM, threaded down to MEM_RAM_49_SDRAM)
      .clk2x(clk2x),
      .clk2x_sdram(clk2x_sdram),
      .O_sdram_clk(O_sdram_clk),
      .O_sdram_cke(O_sdram_cke),
      .O_sdram_cs_n(O_sdram_cs_n),
      .O_sdram_cas_n(O_sdram_cas_n),
      .O_sdram_ras_n(O_sdram_ras_n),
      .O_sdram_wen_n(O_sdram_wen_n),
      .IO_sdram_dq(IO_sdram_dq),
      .O_sdram_addr(O_sdram_addr),
      .O_sdram_ba(O_sdram_ba),
      .O_sdram_dqm(O_sdram_dqm),
      .DBG_MEMW(s_dbg_memw)
  );

endmodule
