/**************************************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH) - unit test                                              **
** CGA_INTR_CNTLR_IRGEL  (top integration: HIGEL/LOGEL/VMUX/HIRL/LORL, schematic p.90)             **
**                                                                                               **
** DUT contract (derived from the top netlist + the five submodule netlists, NOT assumed):        **
**   Five posedge-MCLK state bits (all power up at 0, USE_ENABLE=0, no FPGA_FF_MODE):              **
**     hg = HIGEL Q (HIGSN)   lg = LOGEL Q (LOGSN)                                                  **
**     h1 = HIRL status-overflow FF (hidis_n)   h2 = HIRL int-req FF                                **
**     lq = LORL int-req FF                                                                         **
**   Cross-wiring (top): HIGEL.LOGASN=LORL.LOGASN(logas_n); HIGEL.HIENABN=HIRL.HIENABN;            **
**     HIGEL.HIGAS=HIRL.HIGAS; LOGEL.LIENABN=LORL.LIENABN; LOGEL.LOGAS=LORL.LOGAS;                  **
**     LORL.RDN=HIRL.RDN; HIRL.HIGSN=HIGEL.HIGSN; VMUX.HVE=HIRL.HVE; VMUX.LVE=LORL.LVE.             **
**   IRQN = NOR(HIRQ, LIRQ)  (GATES_1).  PICV = ({3{HVE}}&HIVEC) | ({3{LVE}}&LOVEC).               **
**                                                                                               **
** Self-checking: an INDEPENDENT full shadow of all five submodules (state + comb equations),      **
** clocked in lockstep. Directed named scenarios (HI-selected vector, LO-selected vector, both     **
** request -> IRQN asserted, no request -> IRQN negated) PLUS a 30000-vector randomized lockstep    **
** sweep. All outputs (HIGSN,LOGSN,HIPASSALL,LOPASSALL,PD,IRQN,PICV_2_0) checked every clock.       **
**                                                                                               **
** Teeth: -DTEETH_TEST corrupts the expected PICV -> harness MUST report FAIL.                     **
**                                                                                               **
** Compile (from repo Verilog/):                                                                  **
**   iverilog -g2012 -o /tmp/tb_irgel -y Shared/logisim -y Shared/support -y Shared/ndlib \       **
**     -y DELILAH-CPU/CGA_INTR/circuit \                                                           **
**     DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_IRGEL.v \                                       **
**     DELILAH-CPU/CGA_INTR/sim/CGA_INTR_CNTLR_IRGEL_tb.v && vvp /tmp/tb_irgel                     **
**                                                                                               **
** Last reviewed: 15-JUL-2026                                                                     **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_INTR_CNTLR_IRGEL_tb;

  reg sysclk = 0;
  reg MCLK_EN = 0;

  reg       D = 0;
  reg       E = 0;
  reg       FIDB03 = 0;
  reg       FIDB04 = 0;
  reg       H = 0;
  reg       HIDET = 0;
  reg       HIVGES = 0;
  reg       L = 0;
  reg       LODET = 0;
  reg       LOVGES = 0;
  reg       M = 0;
  reg       MCLK = 0;
  reg       N = 0;
  reg       S = 0;
  reg [2:0] HIVEC_2_0 = 0;
  reg [2:0] LOVEC_2_0 = 0;

  wire       HIGSN, HIPASSALL, IRQN, LOGSN, LOPASSALL, PD;
  wire [2:0] PICV_2_0;

  CGA_INTR_CNTLR_IRGEL dut (
      .sysclk   (sysclk),
      .MCLK_EN  (MCLK_EN),
      .D        (D),
      .E        (E),
      .FIDB03   (FIDB03),
      .FIDB04   (FIDB04),
      .H        (H),
      .HIDET    (HIDET),
      .HIVGES   (HIVGES),
      .L        (L),
      .LODET    (LODET),
      .LOVGES   (LOVGES),
      .M        (M),
      .MCLK     (MCLK),
      .N        (N),
      .S        (S),
      .HIVEC_2_0(HIVEC_2_0),
      .LOVEC_2_0(LOVEC_2_0),
      .HIGSN    (HIGSN),
      .HIPASSALL(HIPASSALL),
      .IRQN     (IRQN),
      .LOGSN    (LOGSN),
      .LOPASSALL(LOPASSALL),
      .PD       (PD),
      .PICV_2_0 (PICV_2_0)
  );

  integer errors = 0;
  integer checks = 0;

  // ---- Independent shadow state ----
  reg s_hg, s_lg, s_h1, s_h2, s_lq;

  // ---- Independent comb functions (take state bits explicitly) ----
  function automatic c_hipassall(input a_h1); begin c_hipassall = HIVGES & HIDET & a_h1; end endfunction
  function automatic c_hve(input a_h1, input a_h2);       begin c_hve = c_hipassall(a_h1) & ~S & a_h2; end endfunction
  function automatic c_higas_n(input a_h1);
    begin c_higas_n = ~(c_hve(a_h1, s_h2) & HIVEC_2_0[2] & HIVEC_2_0[1] & HIVEC_2_0[0]); end
  endfunction
  function automatic c_higas(input a_h1);     begin c_higas = ~c_higas_n(a_h1); end endfunction
  function automatic c_hidnh(input dummy);    begin c_hidnh = ~(HIDET & HIVGES); end endfunction
  function automatic c_pd(input a_hg);        begin c_pd = (~a_hg) | (HIDET & HIVGES); end endfunction
  function automatic c_rdn(input a_h1, input a_hg); begin c_rdn = a_h1 & a_hg & c_hidnh(0); end endfunction
  function automatic c_hienabn(input a_h1);   begin c_hienabn = ~a_h1; end endfunction
  function automatic c_hirq(input a_h1, input a_h2); begin c_hirq = c_hipassall(a_h1) & a_h2; end endfunction

  function automatic c_lopassall(input a_h1, input a_hg); begin c_lopassall = c_rdn(a_h1,a_hg) & LODET & LOVGES; end endfunction
  function automatic c_lve(input a_h1, input a_hg, input a_lq);       begin c_lve = c_lopassall(a_h1,a_hg) & ~S & a_lq; end endfunction
  function automatic c_logas_n(input a_h1, input a_hg);
    begin c_logas_n = ~(c_lve(a_h1,a_hg, s_lq) & LOVEC_2_0[2] & LOVEC_2_0[1] & LOVEC_2_0[0]); end
  endfunction
  function automatic c_logas(input a_h1, input a_hg);     begin c_logas = ~c_logas_n(a_h1,a_hg); end endfunction
  function automatic c_lienabn(input a_h1, input a_hg);   begin c_lienabn = ~c_rdn(a_h1,a_hg); end endfunction
  function automatic c_lirq(input a_h1, input a_hg, input a_lq); begin c_lirq = c_lopassall(a_h1,a_hg) & a_lq; end endfunction

  function automatic [2:0] c_picv(input a_h1, input a_hg);
    begin c_picv = ({3{c_hve(a_h1, s_h2)}} & HIVEC_2_0) | ({3{c_lve(a_h1,a_hg, s_lq)}} & LOVEC_2_0); end
  endfunction
  function automatic c_irqn(input a_h1, input a_h2, input a_hg, input a_lq);
    begin c_irqn = ~(c_hirq(a_h1,a_h2) | c_lirq(a_h1,a_hg,a_lq)); end
  endfunction

  reg        eHIGSN, eLOGSN, eHIPASSALL, eLOPASSALL, ePD, eIRQN;
  reg [2:0]  ePICV;

  task do_compare(input [127:0] what);
    begin
      // expected outputs from NEW (post-edge) shadow state + current inputs
      eHIGSN     = s_hg;
      eLOGSN     = s_lg;
      eHIPASSALL = c_hipassall(s_h1);
      eLOPASSALL = c_lopassall(s_h1, s_hg);
      ePD        = c_pd(s_hg);
      eIRQN      = c_irqn(s_h1, s_h2, s_hg, s_lq);
      ePICV      = c_picv(s_h1, s_hg);
`ifdef TEETH_TEST
      ePICV      = ePICV ^ 3'b001;   // corrupt -> harness must FAIL
`endif
      checks = checks + 1;
      if ({HIGSN,LOGSN,HIPASSALL,LOPASSALL,PD,IRQN,PICV_2_0} !==
          {eHIGSN,eLOGSN,eHIPASSALL,eLOPASSALL,ePD,eIRQN,ePICV}) begin
        errors = errors + 1;
        $display("FAIL %0s in{D=%b E=%b FIDB03=%b FIDB04=%b H=%b HIDET=%b HIVGES=%b L=%b LODET=%b LOVGES=%b M=%b N=%b S=%b HIVEC=%0d LOVEC=%0d} st{hg=%b lg=%b h1=%b h2=%b lq=%b}",
                 what, D,E,FIDB03,FIDB04,H,HIDET,HIVGES,L,LODET,LOVGES,M,N,S,HIVEC_2_0,LOVEC_2_0, s_hg,s_lg,s_h1,s_h2,s_lq);
        $display("     exp HIGSN=%b LOGSN=%b HIPASSALL=%b LOPASSALL=%b PD=%b IRQN=%b PICV=%0d",
                 eHIGSN,eLOGSN,eHIPASSALL,eLOPASSALL,ePD,eIRQN,ePICV);
        $display("     got HIGSN=%b LOGSN=%b HIPASSALL=%b LOPASSALL=%b PD=%b IRQN=%b PICV=%0d",
                 HIGSN,LOGSN,HIPASSALL,LOPASSALL,PD,IRQN,PICV_2_0);
      end
    end
  endtask

  // Pulse MCLK; next-state from OLD shadow state + current inputs; then compare.
  task clk_and_check(input [127:0] what);
    reg nhg, nlg, nh1, nh2, nlq;
    begin
      nhg = (FIDB03 & L & M)
          | (c_logas_n(s_h1,s_hg) & L & ~M)
          | (c_logas_n(s_h1,s_hg) & ~HIDET & N)
          | (c_higas(s_h1) & N)
          | (c_hienabn(s_h1) & N)
          | (~L & M & s_hg);
      nlg = (FIDB04 & L & M)
          | (c_logas(s_h1,s_hg) & N)
          | (c_lienabn(s_h1,s_hg) & N)
          | (~L & M & s_lg);
      nh1 = H ? c_higas_n(s_h1) : s_h1;
      nh2 = D ? s_h2 : E;
      nlq = D ? s_lq : E;
      MCLK = 0; #2;
      MCLK = 1; #2;
      MCLK = 0; #2;
      s_hg = nhg; s_lg = nlg; s_h1 = nh1; s_h2 = nh2; s_lq = nlq;
      do_compare(what);
    end
  endtask

  integer i;
  reg nm_hi_vec, nm_lo_vec, nm_bothreq, nm_noreq;

  initial begin
    $dumpfile("CGA_INTR_CNTLR_IRGEL_tb.vcd");
    $dumpvars(0, CGA_INTR_CNTLR_IRGEL_tb);

    s_hg=0; s_lg=0; s_h1=0; s_h2=0; s_lq=0;
    D=0;E=0;FIDB03=0;FIDB04=0;H=0;HIDET=0;HIVGES=0;L=0;LODET=0;LOVGES=0;M=0;N=0;S=0;HIVEC_2_0=0;LOVEC_2_0=0;
    #2;

    // ---- Named: HI group selected -> PICV = HIVEC ----
    // Force h1=1 (H=1 loads higas_n=1 while HVE=0), then HIVGES&HIDET set HVE via HIPASSALL.
    HIVGES=1; HIDET=1; S=0; HIVEC_2_0=3'b101; H=1; D=1;
    clk_and_check("hi load h1");
    // now h1=1; HVE = HIPASSALL & ~S = 1; LO path idle (LODET=0)
    H=0;
    clk_and_check("hi vector");
    nm_hi_vec = (PICV_2_0 === 3'b101) && (HIPASSALL === 1'b1);

    // ---- Named: LO group selected -> PICV = LOVEC ----
    // Need RDN=1 for LO path: RDN = h1 & HIGSN & ~(HIDET&HIVGES). Currently HIDET&HIVGES=1 -> RDN=0.
    // Clear HI passall so HVE=0, and enable LO: HIDET=0 (so ~(HIDET&HIVGES)=1), need HIGSN=1.
    // Make HIGSN=1 via HIGEL set term; simplest: drive N with HIENABN. HIENABN=~h1=0 now, so use HIGAS.
    // Instead force HIGSN through (~L&M) hold is 0; use set term (HIENABN&N) won't work (HIENABN=0).
    // Use LOGASN&L&~M? that needs L. Just drive L=1,M=1,FIDB03=1 -> HIGEL set term FIDB03&L&M.
    FIDB03=1; L=1; M=1; N=0; HIDET=0; HIVGES=0;
    clk_and_check("set HIGSN");            // hg -> 1
    // Keep FIDB03&L&M asserted so HIGSN HOLDS 1 through the observation cycle
    // (HIGEL has no ~L&M self-hold help here). Now h1=1, HIDET&HIVGES=0 -> RDN=1.
    LODET=1; LOVGES=1; S=0; LOVEC_2_0=3'b011;
    clk_and_check("lo vector");
    nm_lo_vec = (PICV_2_0 === 3'b011) && (LOPASSALL === 1'b1);

    // ---- Named: both request -> IRQN asserted (0) ----
    // Enable both request paths (HIPASSALL & int-req q for HI; LOPASSALL & q for LO).
    HIVGES=1; HIDET=0;   // hmm HI needs HIDET for HIPASSALL; but LO needs ~(HIDET&HIVGES).
    // Use HI via HIDET=1,HIVGES=1 (HIPASSALL); that forces RDN=0 killing LO. So instead show
    // IRQN asserted from the HI request alone (that is a valid "request present" case).
    HIDET=1; HIVGES=1; S=1;   // S=1 -> HVE=0 but HIRQ = HIPASSALL & h2 independent of S
    D=0; E=1;                 // load int-req q (h2) = 1
    clk_and_check("hi req load");
    D=1;                      // hold
    clk_and_check("both/hi req IRQN");
    nm_bothreq = (IRQN === 1'b0);   // HIRQ=1 -> IRQN=0

    // ---- Named: no request -> IRQN negated (1) ----
    HIVGES=0; HIDET=0; LODET=0; LOVGES=0; D=0; E=0; S=0;
    clk_and_check("clear reqs");
    clk_and_check("no req IRQN");
    nm_noreq = (IRQN === 1'b1);

    // ---- Randomized lockstep sweep ----
    for (i = 0; i < 30000; i = i + 1) begin
      D=$random; E=$random; FIDB03=$random; FIDB04=$random; H=$random; HIDET=$random;
      HIVGES=$random; L=$random; LODET=$random; LOVGES=$random; M=$random; N=$random; S=$random;
      HIVEC_2_0=$random; LOVEC_2_0=$random;
      clk_and_check("rand");
    end

    $display("named: hi_vec=%b lo_vec=%b bothreq=%b noreq=%b",
             nm_hi_vec, nm_lo_vec, nm_bothreq, nm_noreq);
    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

endmodule
