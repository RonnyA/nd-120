/***************************************************************************************************
** ND120 CGA - CGA_TRAP/TVGEN - PAGE-FAULT DISPATCH RACE                                          **
**                                                                                                **
** Reproduces the defect measured on the Tang Nano 20K 17-AUG-2026, where SINTRAN III halts in     **
** ERRFATAL. The trap ring captured TVEC and the page-table status IN THE SAME RECORD:             **
**                                                                                                **
**   TVEC=3 RING-DOWN  PCR=2(ring2)  pt15_9=000  WPM=0 RPM=0 FPM=0 WIP=0 PGU=0                     **
**                                                                                                **
** pt15_9=000 means the entry is EMPTY, so PGF is asserted and the vector must be 1 (page fault).   **
** It read 3. A ring-down is impossible on that input: RD1/RD2/RD3 (CGA_TRAP_TVGEN.v:188-220) all   **
** require FPM, and FPM is 0.                                                                      **
**                                                                                                **
** WHY THE EXISTING GOLDEN BENCH CANNOT SEE IT: CGA_TRAP_TVGEN_tb.v sets its inputs and only then   **
** waits for posedge TCLK, so PGF is always stable BEFORE the capturing edge. It also models the    **
** same registration in its golden, so it agrees with the RTL and passes. The silicon case is the   **
** opposite ordering - the page-table status arrives with/after the edge that latches the vector.   **
**                                                                                                **
** MECHANISM (CGA_TRAP_TVGEN_P2.v): the level-1 vector bits are TCLK-REGISTERED                     **
**   L1V1_FF: d = s_pgf                    q = s_l1v1_n  -> TVEC[1] = ~s_l1v1_n                     **
**   L1V0_FF: d = AND(~PGF, PVIOL|RV)      q = s_l1v0_n  -> TVEC[0] = ~s_l1v0_n                     **
** while the mux select LEV1 is COMBINATIONAL. PGF flips the mux to the level-1 slot at once, but   **
** the registered PGF is still the previous cycle's 0 -> TVEC = 0011 = 3 instead of 0001 = 1.       **
** The identical race was fixed for the LEVEL-2 slot on 27-JUL-2026 in this same file; that fix's   **
** own comment records that level 1 was left alone.                                                **
**                                                                                                **
** TEST 1 (control) - PGF stable across the edge: the vector MUST be 1. This is what the existing   **
**                    bench covers, and it passes today.                                           **
** TEST 2 (the defect) - PGF arriving AT the edge, as it does on silicon: the vector MUST still be  **
**                    1 at the dispatch, because the fault is live. Today it reads 3.              **
**                                                                                                **
** So TB_RESULT: FAIL is the CORRECT result against the unfixed RTL - this bench is written to      **
** demonstrate the defect, and it turns PASS when the level-1 slot is made coherent with its live   **
** select. Do NOT register it in tests/run_all_tests.sh until the fix is accepted.                  **
**                                                                                                **
** Runs in both build modes; the Makefile target runs default and -DFPGA_FF_MODE.                   **
**                                                                                                **
** Written: 17-AUG-2026                                                                            **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_TVGEN_pgfrace_tb;

  reg TCLK = 0;
  always #5 TCLK = ~TCLK;

  // FPGA_FF_MODE capture: sysclk with TCLK_EN aligned to the TCLK rise.
  reg sysclk = 0;
  always #1 sysclk = ~sysclk;
  reg TCLK_EN = 0;

  reg       vacc, ifetch, iind, iwrite, intrq, pan, poni;
  reg       dstop_n, ftrap_n, vtrap_n;
  reg [1:0] ipcr;
  reg [6:0] ipt;

  wire       IFETCH = ifetch, IFETCHN = ~ifetch;
  wire       IIND   = iind,   IINDN   = ~iind;
  wire       IWRITE = iwrite, IWRITEN = ~iwrite;
  wire [1:0] IPCR   = ipcr,   IPCR_N  = ~ipcr;
  wire [6:0] IPT    = ipt,    IPT_N   = ~ipt;

  wire       PVIOL, RESTR;
  wire [3:0] TVEC_3_0;

  CGA_TRAP_TVGEN DUT (
      .sysclk(sysclk), .TCLK_EN(TCLK_EN),
      .DSTOPN(dstop_n), .FTRAPN(ftrap_n),
      .IFETCH(IFETCH), .IFETCHN(IFETCHN), .IIND(IIND), .IINDN(IINDN),
      .INTRQ(intrq), .IPCR_1_0(IPCR), .IPCR_1_0_N(IPCR_N),
      .IPT_15_9(IPT), .IPT_15_9_N(IPT_N), .IWRITE(IWRITE), .IWRITEN(IWRITEN),
      .PAN(pan), .PONI(poni), .TCLK(TCLK), .VACC(vacc), .VTRAPN(vtrap_n),
      .PVIOL(PVIOL), .RESTR(RESTR), .TVEC_3_0(TVEC_3_0)
  );

  // IPT_15_9 index 0 = PT bit 9 ... index 6 = PT bit 15.
  //   WPM=idx6 RPM=idx5 FPM=idx4 WIP=idx3 PGU=idx2 ring={idx1,idx0}
  // MAPPED = the entry the machine actually held before the fault, measured in
  // the Verilator capture: permits 111, ring 2, PGU/WIP clear = 0o162 >> 9.
  localparam [6:0] PT_MAPPED = 7'b1110010;   // WPM RPM FPM set, ring 2
  localparam [6:0] PT_EMPTY  = 7'b0000000;   // the unmapped entry from silicon

  integer errors = 0, checks = 0;

  task setup_fetch;
    begin
      vacc=1; ifetch=1; iind=0; iwrite=0; intrq=0; pan=1; poni=1;
      dstop_n=1; ftrap_n=1; vtrap_n=1;
      ipcr=2'b10;              // ring 2, as measured (PCR=2)
      TCLK_EN=0;
    end
  endtask

  task check(input [255:0] name, input [3:0] got, input [3:0] want);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: TVEC=%0d, expected %0d (%0s)", name, got, want,
                 (got==3) ? "3 = ring-down, impossible with FPM=0" : "?");
      end else begin
        $display("ok   %0s: TVEC=%0d", name, got);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_TRAP_TVGEN_pgfrace_tb: FPGA_FF_MODE (sysclk+TCLK_EN capture)");
`else
    $display("CGA_TRAP_TVGEN_pgfrace_tb: latch/CP mode (posedge TCLK capture)");
`endif
    setup_fetch;
    ipt = PT_MAPPED;

    // ---------- TEST 1 (control): PGF stable well before the edge ----------
    @(negedge TCLK);
    ipt = PT_EMPTY;            // entry empty -> PGF asserted
    @(negedge TCLK);           // let it be stable across a full TCLK edge
    pulse_en;
    @(posedge TCLK); #1;
    check("stable  PGF, empty entry", TVEC_3_0, 4'd1);

    // ---------- TEST 2 (the silicon case): PGF arrives AT the edge ----------
    // Put a MAPPED entry back so the registered PGF is 0 again, exactly as it
    // is while the machine walks pages normally (245 PGU traps before the
    // fault). Then let the empty entry appear at the capturing edge, which is
    // what happens when the page-table status arrives with the edge.
    ipt = PT_MAPPED;
    @(negedge TCLK);
    @(negedge TCLK);
    pulse_en;
    @(posedge TCLK);           // this edge latches PGF=0 (mapped)
    ipt = PT_EMPTY;            // the faulting entry appears now
    #1;
    check("arriving PGF, empty entry", TVEC_3_0, 4'd1);

    $display("");
    if (errors == 0)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d checks, %0d errors)", checks, errors);
    $finish;
  end

  // TCLK_EN: one sysclk-wide enable aligned to the coming TCLK rise, matching
  // how the P2 flip-flops are enabled in FPGA_FF_MODE.
  task pulse_en;
    begin
`ifdef FPGA_FF_MODE
      @(negedge sysclk); TCLK_EN = 1;
      @(negedge sysclk); TCLK_EN = 0;
`endif
    end
  endtask

endmodule
