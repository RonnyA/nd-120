/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRGEL_HIRL  (HI request latch + HIPASSALL/HVE/PD/RDN gen, schematic p.91)        **
**                                                                                               **
** DUT contract (derived from GATES_1..7 + two SCAN_FF_EN, NOT assumed):                          **
**   Two posedge-MCLK scan flip-flops (USE_ENABLE=0, no FPGA_FF_MODE), both power up at 0:         **
**     STATUS_OVERFLOW_FF: Q=q1 (s_hidis_n), D=Q (self-hold), TI=higas_n, TE=H                     **
**        -> q1_next = H ? higas_n : q1        ; HIENABN = QN = ~q1                                 **
**     INT_REQ_ENABLE_FF:  Q=q2 (int_req_q),  D-in=E, TI=q2 (self-hold), TE=D                       **
**        -> q2_next = D ? q2 : E                                                                   **
**   Combinational outputs (functions of q1,q2 + inputs):                                          **
**     hipassall_n = NAND3(HIVGES,HIDET,q1)      HIPASSALL = ~hipassall_n = HIVGES&HIDET&q1         **
**     HVE  = AND(~hipassall_n, ~S)   = HIPASSALL & ~S           (GATES_7, both inputs bubbled)     **
**     higas_n = NAND4(HVE,HIVEC2,HIVEC1,HIVEC0)  HIGAS = ~higas_n                                  **
**     hidet_nand_hivges = NAND(HIDET,HIVGES)                                                       **
**     PD  = OR(~HIGSN, ~hidet_nand_hivges) = ~HIGSN | (HIDET&HIVGES)     (GATES_4, both bubbled)   **
**     RDN = NOR3(~q1, ~HIGSN, ~hidet_nand_hivges) = q1 & HIGSN & hidet_nand_hivges  (all bubbled)  **
**     HIRQ = AND(~hipassall_n, ~int_req_qn) = HIPASSALL & q2          (GATES_6, both bubbled)      **
**   Note: TI of STATUS_OVERFLOW_FF (higas_n) itself depends on q1 through HVE -> higas_n; the      **
**   shadow models that ordering exactly.                                                          **
**                                                                                               **
** Self-checking: independent shadow of {q1,q2} + independent comb equations, clocked in lockstep. **
** Directed named scenarios (HIPASSALL gen, HVE gen, status-overflow self-hold, int-req load/hold, **
** PD/RDN) PLUS exhaustive 2-pass lockstep sweep over all 1024 input combinations.                 **
**                                                                                               **
** Teeth: -DTEETH_TEST corrupts one compared output -> harness MUST report FAIL.                   **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_hirl -y Shared/logisim -y Shared/support -y Shared/ndlib \        **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL_HIRL.v \                                  **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRGEL_HIRL_tb.v && vvp /tmp/tb_hirl                 **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRGEL_HIRL_tb;

  reg sysclk = 0;
  reg MCLK_EN = 0;

  reg       D = 0;
  reg       E = 0;
  reg       H = 0;
  reg       HIDET = 0;
  reg       HIGSN = 1;
  reg [2:0] HIVEC_2_0 = 0;
  reg       HIVGES = 0;
  reg       MCLK = 0;
  reg       S = 0;

  wire HIENABN, HIGAS, HIPASSALL, HIRQ, HVE, PD, RDN;

  CGA_INTR_CNTLR_IRGEL_HIRL dut (
      .sysclk   (sysclk),
      .MCLK_EN  (MCLK_EN),
      .D        (D),
      .E        (E),
      .H        (H),
      .HIDET    (HIDET),
      .HIGSN    (HIGSN),
      .HIVEC_2_0(HIVEC_2_0),
      .HIVGES   (HIVGES),
      .MCLK     (MCLK),
      .S        (S),
      .HIENABN  (HIENABN),
      .HIGAS    (HIGAS),
      .HIPASSALL(HIPASSALL),
      .HIRQ     (HIRQ),
      .HVE      (HVE),
      .PD       (PD),
      .RDN      (RDN)
  );

  integer errors = 0;
  integer checks = 0;

  reg q1, q2;   // independent shadow state (s_hidis_n, int_req_q)

  // ---- Independent comb functions of shadow state + inputs ----
  function automatic e_hipassall; input a_q1; begin e_hipassall = HIVGES & HIDET & a_q1; end endfunction
  function automatic e_hve;       input a_q1; input a_q2; begin e_hve = e_hipassall(a_q1) & ~S & a_q2; end endfunction
  function automatic e_higas_n;   input a_q1; input a_q2;
    begin e_higas_n = ~(e_hve(a_q1, a_q2) & HIVEC_2_0[2] & HIVEC_2_0[1] & HIVEC_2_0[0]); end
  endfunction
  function automatic e_higas;     input a_q1; input a_q2; begin e_higas = ~e_higas_n(a_q1, a_q2); end endfunction
  function automatic e_hidnh;     input dummy; begin e_hidnh = ~(HIDET & HIVGES); end endfunction
  function automatic e_pd;        input dummy; begin e_pd = (~HIGSN) | (HIDET & HIVGES); end endfunction
  function automatic e_rdn;       input a_q1; begin e_rdn = a_q1 & HIGSN & (~(HIDET & HIVGES)); end endfunction
  function automatic e_hienabn;   input a_q1; begin e_hienabn = ~a_q1; end endfunction
  function automatic e_hirq;      input a_q1; input a_q2; begin e_hirq = e_hipassall(a_q1) & a_q2; end endfunction

  reg eHIENABN, eHIGAS, eHIPASSALL, eHIRQ, eHVE, ePD, eRDN;

  task compute_expected;
    begin
      eHIPASSALL = e_hipassall(q1);
      eHVE       = e_hve(q1, q2);
      eHIGAS     = e_higas(q1, q2);
      ePD        = e_pd(0);
      eRDN       = e_rdn(q1);
      eHIENABN   = e_hienabn(q1);
      eHIRQ      = e_hirq(q1, q2);
    end
  endtask

  task do_compare(input [127:0] what);
    begin
      compute_expected;
