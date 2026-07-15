/**************************************************************************************************
** ND120 CGA (DELILAH) - /CGA/TRAP top-level integration test                                     **
**                                                                                                **
** DUT: CGA_TRAP (Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP.v, page 100)                       **
**   wires TBUF (input buffers) -> BRKDET (break/trap detect) + TVGEN (vector gen, w/ TVGEN_P2).   **
**   Board-side inputs: CBRKN DSTOPN ETRAPN FETCHN FTRAPN INDN INTRQN PANN PCR PONI PT VACCN        **
**                      VTRAPN WRITEN (+ TCLK, and sysclk/TCLK_EN for FF mode).                    **
**   Outputs: BRKN, PVIOL, RESTR, TRAPN, TVEC_3_0.                                                 **
**                                                                                                **
** Golden model: an INDEPENDENT end-to-end re-derivation from the raw board inputs - the TBUF      **
** inversions, the BRKDET break/trap Boolean algebra, and the TVGEN PVIOL/RESTR/FF+mux TVEC - all   **
** written from the schematic intent, NOT read from DUT internals. All FIVE outputs are compared     **
** every TCLK edge across directed + randomized-soak vectors.                                       **
** SPEC ANCHORS: the five microcode trap-vector sources are driven from the raw board pins and the   **
** absolute octal TVEC is asserted (page-fault=1, protect-violation=2, ring-down=3, PGU=4, WIP=5),  **
** each additionally required to raise the break output (BRKN=0).                                   **
**                                                                                                **
** Default clocking (no FPGA_FF_MODE): the vector FFs clock on posedge TCLK; sysclk/TCLK_EN unused. **
** Teeth (-DTEETH_TEST): one golden TVEC bit is flipped so the checker MUST report FAIL.           **
**                                                                                                **
** Last reviewed: 15-JUL-2026                                                                     **
** Ronny Hansen                                                                                   **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_tb;

`ifdef TEETH_TEST
  localparam [3:0] TEETH = 4'b0010;
`else
  localparam [3:0] TEETH = 4'b0000;
`endif

  reg TCLK = 0;
  always #5 TCLK = ~TCLK;
  reg sysclk = 0, TCLK_EN = 0;

  // ---- board-side stimulus (active-low as named) ----
  reg       CBRKN, DSTOPN, ETRAPN, FETCHN, FTRAPN, INDN, INTRQN, PANN, PONI, VACCN, VTRAPN, WRITEN;
  reg [1:0] PCR_1_0;
  reg [6:0] PT_15_9;

  wire       BRKN, PVIOL, RESTR, TRAPN;
  wire [3:0] TVEC_3_0;

  CGA_TRAP DUT (
      .sysclk(sysclk), .TCLK_EN(TCLK_EN),
      .CBRKN(CBRKN), .DSTOPN(DSTOPN), .ETRAPN(ETRAPN), .FETCHN(FETCHN), .FTRAPN(FTRAPN),
      .INDN(INDN), .INTRQN(INTRQN), .PANN(PANN), .PCR_1_0(PCR_1_0), .PONI(PONI),
      .PT_15_9(PT_15_9), .TCLK(TCLK), .VACCN(VACCN), .VTRAPN(VTRAPN), .WRITEN(WRITEN),
      .BRKN(BRKN), .PVIOL(PVIOL), .RESTR(RESTR), .TRAPN(TRAPN), .TVEC_3_0(TVEC_3_0)
  );

  // ---------------- independent golden ----------------
  // TBUF inversions -> internal I-domain
  wire       vacc   = ~VACCN;
  wire       ifetch = ~FETCHN;
  wire       iind   = ~INDN;
  wire       iwrite = ~WRITEN;
  wire       intrq  = ~INTRQN;
  wire       pan    = ~PANN;
  wire [1:0] ipcr   = PCR_1_0;
  wire [6:0] ipt    = PT_15_9;
  wire       poni   = PONI;
  wire       dstop_n= DSTOPN, ftrap_n=FTRAPN, vtrap_n=VTRAPN, cbrk_n=CBRKN, etrap_n=ETRAPN;

  wire ifn=~ifetch, iwn=~iwrite;
  wire p1=ipcr[1], p0=ipcr[0], pn1=~ipcr[1], pn0=~ipcr[0];
  wire t6=ipt[6],t5=ipt[5],t4=ipt[4],t3=ipt[3],t2=ipt[2],t1=ipt[1],t0=ipt[0];
  wire tn6=~t6,tn5=~t5,tn4=~t4,tn3=~t3,tn2=~t2,tn1=~t1,tn0=~t0;
  wire vt=~vtrap_n;

  // --- BRKDET break/trap (flattened page-103 algebra) ---
  wire b_ipv = ~(vacc & tn5 & tn4);
  wire b_wip = ~((vacc&iwrite) & t6 & tn3);
  wire b_rd2 = ~((vacc&ifetch&p0) & tn1 & tn0);
  wire b_rv3 = ~((vacc&pn0) & t1 & t0);
  wire b_g5  = (~b_ipv)|(~b_wip)|(~b_rd2)|(~b_rv3);
  wire b_pgf = ~(vacc & tn6 & tn5 & tn4);
  wire b_intr= ~(ifetch & intrq);
  wire b_g14 = ~(vt & vacc);
  wire b_g15 = ~((~ftrap_n) & ifetch);
  wire b_g10 = (~b_pgf)|(~b_intr)|(~b_g14)|(~b_g15);
  wire b_g18 = vacc & ifetch;
  wire b_an2 = vacc & iwrite;
  wire b_g19 = vacc & iwn & (~iind) & ifn;    // iind_n = INDN = ~iind
  wire b_g22 = vacc & ifetch & p1 & p0;
  wire b_g21 = vacc & ifetch & p1;
  wire b_g24 = vacc & pn1 & pn0;
  wire b_g23 = vacc & pn1;
  wire b_a1  = ~((tn4 & b_g18) | (tn6 & b_an2));
  wire b_a2  = ~((tn2 & vacc)  | (tn5 & b_g19));
  wire b_a3  = ~((tn0 & b_g22) | (tn1 & b_g21));
  wire b_a4  = ~((t0  & b_g24) | (t1  & b_g23));
  wire b_g20 = (~b_a1)|(~b_a2)|(~b_a3)|(~b_a4);
  wire b_g12 = ~(b_g10 | b_g5 | b_g20);
  wire g_brkn  = b_g12 & cbrk_n;
  wire g_trapn = ~((~g_brkn) & cbrk_n & (~etrap_n));

  // --- TVGEN detect terms / PVIOL / RESTR ---
  wire g_pgf = vacc & tn6 & tn5 & tn4;
  wire g_pgu = vacc & tn2;
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
  wire g_rd  = g_rd1|g_rd2|g_rd3;
  wire g_rv  = g_rv1|g_rv2|g_rv3;
  wire g_pviol = g_pgf|g_wpv|g_ipv|g_fpv|g_rpv;
  wire g_lev1  = g_pviol|g_rv;
  wire g_lev2  = g_wip|g_pgu|g_rd;
  wire g_restr = pn1 & poni;

  // --- TVGEN_P2 FF+mux ---
  wire g_ftrap=~ftrap_n;
  wire g_nvfi=~(vacc & g_ftrap & ifetch);
  wire g_nvv =~(vt & vacc);
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
      2'b11: begin g_t2n=1'b0;   g_t1n=1'b0;   g_t0n=1'b0;   end
    endcase
  end
  wire [3:0] g_tvec = { (~g_lev2 & ~g_lev1), ~g_t2n, ~g_t1n, ~g_t0n } ^ TEETH;

  integer errors=0, checks=0, i;

  task edge_check(input [255:0] name);
    begin
      @(posedge TCLK); #1;
      checks = checks + 1;
      if (TVEC_3_0 !== g_tvec || PVIOL !== g_pviol || RESTR !== g_restr ||
          BRKN !== g_brkn || TRAPN !== g_trapn) begin
        errors = errors + 1;
        if (errors <= 15)
          $display("FAIL [%0s] PT=%b PCR=%b VACCN=%b FETCHN=%b INDN=%b WRITEN=%b CBRKN=%b ETRAPN=%b | TVEC e=%0o g=%0o PVIOL e=%b g=%b RESTR e=%b g=%b BRKN e=%b g=%b TRAPN e=%b g=%b",
                   name, PT_15_9, PCR_1_0, VACCN, FETCHN, INDN, WRITEN, CBRKN, ETRAPN,
                   g_tvec, TVEC_3_0, g_pviol, PVIOL, g_restr, RESTR, g_brkn, BRKN, g_trapn, TRAPN);
      end
    end
  endtask

  // spec anchor: absolute octal TVEC + break must fire (BRKN=0)
  task assert_src(input [3:0] expo, input [255:0] name);
    begin
      @(posedge TCLK); #1;
      checks = checks + 1;
      if (TVEC_3_0 !== (expo ^ TEETH)) begin
        errors = errors + 1;
        $display("FAIL SPEC [%0s] expected TVEC=%0o got=%0o", name, expo, TVEC_3_0);
      end
      if (BRKN !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL SPEC [%0s] expected BRKN=0 (break) got=%b", name, BRKN);
      end
    end
  endtask

  // idle background (all active-lows deasserted = 1, no access)
  task idle;
    begin
      CBRKN=1; DSTOPN=1; ETRAPN=1; FETCHN=1; FTRAPN=1; INDN=1; INTRQN=1;
      PANN=1; PONI=0; VACCN=1; VTRAPN=1; WRITEN=1; PCR_1_0=2'b00; PT_15_9=7'b0;
    end
  endtask

  initial begin
`ifdef DUMP_VCD
    $dumpfile("CGA_TRAP_tb.vcd");
    $dumpvars(0, CGA_TRAP_tb);
`endif
    idle; @(negedge TCLK);

    // ---- SPEC ANCHORS from the raw board pins (VACC active => VACCN=0) ----
    // page fault
    idle; VACCN=0; PT_15_9=7'b0000100;
    @(negedge TCLK); assert_src(4'o1, "page-fault");
    // protect violation (fetch protect): FETCH active => FETCHN=0
    idle; VACCN=0; FETCHN=0; WRITEN=1; INDN=1; PT_15_9=7'b0100100;
    @(negedge TCLK); assert_src(4'o2, "protect-violation");
    // ring-down (rd2): FETCH active, PCR0=1
    idle; VACCN=0; FETCHN=0; PCR_1_0=2'b01; PT_15_9=7'b0010100;
    @(negedge TCLK); assert_src(4'o3, "ring-down");
    // PGU trap
    idle; VACCN=0; FETCHN=1; WRITEN=1; INDN=1; PT_15_9=7'b0110000;
    @(negedge TCLK); assert_src(4'o4, "pgu-trap");
    // WIP trap: WRITE active => WRITEN=0
    idle; VACCN=0; WRITEN=0; FETCHN=1; INDN=1; PT_15_9=7'b1000100;
    @(negedge TCLK); assert_src(4'o5, "wip-trap");

    // ---- directed break/trap-path checks ----
    idle; @(negedge TCLK); edge_check("idle-notrap");
    idle; CBRKN=0; @(negedge TCLK); edge_check("control-break");            // BRKN via CBRK
    idle; VACCN=0; PT_15_9=7'b0000100; ETRAPN=0;                            // page fault + ETRAP
    @(negedge TCLK); edge_check("pagefault+etrap-trapn");
    idle; VACCN=0; INTRQN=0; FETCHN=0;                                     // interrupt at fetch
    @(negedge TCLK); edge_check("intr-at-fetch");
    idle; VACCN=0; VTRAPN=0;                                               // vector trap
    @(negedge TCLK); edge_check("vtrap");
    idle; PONI=1; PCR_1_0=2'b00;                                           // RESTR path
    @(negedge TCLK); edge_check("restr");

    // ---- randomized soak over all board inputs ----
    for (i = 0; i < 8000; i = i + 1) begin
      @(negedge TCLK);
      CBRKN=$random; DSTOPN=$random; ETRAPN=$random; FETCHN=$random; FTRAPN=$random;
      INDN=$random; INTRQN=$random; PANN=$random; PONI=$random; VACCN=$random;
      VTRAPN=$random; WRITEN=$random; PCR_1_0=$random; PT_15_9=$random;
      edge_check("soak");
    end

    $display("checks=%0d errors=%0d teeth=%b", checks, errors, TEETH);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors, teeth=%b)", errors, TEETH);
    $finish;
  end

endmodule
