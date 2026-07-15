/**************************************************************************************************
** ND120 CGA (DELILAH) - /CGA/TRAP/TBUF unit test                                                 **
**                                                                                                **
** DUT: CGA_TRAP_TBUF (Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP_TBUF.v)                       **
**                                                                                                **
** What it does (verified from the RTL, page 101): despite the name "TRAP BUFFERS" this block is  **
** purely COMBINATIONAL - it buffers the raw board-side trap-input strobes into the internal      **
** I-domain and produces both the true and negated senses used by BRKDET / TVGEN. There is no     **
** clock and no state.  Mapping (from the source):                                                **
**   IFETCH  = ~FETCHN     IFETCHN = FETCHN                                                        **
**   IIND    = ~INDN       IINDN   = INDN                                                          **
**   INTRQ   = ~INTRQN                                                                             **
**   IPCR    = PCR         IPCR_N  = ~PCR      (double inversion)                                  **
**   IPT     = PT          IPT_N   = ~PT       (double inversion)                                  **
**   IWRITE  = ~WRITEN     IWRITEN = WRITEN                                                        **
**   PAN     = ~PANN                                                                               **
**   VACC    = ~VACCN                                                                              **
**                                                                                                **
** Golden model: an INDEPENDENT re-statement of the mapping above (not the DUT gates).            **
** Coverage: EXHAUSTIVE over all 2^15 input combinations.                                         **
** Teeth (-DTEETH_TEST): the golden IFETCH sense is deliberately corrupted so the checker MUST    **
** report FAIL - proving the comparison is not vacuous.                                            **
**                                                                                                **
** Self-check: prints exactly "TB_RESULT: PASS" (or "TB_RESULT: FAIL ...").                        **
** Run: make test-trap-tbuf   (or compile with iverilog -g2012, see the module Makefile)          **
**                                                                                                **
** Last reviewed: 15-JUL-2026                                                                     **
** Ronny Hansen                                                                                   **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_TBUF_tb;

  // ----- teeth mask (0 in a normal build; 1 corrupts golden IFETCH) -----
`ifdef TEETH_TEST
  localparam TEETH = 1'b1;
`else
  localparam TEETH = 1'b0;
`endif

  // ----- DUT inputs -----
  reg        FETCHN, INDN, INTRQN, PANN, VACCN, WRITEN;
  reg [1:0]  PCR_1_0;
  reg [6:0]  PT_15_9;

  // ----- DUT outputs -----
  wire       IFETCH, IFETCHN, IIND, IINDN, INTRQ, IWRITE, IWRITEN, PAN, VACC;
  wire [1:0] IPCR_1_0, IPCR_1_0_N;
  wire [6:0] IPT_15_9, IPT_15_9_N;

  CGA_TRAP_TBUF DUT (
      .FETCHN(FETCHN), .INDN(INDN), .INTRQN(INTRQN), .PANN(PANN),
      .PCR_1_0(PCR_1_0), .PT_15_9(PT_15_9), .VACCN(VACCN), .WRITEN(WRITEN),
      .IFETCH(IFETCH), .IFETCHN(IFETCHN), .IIND(IIND), .IINDN(IINDN),
      .INTRQ(INTRQ), .IPCR_1_0(IPCR_1_0), .IPCR_1_0_N(IPCR_1_0_N),
      .IPT_15_9(IPT_15_9), .IPT_15_9_N(IPT_15_9_N),
      .IWRITE(IWRITE), .IWRITEN(IWRITEN), .PAN(PAN), .VACC(VACC)
  );

  // ----- independent golden -----
  wire       g_ifetch  = (~FETCHN) ^ TEETH;   // teeth corrupts this sense
  wire       g_ifetchn = FETCHN;
  wire       g_iind    = ~INDN;
  wire       g_iindn   = INDN;
  wire       g_intrq   = ~INTRQN;
  wire [1:0] g_ipcr    = PCR_1_0;
  wire [1:0] g_ipcr_n  = ~PCR_1_0;
  wire [6:0] g_ipt     = PT_15_9;
  wire [6:0] g_ipt_n   = ~PT_15_9;
  wire       g_iwrite  = ~WRITEN;
  wire       g_iwriten = WRITEN;
  wire       g_pan     = ~PANN;
  wire       g_vacc    = ~VACCN;

  integer errors = 0;
  integer checks = 0;
  integer i;

  task do_check;
    begin
      #1;
      checks = checks + 1;
      if (IFETCH   !== g_ifetch  || IFETCHN !== g_ifetchn ||
          IIND     !== g_iind    || IINDN   !== g_iindn   ||
          INTRQ    !== g_intrq   || IPCR_1_0 !== g_ipcr   ||
          IPCR_1_0_N !== g_ipcr_n|| IPT_15_9 !== g_ipt    ||
          IPT_15_9_N !== g_ipt_n || IWRITE  !== g_iwrite  ||
          IWRITEN  !== g_iwriten || PAN     !== g_pan     ||
          VACC     !== g_vacc) begin
        errors = errors + 1;
        if (errors <= 8)
          $display("FAIL vec: FETCHN=%b INDN=%b INTRQN=%b PANN=%b VACCN=%b WRITEN=%b PCR=%b PT=%b | IFETCH exp=%b got=%b  VACC exp=%b got=%b",
                   FETCHN, INDN, INTRQN, PANN, VACCN, WRITEN, PCR_1_0, PT_15_9,
                   g_ifetch, IFETCH, g_vacc, VACC);
      end
    end
  endtask

  initial begin
    $dumpfile("CGA_TRAP_TBUF_tb.vcd");
    $dumpvars(0, CGA_TRAP_TBUF_tb);

    // EXHAUSTIVE: 15 input bits -> 2^15 = 32768 vectors
    for (i = 0; i < 32768; i = i + 1) begin
      {FETCHN, INDN, INTRQN, PANN, VACCN, WRITEN, PCR_1_0, PT_15_9} = i[14:0];
      do_check;
    end

    // Normal build: TEETH=0 -> golden matches DUT -> PASS.
    // Teeth build : TEETH=1 -> golden IFETCH corrupted -> mismatches -> FAIL.
    $display("checks=%0d errors=%0d teeth=%0d", checks, errors, TEETH);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors, teeth=%0d)", errors, TEETH);
    $finish;
  end

endmodule
