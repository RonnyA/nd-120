/***************************************************************************************************
** ND120 - PAGE-TABLE STALE READ -> WRONG TRAP VECTOR                                             **
**                                                                                                **
** THE POINT: wire the REAL page-table status RAM to the REAL trap-vector generator and show that  **
** the synchronous BRAM read hands the trap logic STALE page-table status, so an UNMAPPED page      **
** dispatches as vector 3 (ring-down) instead of vector 1 (page fault). This is the ERRFATAL that   **
** halts SINTRAN III, measured on the Tang Nano 20K 17-AUG-2026:                                    **
**                                                                                                **
**   TVEC=3 RING-DOWN  PCR=2(ring2)  pt15_9=000  WPM=0 RPM=0 FPM=0                                  **
**                                                                                                **
** and a ring-down is IMPOSSIBLE on that input - RD1/RD2/RD3 all require FPM, which is 0.           **
**                                                                                                **
** WHAT IS AND IS NOT AT FAULT (both established before this bench was written):                   **
**   * CGA_TRAP_TVGEN's logic is CORRECT - proved exhaustively over all 524288 input combinations   **
**     in both build modes (CGA_TRAP_TVGEN_exhaustive_tb.v). No wiring error, no LEV1/LEV2 error.   **
**   * The level-1 vector flip-flops are CORRECT - they latch on TCLK exactly as drawn.            **
**   * The DATA is late. Shared/support/TMM2018D_25.v models an ASYNC SRAM with a SYNCHRONOUS BRAM  **
**     read, and its own comment says so: it "serves data one clock stale when the address changes  **
**     just before the consuming edge".                                                             **
**                                                                                                 **
** CHIP UNDER TEST: CHIP_24G, the page-table STATUS bank high byte. Per CPU_MMU_PT_29.v:93-104 its  **
** D_OUT drives s_pt_15_0_out[15:8], so D_OUT[7:1] IS PT bits 15..9 = IPT_15_9, which is what the   **
** trap generator decodes (WPM=15 RPM=14 FPM=13 WIP=12 PGU=11 ring=10:9).                          **
**                                                                                                 **
** HOW TO RUN BOTH WAYS:                                                                            **
**   iverilog -g2012 ... PT_stale_read_tvec_tb.v                    -> sync read  (today's build)   **
**   iverilog -g2012 -DTMM_ASYNC_READ ... PT_stale_read_tvec_tb.v   -> async read (the real chip)   **
**                                                                                                 **
** EXPECTED: sync read FAILS loudly (TVEC=3 where 1 is required). Async read PASSES. That is the    **
** whole experiment - it decides whether the async read is the actual cure.                        **
**                                                                                                 **
** Written: 17-AUG-2026                                                                            **
***************************************************************************************************/
`timescale 1ns / 1ps

module PT_stale_read_tvec_tb;

  // sysclk clocks the RAM; TCLK clocks the trap-vector capture. Four sysclks
  // per TCLK, so the "address changes just before the consuming edge" case can
  // actually be expressed.
  reg sysclk = 0;
  always #1 sysclk = ~sysclk;
  reg TCLK = 0;
  reg TCLK_EN = 0;

  reg sys_rst_n = 0;

  // ---- the page-table status RAM (CHIP_24G equivalent) ----
  reg  [10:0] pt_addr;
  reg         cs_n, w_n;
  reg  [7:0]  wdata;
  wire [7:0]  pt_dout;

  TMM2018D_25 #(.INSTANCE_NAME("CHIP_24G")) CHIP_24G (
      .clk(sysclk), .reset_n(sys_rst_n),
      .ADDRESS(pt_addr), .CS_n(cs_n), .D(wdata), .D_OUT(pt_dout),
      .OE_n(1'b0), .W_n(w_n)
  );

  // D_OUT[7:1] = PT bits 15..9 = IPT_15_9 (index 6 = PT15 ... index 0 = PT9)
  wire [6:0] ipt = pt_dout[7:1];

  // ---- the trap-vector generator ----
  reg       vacc, ifetch, iind, iwrite, intrq, pan, poni;
  reg       dstop_n, ftrap_n, vtrap_n;
  reg [1:0] ipcr;

  wire       PVIOL, RESTR;
  wire [3:0] TVEC_3_0;

  CGA_TRAP_TVGEN DUT (
      .sysclk(sysclk), .TCLK_EN(TCLK_EN),
      .DSTOPN(dstop_n), .FTRAPN(ftrap_n),
      .IFETCH(ifetch), .IFETCHN(~ifetch), .IIND(iind), .IINDN(~iind),
      .INTRQ(intrq), .IPCR_1_0(ipcr), .IPCR_1_0_N(~ipcr),
      .IPT_15_9(ipt), .IPT_15_9_N(~ipt), .IWRITE(iwrite), .IWRITEN(~iwrite),
      .PAN(pan), .PONI(poni), .TCLK(TCLK), .VACC(vacc), .VTRAPN(vtrap_n),
      .PVIOL(PVIOL), .RESTR(RESTR), .TVEC_3_0(TVEC_3_0)
  );

  // Page-table entries, as the machine actually holds them (measured in the
  // Verilator PT capture): a MAPPED page is 0o162xxx -> high byte 8'b11100100
  // (WPM RPM FPM set, WIP/PGU clear, ring 2). An UNMAPPED page is all zero.
  localparam [10:0] ADDR_MAPPED   = 11'o0377;
  localparam [10:0] ADDR_UNMAPPED = 11'o0400;
  localparam [7:0]  ENTRY_MAPPED  = 8'b11100100;   // PT[15:8] of 0o162000
  localparam [7:0]  ENTRY_EMPTY   = 8'b00000000;   // page not present

  integer errors = 0, checks = 0;
  integer lead;

  // Report per lead time rather than pass/fail only: the LEAD AT WHICH IT
  // STARTS WORKING is the number the fix has to deliver.
  task check_lead(input integer ld, input [3:0] want);
    begin
      checks = checks + 1;
      if (TVEC_3_0 !== want) begin
        errors = errors + 1;
        $display("*** FAIL lead=%0d sysclk: TVEC=%0d, REQUIRED %0d  ipt=%b (WPM=%b RPM=%b FPM=%b)  <- STALE",
                 ld, TVEC_3_0, want, ipt, ipt[6], ipt[5], ipt[4]);
      end else begin
        $display("ok   lead=%0d sysclk: TVEC=%0d (page fault seen correctly)", ld, TVEC_3_0);
      end
    end
  endtask

  task ram_write(input [10:0] a, input [7:0] d);
    begin
      @(negedge sysclk); pt_addr = a; wdata = d; cs_n = 0; w_n = 0;
      @(negedge sysclk); cs_n = 1; w_n = 1;
    end
  endtask

  task tclk_cycle;
    begin
      // one TCLK period = 4 sysclks, rising in the middle
      @(negedge sysclk); TCLK_EN = 1;
      @(negedge sysclk); TCLK = 1; TCLK_EN = 0;
      @(negedge sysclk);
      @(negedge sysclk); TCLK = 0;
    end
  endtask

  task check(input [255:0] name, input [3:0] want);
    begin
      checks = checks + 1;
      if (TVEC_3_0 !== want) begin
        errors = errors + 1;
        $display("*** FAIL %0s: TVEC=%0d, REQUIRED %0d   ipt=%b (WPM=%b RPM=%b FPM=%b)",
                 name, TVEC_3_0, want, ipt, ipt[6], ipt[5], ipt[4]);
        if (TVEC_3_0 == 3)
          $display("    TVEC 3 is RING-DOWN and is IMPOSSIBLE here: RD1/RD2/RD3 all require FPM, FPM=%b.", ipt[4]);
        $display("    STALE PAGE-TABLE READ: the RAM served the PREVIOUS address's entry.");
      end else begin
        $display("ok   %0s: TVEC=%0d", name, TVEC_3_0);
      end
    end
  endtask

  initial begin
`ifdef TMM_ASYNC_READ
    $display("PT_stale_read_tvec_tb: TMM2018D ASYNC read (the real chip)");