`ifdef TEETH_TEST
      eHVE = ~eHVE;   // corrupt one output -> harness must FAIL
`endif
      checks = checks + 1;
      if ({HIENABN,HIGAS,HIPASSALL,HIRQ,HVE,PD,RDN} !==
          {eHIENABN,eHIGAS,eHIPASSALL,eHIRQ,eHVE,ePD,eRDN}) begin
        errors = errors + 1;
        $display("FAIL %0s in{D=%b E=%b H=%b HIDET=%b HIGSN=%b HIVEC=%0d HIVGES=%b S=%b} q1=%b q2=%b",
                 what, D,E,H,HIDET,HIGSN,HIVEC_2_0,HIVGES,S,q1,q2);
        $display("     exp HIENABN=%b HIGAS=%b HIPASSALL=%b HIRQ=%b HVE=%b PD=%b RDN=%b",
                 eHIENABN,eHIGAS,eHIPASSALL,eHIRQ,eHVE,ePD,eRDN);
        $display("     got HIENABN=%b HIGAS=%b HIPASSALL=%b HIRQ=%b HVE=%b PD=%b RDN=%b",
                 HIENABN,HIGAS,HIPASSALL,HIRQ,HVE,PD,RDN);
      end
    end
  endtask

  // Pulse MCLK; update shadow state using pre-edge inputs+state; then compare comb outputs.
  task clk_and_check(input [127:0] what);
    reg n1, n2;
    begin
      n1 = H ? e_higas_n(q1, q2) : q1;   // STATUS_OVERFLOW_FF: TE=H, TI=higas_n, D=q1(self-hold)
      n2 = D ? q2 : E;               // INT_REQ_ENABLE_FF: TE=D, TI=q2(self-hold), D-in=E
      MCLK = 0; #2;
      MCLK = 1; #2;
      MCLK = 0; #2;
      q1 = n1;
      q2 = n2;
      do_compare(what);
    end
  endtask

  integer i, pass;
  reg nm_hipassall, nm_hve, nm_selfhold, nm_intreq, nm_pd, nm_rdn;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRGEL_HIRL_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRGEL_HIRL_tb);

    q1 = 1'b0; q2 = 1'b0;
    D=0; E=0; H=0; HIDET=0; HIGSN=1; HIVEC_2_0=0; HIVGES=0; S=0;
    #2;

    // ---- Named: load q1 via H (scan TI=higas_n), then observe HIPASSALL/HVE ----
    // First force q1=1: need higas_n=1 loaded. higas_n=~(HVE & HIVEC). With HVE=0 (q1 currently 0)
    // higas_n=1, so H=1 loads q1<=1.
    HIVGES=1; HIDET=1; S=0; HIVEC_2_0=3'b111; H=1; D=1; E=0;
    clk_and_check("load q1 via H");
    nm_hipassall = (HIPASSALL === 1'b1);          // HIVGES&HIDET&q1 = 1
    nm_hve       = (HVE === 1'b1);                 // HIPASSALL & ~S = 1

    // ---- Named: HVE must drop when S asserted ----
    H=0; D=1; S=1;
    clk_and_check("HVE drops on S");
    nm_hve = nm_hve & (HVE === 1'b0);

    // ---- Named: STATUS_OVERFLOW self-hold (H=0 -> q1 holds across clocks) ----
    S=0; H=0; D=1;
    nm_selfhold = 1'b1;
    clk_and_check("selfhold#1"); if (HIPASSALL !== 1'b1) nm_selfhold = 1'b0;
    clk_and_check("selfhold#2"); if (HIPASSALL !== 1'b1) nm_selfhold = 1'b0;

    // ---- Named: INT_REQ load (D=0 loads E) then hold (D=1) -> observed via HIRQ ----
    // q1 currently 1, HIVGES=HIDET=1,S=0 -> HIPASSALL=1 so HIRQ mirrors q2.
    D=0; E=1;
    clk_and_check("intreq load E=1");
    nm_intreq = (HIRQ === 1'b1);                   // q2 loaded 1
    D=1; E=0;
    clk_and_check("intreq hold");
    nm_intreq = nm_intreq & (HIRQ === 1'b1);       // held 1 despite E=0
    D=0; E=0;
    clk_and_check("intreq load E=0");
    nm_intreq = nm_intreq & (HIRQ === 1'b0);       // q2 loaded 0

    // ---- Named: PD = ~HIGSN | (HIDET&HIVGES) ----
    HIGSN=1; HIDET=0; HIVGES=0;
    clk_and_check("pd case a"); nm_pd = (PD === 1'b0);
    HIGSN=0;
    clk_and_check("pd case b"); nm_pd = nm_pd & (PD === 1'b1);
    HIGSN=1; HIDET=1; HIVGES=1;
    clk_and_check("pd case c"); nm_pd = nm_pd & (PD === 1'b1);

    // ---- Named: RDN = q1 & HIGSN & ~(HIDET&HIVGES) ----
    // q1=1 (still held). HIGSN=1, HIDET&HIVGES currently 1 -> RDN=0.
    clk_and_check("rdn case a"); nm_rdn = (RDN === 1'b0);
    HIDET=0; HIVGES=0; HIGSN=1;   // ~(HIDET&HIVGES)=1, q1=1, HIGSN=1 -> RDN=1
    clk_and_check("rdn case b"); nm_rdn = nm_rdn & (RDN === 1'b1);

    // ---- Exhaustive lockstep sweep over all 1024 input combos, 2 passes ----
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (i = 0; i < 1024; i = i + 1) begin
        {D, E, H, HIDET, HIGSN, HIVGES, S, HIVEC_2_0} = i[9:0];
        clk_and_check("sweep");
      end
    end

    $display("named: hipassall=%b hve=%b selfhold=%b intreq=%b pd=%b rdn=%b",
             nm_hipassall, nm_hve, nm_selfhold, nm_intreq, nm_pd, nm_rdn);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
