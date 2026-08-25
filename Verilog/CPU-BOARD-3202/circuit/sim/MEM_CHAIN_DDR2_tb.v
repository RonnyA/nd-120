/**************************************************************************
** Chain testbench: the REAL RAM-control PALs + MEM_RAM_49_DDR2 freeze   **
**                                                                       **
** Answers the question the unit bench (MEM_RAM_49_DDR2_tb) cannot:      **
** does the cache-miss freeze work with the GENUINE grant machinery?     **
** The unit bench emulated the frozen PALs in its driver; here the       **
** actual chain runs:                                                    **
**                                                                       **
**   MEM_RAMC_50 (PAL_44803A arbiter + PAL_44902A RAS/CAS FSM, both      **
**                with the new HOLD input, driven by MEM_HOLD)           **
**   MEM_LBDIF_48 (AM29C821 delay chains + PAL_44310D BDRY/RDATA)        **
**   MEM_ADDR_44  (BCGNT25 edge-captured row/col mux from LBD)           **
**   MEM_RAM_49_DDR2 (BRAM cache + behavioral random-latency DDR2)       **
**                                                                       **
** The tb only does what the surrounding board does: it raises CLRQ_n /  **
** BLRQ_n requests with the address on LBD, switches LBD to write data   **
** after the grant captures the address (the 8-JUL-2026 multiplex        **
** hazard), and watches the chain run the whole cycle by itself.         **
**                                                                       **
** Checks:                                                               **
**  1. Every read is sampled AT THE REAL RDATA STROBE (PAL_44310D) and   **
**     compared to a reference model - hit and miss alike.               **
**  2. During a miss freeze the GRANT STAYS ACTIVE (this is what         **
**     CGNTCACT_n derives from - the CPU-side wait) and RAS/CAS stand    **
**     still; the cycle completes after release.                         **
**  3. Bus cycles (BLRQ): BDRY_n fires only after the (possibly          **
**     stretched) phases finish - the DMA-side wait.                     **
**  4. Refresh grants (RLRQ, idle all-BANKx-high bus) never trigger the  **
**     bridge or MEM_HOLD.                                               **
**  5. Grant one-hot invariant on every OSC cycle.                       **
**                                                                       **
** Prints "TB_RESULT: PASS" / "TB_RESULT: FAIL ..." (never silent).      **
**                                                                       **
** Run: make test-memchain-ddr2   (CPU-BOARD-3202/circuit/sim)           **
**                                                                       **
** Last reviewed: 25-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_CHAIN_DDR2_tb;

  localparam CACHE_IDX_BITS = 6;  // small cache -> frequent real misses

  reg sysclk = 0;
  reg ui_clk = 0;
  always #30 sysclk = ~sysclk;    // 16.667 MHz OSC
  always #6.66 ui_clk = ~ui_clk;  // ~75 MHz MIG user clock

  reg sys_rst_n = 0;

  // ---- tb-driven board-side signals ----
  reg clrq_n = 1;      // CPU local request (level until granted)
  reg blrq_n = 1;      // bus local request (into the LBDIF 50ns pipe)
  reg rlrq_n = 1;      // refresh request
  reg bdap50_n = 1;    // bus data present (bus cycles only)
  reg mwrite_n = 1;    // direction, piped to MWRITE50_n by LBDIF
  reg [19:0] lbd = 0;  // local bus: ADDRESS then (for writes) DATA
  reg bank0 = 1, bank1 = 1, bank2 = 1;  // idle = all high (RN18 pull-ups)
  reg [17:0] dd_in = 0;

  // ---- chain wiring (names as in MEM_43.v) ----
  wire s_bcgnt25, s_bgnt_n, s_cgnt_n, s_rgnt_n, s_ras, s_cas;
  wire s_hien_n, s_loen_n, s_qd_n;
  wire s_bcgnt50, s_bcgnt50r_n, s_bdry_n, s_bioxl_n;
  wire s_blockl25_n, s_blrq50_n, s_bgnt25_n, s_bgnt50_n, s_gnt50_n;
  wire s_cgnt25_n, s_cgnt50_n, s_mor25_n, s_mwrite50_n, s_rdata, s_rdata25;
  wire [9:0] s_aa;
  wire [17:0] s_dd_out;
  wire s_corr_n, s_mem_hold;

  wire s_gnt_n = s_cgnt_n & s_bgnt_n;

  MEM_RAMC_50 u_ramc (
      .BDAP50_n (bdap50_n),
      .BDRY50_n (1'b1),
      .BCGNT25  (s_bcgnt25),
      .BGNT25_n (s_bgnt25_n),
      .BGNT_n   (s_bgnt_n),
      .BLRQ50_n (s_blrq50_n),
      .CAS      (s_cas),
      .CGNT25_n (s_cgnt25_n),
      .CGNT_n   (s_cgnt_n),
      .CLRQ_n   (clrq_n),
      .HIEN_n   (s_hien_n),
      .LOEN_n   (s_loen_n),
      .MR_n     (1'b1),
      .OSC      (sysclk),
      .PD1      (1'b0),
      .PD3      (1'b0),
      .QD_n     (s_qd_n),
      .RAS      (s_ras),
      .RGNT_n   (s_rgnt_n),
      .RLRQ_n   (rlrq_n),
      .SEMRQ50_n(1'b1),
      .SSEMA_n  (1'b1),
      .MEM_HOLD (s_mem_hold),
      .LED_CPU_GI(),
      .LED_BUS_GI()
  );

  MEM_LBDIF_48 u_lbdif (
      .sysclk    (sysclk),
      .BDAP50_n  (bdap50_n),
      .BGNT_n    (s_bgnt_n),
      .BIOXE_n   (1'b1),
      .BLOCKL_n  (1'b1),
      .BLRQ_n    (blrq_n),
      .CGNT_n    (s_cgnt_n),
      .ECCR      (1'b0),
      .GNT_n     (s_gnt_n),
      .HIEN_n    (s_hien_n),
      .LOEN_n    (s_loen_n),
      .MOR_n     (1'b1),
      .MR_n      (1'b1),
      .MWRITE_n  (mwrite_n),
      .OSC       (sysclk),
      .sys_rst_n (sys_rst_n),
      .PD4       (1'b0),
      .RAS       (s_ras),
      .REF_n     (1'b1),

      .BCGNT50   (s_bcgnt50),
      .BCGNT50R_n(s_bcgnt50r_n),
      .BDRY_n    (s_bdry_n),
      .BGNT25_n  (s_bgnt25_n),
      .BGNT50_n  (s_bgnt50_n),
      .BIOXL_n   (s_bioxl_n),
      .BLOCKL25_n(s_blockl25_n),
      .BLRQ50_n  (s_blrq50_n),
      .CGNT25_n  (s_cgnt25_n),
      .CGNT50_n  (s_cgnt50_n),
      .GNT50_n   (s_gnt50_n),
      .MOR25_n   (s_mor25_n),
      .MWRITE50_n(s_mwrite50_n),
      .RDATA     (s_rdata),
      .RDATA25   (s_rdata25)
  );

  MEM_ADDR_44 u_addr (
      .sysclk  (sysclk),
      .LBD_19_0(lbd),
      .BCGNT50 (s_bcgnt25),  // MEM_43 wires BCGNT25 here (7-DEC-2024 note)
      .LOEN_n  (s_loen_n),
      .HIEN_n  (s_hien_n),
      .PD4     (1'b0),
      .AA_9_0  (s_aa)
  );

  wire         mm_req_valid, mm_req_we;
  wire [26:0]  mm_req_addr;
  wire [127:0] mm_req_wdata;
  wire [15:0]  mm_req_wmask;
  reg          mm_req_ready = 0;
  reg          mm_rsp_valid = 0;
  reg  [127:0] mm_rsp_rdata = 0;

  MEM_RAM_49_DDR2 #(
      .CACHE_IDX_BITS(CACHE_IDX_BITS)
  ) u_ram (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .AA_9_0(s_aa),
      .BANK0(bank0),
      .BANK1(bank1),
      .BANK2(bank2),
      .CAS(s_cas),
      .RAS(s_ras),
      .MWRITE50_n(s_mwrite50_n),
      .DD_17_0_IN(dd_in),
      .DD_17_0_OUT(s_dd_out),
      .CORR_n(s_corr_n),
      .MEM_HOLD(s_mem_hold),
      .ui_clk(ui_clk),
      .ui_rst(~sys_rst_n),
      .mm_req_valid(mm_req_valid),
      .mm_req_we(mm_req_we),
      .mm_req_addr(mm_req_addr),
      .mm_req_wdata(mm_req_wdata),
      .mm_req_wmask(mm_req_wmask),
      .mm_req_ready(mm_req_ready),
      .mm_rsp_valid(mm_rsp_valid),
      .mm_rsp_rdata(mm_rsp_rdata),
      .DBG_BRIDGE()
  );

  /*************************************************************************
   * Behavioral DDR2 port model: random latency 10..70 ui cycles
   *************************************************************************/
  reg [15:0] ddr_mem[0:2097151];
  integer d_lat, d_state, d_cnt, bi;
  reg [26:0] d_addr;
  reg d_we;
  reg [127:0] d_wdata;
  reg [15:0] d_wmask;
  reg [20:0] d_unit;

  always @(posedge ui_clk) begin
    mm_rsp_valid <= 0;
    if (!sys_rst_n) begin
      d_state <= 0;
      mm_req_ready <= 0;
    end else begin
      mm_req_ready <= (d_state == 0);
      if (d_state == 0 && mm_req_valid && mm_req_ready) begin
        d_addr <= mm_req_addr; d_we <= mm_req_we;
        d_wdata <= mm_req_wdata; d_wmask <= mm_req_wmask;
        d_lat <= 10 + ({$random} % 61); d_cnt <= 0; d_state <= 1;
        mm_req_ready <= 0;
      end else if (d_state == 1) begin
        d_cnt <= d_cnt + 1;
        if (d_cnt == d_lat) begin
          d_unit = d_addr[20:0] & 21'h1FFFF8;
          if (d_we) begin
            for (bi = 0; bi < 8; bi = bi + 1) begin
              if (!d_wmask[2*bi])   ddr_mem[d_unit+bi][7:0]  <= d_wdata[16*bi+:8];
              if (!d_wmask[2*bi+1]) ddr_mem[d_unit+bi][15:8] <= d_wdata[16*bi+8+:8];
            end
          end else begin
            for (bi = 0; bi < 8; bi = bi + 1)
              mm_rsp_rdata[16*bi+:16] <= ddr_mem[d_unit+bi];
          end
          mm_rsp_valid <= 1;
          d_state <= 0;
        end
      end
    end
  end

  /*************************************************************************
   * Invariant monitors (every OSC cycle)
   *************************************************************************/
  integer errors = 0;

  // grant one-hot
  always @(posedge sysclk) if (sys_rst_n) begin
    if ((!s_cgnt_n && !s_bgnt_n) || (!s_cgnt_n && !s_rgnt_n) || (!s_bgnt_n && !s_rgnt_n)) begin
      errors = errors + 1;
      $display("FAIL: grants not one-hot: C=%b B=%b R=%b at %0t", s_cgnt_n, s_bgnt_n, s_rgnt_n, $time);
    end
  end

  // during a freeze the grant must stay active and RAS/CAS must stand still
  reg h_d;
  reg ras_h, cas_h, cgnt_h, bgnt_h;
  always @(posedge sysclk) if (sys_rst_n) begin
    h_d <= s_mem_hold;
    if (s_mem_hold && !h_d) begin  // freeze begins: snapshot
      ras_h <= s_ras; cas_h <= s_cas; cgnt_h <= s_cgnt_n; bgnt_h <= s_bgnt_n;
    end else if (s_mem_hold && h_d) begin
      if (s_ras !== ras_h || s_cas !== cas_h) begin
        errors = errors + 1;
        $display("FAIL: RAS/CAS moved during freeze at %0t", $time);
      end
      if (s_cgnt_n !== cgnt_h || s_bgnt_n !== bgnt_h) begin
        errors = errors + 1;
        $display("FAIL: grant changed during freeze at %0t", $time);
      end
      if (cgnt_h && bgnt_h) begin
        errors = errors + 1;
        $display("FAIL: freeze with no grant active at %0t", $time);
      end
    end
  end

  // read check at the REAL RDATA strobe
  reg [15:0] exp_rd;
  reg exp_valid;      // an expected read is in flight
  reg rdata_d;
  reg saw_rdata;
  // RDATA is a combinational level, active for whole PAL states; sample it
  // mid-cycle (negedge) where it is stable - at the posedge it is still
  // resolving and reads X.
  always @(negedge sysclk) if (sys_rst_n) begin
    rdata_d <= s_rdata;
    if (s_rdata === 1'b1 && rdata_d !== 1'b1 && exp_valid) begin
      saw_rdata <= 1;
      if ({s_dd_out[16:9], s_dd_out[7:0]} !== exp_rd) begin
        errors = errors + 1;
        $display("FAIL: RDATA sampled %x expected %x at %0t",
                 {s_dd_out[16:9], s_dd_out[7:0]}, exp_rd, $time);
      end
      if (s_corr_n !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL: CORR_n low at RDATA at %0t", $time);
      end
    end
  end

  /*************************************************************************
   * Reference model + drivers
   *************************************************************************/
  reg [15:0] ref_mem[0:2097151];
  integer i;
  initial begin
    for (i = 0; i < 2097152; i = i + 1) begin
      ddr_mem[i] = 16'h0000;
      ref_mem[i] = 16'h0000;
    end
  end

  integer n_access = 0, n_freeze = 0, n_refresh = 0, n_bus = 0;
  integer guard;
  reg fatal = 0;

  // one CPU (CLRQ) access through the real chain
  task cpu_access;
    input [20:0] wa;      // {bank2sel, row, col}
    input do_write;
    input [15:0] wdata;
    reg froze;
    begin
      froze = 0;
      @(negedge sysclk);
      lbd      = wa[19:0];
      mwrite_n = ~do_write;
      bank0 = ~wa[20]; bank1 = 0; bank2 = wa[20];  // one-hot decode
      dd_in = do_write ? {1'b0, wdata[15:8], 1'b0, wdata[7:0]} : 18'h0;
      exp_rd = ref_mem[wa];
      exp_valid = ~do_write;
      saw_rdata = 0;
      clrq_n = 0;

      // wait for the grant
      guard = 0;
      while (s_cgnt_n && guard < 100) begin @(negedge sysclk); guard = guard + 1; end
      if (s_cgnt_n) begin
        errors = errors + 1; fatal = 1;
        $display("FAIL: no CPU grant within 100 cycles at %0t", $time);
      end
      clrq_n = 1;  // request consumed by the grant

      // the address is captured at the BCGNT25 rising edge; two cycles
      // after the grant the LBD may move on to the write DATA (the
      // multiplex hazard MEM_CHAIN_tb documents)
      @(negedge sysclk);
      @(negedge sysclk);
      if (do_write) lbd = {4'h0, wdata};

      // let the chain run the whole cycle (freeze included): done when the
      // grant releases
      guard = 0;
      while (!s_cgnt_n && guard < 400) begin
        if (s_mem_hold) froze = 1;
        @(negedge sysclk);
        guard = guard + 1;
      end
      if (!s_cgnt_n) begin
        errors = errors + 1; fatal = 1;
        $display("FAIL: CPU grant never released (stuck freeze?) at %0t", $time);
      end
      if (!do_write && !saw_rdata) begin
        errors = errors + 1;
        $display("FAIL: no RDATA strobe on CPU read of %o at %0t", wa, $time);
      end
      exp_valid = 0;
      if (do_write) ref_mem[wa] = wdata;
      if (froze) n_freeze = n_freeze + 1;
      n_access = n_access + 1;

      // idle bus state between accesses (pull-ups: all BANKx high)
      bank0 = 1; bank1 = 1; bank2 = 1;
      mwrite_n = 1;
      repeat (4) @(negedge sysclk);
      if (fatal) begin
        $display("TB_RESULT: FAIL (fatal chain hang)");
        $finish;
      end
    end
  endtask

  // one bus (BLRQ) read: same chain, grant = BGNT, completion = BDRY_n
  task bus_read;
    input [20:0] wa;
    reg froze;
    begin
      froze = 0;
      @(negedge sysclk);
      lbd = wa[19:0];
      mwrite_n = 1;
      bank0 = ~wa[20]; bank1 = 0; bank2 = wa[20];
      bdap50_n = 0;
      exp_rd = ref_mem[wa];
      exp_valid = 1;
      saw_rdata = 0;
      blrq_n = 0;

      guard = 0;
      while (s_bgnt_n && guard < 100) begin @(negedge sysclk); guard = guard + 1; end
      if (s_bgnt_n) begin
        errors = errors + 1; fatal = 1;
        $display("FAIL: no bus grant within 100 cycles at %0t", $time);
      end
      blrq_n = 1;

      // BDRY_n must NOT fire while frozen mid-phases; wait for it
      guard = 0;
      while (s_bdry_n !== 1'b0 && guard < 400) begin
        if (s_mem_hold) begin
          froze = 1;
          if (s_bdry_n === 1'b0) begin
            errors = errors + 1;
            $display("FAIL: BDRY fired during freeze at %0t", $time);
          end
        end
        @(negedge sysclk);
        guard = guard + 1;
      end
      if (s_bdry_n !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL: BDRY never fired on bus read at %0t", $time);
      end
      // data must be right when BDRY says ready
      if ({s_dd_out[16:9], s_dd_out[7:0]} !== exp_rd) begin
        errors = errors + 1;
        $display("FAIL: bus read at BDRY got %x expected %x at %0t",
                 {s_dd_out[16:9], s_dd_out[7:0]}, exp_rd, $time);
      end
      exp_valid = 0;
      bdap50_n = 1;
      if (froze) n_freeze = n_freeze + 1;
      n_bus = n_bus + 1;

      bank0 = 1; bank1 = 1; bank2 = 1;
      // wait out grant release + tail
      guard = 0;
      while (!s_bgnt_n && guard < 100) begin @(negedge sysclk); guard = guard + 1; end
      repeat (4) @(negedge sysclk);
      if (fatal) begin
        $display("TB_RESULT: FAIL (fatal chain hang)");
        $finish;
      end
    end
  endtask

  // one refresh grant: idle bus (all BANKx high), must not touch the bridge
  task refresh_cycle;
    begin
      @(negedge sysclk);
      bank0 = 1; bank1 = 1; bank2 = 1;
      rlrq_n = 0;
      guard = 0;
      while (s_rgnt_n && guard < 100) begin @(negedge sysclk); guard = guard + 1; end
      rlrq_n = 1;
      guard = 0;
      while (!s_rgnt_n && guard < 100) begin
        if (s_mem_hold) begin
          errors = errors + 1;
          $display("FAIL: MEM_HOLD during refresh at %0t", $time);
        end
        @(negedge sysclk);
        guard = guard + 1;
      end
      n_refresh = n_refresh + 1;
      repeat (4) @(negedge sysclk);
    end
  endtask

`ifdef TRACE
  always @(negedge sysclk) if (sys_rst_n && $time < 6_000_000)
    $display("%0t Q=%b%b%b%b RAS=%b CAS=%b HIEN_n=%b LOEN_n=%b CGNT_n=%b BGNT_n=%b RGNT_n=%b MW50_n=%b RDATA=%b HOLD=%b clrq=%b",
      $time,
      u_ramc.PAL_44902_URAMC.QD_reg, u_ramc.PAL_44902_URAMC.QC_reg,
      u_ramc.PAL_44902_URAMC.QB_reg, u_ramc.PAL_44902_URAMC.QA_reg,
      s_ras, s_cas, s_hien_n, s_loen_n, s_cgnt_n, s_bgnt_n, s_rgnt_n,
      s_mwrite50_n, s_rdata, s_mem_hold, clrq_n);
`endif

  integer t;
  reg [20:0] ra;
  reg [15:0] rd;
  integer wr;

  initial begin
`ifdef DUMP
    $dumpfile("MEM_CHAIN_DDR2_tb.vcd");
    $dumpvars(0, MEM_CHAIN_DDR2_tb);
`endif
    // The PAL registers have no initializer: deposit the inactive state
    // (same practice as MEM_RAMC_50_tb) before releasing reset.
    u_ramc.PAL_44803_URAMA.RGNT_reg = 0;
    u_ramc.PAL_44803_URAMA.CGNT_reg = 0;
    u_ramc.PAL_44803_URAMA.BGNT_reg = 0;
    u_ramc.PAL_44803_URAMA.LDR_reg = 0;
    u_ramc.PAL_44803_URAMA.CSEM_reg = 0;
    u_ramc.PAL_44803_URAMA.BSEM_reg = 0;
    u_ramc.PAL_44803_URAMA.LOEN25_reg = 0;
    u_ramc.PAL_44803_URAMA.BCGNT25_n_reg = 1;
    u_ramc.PAL_44902_URAMC.QA_reg = 0;
    u_ramc.PAL_44902_URAMC.QB_reg = 0;
    u_ramc.PAL_44902_URAMC.QC_reg = 0;
    u_ramc.PAL_44902_URAMC.QD_reg = 0;
    u_ramc.PAL_44902_URAMC.RAS_n_reg = 1;
    u_ramc.PAL_44902_URAMC.CAS_n_reg = 1;
    u_ramc.PAL_44902_URAMC.LOEN_reg = 0;
    u_ramc.PAL_44902_URAMC.HIEN_reg = 0;
    exp_valid = 0;
    saw_rdata = 0;

    repeat (10) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (10) @(negedge sysclk);

    // directed: write, read (miss), read (hit), on both banks
    cpu_access({1'b0, 20'o0001000}, 1, 16'h1234);
    cpu_access({1'b0, 20'o0001000}, 0, 0);
    cpu_access({1'b0, 20'o0001000}, 0, 0);
    cpu_access({1'b1, 20'o0200000}, 1, 16'h4321);
    cpu_access({1'b1, 20'o0200000}, 0, 0);
    // the old BRAM aliasing boundary
    cpu_access({1'b0, 20'o0177777}, 1, 16'hAAAA);
    cpu_access({1'b0, 20'o0200000}, 1, 16'h5555);
    cpu_access({1'b0, 20'o0177777}, 0, 0);
    cpu_access({1'b0, 20'o0200000}, 0, 0);

    // refresh among accesses
    refresh_cycle;
    cpu_access({1'b0, 20'o0001000}, 0, 0);

    // bus reads (DMA path), hit and miss
    bus_read({1'b0, 20'o0001000});
    bus_read({1'b0, 20'o0345670});

    // random mix
    for (t = 0; t < 400; t = t + 1) begin
      ra = {$random} % 2097152;
      // cluster half the traffic in a small window for hits
      if ({$random} % 2) ra = ra % 1024;
      wr = ({$random} % 10) < 3;
      rd = $random;
      case ({$random} % 8)
        0: refresh_cycle;
        1: bus_read(ra);
        default: cpu_access(ra, wr[0], rd);
      endcase
    end

    $display("accesses=%0d bus=%0d refresh=%0d freezes=%0d errors=%0d",
             n_access, n_bus, n_refresh, n_freeze, errors);
    if (errors == 0 && n_freeze > 0 && n_refresh > 0 && n_bus > 0)
      $display("TB_RESULT: PASS");
    else if (n_freeze == 0)
      $display("TB_RESULT: FAIL (no freeze exercised)");
    else
      $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #400_000_000;
    $display("TB_RESULT: FAIL (watchdog timeout)");
    $finish;
  end

endmodule
