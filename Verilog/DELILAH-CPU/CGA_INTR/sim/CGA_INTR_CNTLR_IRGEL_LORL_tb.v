/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRGEL_LORL  (LO request latch + LOPASSALL/LVE/LOGAS gen, schematic p.92)         **
**                                                                                               **
** DUT contract (derived from GATES_1..4 + one SCAN_FF_EN + inline NOTs, NOT assumed):            **
**   One posedge-MCLK scan flip-flop (USE_ENABLE=0, no FPGA_FF_MODE), powers up at 0:              **
**     INT_REQ_ENABLE_FF: Q=q (int_req_enable_q), D-in=E, TI=q (self-hold), TE=D                   **
**        -> q_next = D ? q : E                                                                     **
**   Combinational outputs (functions of q + inputs):                                              **
**     lopassall_n = NAND3(RDN,LODET,LOVGES)     LOPASSALL = ~lopassall_n = RDN&LODET&LOVGES        **
**     LVE   = AND(~lopassall_n, ~S) = LOPASSALL & ~S              (GATES_4, both inputs bubbled)   **
**     logas_n (LOGASN) = NAND4(LVE,LOVEC2,LOVEC1,LOVEC0)   LOGAS = ~logas_n                        **
**     LIENABN = ~RDN                              (inline NOT)                                     **
**     LIRQ  = AND(~lopassall_n, ~int_req_enable_q_n) = LOPASSALL & q  (GATES_3, both bubbled)      **
**                                                                                               **
** Self-checking: independent shadow of q + independent comb equations, clocked in lockstep.       **
** Directed named scenarios (LOPASSALL/LVE/LOGAS/LIENABN gen, int-req load/hold via LIRQ) PLUS      **
** exhaustive 2-pass lockstep sweep over all 512 input combinations.                               **
**                                                                                               **
** Teeth: -DTEETH_TEST corrupts one compared output -> harness MUST report FAIL.                   **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_lorl -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_LORL.v \                                  **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRGEL_LORL_tb.v && vvp /tmp/tb_lorl                 **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRGEL_LORL_tb;

  reg sysclk = 0;
  reg MCLK_EN = 0;

  reg       D = 0;
  reg       E = 0;
  reg       LODET = 0;
  reg [2:0] LOVEC_2_0 = 0;
  reg       LOVGES = 0;
  reg       MCLK = 0;
  reg       RDN = 0;
  reg       S = 0;

  wire LIENABN, LIRQ, LOGAS, LOGASN, LOPASSALL, LVE;

  CGA_INTR_CNTLR_IRGEL_LORL dut (
      .sysclk   (sysclk),
      .MCLK_EN  (MCLK_EN),
      .D        (D),
      .E        (E),
      .LODET    (LODET),
      .LOVEC_2_0(LOVEC_2_0),
      .LOVGES   (LOVGES),
      .MCLK     (MCLK),
      .RDN      (RDN),
      .S        (S),
      .LIENABN  (LIENABN),
      .LIRQ     (LIRQ),
      .LOGAS    (LOGAS),
      .LOGASN   (LOGASN),
      .LOPASSALL(LOPASSALL),
      .LVE      (LVE)
  );

  integer errors = 0;
  integer checks = 0;
  reg q;   // independent shadow state (int_req_enable_q)

  function automatic e_lopassall; input dummy; begin e_lopassall = RDN & LODET & LOVGES; end endfunction
  function automatic e_lve;       input a_q; begin e_lve = e_lopassall(0) & ~S & a_q; end endfunction
  function automatic e_logas_n;   input dummy;
    begin e_logas_n = ~(e_lve(q) & LOVEC_2_0[2] & LOVEC_2_0[1] & LOVEC_2_0[0]); end
  endfunction
  function automatic e_logas;     input dummy; begin e_logas = ~e_logas_n(0); end endfunction
  function automatic e_lienabn;   input dummy; begin e_lienabn = ~RDN; end endfunction
  function automatic e_lirq;      input a_q;   begin e_lirq = e_lopassall(0) & a_q; end endfunction

  reg eLIENABN, eLIRQ, eLOGAS, eLOGASN, eLOPASSALL, eLVE;

  task do_compare(input [127:0] what);
    begin
      eLOPASSALL = e_lopassall(0);
      eLVE       = e_lve(q);
      eLOGASN    = e_logas_n(0);
      eLOGAS     = e_logas(0);
      eLIENABN   = e_lienabn(0);
      eLIRQ      = e_lirq(q);
