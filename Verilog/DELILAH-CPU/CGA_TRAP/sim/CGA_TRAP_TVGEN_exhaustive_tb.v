/***************************************************************************************************
** ND120 CGA - CGA_TRAP/TVGEN - FULLY EXHAUSTIVE INPUT SWEEP                                      **
**                                                                                                **
** PURPOSE: prove every output of CGA_TRAP_TVGEN (TVEC_3_0, PVIOL, RESTR) is correct for EVERY     **
** combination of its raw inputs - not a sample of them. The sheet is dense with detect terms      **
** (PGF, PGU, WIP, RD1-3, RV1-3, WPV/IPV/FPV/RPV) feeding LEV1/LEV2 and a 3-way vector mux, and a  **
** single mis-transcribed gate input there is invisible until a rare input pattern hits it.        **
**                                                                                                **
** WHY THIS EXISTS ALONGSIDE CGA_TRAP_TVGEN_tb.v: that bench checks 5 directed vectors plus a      **
** 6000-vector RANDOM soak. The independent input space is 19 bits = 524288 combinations, so a     **
** 6000-vector sample covers about 1% of it. A wiring error on a term that needs a specific         **
** 6-input coincidence can sit under that sample indefinitely. This sweeps all 524288.             **
**                                                                                                **
** INPUT SPACE (19 independent bits; the _N ports are driven as exact complements, as TBUF does):  **
**   vacc ifetch iind iwrite intrq pan poni dstop_n ftrap_n vtrap_n   (10)                          **
**   ipcr[1:0]                                                        (2)                          **
**   ipt[6:0]  = IPT_15_9, index 0 = PT bit 9 ... index 6 = PT bit 15 (7)                          **
**                                                                                                **
** GOLDEN MODEL: re-derived from the raw inputs per the ND-100 page-table semantics (WPM=bit15,    **
** RPM=14, FPM=13, WIP=12, PGU=11, ring=10:9), NOT read off the gate netlist. Same derivation the  **
** existing bench uses, so the two agree by construction on the terms - what is new here is        **
** COVERAGE.                                                                                       **
**                                                                                                **
** SETTLING: inputs are applied, then TWO TCLK edges are taken before comparing, so the registered  **
** level-1/level-3 vector bits hold values matching the applied inputs. This bench therefore tests  **
** the STEADY-STATE wiring only. The separate CGA_TRAP_TVGEN_pgfrace_tb.v covers the timing case    **
** where the page-table status arrives AT the capturing edge (the ERRFATAL defect, 17-AUG-2026).    **
**                                                                                                **
** Runs in both build modes. Expected: TB_RESULT: PASS (524288 checks).                            **
**                                                                                                **
** Written: 17-AUG-2026                                                                            **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_TVGEN_exhaustive_tb;

  reg TCLK = 0;
  always #5 TCLK = ~TCLK;
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

  // ---------------- independent golden ----------------
  wire ifn=~ifetch, iwn=~iwrite;
  wire p1=ipcr[1], p0=ipcr[0], pn1=~ipcr[1], pn0=~ipcr[0];
  wire t6=ipt[6],t5=ipt[5],t4=ipt[4],t3=ipt[3],t2=ipt[2],t1=ipt[1],t0=ipt[0];
  wire tn6=~t6,tn5=~t5,tn4=~t4,tn3=~t3,tn2=~t2,tn1=~t1,tn0=~t0;

  wire g_pgf = vacc & tn6 & tn5 & tn4;          // WPM,RPM,FPM all clear
  wire g_pgu = vacc & tn2;                      // PGU bit clear
  wire g_wip = vacc & iwrite & t6 & tn3;
  wire g_wpv = vacc & iwrite & (~iind) & ifn & tn6;
  wire g_ipv = vacc & iwn & iind & ifn & tn5 & tn4;
  wire g_fpv = vacc & iwn & (~iind) & ifetch & tn4;
  wire g_rpv = vacc & iwn & (~iind) & ifn & tn5;
  wire g_rv1 = vacc & t1 & pn1;
  wire g_rv2 = vacc & t0 & pn1 & pn0;
  wire g_rv3 = vacc & t1 & t0 & pn0;
  wire g_rd1 = vacc & ifetch & t4 & tn1 & p1;
  wire g_rd2 = vacc & ifetch & t4 & tn1 & tn0 & p0;
  wire g_rd3 = vacc & ifetch & t4 & tn0 & p1 & p0;
  wire g_rd  = g_rd1 | g_rd2 | g_rd3;
  wire g_rv  = g_rv1 | g_rv2 | g_rv3;
  wire g_pviol = g_pgf | g_wpv | g_ipv | g_fpv | g_rpv;
  wire g_lev1  = g_pviol | g_rv;
  wire g_lev2  = g_wip | g_pgu | g_rd;
  wire g_restr = pn1 & poni;

  wire g_ftrap=~ftrap_n, g_vt=~vtrap_n;
  wire g_nvfi=~(vacc & g_ftrap & ifetch);
  wire g_nvv =~(g_vt & vacc);
  wire g_g6  =~(g_nvv & ifetch & intrq & pan & dstop_n);
  wire g_wipn=~g_wip, g_pgun=~g_pgu;
  wire g_d_l1v0=(~g_pgf)&(g_pviol|g_rv);
  wire g_d_l1v1=g_pgf;
  wire g_d_l2v0=~(g_wipn & g_pgu);
  wire g_d_l2v1=~(g_wip | g_pgu);
  wire g_d_l2v2=~(g_rd & g_wipn & g_pgun);
  wire g_d_l3v0=g_nvfi & g_g6;
  wire g_d_l3v1=g_nvv & g_nvfi;

  // ALL SEVEN vector bits are FD1 flip-flops clocked from TCLK on page 104
  // (/CGA/TRAP/TVGEN sheet 2 of 2). The level-2 bits were restored to
  // flip-flops on 17-AUG-2026 after the drawing was read, so the golden models
  // all seven the same way.
  reg q_l1v0=0,q_l1v1=0,q_l2v0=0,q_l2v1=0,q_l2v2=0,q_l3v0=0,q_l3v1=0;
  always @(posedge TCLK) begin
    q_l1v0<=g_d_l1v0; q_l1v1<=g_d_l1v1;
    q_l2v0<=g_d_l2v0; q_l2v1<=g_d_l2v1; q_l2v2<=g_d_l2v2;
    q_l3v0<=g_d_l3v0; q_l3v1<=g_d_l3v1;
  end
  wire l1v0_n=q_l1v0, l1v1_n=q_l1v1;              // .q  outputs
  wire l2v0_n=~q_l2v0, l2v1_n=~q_l2v1, l2v2_n=~q_l2v2;  // .qBar outputs
  wire l3v0_n=~q_l3v0, l3v1_n=~q_l3v1;            // .qBar outputs

  reg g_t2n,g_t1n,g_t0n;
  always @(*) begin
    case ({g_lev1,g_lev2})
      2'b00: begin g_t2n=1'b0;   g_t1n=l3v1_n; g_t0n=l3v0_n; end
      2'b01: begin g_t2n=l2v2_n; g_t1n=l2v1_n; g_t0n=l2v0_n; end
      2'b10: begin g_t2n=1'b1;   g_t1n=l1v1_n; g_t0n=l1v0_n; end
      // MUX31LP has no D3: A=B=1 selects D2, so level 1 wins over level 2.
      2'b11: begin g_t2n=1'b1;   g_t1n=l1v1_n; g_t0n=l1v0_n; end
    endcase
  end
  wire [3:0] g_tvec = { (~g_lev2 & ~g_lev1), ~g_t2n, ~g_t1n, ~g_t0n };

  integer errors=0, checks=0;
  integer v;
  reg [18:0] vec;

  task apply_and_check;
    begin
      // two edges so the registered level-1/level-3 bits match these inputs
      @(posedge TCLK);
      @(posedge TCLK); #1;
      checks = checks + 1;
      if (TVEC_3_0 !== g_tvec || PVIOL !== g_pviol || RESTR !== g_restr) begin
        errors = errors + 1;
        if (errors <= 20)
          $display("FAIL vec=%05h vacc=%b ifetch=%b iind=%b iwrite=%b intrq=%b pan=%b poni=%b dstop_n=%b ftrap_n=%b vtrap_n=%b ipcr=%b ipt=%b : TVEC=%0d exp %0d  PVIOL=%b exp %b  RESTR=%b exp %b",
                   vec, vacc, ifetch, iind, iwrite, intrq, pan, poni,
                   dstop_n, ftrap_n, vtrap_n, ipcr, ipt,
                   TVEC_3_0, g_tvec, PVIOL, g_pviol, RESTR, g_restr);
      end
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_TRAP_TVGEN_exhaustive_tb: FPGA_FF_MODE (sysclk+TCLK_EN capture)");
    TCLK_EN = 1;   // free-running enable: every TCLK rise captures
`else
    $display("CGA_TRAP_TVGEN_exhaustive_tb: latch/CP mode (posedge TCLK capture)");
`endif
    for (v = 0; v < (1<<19); v = v + 1) begin
      vec     = v[18:0];
      vacc    = vec[0];  ifetch  = vec[1];  iind    = vec[2];
      iwrite  = vec[3];  intrq   = vec[4];  pan     = vec[5];
      poni    = vec[6];  dstop_n = vec[7];  ftrap_n = vec[8];
      vtrap_n = vec[9];
      ipcr    = vec[11:10];
      ipt     = vec[18:12];
      apply_and_check;
    end
    $display("");
    if (errors == 0) $display("TB_RESULT: PASS (%0d checks)", checks);
    else             $display("TB_RESULT: FAIL (%0d checks, %0d errors)", checks, errors);
    $finish;
  end

endmodule
