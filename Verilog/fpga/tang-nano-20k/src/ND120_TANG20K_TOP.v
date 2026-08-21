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
`ifdef TANG_WD_TRACE_DUMP
  wire [19:0] wd_trace_rec;
  wire        wd_trace_we;
  wire        wd_trace_done;
`endif
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
  // Ring depth. The free-running capture modes want every one of 512 clocks;
  // the WD IOX trace stores one entry per REGISTER ACCESS, and the sequence
  // it has to catch is about 33 accesses long. At 20 bits Gowin puts this in
  // distributed RAM (SSRAM), not block RAM, so depth is paid for in LOGIC
  // cells: 512 deep overflowed the part by 114 cells (20850 of 20736) with
  // the Winchester build in, and 128 deep STILL overflowed it by 9 (20745)
  // once the Winchester and the floppy were both in - measured 09-AUG-2026.
  //
  // 64 is still comfortably enough for the sequence that matters. The
  // captured File System Investigator trace (nd100x, ND100X_WD_DEBUG=1) is
  // 72 accesses END TO END for a whole LIST-FILE-NAMES, and the trigger - a
  // read of +0 - first fires at access 17, so a 64-deep ring holds every
  // access from power-on up to and including the first failing transfer.
  //
  // 10-AUG-2026: 64 was NOT enough for the '20500&' mass load. That sequence
  // is hundreds of accesses long, so a 64-deep ring wrapped and returned only
  // its tail - every transfer in it completed with status 060010 and a
  // correctly advanced memory address register, which says nothing about
  // where the guest decided the load had failed. 256 buys the whole window,
  // and the cells for it come from building this diagnostic with TANG_FLOPPY
  // off: the mass load never touches the floppy, and its ND_FLOPPY_DMA plus
  // its own DMA master are the largest block that can be removed without
  // changing what the Winchester path does.
`ifdef TANG_WD_TRACE_DUMP
  localparam CAP_AW = 8;
`else
  localparam CAP_AW = 9;