`ifdef TEETH_TEST
      eLVE = ~eLVE;   // corrupt one output -> harness must FAIL
`endif
      checks = checks + 1;
      if ({LIENABN,LIRQ,LOGAS,LOGASN,LOPASSALL,LVE} !==
          {eLIENABN,eLIRQ,eLOGAS,eLOGASN,eLOPASSALL,eLVE}) begin
        errors = errors + 1;
        $display("FAIL %0s in{D=%b E=%b LODET=%b LOVEC=%0d LOVGES=%b RDN=%b S=%b} q=%b",
                 what, D,E,LODET,LOVEC_2_0,LOVGES,RDN,S,q);
        $display("     exp LIENABN=%b LIRQ=%b LOGAS=%b LOGASN=%b LOPASSALL=%b LVE=%b",
                 eLIENABN,eLIRQ,eLOGAS,eLOGASN,eLOPASSALL,eLVE);
        $display("     got LIENABN=%b LIRQ=%b LOGAS=%b LOGASN=%b LOPASSALL=%b LVE=%b",
                 LIENABN,LIRQ,LOGAS,LOGASN,LOPASSALL,LVE);
      end
    end
  endtask

  task clk_and_check(input [127:0] what);
    reg nq;
    begin
      nq = D ? q : E;   // TE=D, TI=q(self-hold), D-in=E
      MCLK = 0; #2;
      MCLK = 1; #2;
      MCLK = 0; #2;
      q = nq;
      do_compare(what);
    end
  endtask

  integer i, pass;
  reg nm_lopassall, nm_lve, nm_logas, nm_lienabn, nm_intreq;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRGEL_LORL_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRGEL_LORL_tb);

    q = 1'b0;
    D=0; E=0; LODET=0; LOVEC_2_0=0; LOVGES=0; RDN=0; S=0;
    #2;

    // ---- Named: LOPASSALL = RDN&LODET&LOVGES ----
    RDN=1; LODET=1; LOVGES=1; S=0; D=1; E=0;
    clk_and_check("lopassall on"); nm_lopassall = (LOPASSALL === 1'b1);
    LODET=0;
    clk_and_check("lopassall off"); nm_lopassall = nm_lopassall & (LOPASSALL === 1'b0);

    // ---- Named: LVE = LOPASSALL & ~S ; and LOGAS = LVE & (LOVEC all ones) ----
    RDN=1; LODET=1; LOVGES=1; S=0; LOVEC_2_0=3'b111;
    clk_and_check("lve on"); nm_lve = (LVE === 1'b1);
    nm_logas = (LOGAS === 1'b1) & (LOGASN === 1'b0);
    S=1;
    clk_and_check("lve off on S"); nm_lve = nm_lve & (LVE === 1'b0);
    nm_logas = nm_logas & (LOGAS === 1'b0);          // LVE=0 -> LOGAS=0

    // ---- Named: LIENABN = ~RDN ----
    RDN=1; clk_and_check("lienabn a"); nm_lienabn = (LIENABN === 1'b0);
    RDN=0; clk_and_check("lienabn b"); nm_lienabn = nm_lienabn & (LIENABN === 1'b1);

    // ---- Named: INT_REQ load/hold observed via LIRQ (need LOPASSALL=1) ----
    RDN=1; LODET=1; LOVGES=1; S=0;   // LOPASSALL=1 so LIRQ mirrors q
    D=0; E=1; clk_and_check("intreq load E=1"); nm_intreq = (LIRQ === 1'b1);
    D=1; E=0; clk_and_check("intreq hold");     nm_intreq = nm_intreq & (LIRQ === 1'b1);
    D=0; E=0; clk_and_check("intreq load E=0"); nm_intreq = nm_intreq & (LIRQ === 1'b0);

    // ---- Exhaustive lockstep sweep over all 512 input combos, 2 passes ----
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 512; i = i + 1) begin
        {D, E, LODET, LOVGES, RDN, S, LOVEC_2_0} = i[8:0];
        clk_and_check("sweep");
      end
    end

    $display("named: lopassall=%b lve=%b logas=%b lienabn=%b intreq=%b",
             nm_lopassall, nm_lve, nm_logas, nm_lienabn, nm_intreq);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
