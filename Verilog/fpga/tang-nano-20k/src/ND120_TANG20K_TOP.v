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

    // microSD slot (SD-native mode). Pin map and PULL_MODE come from the
    // silicon-proven sd-fat-test/src/nano20k_sd.cst - the slot has external
    // 10K pull-ups (R53-R57), so released lines idle high. Only CMD and DAT0
    // are used: the storage reader is 1-bit (the 4-bit writer is not built in
    // this design), so DAT1-3 are not brought out at all.
    output wire sd_clk,
    inout  wire sd_cmd,   //! bidirectional: host commands / card responses
    inout  wire sd_dat0,  //! bidirectional: card read data

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

  // Remote reset: a UART BREAK on the console RX (line held LOW for >=200 ms,
  // ~2 character times would be enough but 200 ms rejects any glitch) acts
  // exactly like pressing S1. BREAK is out-of-band: normal typed characters
  // and ndcomm's binary deposit streams always return the line high between
  // frames, so nothing legitimate can fake it. Host side: send a break
  // (python termios.tcsendbreak / picocom C-a C-\ ) to reset the board
  // without touching it.
  localparam integer BREAK_CYCLES = (`BOARD_CLK_FREQ / 5);  // 200 ms of low
  reg [24:0] brk_cnt = 25'd0;
  reg        brk_rst = 1'b0;
  reg        rx_r1 = 1'b1, rx_r2 = 1'b1;
  always @(posedge clk_cpu) begin
    rx_r1 <= uart_rxp;
    rx_r2 <= rx_r1;
    if (rx_r2) begin
      brk_cnt <= 25'd0;
      brk_rst <= 1'b0;
    end else if (brk_cnt >= BREAK_CYCLES[24:0]) begin
      brk_rst <= 1'b1;   // held until the line returns high
    end else begin
      brk_cnt <= brk_cnt + 1'b1;
    end
  end

  reg [7:0] por_count = 8'd0;
  reg       por_done = 1'b0;
  always @(posedge clk_cpu) begin
    if (s1_r2 | brk_rst) begin  // S1 pressed or console BREAK: Master Clear
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
  wire [12:0] CSA_12_0 /* synthesis syn_keep=1 */;  // GAO probe net - see GAO-HOWTO.md
  wire  [3:0] s_pil_3_0 /* synthesis syn_keep=1 */;  // PIL for the grant-capture probe (TANG_GRANT_CAPTURE)
  wire [15:0] s_ireq_15_0_n /* synthesis syn_keep=1 */;  // raw interrupt-request vector (active low) for grant-source capture
  wire [15:0] s_xmic_dbg /* synthesis syn_keep=1 */;  // microsequencer address-advance probe (Tang 06000-hang root cause)

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

  // Installation number, the s_high/s_low helpers, SEL_TESTMUX and the baud
  // rate thumbwheel (8 = 9600 baud, BAUDV microcode page 158) are CPU-board
  // constants and now live inside ND120_CORE.v -- not duplicated per board.
  // UART_BAUD_RATE in tang20k_defines.v must still match 9600.

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
  reg wdec_seen, write_seen;         // sticky since arm (write-path analyzer)
  // The LED assignments live further down, AFTER the storage block declares
  // the signals they show - see "STORAGE BRING-UP LED SET".

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
  // Capture source / trigger / pre-post split are switchable:
  //  - default: the write-path analyzer (source = s_dbg_memw, trigger = write
  //    decode rising, 64 pre + 448 post).
  //  - TANG_GRANT_CAPTURE: the masked-level-10 grant probe. Source packs
  //    {PIL[3:0], CSA[11:0]}; trigger = PIL entering level 10 (0->10 is the
  //    silicon wedge); 448 PRE + 64 post so the whole lead-up to the switch is
  //    recorded. Reading back the CSA sequence shows whether PIL->10 goes
  //    through the normal level-switch microcode (PLINT 01133 / PLVO 01140 /
  //    LVSWP 01146-01155, as a legit level-13 switch does in sim) or bypasses
  //    it - the decisive fork for the root cause.
  reg [15:0] cap_mem[0:511];
  reg [8:0] cap_wptr;
  reg [8:0] cap_post;
  reg [28:0] arm_cnt;  // 30-JUL: widened 25->29 bits (arm ~40s, was ~2.5s) -
                       // the WCS microcode load keeps CSA STATIC longer than
                       // 2.5s, so the hang trigger fired mid-load and the
                       // dumper seized the TX pin before the console ever
                       // spoke (SRAM-load-no-boot mystery, plan Issue I).
  reg cap_armed, cap_trig, cap_done;
  reg wdec_d2;
  reg [3:0] pil_prev;
  reg [12:0] csa_prev;
  reg [21:0] csa_stable;   // clk2x cycles the microcode CSA has been unchanged
`ifdef TANG_GRANT_CAPTURE
  // Word = {PIL[3:0], INTRQ, CSA[10:0]}.  INTRQ = ~DEBUG_INTRQ_n (already routed
  // to this top) shows WHEN the interrupt-request FF is asserted relative to the
  // 00017 dispatch: held-from-early (a level-held PAN, i.e. the free-running RTC,
  // taken at the first interrupt-enable point => deterministic step 18) vs a late
  // pulse. CSA[10:0] still covers the whole dispatch/level-switch region
  // (00017 / 03740 / 01xxx); the 06xxx/07xxx SETUP context was captured in v1.
  // Word = the 16-bit interrupt-request vector, active-HIGH (bit n set = IREQ[n]
  // pending). Trigger = PIL entering level 10. The 448 pre-trigger samples cover
  // the 00214 dispatch and the 00017/00053 RVECT read, so this shows EXACTLY
  // which request bit (if any) is pending when the spurious grant fires:
  //   all-zero  => a phantom grant with NO real request (empty-vector -> level 10)
  //   bit 0 set => a real level-10 (BINT10 terminal) request
  //   bit 8-15  => a HIGH-group/internal request collapsing to a level-10 read
  // Word = {PIL[3:0], CSA[11:0]} - the microcode path. Trigger on EITHER the
  // PIL->10 wedge OR the microcode HANGING (CSA unchanged for 2^22 clk2x ~ 78 ms
  // = the free-run 0! cold start stalled). 480 pre + 32 post, so the dump shows
  // the CSA sequence LEADING INTO the stall/wedge - i.e. exactly where and how
  // the cold start dies. This is the free-run root-cause tool (single-stepping
  // injects its own panel-stop PAN pulses; free-run does not, so this catches
  // the REAL 0! failure).
  // Word = the MEMORY ADDRESS being accessed, bits [23:8] = {LA_23_10[13:0],
  // CA_9_0[9:8]}. When the cold start stalls at STZ (06000) waiting for a memory
  // write to terminate, this captures WHICH address the write targets - the high
  // bits show the region (in-range main mem < addr 21, vs bit22/23 = storage /
  // out-of-range), which points at the SDRAM-controller condition that never
  // asserts TERM. Trigger = microcode HANG (CSA stable) or PIL->10.
  // Word = the CYCLE-FSM / arbitration state that gates TERM_n (why the STZ
  // memory write never terminates). DEBUG_CC_TERM = {TERM_n,CC3_n,CC2_n,CC1_n,
  // CC0_n}. Plus INTRQ / REFRQ / FETCH / MR_n / LCS_n so we see if an interrupt
  // break, a refresh, or a stuck cycle state is holding TERM_n high at the hang.
  //   bit4:0 = CC_TERM {TERM_n,CC3_n,CC2_n,CC1_n,CC0_n}
  //   bit5=INTRQ(=~INTRQ_n) bit6=REFRQ(=~REFRQ_n) bit7=FETCH bit8=MR_n
  //   bit9=LCS_n bit10=CLEAR_n bit11=POWFAIL_n bit12=MCLK  bit15:13=0
  // Word = the microsequencer address-advance probe (from CGA_MIC XMIC_DBG):
  //   bit15=SC6  bit14=s_mclk_n (regW mux-select = ~mclk_pa routed LEVEL)
  //   bit13=MCLK_EN (microsequencer clock-tick pulse)  bit12:0=regIW (captured
  //   next-address). Captured at the 06000 hang: shows which signal is FROZEN.
  //   MCLK_EN stuck-low => word never retires (mem/CYC, case A); s_mclk_n stuck
  //   => regW mux frozen; regIW stuck 06000 vs jump target 0145 (case B).
  // STACK-hang investigation: capture the STALLED microcode address (CSA) so we
  // know WHERE the STACK test wedges (map to the microcode listing), the same
  // first step that located the boot hang at CSA 06000.
  //   bit12:0 = CSA_12_0 (octal microcode address at the stall)  bit15:13 = 0
  wire [15:0] s_cap_src   = {3'b0, CSA_12_0[12:0]};
  wire        s_hang      = &csa_stable;
  wire        s_cap_event = ((s_pil_3_0 == 4'd10) && (pil_prev != 4'd10)) || s_hang;
  localparam [8:0] CAP_POST = 9'd32;
`elsif TANG_TRAP_CAPTURE
  // Issue-D (PAGING test 3 eject) probe. Word = {TVEC[3:0], TRAPN, CSA[10:0]}:
  // TVEC/TRAPN arrive via the repacked XMIC_DBG (CGA_MIC.v, same define), CSA
  // is the local GAO net. Trigger = CSA held at octal 7 for 16 clk2x cycles
  // (the unimplemented-vector-7 self-jump; a transit through address 7 does
  // not persist) OR the frozen-CSA hang detector. 480 pre + 32 post so the
  // dump shows the trap dispatch LEADING INTO vector 7 - in particular
  // whether TVEC=7 at the jump (trap generator really computed 7 on silicon)
  // or TVEC!=7 (the CSA latch captured a mid-transition value = comb-path
  // setup failure in the TVEC->CSA path).
  wire [15:0] s_cap_src   = {s_xmic_dbg[15:11], CSA_12_0[10:0]};
  reg  [4:0]  csa7_cnt;
  always @(posedge clk2x) begin
    if (!sys_rst_n) csa7_cnt <= 5'd0;
    else if (CSA_12_0 == 13'd7) begin
      if (!(&csa7_cnt)) csa7_cnt <= csa7_cnt + 1'b1;
    end else csa7_cnt <= 5'd0;
  end
  wire        s_hang      = &csa_stable;
  wire        s_cap_event = (csa7_cnt == 5'd16) || s_hang;
  localparam [8:0] CAP_POST = 9'd32;
`else
  wire [15:0] s_cap_src   = s_dbg_memw;
  wire        s_cap_event = !wdec_d2 && s_dbg_memw[7];
  localparam [8:0] CAP_POST = 9'd448;
`endif
  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      cap_wptr <= 0; cap_post <= 0; arm_cnt <= 0;
      cap_armed <= 0; cap_trig <= 0; cap_done <= 0; wdec_d2 <= 0;
      wdec_seen <= 0; write_seen <= 0; pil_prev <= 0;
      csa_prev <= 0; csa_stable <= 0;
    end else begin
      if (!cap_armed) begin
        arm_cnt <= arm_cnt + 1'b1;
        if (arm_cnt == 29'h1FFFFFFF) cap_armed <= 1;  // ~40 s at 13.5 MHz
      end
      // microcode-hang detector: count clk2x cycles CSA stays unchanged
      csa_prev <= CSA_12_0;
      if (CSA_12_0 != csa_prev) csa_stable <= 0;
      else if (!(&csa_stable))  csa_stable <= csa_stable + 1'b1;
      wdec_d2 <= s_dbg_memw[7];
      pil_prev <= s_pil_3_0;
      if (cap_armed && s_dbg_memw[7]) wdec_seen <= 1;
      if (cap_armed && s_dbg_memw[6]) write_seen <= 1;
      if (!cap_done) begin
        cap_mem[cap_wptr] <= s_cap_src;
        cap_wptr <= cap_wptr + 1'b1;
        if (!cap_trig && cap_armed && s_cap_event) begin
          cap_trig <= 1;
          cap_post <= CAP_POST;
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
  // The write-path analyzer served its purpose: with the P3 strobe
  // conversion the write decode fires during normal boot, so the dump
  // would trigger every boot and hold the TX pin forever (dump_fin never
  // clears). Only let it take the console when explicitly enabled.
`ifdef TANG_WRITE_ANALYZER_DUMP
  assign uart_txp = dbg_dumping ? dbg_txd : cpu_txd;
`elsif TANG_GRANT_CAPTURE
  // Grant-capture: after PIL->10 fires the capture, the dumper takes the TX
  // pin and streams the 512 {PIL,CSA} samples as hex. The console is dead
  // after that (expected - the CPU has wedged at level 10 anyway).
  assign uart_txp = dbg_dumping ? dbg_txd : cpu_txd;
`elsif TANG_TRAP_CAPTURE
  // Trap-capture: after the vector-7 / hang trigger fires, the dumper takes
  // the TX pin and streams the 512 {TVEC,TRAPN,CSA} samples as hex. Console
  // dead afterwards (expected - the CPU is spinning at vector 7 / wedged).
  assign uart_txp = dbg_dumping ? dbg_txd : cpu_txd;
`else
  /* verilator lint_off UNUSEDSIGNAL */
  wire unused_dbg_txd = dbg_txd;
  /* verilator lint_on UNUSEDSIGNAL */
  assign uart_txp = cpu_txd;
`endif

  // Phase 2 of the ND120_CORE extraction (14-JUL-2026): the core now carries
  // the ND-BUS tape device (INCLUDE_TAPE=1) and nd_tape_sdfat_source hangs off
  // the TAPE_BYTE_* seam, so '400$' at the console boots BOOT.BPUN off the real
  // SD card - the same RTL proven in the runSim harness against a simulated
  // card. Floppy and SMD stay out until their phases (they need the sync-read
  // buffer refactor first - see BSRAM-BUDGET.md).
  //
  // installation_number, the s_high/s_low helpers, OC_1_0, SEL_TESTMUX and
  // the baud-rate switch now live INSIDE ND120_CORE (CPU-board constants),
  // so this board no longer declares them.
  //
  // installation_number is no longer a constant: ND120_CORE holds a real
  // 16-byte BACK-WIRING PROM (BACKWIRING_PROM, addressed by PIL 3:0) that
  // SINTRAN reads with VERSN / IDBS,INR=35. To bake a CPU NUMBER / CPU TYPE /
  // legal-user count into THIS bitstream, add the `defines to
  // src/tang20k_defines.v (compiled first, so it wins over the defaults):
  //   `define ND120_SYSNO   16'd42
  //   `define ND120_HWINFO2 16'd102
  //   `define ND120_NLEGU   8'd32
  // Defaults + "not present" sentinels live in
  // ../../Shared/support/nd120_backwiring_defaults.vh; mechanism in
  // ../../docs/backwiring-prom-installation-number.md.

  /**********************************************
  *  Storage: BOOT.BPUN off the SD card         *
  ***********************************************/
  // Clock choice - deliberate, do not "simplify" to clk_cpu/clk2x:
  // sd_file_reader's identification clock is a HARDCODED divide (INIT_HALF=99,
  // sd_file_reader.v:124), i.e. clk/198. The SD spec requires 100-400 kHz for
  // card identification, so ONLY the 27 MHz crystal is legal:
  //     27.00 MHz -> 136.4 kHz  OK   (and what sd-fat-test proved on silicon)
  //     13.50 MHz ->  68.2 kHz  OUT OF SPEC
  //      6.75 MHz ->  34.1 kHz  OUT OF SPEC
  // Running the stack from sys_clk also keeps the card at one fixed speed for
  // every VARIANT (slow/crawl/full only move the CPU). The SDRAM device port
  // is built for exactly this: stor_clk is its own domain, toggle-CDC'd into
  // clk2x inside MEM_RAM_49_SDRAM.
  wire clk_stor = sys_clk;

  // sys_rst_n is generated in the clk_cpu domain; 2-FF synchronize its release
  // into the storage domain (async assert, synchronous deassert).
  reg stor_rst_r1, stor_rst_r2;
  always @(posedge clk_stor or negedge sys_rst_n)
    if (!sys_rst_n) begin
      stor_rst_r1 <= 1'b0;
      stor_rst_r2 <= 1'b0;
    end else begin
      stor_rst_r1 <= 1'b1;
      stor_rst_r2 <= stor_rst_r1;
    end
  wire rst_stor_n = stor_rst_r2;

  wire        TAPE_BYTE_REQ, TAPE_REWIND;
  wire        s_tape_byte_valid;
  wire [7:0]  s_tape_byte_data;

  wire        s_sd_clk_o;
  wire        s_sd_cmd_o, s_sd_cmd_oe;
  wire        s_sd_dat0_o, s_sd_dat0_oe;
  wire [ 1:0] s_sd_status;

  // SDRAM device port (clk_stor domain) into MEM_RAM_49_SDRAM's upper half
  wire        s_mem_start, s_mem_we;
  wire [19:0] s_mem_addr;
  wire [31:0] s_mem_wdata, s_mem_rdata;
  wire        s_mem_busy, s_mem_done;

  // Storage device select: TANG_FLOPPY = floppy-only (1560&, no tape); default
  // = tape-only (400$, the proven silicon build). Ronny: don't carry both at
  // once - a floppy build drops the tape (saves the ND_TAPE_400 + tape-adapter
  // resources). Applied to BOTH the core (device presence) and the SD-FAT
  // wrapper (which client it serves).
`ifdef TANG_FLOPPY
  localparam TANG_INC_TAPE   = 0;
  localparam TANG_INC_FLOPPY = 1;
`else
  localparam TANG_INC_TAPE   = 1;
  localparam TANG_INC_FLOPPY = 0;
`endif

  nd_tape_sdfat_source #(
      .SIMULATE(0),                     // real card: full-length SD init
      .INCLUDE_TAPE(TANG_INC_TAPE),
      .INCLUDE_FLOPPY(TANG_INC_FLOPPY)
  ) TAPE_SDFAT_SOURCE (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_stor_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (sys_rst_n),

      .byte_req     (TAPE_BYTE_REQ),
      .byte_valid   (s_tape_byte_valid),
      .byte_data    (s_tape_byte_data),
      .source_rewind(TAPE_REWIND),

      // floppy disk-image backend seam (client 1 = FLOPPY1.IMG) <-> the core
      .FDISK_REQ      (FDISK_REQ),
      .FDISK_WR       (FDISK_WR),
      .FDISK_LSECT    (FDISK_LSECT),
      .FDISK_FORMAT   (FDISK_FORMAT),
      .FDISK_DRIVE    (FDISK_DRIVE),
      .FDISK_WORDCOUNT(FDISK_WORDCOUNT),
      .FDISK_DONE     (FDISK_DONE),
      .FDISK_ERR      (FDISK_ERR),
      .FDISK_MEDIA_FMT(FDISK_MEDIA_FMT),
      .FDBUF_ADDR     (FDBUF_ADDR),
      .FDBUF_WDATA    (FDBUF_WDATA),
      .FDBUF_WE       (FDBUF_WE),
      .FDBUF_RDATA    (FDBUF_RDATA),

      .sd_clk_o  (s_sd_clk_o),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (s_sd_cmd_o),
      .sd_cmd_oe (s_sd_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (s_sd_dat0_o),
      .sd_dat0_oe(s_sd_dat0_oe),

      .mem_start(s_mem_start),
      .mem_we   (s_mem_we),
      .mem_addr (s_mem_addr),
      .mem_wdata(s_mem_wdata),
      .mem_rdata(s_mem_rdata),
      .mem_busy (s_mem_busy),
      .mem_done (s_mem_done),

      .sd_status(s_sd_status)
  );

  /**********************************************
  *  SD pads - the ONLY tristates (repo rule)   *
  ***********************************************/
  // Single-ternary form  oe ? val : 1'bz  is mandatory: it is the only idiom
  // yosys maps to a real IOBUF. A 'z' in an INNER ternary branch silently
  // collapses to a plain driver and shorts the bus - the silicon-only bug
  // documented in sd-fat-test/src/sd_fat_test_top.v. Verified by 'make check'
  // (check_tristate.py) below. DAT1-3 are not driven at all; the slot's
  // external 10K pull-ups hold them high, which is what keeps the card out of
  // SPI mode at CMD0.
  assign sd_clk  = s_sd_clk_o;
  assign sd_cmd  = s_sd_cmd_oe  ? s_sd_cmd_o  : 1'bz;
  assign sd_dat0 = s_sd_dat0_oe ? s_sd_dat0_o : 1'bz;

  /**********************************************
  *  STORAGE BRING-UP LED SET (ACTIVE LOW)      *
  ***********************************************/
  // The board's only window into the SD stack. It answers "did the card
  // mount?" and "did the CPU ever ask the tape for a byte?" SEPARATELY, so a
  // silent console can be attributed to the CPU or to storage instead of
  // guessed at.
  //
  //   led[5] heartbeat ~0.8 Hz        - clk_cpu alive at all
  //   led[4] sd_status[1]  \  00 = NOTCHK (the mount never ran)  01 = NOCARD
  //   led[3] sd_status[0]  /  10 = ERROR (mount/FAT failed)      11 = OK
  //   led[2] a tape byte was served   - the SD->tape path delivered data
  //   led[1] the SD clock has toggled - the card is being talked to at all
  //   led[0] the CPU asked the tape for a byte - '400$' reached ND_TAPE_400
  //
  // Reading it: led[4] AND led[3] both lit = the whole SD-FAT chain works
  // (card init, FAT walk, BOOT.BPUN located and preloaded into the SDRAM
  // region). led[0] dark after typing 400$ = the CPU never drove the device,
  // i.e. a CPU/bus problem and NOT a storage one.
  //
  // sd_status is a clk_stor signal sampled into clk_cpu here with no CDC: it
  // drives an LED for a human eye, where a torn sample is unobservable.
  // The write-path analyzer keeps its stickies (still live behind
  // TANG_WRITE_ANALYZER_DUMP) - they just no longer own the LEDs.
  reg s_tape_byte_seen, s_tape_req_seen, s_sdclk_seen, s_sdclk_d;
  always @(posedge clk_cpu or negedge sys_rst_n)
    if (!sys_rst_n) begin
      s_tape_byte_seen <= 1'b0;
      s_tape_req_seen  <= 1'b0;
      s_sdclk_seen     <= 1'b0;
      s_sdclk_d        <= 1'b0;
    end else begin
      s_sdclk_d <= s_sd_clk_o;
      if (s_tape_byte_valid)       s_tape_byte_seen <= 1'b1;
      if (TAPE_BYTE_REQ)           s_tape_req_seen  <= 1'b1;
      if (s_sd_clk_o != s_sdclk_d) s_sdclk_seen     <= 1'b1;
    end

  assign led[0] = ~s_tape_req_seen;   // ON = the CPU asked the tape for a byte
  assign led[1] = ~s_sdclk_seen;      // ON = the SD clock has toggled
  assign led[2] = ~s_tape_byte_seen;  // ON = a tape byte was actually served
  assign led[3] = ~s_sd_status[0];    // sd_status low bit
  assign led[4] = ~s_sd_status[1];    // sd_status high bit (both lit = OK)
  assign led[5] = clockTicks[24];     // heartbeat ~0.8 Hz (clock alive)

  /* verilator lint_off UNUSEDSIGNAL */
  wire unused_analyzer_leds = &{1'b0, s_dbg_memw, dbg_dumping, wdec_seen,
                                write_seen, s_cpu_led[2], 1'b0};
  /* verilator lint_on UNUSEDSIGNAL */

  // Floppy seam (1560&) is now WIRED to the SD-FAT stack (FLOPPY1.IMG via the
  // nd_storage floppy adapter inside TAPE_SDFAT_SOURCE). SMD stays out (phase).
  wire [15:0] DMA_RDATA;
  wire        DMA_ACK, DMA_ERR, DMA_BUSY;
  // core -> floppy backend (request)
  wire        FDISK_REQ, FDISK_WR;
  wire [15:0] FDISK_LSECT;
  wire [1:0]  FDISK_FORMAT, FDISK_DRIVE;
  wire [10:0] FDISK_WORDCOUNT;
  wire [15:0] FDBUF_RDATA;
  // floppy backend -> core (completion + buffer fill + media format)
  wire        FDISK_DONE, FDISK_ERR;
  wire [3:0]  FDISK_MEDIA_FMT;
  wire [9:0]  FDBUF_ADDR;
  wire [15:0] FDBUF_WDATA;
  wire        FDBUF_WE;
  wire        SDISK_START, SDISK_REQ, SDISK_WR;
  wire [15:0] SDISK_BLKADDR1, SDISK_BLKADDR2;
  wire [2:0]  SDISK_UNIT;
  wire [10:0] SDISK_WORDCOUNT;
  wire [15:0] SDBUF_RDATA;

  /* verilator lint_off UNUSEDSIGNAL */
  // FDISK_*/FDBUF_* are now used (floppy wired). External DMA test-client port
  // and the SMD seam stay unused in this build.
  wire unused_core_seam = &{1'b0, DMA_RDATA,
                            DMA_ACK, DMA_ERR, DMA_BUSY, SDISK_START,
                            SDISK_REQ, SDISK_WR, SDISK_BLKADDR1,
                            SDISK_BLKADDR2, SDISK_UNIT, SDISK_WORDCOUNT,
                            SDBUF_RDATA, 1'b0};
  /* verilator lint_on UNUSEDSIGNAL */

  ND120_CORE #(
      .INCLUDE_TAPE  (TANG_INC_TAPE),
      .INCLUDE_FLOPPY(TANG_INC_FLOPPY),
      .INCLUDE_SMD   (0)
  ) CORE (
      .clk_cpu(clk_cpu),  // CPU core, OSC and bus all on 27 MHz
      .sys_rst_n(sys_rst_n),

      // C-PLUG bus: no external bus on this board (tied off above)
      .BREQ_n(BREQ_n),
      .BINT10_n(BINT10_n),
      .BINT11_n(BINT11_n),
      .BINT12_n(BINT12_n),
      .BINT13_n(BINT13_n),
      .BINT15_n(BINT15_n),
      .POWSENSE_n(POWSENSE_n),

      .BD_23_0_n_IN(BD_23_0_n_IN),
      .BD_23_0_n_OUT(),

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

      .BREF_n(),
      .BERROR_n(),
      .BINACK_n(),
      .BIOXE_n(),
      .BMEM_n(),
      .OUTGRANT_n(),
      .OUTIDENT_n(),
      .MCL(),

      // UART console (BL616 USB serial)
      .RXD(uart_rxp),
      .TXD(cpu_txd),

      // Storage seam: the tape reads BOOT.BPUN off the SD card
      .TAPE_BYTE_REQ(TAPE_BYTE_REQ),
      .TAPE_BYTE_VALID(s_tape_byte_valid),
      .TAPE_BYTE_DATA(s_tape_byte_data),
      .TAPE_REWIND(TAPE_REWIND),

      .DMA_REQ(1'b0),
      .DMA_WR(1'b0),
      .DMA_ADDR(24'd0),
      .DMA_WDATA(16'd0),
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
      .SDISK_DONE(1'b0),
      .SDISK_ERR(1'b0),
      .SDBUF_ADDR(10'd0),
      .SDBUF_WDATA(16'd0),
      .SDBUF_WE(1'b0),
      .SDBUF_RDATA(SDBUF_RDATA),

      // Debug / status
      .LED(s_cpu_led[6:0]),
      .RUN_n(s_run),
      .CSA_12_0(CSA_12_0),
      .PIL(s_pil_3_0),
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
      .DEBUG_FIDBO_15_0(s_debug_fidbo),
      .DEBUG_IREQ_15_0_N(s_ireq_15_0_n),
      .XMIC_DBG_15_0(s_xmic_dbg),

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
      .DBG_MEMW(s_dbg_memw),

      // nd_storage device port -> MEM_RAM_49_SDRAM's upper-half region
      .stor_clk  (clk_stor),
      .stor_rst_n(rst_stor_n),
      .mem_start (s_mem_start),
      .mem_we    (s_mem_we),
      .mem_addr  (s_mem_addr),
      .mem_wdata (s_mem_wdata),
      .mem_rdata (s_mem_rdata),
      .mem_busy  (s_mem_busy),
      .mem_done  (s_mem_done)
  );

endmodule