`else
    $display("PT_stale_read_tvec_tb: TMM2018D SYNC read (today's build)");
`endif
    cs_n = 1; w_n = 1; pt_addr = 0; wdata = 0;
    vacc=0; ifetch=1; iind=0; iwrite=0; intrq=0; pan=1; poni=1;
    dstop_n=1; ftrap_n=1; vtrap_n=1; ipcr=2'b10;   // ring 2, as measured
    repeat (4) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (4) @(negedge sysclk);

    // Load a mapped entry; leave ADDR_UNMAPPED never written (all zero).
    ram_write(ADDR_MAPPED, ENTRY_MAPPED);
    ram_write(ADDR_UNMAPPED, ENTRY_EMPTY);

    // ---- 1. control: read the MAPPED page, settled. No trap expected. ----
    @(negedge sysclk); pt_addr = ADDR_MAPPED; cs_n = 0; w_n = 1; vacc = 1;
    tclk_cycle; tclk_cycle;
    #1 check("mapped page, settled -> no page fault", 4'd4);  // PGU: page-used bit clear

    // ---- 2. THE CHARACTERISATION: how EARLY must the page-table address
    //         change, relative to the TCLK edge that captures the vector, for
    //         the trap generator to see the real page status?
    //
    //         The page is NOT present, so the only correct vector is 1. Sweep
    //         the address-change lead time in sysclks and report which lead
    //         each RAM read style needs. This is what decides the fix: if async
    //         needs 0 and sync needs 1, the RAM latency is the whole problem;
    //         if BOTH need a lead, the address itself arrives too late and
    //         read-ahead is required no matter what the RAM does.
    for (lead = 0; lead <= 3; lead = lead + 1) begin
      // settle back on the mapped page so the stale value is the mapped one
      @(negedge sysclk); pt_addr = ADDR_MAPPED;
      tclk_cycle; tclk_cycle;

      // present the unmapped address `lead` sysclks before the TCLK rise
      @(negedge sysclk); TCLK_EN = 1;
      if (lead >= 3) pt_addr = ADDR_UNMAPPED;
      @(negedge sysclk);
      if (lead == 2) pt_addr = ADDR_UNMAPPED;
      @(negedge sysclk);
      if (lead == 1) pt_addr = ADDR_UNMAPPED;
      @(negedge sysclk);
      if (lead == 0) pt_addr = ADDR_UNMAPPED;
      TCLK = 1; TCLK_EN = 0;
      @(negedge sysclk);
      #1 check_lead(lead, 4'd1);
      @(negedge sysclk); TCLK = 0;
    end

    $display("");
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else             $display("TB_RESULT: FAIL (%0d checks, %0d errors)", checks, errors);
    $finish;
  end

endmodule
