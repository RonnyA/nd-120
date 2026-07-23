/**************************************************************************************************
** ND120 CGA (DELILAH) - /CGA/TRAP/BRKDET unit test                                               **
**                                                                                                **
** DUT: CGA_TRAP_BRKDET (Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP_BRKDET.v, page 103)         **
**                                                                                                **
** Purely combinational break/trap detector. Two outputs:                                          **
**   BRKN  - break request, active low. Asserted (0) when any of the collected detect terms fire   **
**           (page-fault group, protect-violation A02 group, the interrupt/vtrap/ftrap OR group)   **
**           AND NOT overridden by control-break (CBRKN).                                          **
**   TRAPN - trap request, active low, derived from BRKN, CBRK and ETRAPN.                          **
**                                                                                                **
** Golden model: an INDEPENDENT flattened Boolean re-derivation of every gate on page 103          **
** (each *_GATES_n / A02 / bubble-mask collapsed by hand into a single expression). The DUT is the  **
** structural gate netlist; the golden is the algebra. They are compared EXHAUSTIVELY over all      **
** 2^18 input combinations, with the complementary port pairs (IFETCH/IFETCHN, IPCR/IPCR_N,         **
** IPT/IPT_N, IWRITE/IWRITEN) driven CONSISTENTLY, i.e. exactly as the upstream TBUF drives them.   **
**                                                                                                **
** Teeth (-DTEETH_TEST): one bit of the golden BRKN is flipped so the checker MUST report FAIL.    **
**                                                                                                **
** Self-check: prints exactly "TB_RESULT: PASS" (or "TB_RESULT: FAIL ...").                        **
**                                                                                                **
** Last reviewed: 15-JUL-2026                                                                     **
** Ronny Hansen                                                                                   **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_BRKDET_tb;

`ifdef TEETH_TEST
  localparam TEETH = 1'b1;
`else
  localparam TEETH = 1'b0;
`endif

  // ----- base independent stimulus (complementary pairs derived from these) -----
  reg       vacc, ifetch, iind_n, intrq, iwrite;
  reg       cbrk_n, etrap_n, ftrap_n, vtrap_n;
  reg [1:0] ipcr;
  reg [6:0] ipt;

  // ----- DUT port wires (consistent complements, mirroring TBUF) -----
  wire       IFETCH   = ifetch;
  wire       IFETCHN  = ~ifetch;
  wire       IINDN    = iind_n;
  wire       INTRQ    = intrq;
  wire       IWRITE   = iwrite;
  wire       IWRITEN  = ~iwrite;
  wire       VACC     = vacc;
  wire [1:0] IPCR_1_0   = ipcr;
  wire [1:0] IPCR_1_0_N = ~ipcr;
  wire [6:0] IPT_15_9   = ipt;
  wire [6:0] IPT_15_9_N = ~ipt;

  wire BRKN, TRAPN;

  CGA_TRAP_BRKDET DUT (
      .CBRKN(cbrk_n), .ETRAPN(etrap_n), .FTRAPN(ftrap_n),
      .IFETCH(IFETCH), .IFETCHN(IFETCHN), .IINDN(IINDN), .INTRQ(INTRQ),
      .IPCR_1_0(IPCR_1_0), .IPCR_1_0_N(IPCR_1_0_N),
      .IPT_15_9(IPT_15_9), .IPT_15_9_N(IPT_15_9_N),
      .IWRITE(IWRITE), .IWRITEN(IWRITEN),
      .VACC(VACC), .VTRAPN(vtrap_n),
      .BRKN(BRKN), .TRAPN(TRAPN)
  );

  // ---------------- independent golden (flattened page-103 algebra) -------------
  // convenience shorthands
  wire ifn = ~ifetch;               // IFETCHN
  wire iwn = ~iwrite;               // IWRITEN
  wire p1  = ipcr[1], p0 = ipcr[0];
  wire pn1 = ~ipcr[1], pn0 = ~ipcr[0];
  // ipt true / negated bit access
  wire t6=ipt[6], t5=ipt[5], t4=ipt[4], t3=ipt[3], t2=ipt[2], t1=ipt[1], t0=ipt[0];
  wire tn6=~t6, tn5=~t5, tn4=~t4, tn3=~t3, tn2=~t2, tn1=~t1, tn0=~t0;
  wire vt  = ~vtrap_n;              // VTRAP
  wire cbrk= ~cbrk_n;               // CBRK

  wire g_ipv = ~(vacc & tn5 & tn4);                 // IPV  NAND3
  wire g_g2  = vacc & iwrite;                        // GATES_2
  wire g_wip = ~(g_g2 & t6 & tn3);                   // WIP  NAND3
  wire g_g4  = vacc & ifetch & p0;                   // GATES_4
  wire g_rd2 = ~(g_g4 & tn1 & tn0);                  // RD2  NAND3
  wire g_g7  = vacc & pn0;                           // GATES_7
  wire g_rv3 = ~(g_g7 & t1 & t0);                    // RV3  NAND3
  wire g_g5  = (~g_ipv)|(~g_wip)|(~g_rd2)|(~g_rv3);  // GATES_5 OR4 bubbled(F)
  wire g_pgf = ~(vacc & tn6 & tn5 & tn4);            // PGF  NAND4 (note: this is pgf_out, active-low pgf)
  wire g_intr= ~(ifetch & intrq);                    // INTR NAND
  wire g_g14 = ~(vt & vacc);                         // GATES_14 NAND
  wire g_g15 = ~((~ftrap_n) & ifetch);               // GATES_15 NAND bubbled(3): ~(ftrap & ifetch)
  wire g_g10 = (~g_pgf)|(~g_intr)|(~g_g14)|(~g_g15); // GATES_10 OR4 bubbled(F)
  wire g_g18 = vacc & ifetch;                        // GATES_18
  wire g_an2 = vacc & iwrite;                        // AN2_1
  wire g_g19 = vacc & iwn & iind_n & ifn;            // GATES_19 AND4
  wire g_g22 = vacc & ifetch & p1 & p0;              // GATES_22 AND4
  wire g_g21 = vacc & ifetch & p1;                   // GATES_21 AND3
  wire g_g24 = vacc & pn1 & pn0;                     // GATES_24 AND3
  wire g_g23 = vacc & pn1;                           // GATES_23 AND
  wire g_a1  = ~((tn4 & g_g18) | (tn6 & g_an2));     // A02_1
  wire g_a2  = ~((tn2 & vacc)  | (tn5 & g_g19));     // A02_2
  wire g_a3  = ~((tn0 & g_g22) | (tn1 & g_g21));     // A02_3
  wire g_a4  = ~((t0  & g_g24) | (t1  & g_g23));     // A02_4
  wire g_g20 = (~g_a1)|(~g_a2)|(~g_a3)|(~g_a4);      // GATES_20 OR4 bubbled(F)
  wire g_g12 = ~(g_g10 | g_g5 | g_g20);              // GATES_12 NOR3
  wire g_brkn_raw = g_g12 & cbrk_n;                  // GATES_13 NOR bubbled(11) = g12 & cbrk_n
  wire g_trapn    = ~((~g_brkn_raw) & cbrk_n & (~etrap_n)); // GATES_16 NAND3 bubbled(7)

  wire g_brkn = g_brkn_raw ^ TEETH;                  // teeth corrupts BRKN

  integer errors = 0;
  integer checks = 0;
  integer i;

  task do_check;
    begin
      #1;
      checks = checks + 1;
      if (BRKN !== g_brkn || TRAPN !== g_trapn) begin
        errors = errors + 1;
        if (errors <= 12)
          $display("FAIL vacc=%b ife=%b iindn=%b intrq=%b iw=%b cbn=%b etn=%b ftn=%b vtn=%b ipcr=%b ipt=%b | BRKN exp=%b got=%b  TRAPN exp=%b got=%b",
                   vacc, ifetch, iind_n, intrq, iwrite, cbrk_n, etrap_n, ftrap_n, vtrap_n,
                   ipcr, ipt, g_brkn, BRKN, g_trapn, TRAPN);
      end
    end
  endtask

  initial begin
`ifdef DUMP_VCD
    $dumpfile("CGA_TRAP_BRKDET_tb.vcd");
    $dumpvars(0, CGA_TRAP_BRKDET_tb);
`endif

    // EXHAUSTIVE over the 18 independent bits:
    // {vacc,ifetch,iind_n,intrq,iwrite,cbrk_n,etrap_n,ftrap_n,vtrap_n,ipcr[2],ipt[7]}
    for (i = 0; i < (1<<18); i = i + 1) begin
      {vacc, ifetch, iind_n, intrq, iwrite,
       cbrk_n, etrap_n, ftrap_n, vtrap_n, ipcr, ipt} = i[17:0];
      do_check;
    end

    $display("checks=%0d errors=%0d teeth=%0d", checks, errors, TEETH);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors, teeth=%0d)", errors, TEETH);
    $finish;
  end

endmodule