`endif
  localparam [CAP_AW-1:0] CAP_LAST = {CAP_AW{1'b1}};

  reg [19:0] cap_mem[0:(1<<CAP_AW)-1];   // 20 bits: rw + register + data
  reg [CAP_AW-1:0] cap_wptr;
  reg [8:0] cap_post;
  reg [28:0] arm_cnt;  // 30-JUL: widened 25->29 bits (arm ~40s, was ~2.5s) -
                       // the WCS microcode load keeps CSA STATIC longer than
                       // 2.5s, so the hang trigger fired mid-load and the
                       // dumper seized the TX pin before the console ever
                       // spoke (SRAM-load-no-boot mystery, plan Issue I).
  reg cap_armed, cap_trig, cap_done;
  reg wdec_d2;
  reg [3:0] pil_prev;
  // TRAPN is ACTIVE LOW and is asserted only for the dispatch microcycle, so
  // its previous value is what makes a one-record-per-trap strobe possible.
  // Sampling at the PIL->14 transition instead is TOO LATE: measured
  // 11-AUG-2026, all 255 records came back TVEC=15 TRAPN=1, the idle state.
  reg       trapn_prev;

  // Sticky "has this machine EVER executed the page-in microcode" flags.
  // CLPT = 0o5705 unmaps a victim page, ENPT = 0o5706 maps the new one in.
  // Set once and never cleared, so a single ring dump answers the question
  // even though the ring itself only covers a few microseconds.
  reg       seen_enpt, seen_clpt;
  always @(posedge clk2x or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      seen_enpt <= 1'b0;
      seen_clpt <= 1'b0;
    end else begin
      if (CSA_12_0 == 13'o5706) seen_enpt <= 1'b1;
      if (CSA_12_0 == 13'o5705) seen_clpt <= 1'b1;
    end
  end
  reg [4:0] estate_prev;
  reg [7:0] rxraw_prev;
  reg [31:0] lba_prev;
  reg [15:0] wdata_prev;
  reg [12:0] csa_prev;
  reg [21:0] csa_stable;   // clk2x cycles the microcode CSA has been unchanged
`ifdef TANG_PF_CAPTURE
  // ---------------------------------------------------------------------------
  // FIRST PAGE-FAULT FREEZE REGISTER readout (21-AUG-2026).
  //
  // ND120_PF_CAPTURE (inside CGA) froze the trap-logic inputs at the TCLK edge
  // that latched a page-fault vector. It emits that 56-bit word through
  // XMIC_DBG_15_0 as four 14-bit slices, slice index in [15:14]:
  //
  //   slice 0 -> frozen[13:0]   PT_15_9[6:0], VACC, LA[5:0]
  //   slice 1 -> frozen[27:14]  LA[13:6]
  //   slice 2 -> frozen[41:28]  TVEC, PVIOL, RESTR, ptram CS_n/OE_n,
  //                             captured(bit 2), strobes_valid(bit 3), cycle[9:0]
  //   slice 3 -> frozen[55:42]  cycle[23:10]
  //
  // Full layout and the decode are in
  //   Verilog/fpga/tang-nano-20k/PLAN-pagefault-root-cause.md
  //
  // NOTE: while this define is set, XMIC_DBG_15_0 carries the capture readout,
  // NOT the microsequencer address-advance probe. Do not decode it as the latter.
  //
  // Trigger: the frozen word's `captured` flag is bit 30, which lands in slice 2
  // at bit 2. Latch it when that slice goes past, so the dump fires once the
  // evidence actually exists rather than on a rotation of an empty register.
  // Slice index is THREE bits ([15:13]) and the payload is 13 bits. The
  // `captured` flag is frozen[30], and slice 2 carries frozen[38:26], so it
  // arrives at payload bit 30-26 = 4.
  //
  // Measured 21-AUG-2026: this trigger was left decoding the OLD 2-bit index
  // and bit 2 after the word was widened. `[15:14] == 2'd2` then matched
  // slices 4 AND 5, bit 2 of those payloads is arbitrary, so pf_seen set at
  // power-up, the dumper took the TX pin immediately and streamed zeros. The
  // layout has THREE consumers - this file, ND120_PF_CAPTURE.v and
  // pf_capture_run.py - and all three must move together.
  reg  pf_seen = 1'b0;
  reg [1:0] pf_s5_cnt = 2'd0;
  reg [2:0] pf_slice_prev;
  always @(posedge clk_cpu) begin
    pf_slice_prev <= s_xmic_dbg[15:13];
    // Trigger on c_next_valid (frozen[71]), NOT on `captured` (frozen[30]).
    // c_next_valid means the DISCRIMINATOR sample - PT one capturing edge
    // AFTER the fault - has actually been taken. Triggering on `captured`
    // dumped the ring before that sample existed and the readout came back
    // "NOT TAKEN", losing the one field that separates a real page fault from
    // a late-arriving page-table entry. frozen[71] is slice 5 payload bit 6.
    // Fire only after a COMPLETE post-capture rotation is in the ring.
    //
    // Measured 21-AUG-2026: triggering on the first sighting of slice 5 ended
    // the dump immediately after it, so the rotation never wrapped back to
    // slice 0 and the ring held only the STALE pre-capture slice 0 (501 copies
    // of 0x0000). Slice 0 carries c_pt and c_vacc, so both came back as zeros
    // that were never measured - which is what produced the impossible
    // "PVIOL=1 with VACC=0" word.
    //
    // Counting two sightings of slice 5 guarantees slices 0..5 have all been
    // emitted from the frozen, immutable word before the dump starts.
    // Trigger on the LAST slice (7), not on a captured-only field. The readout
    // now rotates either after a capture OR after a census timeout, so slice 7
    // appearing twice means a complete word is in the ring in BOTH cases -
    // including the case where nothing was captured and only the census has
    // anything to say.
    if ((s_xmic_dbg[15:13] == 3'd7) &&
        (s_xmic_dbg[15:13] != pf_slice_prev)) begin
      if (pf_s5_cnt == 2'd1) pf_seen <= 1'b1;
      else                   pf_s5_cnt <= pf_s5_cnt + 1'b1;
    end
  end

  wire [19:0] s_cap_src   = {4'd0, s_xmic_dbg[15:0]};
  // One sample per slice: the slice rotates far slower than clk_cpu, so a
  // change-detect records each slice exactly once instead of thousands of times.
  wire        s_cap_stb   = (s_xmic_dbg[15:13] != pf_slice_prev);
  wire        s_cap_arm   = cap_armed;
  /* verilator lint_off UNUSEDSIGNAL */
  wire        s_hang      = &csa_stable;   // deliberately NOT used - see below
  /* verilator lint_on UNUSEDSIGNAL */
  // TRIGGER ON THE CAPTURED FAULT ONLY. Do NOT or-in s_hang.
  //
  // Measured 21-AUG-2026: with `pf_seen || s_hang` the board emitted 7940
  // NUL bytes and nothing else. s_hang is "CSA unchanged for 2^22 cycles",
  // which is exactly what the WCS microcode load looks like, so the dump
  // triggered during the load, dump_fin latched permanently, and the dumper
  // held the TX pin forever. The console never spoke, the boot command was
  // never accepted, and no page fault could ever happen. The comment on
  // arm_cnt above warns about precisely this.
  //
  // This experiment NEEDS the console alive: a human types '20500&' and the
  // fault arrives 25+ minutes later. Only the real capture may take the pin.
  wire        s_cap_event = pf_seen;
  // All six slices must be recorded AFTER the trigger, and the rotation is
  // slow, so keep collecting well past the event.
  localparam [8:0] CAP_POST = 9'd64;
`elsif TANG_GRANT_CAPTURE
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
  wire [19:0] s_cap_src   = {4'd0, 3'b0, CSA_12_0[12:0]};
  wire        s_cap_stb   = 1'b1;
  wire        s_cap_arm   = cap_armed;
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
  wire [19:0] s_cap_src   = {4'd0, s_xmic_dbg[15:11], CSA_12_0[10:0]};
  wire        s_cap_stb   = 1'b1;
  wire        s_cap_arm   = cap_armed;
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
`elsif TANG_WD_TRACE_DUMP
  // One ring entry per COMPLETED IOX access to the Winchester, not per clock:
  // s_cap_stb gates the ring write, so 128 entries are 128 register accesses
  // and the pointer wraps, always holding the MOST RECENT 128.
  //
  // TRIGGER ON THE END OF THE OPERATION, NOT ON A REGISTER. The first version
  // triggered on a read of +0 - but that is the diagnostic's very FIRST
  // access (op 1 of the captured oracle trace is `RD +0 -> 0`), so it fired
  // immediately, at the "Sector" prompt, and dumped a ring that was still
  // almost entirely empty. The interesting accesses are the LAST ones, so
  // wait until the card has been quiet for about a second instead: DISC-TEMA
  // stops touching it once the transfer is reported.
  // ND_WD_TRACE_DBUF: capture what the ADAPTER FORWARDS into the controller's
  // sector buffer, instead of the IOX register traffic.
  //
  // WHY, 09-AUG-2026. The silicon zero-read is now narrowed to exactly two
  // components: the c_buf_we -> dbuf_we forwarding window inside
  // nd_storage_disc_adapter (S_CWAIT / s_in_win), or the s_buffer BSRAM read
  // inside ND_WINCHESTER. Both pass in simulation, so only a probe on real
  // hardware can separate them, and black-box A/B has been exhausted:
  // the fault is independent of the file (BOOT.TAP reads fine through the
  // TAPE client and returns zeros through the WINCHESTER client), of the
  // cache, of the clock domain and of the LBA.
  //
  // This records every word the adapter writes into the buffer, tagged 4'hE.
  //   ring full of E<data> with REAL values -> the adapter forwards fine,
  //     so the fault is the controller's BSRAM read path.
  //   ring EMPTY, or full of E0000 -> the adapter never forwards, so the
  //     fault is the window in the adapter.
  // Either way it names the culprit in one run.
  // Fill-path diagnostic seam from nd_storage (see nd_storage_engine.v).
  wire [4:0] DBG_STATE;
  wire [31:0] DBG_LBA;
  wire [15:0] DBG_WDATA;
  wire [15:0] DBG_RDATA;
  wire [15:0] DBG_BUFW;
  wire DBG_BUFWE;
  wire [15:0] DBG_FSEC;
  wire       DBG_RX_STB;
  wire [7:0] DBG_RX_RAW, DBG_RX_BYTE;
  wire       DBG_PAST_EOF;
  wire [2:0] DBG_GRANT;

`ifdef ND_WD_TRACE_FILL
  // Capture CARD BYTES arriving during a fill, raw AND after the end-of-file
  // gate, tagged with the granted client:
  //   tag  = {1'b1, grant[2:0]}
  //   data = {raw byte from the card, byte actually written to staging}
  // raw != 0 while gated == 0 -> the s_past_eof gate is zeroing real data.
  // raw == 0                  -> the card itself delivered nothing.
  //
  // BIT 19 IS A WRITTEN-MARKER AND MUST STAY 1. It was 1'b0 until 09-AUG-2026,
  // which made the probe undecidable: the TAPE client is grant 0, so a genuine
  // record of a zero card byte encoded as 00000 - exactly what an unwritten
  // cap_mem entry reads back as (cap_mem has no reset). Two silicon runs came
  // back 64/64 zeros and neither could be interpreted. With bit 19 set, any
  // record that is still 00000 was never written, full stop.
  wire [19:0] s_cap_src   = {1'b1, DBG_GRANT, DBG_RX_RAW, DBG_RX_BYTE};
`elsif ND_WD_TRACE_REGION
  // Capture what the SDRAM REGION actually returns on a read completion.
  //
  // The dbuf probe (ND_WD_TRACE_DBUF) showed the adapter forwarding 63 words
  // that were ALL ZERO, which cleared both the adapter window and the
  // controller BSRAM and pushed the fault back inside nd_storage: the words
  // are already zero when the client buffer is written, i.e. s_bridge_rd_data
  // is zero, i.e. the REGION READ returned nothing. This probe tests that
  // directly at the SDRAM device port, which is the last place the data can
  // still be checked from outside nd_storage.
  //
  //   ring full of D<data> with REAL values -> SDRAM returns the data and it
  //     is lost between the region read and the client write (the bridge).
  //   ring full of D0000 -> the region itself holds zeros, so the staging ->
  //     region WRITE never landed, and the fault is on the write side.
  wire [19:0] s_cap_src   = {4'hD, s_mem_rdata[15:0]};
`elsif ND_WD_TRACE_DBUF
  wire [19:0] s_cap_src   = {4'hE, WDBUF_WDATA};
`elsif ND_WD_TRACE_ESTATE
  // Every CHANGE of the storage engine's state, tagged F, with the granted
  // client. Answers "which states does a Winchester read actually visit"
  // directly, instead of inferring it from a byte strobe that has now come
  // back empty three times for three different reasons.
  wire [19:0] s_cap_src   = {4'hF, 8'd0, DBG_GRANT, DBG_STATE};
`elsif ND_WD_TRACE_PIL
  // Every CHANGE of the CPU's priority interrupt level, tagged B. Added
  // 09-AUG-2026 because the Winchester-register trace had gone as far as it
  // can: the File System Investigator's device-open sequence matches the
  // nd100x oracle access for access, and then LI-FI issues no IOX at all and
  // reports the status it cached at open. That decision is taken CPU-side, so
  // the question is no longer what the controller returned but whether the
  // machine ever runs the level-11 handler. Recording only transitions keeps
  // the 64-entry ring useful - PIL sampled every clk2x would fill it in
  // microseconds and show nothing but the idle level.
  wire [19:0] s_cap_src   = {4'hB, 12'd0, s_pil_3_0};
`elsif ND_WD_TRACE_TVEC
  // TRAP DISPATCH. Word = {tag, TVEC[3:0], TRAPN, PIL[3:0]}, so each record
  // says WHICH internal interrupt was dispatched and at what level. TVEC is
  // the ND-100 internal interrupt code: 1 = monitor call, 2 = memory
  // protection violation, 3 = page fault.
  //
  // The reference number, measured 11-AUG-2026: in an nd100x boot of the SAME
  // WD0.IMG, the 65536-instruction window following the block-3643 read holds
  // EIGHT monitor calls (IID bit 1) and NO page fault and NO protection
  // violation. So a ring full of code 2 or code 3 here IS the divergence,
  // and a ring full of code 1 says the machine is re-taking monitor calls.
`elsif ND_WD_TRACE_CSATRAP
  // The microcode addresses LEADING INTO a trap. Sampling CSA at the trap
  // instant is useless - on a trap the micro-address bus IS the trap vector
  // (docs/SIGNALS.md: MA muxes WCA/W/TVEC/CD on EWCA/MAP_n/TRAP_n), so it
  // just reads back the vector, which is what the previous build measured.
  // Free-run CSA instead and let the TRAP be the TRIGGER, so the ring holds
  // the ~256 clk2x cycles (~19 us) of microcode before the fault.
  wire [19:0] s_cap_src   = {4'd0, 3'b0, CSA_12_0[12:0]};
`elsif ND_WD_TRACE_TVEC_CSA
  // CSA, not PIL, in the low bits: the PAGING test-3 analysis
  // (docs/HANDOFF-paging-test3-pof-dispatch-rootcause.md) pins its D2
  // defect to the overlapped COMM,AREAD dispatch word at CSA 04420. If
  // the SINTRAN hang traps at the same microcode address, it is the same
  // defect and not merely the same symptom.
  // CSA dropped: it was measured to equal TVEC in every one of 255 records, so
  // it carried nothing. CGA.v now packs the ring evidence into the low bits
  // instead - see the repack note there.
  //   [19:9] CSA[10:0]  [8:5] TVEC  [4] TRAPN  [3] VACC  [2] PGF  [1] TCLK  [0] 0
  //
  // The FULL low CSA is carried, not the top bits: the handlers that identify
  // the vector actually used sit at LOW addresses (vector 1 -> 00020 = 16,
  // vector 3 -> 00040 = 32), so CSA[10:0] is what distinguishes them and
  // CSA[10:7] would read 0 for both. PT_15_9 is dropped to make room - it is
  // already known to be 000 at the fault from the previous capture.
  // DEMAND-PAGING PROBE (17-AUG-2026). The oracle shows that servicing a page
  // fault ALWAYS runs the same microcode sequence, and 126 of 126 faults in a
  // healthy boot end in a disc read:
  //     PF -> CLPT (unmap victim) -> seek/read -> IDENT level 11
  //        -> ENPT (map the page in) -> resume
  // Our machine produces faults with NO disc read, so the question is whether
  // it ever reaches those routines at all. From the microcode listing
  // (/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc):
  //     CLPT = CSA 0o5705,  ENPT = CSA 0o5706,  CLPT1 = 0o4071, CLPT3 = 0o4115
  //
  // NOTE 0o5705 = 3013 decimal - that needs TWELVE bits. The previous record
  // carried only CSA[10:0], which would have truncated bit 11 and shown 0o1705,
  // i.e. "never reached" for a routine that was in fact running. Carry the full
  // 13-bit CSA here.
  //
  // The sticky flags matter more than the live CSA: a 256-record window is only
  // microseconds, so it may simply miss a routine that does execute. Once set,
  // seen_enpt/seen_clpt stay set, so ANY dump answers "has this machine EVER
  // mapped a page in".
  //   [19:16] CSA[3:0]  [15:4] LA_21_10  [3] VACC  [2] PGF  [1] TRAPN  [0] TCLK
  //
  // PGS reconstruction: PGS is the last LA_21_10 loaded while VACC was high
  // (CGA_IDBCTL_PGSREG, drawing page 98 - self-holding scan FFs, TE = VACC).
  // SINTRAN masks PGS & 001777 to get PT<<6|VPN and keys its serviceable/fatal
  // decision on it. Oracle known-good at the first serviced fault: 040762
  // (PT=7, VPN 0o62). L-reg 072627 implies ours reported 000760.
  // Capturing LA + VACC free-running around the fault shows both the value AND
  // whether it is overwritten before SINTRAN reads it.
  wire [19:0] s_cap_src   = {CSA_12_0[3:0], s_xmic_dbg[15:0]};      // [0] PTM (STS bit 0)
`elsif ND_WD_TRACE_FSEC
  // The mount's first_sector for the granted client, low 16 bits, strobed on
  // entry to C_SEC_GO so it is captured at the moment a fetch is launched.
  // Compare against the ND_WD_TRACE_LBA capture of the SAME run configuration:
  // for block 0 they must be equal. Client 6 / WD0.IMG resolved to 64672 on
  // 10-AUG-2026; if first_sector is also 64672 the resolve is right and the
  // card really holds zeros there, and if it differs the resolve is wrong for
  // large files. Neither answer needs the card's layout.
  wire [19:0] s_cap_src   = {1'b1, DBG_GRANT, DBG_FSEC};
`elsif ND_WD_TRACE_BUFW
  // The word the engine hands to the granted client's buffer, strobed by that
  // buffer's own write enable. THE LAST UNMEASURED SIGNAL in the read chain.
  // Everything either side is now proven on silicon: the region reads back
  // real file text (10-AUG-2026), and the adapter forwards words that are
  // zero. If this is non-zero, the loss is inside nd_storage_disc_adapter -
  // which is the Winchester's adapter and NOT the tape's, matching a fault
  // that follows the client. If this is zero, the loss is in the engine's
  // clk_cpu client front-end between the bridge and the buffer.
  //
  // The strobe is safe here where the clk_stor ones were not: clk_cpu is HALF
  // of clk2x, so this write enable is two clk2x cycles wide.
  wire [19:0] s_cap_src   = {1'b1, DBG_GRANT, DBG_BUFW};
`elsif ND_WD_TRACE_RDATA
  // What the SDRAM region RETURNS on read-back, tagged with the client, taken
  // at R_PUSH_HI where mem_rdata is valid. The write side is now PROVEN good:
  // 10-AUG-2026, 63 of 63 region writes for client 6 were non-zero and carried
  // readable ASCII straight off the card. So staging is filled and the region
  // is written with real data; if it reads back zero, the fault is the region
  // read or the SDRAM device port, not the storage engine's fetch path.
  wire [19:0] s_cap_src   = {1'b1, DBG_GRANT, DBG_RDATA};
`elsif ND_WD_TRACE_WDATA
  // The word the engine writes into the SDRAM region, tagged with the client.
  // The resolve is now PROVEN correct (10-AUG-2026: pointed at BOOT.TAP,
  // client 6 fetched sectors 21920-21923 - four consecutive sectors, block 0
  // of the file, in the same card region the tape client reads). So the card
  // is read from the right place and the region still ends up zero. This
  // splits the last span: non-zero here means staging was filled and the
  // fault is in the region write or read-back; zero here means the received
  // bytes never reached staging.
  wire [19:0] s_cap_src   = {1'b1, DBG_GRANT, DBG_WDATA};
`elsif ND_WD_TRACE_LBA
  // The resolved card sector of each fetch, low 16 bits, tagged with the
  // granted client. Bit 19 is 1 so an unwritten ring slot (00000) stays
  // distinguishable from a genuine record.
  //
  // Why this value: the card fetch demonstrably RUNS for client 6 (four
  // C_SEC_WAIT per block in the engine-state trace) and completes with no
  // error, yet the region ends up zero. A read of the WRONG sector produces
  // exactly that - it lands in blank card space, sdw_err never asserts, and
  // every word is zero. BOOT.TAP reads correctly as client 0 and returns
  // zeros as client 6, same file and same card, so the fault follows the
  // CLIENT, and the sector is the per-client value.
  wire [19:0] s_cap_src   = {1'b1, DBG_GRANT, DBG_LBA[15:0]};
`else
  wire [19:0] s_cap_src   = wd_trace_rec;
`endif

  // RISING EDGE ONLY, and that is not a detail. This capture block is clocked
  // by clk2x while ND_WINCHESTER runs on clk_cpu, which is clk2x/2, so its
  // one-cycle trace_we pulse is TWO clk2x cycles
  // wide and the ring recorded every single event TWICE - halving the usable
  // depth from 64 entries to 32. Measured on silicon 09-AUG-2026: the whole
  // dump came back in exact pairs, including the interrupt-edge record, and
  // an edge-detected pulse cannot legitimately fire twice. Confined to this
  // trace mode: the other capture modes tie s_cap_stb high and sample every
  // clk2x cycle on purpose.
  reg         wd_trace_we_q;
  always @(posedge clk2x) begin
    if (!sys_rst_n) wd_trace_we_q <= 1'b0;
    else            wd_trace_we_q <= wd_trace_we;
  end
`ifdef ND_WD_TRACE_FILL
  // LEVEL change, not the strobe. DBG_RX_STB is a ONE-CYCLE pulse in the
  // clk_stor domain (27 MHz) and this ring samples on clk2x (13.5 MHz), so a
  // single-cycle pulse is simply not observable here - it can fall entirely
  // between two sampling edges. That, and not "the card delivered nothing",
  // is why three separate fill captures came back with an empty ring on
  // 09-AUG-2026. DBG_RX_RAW is held between bytes, so a change-detect on the
  // value samples reliably at half rate. It will MISS repeats of the same
  // byte value; that is fine, because the question is only whether the bytes
  // arriving from the card are non-zero.
  wire        s_cap_stb   = (DBG_RX_RAW != rxraw_prev);
`elsif ND_WD_TRACE_REGION
  wire        s_cap_stb   = s_mem_done && !s_mem_we;   // read completions only
`elsif ND_WD_TRACE_DBUF
  wire        s_cap_stb   = WDBUF_WE;
`elsif ND_WD_TRACE_ESTATE
  // The per-WORD serve loop is NOT recorded. R_WAIT(4) -> R_PUSH_HI(5) ->
  // R_PUSH_LO(6) repeats once per word, 512 times per block, and on 09-AUG-2026
  // it filled all 64 ring slots by itself - the capture showed nothing but the
  // tail of the serve loop and evicted every state that says HOW the block was
  // obtained (E_GRANT, C_SEC_GO/C_SEC_WAIT for a card read, W_MEM for the
  // staging->region write). Those are the states in question, so the loop is
  // filtered out exactly like the foreign IOX records were.
  // There are TWO per-word loops and both must go. The serve loop is
  // R_WAIT(4)/R_PUSH_HI(5)/R_PUSH_LO(6); the staging->region write loop is
  // W_MEM(10)/W_MEM_WAIT(11). Each runs once per word, 512 times per block.
  // Filtering only the first (09-AUG-2026) simply handed the whole ring to the
  // second. What is left is low-rate and is the actual question: E_GRANT,
  // C_SEC_GO/C_SEC_WAIT (four per fill - a real card read), C_ALLOC, R_MEM,
  // E_DONE.
  wire        s_cap_stb   = (DBG_STATE != estate_prev)
                            && (DBG_STATE != 5'd4)
                            && (DBG_STATE != 5'd5)
                            && (DBG_STATE != 5'd6)
                            && (DBG_STATE != 5'd10)
                            && (DBG_STATE != 5'd11);
`elsif ND_WD_TRACE_FSEC
  wire        s_cap_stb   = (DBG_STATE == 5'd14) && (estate_prev != 5'd14);
`elsif ND_WD_TRACE_BUFW
  wire        s_cap_stb   = DBG_BUFWE;
`elsif ND_WD_TRACE_RDATA
  wire        s_cap_stb   = (DBG_STATE == 5'd5) && (estate_prev != 5'd5);
`elsif ND_WD_TRACE_WDATA
  // Strobe on ENTRY TO W_MEM(10), not on a change of the data.
  //
  // A change-detector cannot answer this question, and 10-AUG-2026 proved it
  // the hard way: `DBG_WDATA != wdata_prev` produces an empty ring both when
  // the probe is broken AND when the value is constantly zero - which is the
  // exact hypothesis under test. Same undecidable design as the first fill
  // probe, made twice.
  //
  // W_MEM entry is a level transition the ESTATE trace already PROVED happens
  // (once per word, 512 per block). So records carrying 0000 mean the region
  // really is being written with zeros, and NO records at all means the probe
  // itself is dead. The two are finally distinguishable.
  wire        s_cap_stb   = (DBG_STATE == 5'd10) && (estate_prev != 5'd10);
`elsif ND_WD_TRACE_LBA
  wire        s_cap_stb   = (DBG_LBA != lba_prev);
`elsif ND_WD_TRACE_PIL
  wire        s_cap_stb   = (s_pil_3_0 != pil_prev);
`elsif ND_WD_TRACE_TVEC
  // One record per DISPATCHED trap: strobe on entry to level 14, the
  // internal-interrupt level, not on every clock. A machine re-taking the
  // same trap forever therefore fills the ring with that trap's code.
`elsif ND_WD_TRACE_CSATRAP
  wire        s_cap_stb   = 1'b1;
`elsif ND_WD_TRACE_TVEC_CSA
  // Falling edge of TRAPN = a trap is being DISPATCHED, which is the only
  // moment TVEC is valid. One record per trap - but ONLY a REAL one.
  //
  // TVEC 15 is excluded (measured 17-AUG-2026). A first capture came back with
  // all 256 slots holding the identical record AF00F = TVEC 15, CSA 0o17: the
  // TRAPN edge fires constantly with vector 15, so the ring filled with those
  // and evicted every real trap. This is not a new discovery - the repo's own
  // trap probe already treats it as noise and prints nothing for it
  // (DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP.v:117 tests
  // `s_tvec_3_0_out != 4'd15` on exactly this edge).
  //
  // With vector 15 filtered out, the OPCOM idle loop after the ERRFATAL halt
  // no longer consumes slots, so the card-idle trigger 45 s later still leaves
  // the ring holding the last 256 REAL traps - the ones taken on the way into
  // the fault.
  // FREE-RUN (17-AUG-2026). One record per trap has no time axis, and that is
  // now the limiting factor: the vector bits are TCLK-registered while TRAPN is
  // combinational (CGA_TRAP_BRKDET.v has no clock port), so a sample taken at
  // the TRAPN edge may read the vector BEFORE the capturing edge. That cannot
  // be told apart from a genuinely wrong dispatch without consecutive clocks.
  //
  // Free-running at clk2x makes each record one clock, so the sequence shows
  // TCLK rising, the vector settling, and - critically - which microcode
  // address the sequencer actually RUNS afterwards. Vector 3 jumps to 00040,
  // vector 1 jumps to 00020, so the handler entered names the vector that was
  // really used.
  wire        s_cap_stb   = 1'b1;
`else
  // FOREIGN ACCESSES ARE NOT RECORDED. They were excluded from the TRIGGER on
  // 09-AUG-2026 but still consumed ring slots, and with a 64-entry ring that
  // loses the evidence outright: the tape reader at IOX 400/402/403 polls
  // continuously, so a captured File System Investigator session came back
  // with 59 of 63 slots holding tape polls and only the last four Winchester
  // accesses surviving. The failing read had been evicted by the very traffic
  // this filter now drops. Foreign records still reach wd_trace_foreign for
  // the trigger logic below - only the ring write is gated. The tag test is
  // spelled out rather than reusing wd_trace_foreign, which is declared below
  // this point; module-level nets may legally be used before declaration but
  // there is no reason to lean on that through the Gowin front end.
`ifdef ND_WD_TRACE_OPSONLY
  // ONE OPERATION PER THREE RECORDS: the block address (+3), the word count
  // (+7), and the control word (+5) that actually ACTIVATES the card (bit 2).
  // The four device-clear words each operation writes to +5 carry bit 2 = 0
  // and are dropped, as are the status polls, the IDENT, the interrupt and
  // the address readback. 256 entries therefore hold 85 operations, which
  // reaches back past the block-0 retry loop the block-only capture found at
  // operation 121 of 158 - the full trace reaches back only thirteen.
  //
  // Tags: 4'hB = write to +3, 4'hF = write to +7, 4'hD = write to +5.
  wire        s_cap_stb   = wd_trace_we && !wd_trace_we_q
                            && ((wd_trace_rec[19:16] == 4'hB)
                             || (wd_trace_rec[19:16] == 4'hF)
                             || ((wd_trace_rec[19:16] == 4'hD)
                                 && wd_trace_rec[2]));
`elsif ND_WD_TRACE_BLKONLY
  // BLOCK ADDRESSES ONLY - one record per disc operation instead of the
  // nineteen a full operation costs (block address, two address halves, word
  // count, control word, status polls, IDENT, interrupt, address readback,
  // four device clears). The whole '20500&' SINTRAN load writes 251 block
  // addresses end to end, measured from the nd100x trace of the same WD0.IMG,
  // so a 256-entry ring holds EVERY disc address the boot asks for, from the
  // first to the last. The unfiltered trace cannot do that: at nineteen
  // records per operation a 256-entry ring reaches back only thirteen
  // operations, which is the last five percent of the load.
  //
  // Tag 4'hB is a WRITE (bit 19) to register 3 (bits 18:16), the block
  // address register.
  wire        s_cap_stb   = wd_trace_we && !wd_trace_we_q
                            && (wd_trace_rec[19:16] == 4'hB);
`else
  wire        s_cap_stb   = wd_trace_we && !wd_trace_we_q
                            && (wd_trace_rec[19:16] != 4'hC);
`endif
`endif

  // THE ARM DELAY DOES NOT APPLY HERE. cap_armed only goes high ~40 s after
  // reset, which exists so the CPU-debug capture modes do not trigger during
  // boot. For this trace it silently DISCARDS events: a mass-load hang three
  // seconds after reset trips the idle trigger at ~6 s, long before arming,
  // and the result is no dump at all - indistinguishable from "the card was
  // never touched". That ambiguity produced a wrong conclusion once already.
  wire        s_cap_arm = 1'b1;

  // COUNT ONLY REAL CARD ACCESSES. ND_WINCHESTER.v's trace_we bundles FIVE
  // kinds of record into one strobe (see its trace_rec assignment): register
  // write, register read, IDENT answer, interrupt edge, and - top nibble
  // 4'hC - a FOREIGN IOX, i.e. somebody ELSE'S device being addressed while
  // the Winchester just watches the bus go by. Feeding all five into the
  // trigger made the probe fire on traffic that has nothing to do with this
  // card: measured 09-AUG-2026 on silicon, a plain '400$' tape load filled
  // the entire 64-entry ring with C0100 / C0102 / C0103 - octal 400, 402,
  // 403, the PAPER TAPE READER's own registers - and tripped the trigger
  // before the Winchester had been touched at all. Twice that dump was read
  // as "the ring came back empty"; it never was, it was full of the tape.
  //
  // So the idle timer and the access count now advance ONLY on records that
  // are really this card's. Foreign records are still RECORDED - seeing the
  // surrounding IOX traffic is the whole point of having them - they simply
  // do not arm anything.
  wire wd_trace_foreign = (wd_trace_rec[19:16] == 4'hC);
  // The IOX one-shot, kept SEPARATE from s_cap_stb: when ND_WD_TRACE_DBUF
  // makes the ring capture buffer writes, the TRIGGER must still key off the
  // card's IOX activity going idle, not off buffer writes.
  wire wd_iox_own       = wd_trace_we && !wd_trace_we_q && !wd_trace_foreign;
  wire wd_trace_own     = wd_iox_own;

  reg [29:0] wd_idle;      // clk2x cycles since the last access to the card
  reg [7:0]  wd_count;     // OWN accesses seen (saturating)
  reg        wd_ran;       // a device OPERATION has completed
  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      wd_idle  <= 30'd0;
      wd_count <= 8'd0;
      wd_ran   <= 1'b0;
    end else begin
      if (wd_trace_done) wd_ran <= 1'b1;
      if (wd_trace_own) begin
        wd_idle <= 30'd0;
        if (!(&wd_count)) wd_count <= wd_count + 1'b1;
      end else if (!(&wd_idle)) begin
        wd_idle <= wd_idle + 1'b1;
      end
    end
  end

  // COMPARE WITH >=, NEVER ==. wd_idle saturates, so an equality test matches
  // for exactly one cycle and is lost if anything gates it that cycle - which
  // is the other half of how the last capture came back empty.
  //
  // Two ways in, because the two failures look different from here:
  //   - a COMPLETED operation then ~1 s of quiet: the DISC-TEMA case, where
  //     the memory-address readback is the last thing to happen;
  //   - at least 4 accesses then ~4 s of quiet with nothing completing: the
  //     mass-load hang. The count requirement stops a lone probe during the
  //     floppy boot from tripping it, which is what made an earlier version
  //     fire early and dump an empty ring.
  // The idle threshold has to exceed the LONGEST gap DISC-TEMA leaves while
  // collecting Disc name / Unit / Cylinder / Surface / Sector / Amount from
  // the operator. Measured: about 15 s with the scripted driver, longer with
  // a human. A 4 s window fired at the "Amount" prompt and dumped only the
  // seven opening probe accesses. 30 s clears it; the mass-load hang is
  // permanent, so any threshold works there.
  //
  // The completion path stays at ~1 s and fires FIRST in every healthy run,
  // so this long window only ever matters when nothing completes at all.
  // 09-AUG-2026: BOTH terms now also require a MINIMUM ACCESS COUNT, because
  // the old thresholds fired during the boot probe and dumped an empty ring -
  // exactly the failure this comment block warned about, just at a different
  // scale. Loading the File System Investigator from tape and getting it to
  // its first Winchester read takes well over the 30 s idle window, so a
  // 2-access boot probe armed the capture long before the traffic of
  // interest existed. The captured File System Investigator sequence
  // (nd100x, ND100X_WD_DEBUG=1) reaches its first completed transfer at
  // access 12 and runs to 72, so 8 and 40 sit clear of a probe and well
  // inside the real run.
  // THRESHOLDS MEASURED, NOT GUESSED. 09-AUG-2026 on silicon: a complete
  // File System Investigator session - load from tape, open DISC-74MB-1
  // unit 0, read the geometry, then LI-FI - produces only FOUR accesses of
  // this card's own (status read, the M7 return-to-zero, the completion
  // interrupt, status read). With the old >=8 requirement the trigger could
  // therefore NEVER fire, and a 180 s idle capture came back with no dump
  // at all - which reads exactly like "the probe is broken" and is why the
  // numbers are now tied to a measurement instead of a guess.
  //
  // The counts exist only to stop a ONE-access probe from arming, so 3 is
  // enough. The second term (no completion at all) drops in proportion.
  // 09-AUG-2026, SECOND correction, measured not guessed: the completion-path
  // idle window was 13_500_000 = ONE SECOND at 13.5 MHz, and that makes an
  // interactive File System Investigator session impossible to capture. The
  // console floor is 0.30 s per character (below 0.20 s OPCOM drops input), so
  // typing "LI-FI" alone takes 1.5 s, and the operator gap between answering
  // "Device unit :" and issuing the command is several seconds more. None of
  // that touches the Winchester, so wd_idle runs free and the capture closes
  // during the DIALOGUE - long before the read it exists to record. Observed
  // exactly that: the ring dumped while LI-FI was still printing, holding only
  // the three opening probe accesses. 45 s clears any scripted dialogue gap
  // and still fires well inside a listen window. Both terms move together so
  // the 30 s term cannot pre-empt the 45 s one.
`ifdef ND_WD_TRACE_CSATRAP
  // Trigger on the trap itself, keeping a few records after it so the ring
  // shows the dispatch as well as the run-up.
  // Gated on the card having gone QUIET first (same 45 s idle the register
  // trace uses). Traps happen constantly during a healthy boot; without the
  // gate the ring would capture the first one and be long gone by the time
  // the machine livelocks.
  wire        s_cap_event = (!s_xmic_dbg[11] && trapn_prev)
                            && (wd_count >= 8'd3)
                            && (wd_idle >= 30'd607_500_000);
  localparam [8:0] CAP_POST = 9'd16;
`elsif ND_WD_TRACE_TVEC_CSA
  // Keep the card-idle trigger; the STROBE above now filters vector 15, which
  // is what makes it work. Triggering on the page fault itself (TVEC == 1) was
  // tried on 17-AUG-2026 and produced ZERO records - the condition never became
  // true in the whole 146 s run up to the ERRFATAL halt, even though SINTRAN
  // then printed "IIC : 000003  Page Fault". That is worth knowing but it is
  // NOT usable as a trigger, and it is NOT yet proof of anything: it means
  // either page faults here are not delivered as microcode trap vector 1, or
  // PGF never asserted. Recording every REAL trap and reading what the machine
  // actually takes settles that without assuming the answer first.
  // Trigger on the PAGE-FAULT dispatch itself: TRAPN falling with PGF live.
  // The card-idle trigger is useless with a free-running strobe - 256 clk2x
  // cycles is a window of microseconds, and the idle trigger only becomes true
  // 45 s AFTER the halt.
  //
  // CAP_POST 200 of 256 puts most of the ring AFTER the trap, which is the
  // whole question: does the sequencer run the vector-1 handler (00020) or the
  // vector-3 handler (00040)? The ~56 records before the trigger still show the
  // vector settling across the TCLK edge.
  // BIT POSITIONS FOLLOW THE CGA REPACK. XMIC_DBG is now the PT/APT record
  //   [15:12] PT  [11:8] APT  [7:4] table used  [3] FETCH_n  [2] PTM
  //   [1] PGF  [0] TRAPN
  // so TRAPN is bit 0 and PGF is bit 1. Every earlier packing put them
  // somewhere else; leaving a stale index here makes the trigger test an
  // address bit and it silently never fires - that cost a build+boot on
  // 17-AUG-2026 and is what scratchpad/preflight_capture.py now checks.
  wire        s_cap_event = (!s_xmic_dbg[0] && trapn_prev) && s_xmic_dbg[1];
  localparam [8:0] CAP_POST = 9'd200;
`else
  wire        s_cap_event = (wd_ran && (wd_count >= 8'd3)
                             && (wd_idle >= 30'd607_500_000))
                         || ((wd_count >= 8'd6) && (wd_idle >= 30'd607_500_000));
  localparam [8:0] CAP_POST = 9'd0;   // the trigger IS the end - nothing after
`endif
`else
  wire [19:0] s_cap_src   = {4'd0, s_dbg_memw};
  wire        s_cap_stb   = 1'b1;
  wire        s_cap_arm   = cap_armed;
  wire        s_cap_event = !wdec_d2 && s_dbg_memw[7];
  localparam [8:0] CAP_POST = 9'd448;
`endif
  always @(posedge clk2x) begin
    if (!sys_rst_n) begin
      cap_wptr <= 0; cap_post <= 0; arm_cnt <= 0;
      cap_armed <= 0; cap_trig <= 0; cap_done <= 0; wdec_d2 <= 0;
      wdec_seen <= 0; write_seen <= 0; pil_prev <= 0; estate_prev <= 0; rxraw_prev <= 0; lba_prev <= 0; wdata_prev <= 0;
      trapn_prev <= 1'b1;
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
      trapn_prev <= s_xmic_dbg[0];   // TRAPN, see the repack note above
      estate_prev <= DBG_STATE;
      rxraw_prev  <= DBG_RX_RAW;
      lba_prev    <= DBG_LBA;
      wdata_prev  <= DBG_WDATA;
      if (cap_armed && s_dbg_memw[7]) wdec_seen <= 1;
      if (cap_armed && s_dbg_memw[6]) write_seen <= 1;
      if (!cap_done) begin
        if (s_cap_stb) begin
          cap_mem[cap_wptr] <= s_cap_src;
          cap_wptr <= cap_wptr + 1'b1;
        end
        if (!cap_trig && s_cap_arm && s_cap_event) begin
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
  reg [CAP_AW-1:0] cap_raddr;
  reg [19:0] cap_rd;
  always @(posedge clk2x) cap_rd <= cap_mem[cap_raddr];

  reg [CAP_AW-1:0] dump_i;
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
          3'd0: d_tx_data <= hexd(cap_rd[19:16]);  // rw + register offset
          3'd1: d_tx_data <= hexd(cap_rd[15:12]);
          3'd2: d_tx_data <= hexd(cap_rd[11:8]);
          3'd3: d_tx_data <= hexd(cap_rd[7:4]);
          3'd4: d_tx_data <= hexd(cap_rd[3:0]);
          3'd5: d_tx_data <= 8'h0D;
          default: d_tx_data <= 8'h0A;
        endcase
        d_tx_valid <= 1;
        if (dump_c == 3'd6) begin
          dump_c <= 0;
          dump_i <= dump_i + 1'b1;
          cap_raddr <= cap_raddr + 1'b1;  // settled long before next char
          if (dump_i == CAP_LAST) begin dump_run <= 0; dump_fin <= 1; end
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
`ifdef TANG_PF_CAPTURE
  // Page-fault freeze readout: once ND120_PF_CAPTURE has frozen a fault the
  // dumper takes the TX pin and streams the ring, which holds the four 14-bit
  // slices of the frozen word. The console is dead afterwards - expected, the
  // machine has already halted in ERRFATAL.
  //
  // WITHOUT this branch the dump never reaches a pin, so the ring is dead
  // logic and synthesis removes everything feeding it - including the capture
  // block itself. Measured 21-AUG-2026: the netlist contained no PF_CAPTURE
  // registers at all and the readout would have streamed constants.
  assign uart_txp = dbg_dumping ? dbg_txd : cpu_txd;
`elsif TANG_WRITE_ANALYZER_DUMP
  assign uart_txp = dbg_dumping ? dbg_txd : cpu_txd;
`elsif TANG_WD_TRACE_DUMP
  // The dump takes the console only after the diagnostic has printed.
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
  // the ND-BUS tape device (INCLUDE_TAPE=1) and nd_storage_devices hangs off
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

  // Storage device select: TANG_FLOPPY adds the floppy (1560&); the tape
  // (400$) is carried in EVERY build - Ronny 06-AUG-2026: the tape driver is
  // small, keep it alongside the floppy. What stays dropped in a floppy build
  // is LONG-FILENAME parsing (SDFAT_NO_LFN, ~1800 LUT), which is why the
  // tape's boot file on the Tang is the 8.3 name BOOT.TAP, not BOOT.BPUN -
  // see the BOOT_NAME override at the nd_storage_devices instantiation.
`ifdef TANG_FLOPPY
  localparam TANG_INC_TAPE   = 1;
  localparam TANG_INC_FLOPPY = 1;
`else
  localparam TANG_INC_TAPE   = 1;
  localparam TANG_INC_FLOPPY = 0;
`endif
  // TANG_SMD (src/tang20k_defines.v) adds the SMD disk at 1540 (SMD0.IMG via
  // nd_storage client 3) on top of whichever base build is selected. It is a
  // separate gate so it can be dropped alone if resources overflow.
`ifdef TANG_SMD
  localparam TANG_INC_SMD    = 1;
`else
  localparam TANG_INC_SMD    = 0;
`endif
  // TANG_WD adds the Winchester at 500 (WD0.IMG via nd_storage client 6)
  // INSTEAD of the SMD - the two are mutually exclusive on BSRAM, which
  // tang20k_defines.v enforces at elaboration.
`ifdef TANG_WD
  localparam TANG_INC_WD     = 1;
 `ifdef TANG_SMD
  // Both disc controllers selected. There is no 47th BSRAM block: each owns a
  // 1024x16 buffer and TANG_SMD alone already sits at 46/46 (see the note on
  // `define TANG_SMD in tang20k_defines.v). Pick one. This deliberately
  // instantiates a module that does not exist, so the build stops with a
  // message that names the problem rather than failing later in place-and-
  // route with an opaque resource error.
  TANG_SMD_AND_TANG_WD_ARE_MUTUALLY_EXCLUSIVE_ONLY_ONE_BSRAM_BUFFER_IS_FREE u_pick_one();
 `endif
`else
  localparam TANG_INC_WD     = 0;
`endif

  nd_storage_devices #(
      .SIMULATE(0),                     // real card: full-length SD init
      .INCLUDE_TAPE(TANG_INC_TAPE),
      .INCLUDE_FLOPPY(TANG_INC_FLOPPY),
      .INCLUDE_SMD(TANG_INC_SMD),
      .INCLUDE_WD(TANG_INC_WD),
      // The Tang boots the tape from BOOT.TAP, not the default BOOT.BPUN:
      // ".BPUN" is a 4-character extension, which FAT can only store via a
      // VFAT long-filename entry, and the floppy/WD builds strip LFN parsing
      // (SDFAT_NO_LFN). An 8.3 name is readable by every build variant.
      .BOOT_NAME("BOOT.TAP"),
      .BOOT_LEN(8'd8)
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
      .FDISK_ERR_CODE (FDISK_ERR_CODE),
      .FDISK_MEDIA_FMT(FDISK_MEDIA_FMT),
      .FDBUF_ADDR     (FDBUF_ADDR),
      .FDBUF_WDATA    (FDBUF_WDATA),
      .FDBUF_WE       (FDBUF_WE),
      .FDBUF_RDATA    (FDBUF_RDATA),

      // SMD disk-image backend seam (client 3 = SMD0.IMG) <-> the core
      .SDISK_START    (SDISK_START),
      .SDISK_REQ      (SDISK_REQ),
      .SDISK_WR       (SDISK_WR),
      .SDISK_BLKADDR1 (SDISK_BLKADDR1),
      .SDISK_BLKADDR2 (SDISK_BLKADDR2),
      .SDISK_UNIT     (SDISK_UNIT),
      .SDISK_WORDCOUNT(SDISK_WORDCOUNT),
      .SDISK_DONE     (SDISK_DONE),
      .SDISK_ERR      (SDISK_ERR),
      .SDISK_ERR_CODE (SDISK_ERR_CODE),
      .SDBUF_ADDR     (SDBUF_ADDR),
      .SDBUF_WDATA    (SDBUF_WDATA),
      .SDBUF_WE       (SDBUF_WE),
      .SDBUF_RDATA    (SDBUF_RDATA),

      // Winchester disk-image backend (client 6 = WD0.IMG)
      .WDISK_START    (WDISK_START),
      .WDISK_REQ      (WDISK_REQ),
      .WDISK_WR       (WDISK_WR),
      .WDISK_BLKADDR1 (WDISK_BLKADDR1),
      .WDISK_BLKADDR2 (WDISK_BLKADDR2),
      .WDISK_UNIT     (WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE     (WDISK_DONE),
      .WDISK_ERR      (WDISK_ERR),
      .WDISK_ERR_CODE (WDISK_ERR_CODE),
      .WDBUF_ADDR     (WDBUF_ADDR),
      .WDBUF_WDATA    (WDBUF_WDATA),
      .WDBUF_WE       (WDBUF_WE),
      .WDBUF_RDATA    (WDBUF_RDATA),

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

      .DBG_STATE   (DBG_STATE),
      .DBG_LBA     (DBG_LBA),
      .DBG_WDATA   (DBG_WDATA),
      .DBG_RDATA   (DBG_RDATA),
      .DBG_BUFW    (DBG_BUFW),
      .DBG_BUFWE   (DBG_BUFWE),
      .DBG_FSEC    (DBG_FSEC),
      .DBG_RX_STB  (DBG_RX_STB),
      .DBG_RX_RAW  (DBG_RX_RAW),
      .DBG_RX_BYTE (DBG_RX_BYTE),
      .DBG_PAST_EOF(DBG_PAST_EOF),
      .DBG_GRANT   (DBG_GRANT),
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

  // led[0]/led[1] repurposed 07-AUG-2026 (Ronny): storage BLOCK activity.
  // A block op lasts microseconds, so each event loads a ~150 ms stretcher
  // (22 bits at 27 MHz) - one flash per block, a solid glow under load.
  // Sources are the device-side backend seams (clk_cpu domain): floppy and
  // Winchester block requests, direction from the WR flag. The old meanings
  // (tape-req-seen / sd-clk-seen) served bring-up and are retired.
  reg [21:0] s_led_rd_stretch, s_led_wr_stretch;
  wire s_blk_rd_ev = (FDISK_REQ & ~FDISK_WR) | (WDISK_REQ & ~WDISK_WR);
  wire s_blk_wr_ev = (FDISK_REQ &  FDISK_WR) | (WDISK_REQ &  WDISK_WR);
  always @(posedge clk_cpu or negedge sys_rst_n)
    if (!sys_rst_n) begin
      s_led_rd_stretch <= 22'd0;
      s_led_wr_stretch <= 22'd0;
    end else begin
      if (s_blk_rd_ev)                 s_led_rd_stretch <= {22{1'b1}};
      else if (|s_led_rd_stretch)      s_led_rd_stretch <= s_led_rd_stretch - 22'd1;
      if (s_blk_wr_ev)                 s_led_wr_stretch <= {22{1'b1}};
      else if (|s_led_wr_stretch)      s_led_wr_stretch <= s_led_wr_stretch - 22'd1;
    end

  assign led[0] = ~|s_led_rd_stretch; // ON = storage BLOCK READ in the last ~150 ms
  assign led[1] = ~|s_led_wr_stretch; // ON = storage BLOCK WRITE in the last ~150 ms
  assign led[2] = ~s_tape_byte_seen;  // ON = a tape byte was actually served
  assign led[3] = ~s_sd_status[0];    // sd_status low bit
  assign led[4] = ~s_sd_status[1];    // sd_status high bit (both lit = OK)
  assign led[5] = clockTicks[24];     // heartbeat ~0.8 Hz (clock alive)

  /* verilator lint_off UNUSEDSIGNAL */
  wire unused_analyzer_leds = &{1'b0, s_dbg_memw, dbg_dumping, wdec_seen,
                                write_seen, s_cpu_led[2], s_tape_req_seen,
                                s_sdclk_seen, 1'b0};
  /* verilator lint_on UNUSEDSIGNAL */

  // Floppy seam (1560&) is WIRED to the SD-FAT stack (FLOPPY1.IMG via the
  // nd_storage floppy adapter inside TAPE_SDFAT_SOURCE). The SMD seam (1540&)
  // is wired the same way (SMD0.IMG via nd_storage_disc_adapter, client 3)
  // when TANG_SMD is defined; otherwise the source ties it idle and the core
  // leaves the device out.
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
  wire [ 3:0] FDISK_ERR_CODE;
  wire [3:0]  FDISK_MEDIA_FMT;
  wire [9:0]  FDBUF_ADDR;
  wire [15:0] FDBUF_WDATA;
  wire        FDBUF_WE;
  wire        SDISK_START, SDISK_REQ, SDISK_WR;
  wire        WDISK_START, WDISK_REQ, WDISK_WR;
  wire [15:0] SDISK_BLKADDR1, SDISK_BLKADDR2;
  wire [2:0]  SDISK_UNIT;
  wire [10:0] SDISK_WORDCOUNT;
  wire [15:0] SDBUF_RDATA;
  wire [15:0] WDISK_BLKADDR1, WDISK_BLKADDR2;
  wire [ 2:0] WDISK_UNIT;
  wire [10:0] WDISK_WORDCOUNT;
  wire        WDISK_DONE, WDISK_ERR;
  wire [ 3:0] WDISK_ERR_CODE;
  wire [ 9:0] WDBUF_ADDR;
  wire [15:0] WDBUF_WDATA;
  wire        WDBUF_WE;
  wire [15:0] WDBUF_RDATA;
  // SMD backend -> core (completion + buffer fill); tied idle by the
  // source's gen_no_smd when TANG_SMD is absent
  wire        SDISK_DONE, SDISK_ERR;
  wire [ 3:0] SDISK_ERR_CODE;
  wire [9:0]  SDBUF_ADDR;
  wire [15:0] SDBUF_WDATA;
  wire        SDBUF_WE;

  /* verilator lint_off UNUSEDSIGNAL */
  // FDISK_*/FDBUF_* and (under TANG_SMD) SDISK_*/SDBUF_* are used; only the
  // external DMA test-client port stays unused in this build.
  wire unused_core_seam = &{1'b0, DMA_RDATA,
                            DMA_ACK, DMA_ERR, DMA_BUSY, 1'b0};
  /* verilator lint_on UNUSEDSIGNAL */

  ND120_CORE #(
      .INCLUDE_TAPE  (TANG_INC_TAPE),
      .INCLUDE_FLOPPY(TANG_INC_FLOPPY),
      .INCLUDE_SMD   (TANG_INC_SMD),
      .INCLUDE_WD    (TANG_INC_WD)
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
      .FDISK_ERR_CODE(FDISK_ERR_CODE),
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
      .SDISK_ERR_CODE(SDISK_ERR_CODE),
      .SDBUF_ADDR(SDBUF_ADDR),
      .SDBUF_WDATA(SDBUF_WDATA),
      .SDBUF_WE(SDBUF_WE),
      .SDBUF_RDATA(SDBUF_RDATA),

      // Winchester disk-image backend (TANG_WD; tied idle otherwise)
      .WDISK_START(WDISK_START),
      .WDISK_REQ(WDISK_REQ),
      .WDISK_WR(WDISK_WR),
      .WDISK_BLKADDR1(WDISK_BLKADDR1),
      .WDISK_BLKADDR2(WDISK_BLKADDR2),
      .WDISK_UNIT(WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE(WDISK_DONE),
      .WDISK_ERR(WDISK_ERR),
      .WDISK_ERR_CODE(WDISK_ERR_CODE),
      .WDBUF_ADDR(WDBUF_ADDR),
      .WDBUF_WDATA(WDBUF_WDATA),
      .WDBUF_WE(WDBUF_WE),
      .WDBUF_RDATA(WDBUF_RDATA),

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
`ifdef TANG_WD_TRACE_DUMP
      ,
      .wd_trace_rec (wd_trace_rec),
      .wd_trace_we  (wd_trace_we),
      .wd_trace_done(wd_trace_done)
`endif
  );

endmodule
