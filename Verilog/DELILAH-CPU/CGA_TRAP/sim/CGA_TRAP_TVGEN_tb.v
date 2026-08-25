/**************************************************************************************************
** ND120 CGA (DELILAH) - /CGA/TRAP/TVGEN unit test  (level logic + TVGEN_P2 vector core)          **
**                                                                                                **
** DUT: CGA_TRAP_TVGEN (Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP_TVGEN.v, page 104 sheet 1)   **
**                                                                                                **
** Combinational level-detect logic that decodes the page-table status word (IPT), the ring bits   **
** (IPCR) and the access type (IWRITE/IIND/IFETCH under VACC) into the per-trap-source detect       **
** terms - PGF, PGU, WIP, RD(1..3), RV(1..3) and the protect-violation family (WPV/IPV/FPV/RPV) -   **
** feeding the priority levels LEV1/LEV2 and the TCLK-latched vector core (TVGEN_P2).               **
** Outputs: PVIOL (protect-violation OR), RESTR (~IPCR1 & PONI), TVEC_3_0 (the 4-bit trap vector).  **
**                                                                                                **
** Golden model: an INDEPENDENT re-derivation from the raw IPT/IPCR/VACC/access inputs (NOT the     **
** gate netlist) of every detect term, PVIOL, RESTR, and the FF+mux TVEC. Compared every TCLK edge  **
** across directed + randomized-soak vectors.                                                       **
** SPEC ANCHORS: five directed vectors built at the RAW page-table-word level assert the ABSOLUTE   **
** octal TVEC from the DELILAH microcode trap-vector table: page-fault=1, protect-violation=2,       **
** ring-down=3, PGU-trap=4, WIP-trap=5.                                                             **
**                                                                                                **
** Default clocking (no FPGA_FF_MODE): the vector FFs clock on posedge TCLK (sysclk/TCLK_EN unused). **
** Teeth (-DTEETH_TEST): one golden TVEC bit is flipped so the checker MUST report FAIL.           **
**                                                                                                **
** Last reviewed: 15-JUL-2026                                                                     **
** Ronny Hansen                                                                                   **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_TVGEN_tb;

`ifdef TEETH_TEST
  localparam [3:0] TEETH = 4'b0001;
`else
  localparam [3:0] TEETH = 4'b0000;
`endif

  reg TCLK = 0;
  always #5 TCLK = ~TCLK;
  reg sysclk = 0, TCLK_EN = 0;

  // ---- base independent stimulus ----
  reg       vacc, ifetch, iind, iwrite, intrq, pan, poni;
  reg       dstop_n, ftrap_n, vtrap_n;
  reg [1:0] ipcr;
  reg [6:0] ipt;

  // ---- consistent complementary DUT port drives (as TBUF would produce) ----
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

  // ------------------ independent golden ------------------
  wire ifn=~ifetch, iwn=~iwrite;
  wire p1=ipcr[1], p0=ipcr[0], pn1=~ipcr[1], pn0=~ipcr[0];
  wire t6=ipt[6],t5=ipt[5],t4=ipt[4],t3=ipt[3],t2=ipt[2],t1=ipt[1],t0=ipt[0];
  wire tn6=~t6,tn5=~t5,tn4=~t4,tn3=~t3,tn2=~t2,tn1=~t1,tn0=~t0;

  wire g_pgf = vacc & tn6 & tn5 & tn4;
  wire g_pgu = vacc & tn2;
  wire g_wip = vacc & iwrite & t6 & tn3;
  wire g_wpv = vacc & iwrite & (~iind) & ifn & tn6;   // iind_n = ~iind
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
  wire g_pviol = g_pgf | g_wpv | g_ipv | g_fpv | g_rpv;   // PVIOL
  wire g_lev1  = g_pviol | g_rv;
  wire g_lev2  = g_wip | g_pgu | g_rd;
  wire g_restr = pn1 & poni;                              // RESTR

  // P2 D-inputs (re-derived)
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

  reg q_l1v0=0,q_l1v1=0,q_l2v0=0,q_l2v1=0,q_l2v2=0,q_l3v0=0,q_l3v1=0;
  always @(posedge TCLK) begin
    q_l1v0<=g_d_l1v0; q_l1v1<=g_d_l1v1;
    q_l2v0<=g_d_l2v0; q_l2v1<=g_d_l2v1; q_l2v2<=g_d_l2v2;
    q_l3v0<=g_d_l3v0; q_l3v1<=g_d_l3v1;
  end
  wire l1v0_n=q_l1v0, l1v1_n=q_l1v1;
  wire l2v0_n=~q_l2v0, l2v1_n=~q_l2v1, l2v2_n=~q_l2v2;
  wire l3v0_n=~q_l3v0, l3v1_n=~q_l3v1;

  reg g_t2n,g_t1n,g_t0n;
  always @(*) begin
    case ({g_lev1,g_lev2})
      2'b00: begin g_t2n=1'b0;   g_t1n=l3v1_n; g_t0n=l3v0_n; end
      2'b01: begin g_t2n=l2v2_n; g_t1n=l2v1_n; g_t0n=l2v0_n; end
      2'b10: begin g_t2n=1'b1;   g_t1n=l1v1_n; g_t0n=l1v0_n; end
      // MUX31LP (fix 27-JUL): no D3 - A=B=1 selects D2, level 1 wins.
      2'b11: begin g_t2n=1'b1;   g_t1n=l1v1_n; g_t0n=l1v0_n; end
    endcase
  end
  wire [3:0] g_tvec = { (~g_lev2 & ~g_lev1), ~g_t2n, ~g_t1n, ~g_t0n } ^ TEETH;

  integer errors=0, checks=0, i;

  task edge_check(input [255:0] name);
    begin
      @(posedge TCLK); #1;
      checks = checks + 1;
      if (TVEC_3_0 !== g_tvec || PVIOL !== g_pviol || RESTR !== g_restr) begin
        errors = errors + 1;
        if (errors <= 15)
          $display("FAIL [%0s] ipt=%b ipcr=%b vacc=%b ife=%b iind=%b iw=%b | TVEC exp=%0o got=%0o PVIOL exp=%b got=%b RESTR exp=%b got=%b",
                   name, ipt, ipcr, vacc, ifetch, iind, iwrite,
                   g_tvec, TVEC_3_0, g_pviol, PVIOL, g_restr, RESTR);
      end
    end
  endtask

  task assert_tvec(input [3:0] expo, input [255:0] name);
    begin
      @(posedge TCLK); #1;
      checks = checks + 1;
      if (TVEC_3_0 !== (expo ^ TEETH)) begin
        errors = errors + 1;
        $display("FAIL SPEC [%0s] ipt=%b ipcr=%b expected TVEC=%0o got=%0o (PVIOL=%b)",
                 name, ipt, ipcr, expo, TVEC_3_0, PVIOL);
      end
    end
  endtask

  task clr;
    begin
      vacc=0; ifetch=0; iind=0; iwrite=0; intrq=0; pan=0; poni=0;
      dstop_n=1; ftrap_n=1; vtrap_n=1; ipcr=2'b00; ipt=7'b0000000;
    end
  endtask

  initial begin
`ifdef DUMP_VCD
    $dumpfile("CGA_TRAP_TVGEN_tb.vcd");
    $dumpvars(0, CGA_TRAP_TVGEN_tb);
`endif
    clr; @(negedge TCLK);

    // ---- SPEC ANCHORS built at the raw page-table-word level ----
    // page fault: pgf (ipt[6:4]=000), keep LEV2 clear (ipt[2]=1) -> vector 1
    clr; vacc=1; ipt=7'b0000100;                    // t2=1
    @(negedge TCLK); assert_tvec(4'o1, "page-fault=1");

    // protect violation (fetch protect, fpv): ifetch=1, ipt[4]=0, ipt[5]=1 kills pgf/rpv
    clr; vacc=1; ifetch=1; iwrite=0; iind=0; ipt=7'b0100100;
    @(negedge TCLK); assert_tvec(4'o2, "protect-violation=2");

    // ring-down (rd2): ifetch=1, ipt[4]=1, ipt[1:0]=0, ipcr[0]=1
    clr; vacc=1; ifetch=1; ipcr=2'b01; ipt=7'b0010100;
    @(negedge TCLK); assert_tvec(4'o3, "ring-down=3");

    // PGU trap: pgu (ipt[2]=0), no fetch/write, ipt[5:4]=11 kills pgf/rpv/ipv
    clr; vacc=1; iwrite=0; iind=0; ifetch=0; ipt=7'b0110000;
    @(negedge TCLK); assert_tvec(4'o4, "pgu-trap=4");

    // WIP trap: iwrite=1, ipt[6]=1, ipt[3]=0, ipt[2]=1 kills pgu
    clr; vacc=1; iwrite=1; ifetch=0; iind=0; ipt=7'b1000100;
    @(negedge TCLK); assert_tvec(4'o5, "wip-trap=5");

    // ---- directed PVIOL / RESTR spot checks ----
    clr; vacc=1; poni=1; ipcr=2'b00;                // RESTR = ~ipcr1 & poni = 1
    @(negedge TCLK); edge_check("restr-on");
    clr; vacc=1; poni=1; ipcr=2'b10;                // ipcr1=1 -> RESTR=0
    @(negedge TCLK); edge_check("restr-off");

    // ---- randomized soak over raw inputs ----
    for (i = 0; i < 6000; i = i + 1) begin
      @(negedge TCLK);
      vacc=$random; ifetch=$random; iind=$random; iwrite=$random;
      intrq=$random; pan=$random; poni=$random;
      dstop_n=$random; ftrap_n=$random; vtrap_n=$random;
      ipcr=$random; ipt=$random;
      edge_check("soak");
    end

    $display("checks=%0d errors=%0d teeth=%b", checks, errors, TEETH);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors, teeth=%b)", errors, TEETH);
    $finish;
  end

endmodule
