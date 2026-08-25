/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_ALU top-level testbench (INTEGRATION / WIRING MAP)                **
**                                                                       **
** SCOPE - read this before trusting the verdict.                        **
** CGA_ALU.v is pure integration: it instantiates thirteen sub-circuits  **
** (RALU, SHIFT, STS, GPR, DBR, ARG, SWAP, OUTMUX, QREG, RMUX, SMUX,     **
** CONTR and one MUX21LP + one D_FLIPFLOP_EN) and wires them together.   **
** Reproducing what the ALU computes would mean re-modelling the whole   **
** microcode decoder CGA_CPU_ALU_CONTR, and that model would be a copy   **
** of the RTL rather than an independent reference - so this testbench   **
** does NOT attempt it. Each sub-circuit has its own testbench in this   **
** same directory (CGA_ALU_ARG_tb, CGA_ALU_DBR_tb, CGA_ALU_QREG_tb,      **
** CGA_ALU_SHIFT_tb, CGA_ALU_SMUX_tb, CGA_ALU_STS_tb, CGA_ALU_SWAP_tb,   **
** CGA_CPU_ALU_CONTR_tb, CGA_CPU_ALU_RMUX_tb, CGA_CPU_ALU_RALU_tb,       **
** CGA_ALU_OUTMUX_tb, CGA_ALU_GPR_tb).                                   **
**                                                                       **
** What IS verified here, and it is the thing CGA_ALU.v alone can get    **
** wrong: the wiring map. Every check below asserts that a named DUT     **
** port, or a named sub-circuit port, carries exactly the signal the     **
** netlist says it should. A single crossed port connection at this      **
** level - the exact bug class this project keeps finding - fails.       **
** This is double-entry bookkeeping against                              **
** Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU.v: the map was            **
** transcribed from that file, so it is a REGRESSION guard (a future     **
** Logisim regeneration or hand edit that rewires a port fails at once)  **
** rather than proof that the original schematic transcription was       **
** right. Stated plainly so nobody over-reads the PASS.                  **
**                                                                       **
** Real logic that IS modelled independently here:                       **
**   - MEMORY_1 registers CSIDBS_4_0[2] on the ALUCLK edge -> s_sel_idbs2
**   - AARG0_MUX (MUX21LP, A=LBA_3_0[3], B=LAA_3_0[0], S=s_sel_idbs2,    **
**     output ZN inverted again by CGA_ALU.v) gives                      **
**         s_aarg0 = s_sel_idbs2 ? LAA_3_0[0] : LBA_3_0[3]               **
**   - FIDBO_15_0_OUT = ~ALU_OUTMUX.G_15_0 (the inversion lives in       **
**     CGA_ALU.v itself, not in OUTMUX)                                  **
**   - the six STS taps: DOUBLE=STS[13] IONI=STS[15] PONI=STS[14]        **
**     PTM=STS[0] Z=STS[3] PIL_3_0=STS[11:8]                             **
**   - F11 / F15 taken from the RALU result bus                          **
**                                                                       **
** Test plan:                                                            **
**   1. warm-up clocks so no storage element is still undefined          **
**   2. 128 fixed-seed pseudo-random microcode words: every input bus    **
**      driven, one ALUCLK edge per vector, and after each edge the full **
**      wiring map (79 assertions) plus the modelled logic is checked    **
**   3. an all-outputs X-freedom check on every vector - if any output   **
**      of CGA_ALU goes to X after warm-up the test fails                **
**                                                                       **
** Registered sub-circuits (FPGA_FF_MODE switches R81_EN / SCAN_FF_EN /  **
** D_FLIPFLOP_EN): the Makefile target test-alu-top runs this twice,     **
** default latch/CP mode and -DFPGA_FF_MODE, and both must PASS.         **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_ALU/sim && make test-alu-top             **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_ALU_tb;

  reg         sysclk = 0;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg  [15:0] A_15_0 = 0;
  reg  [15:0] B_15_0 = 0;
  reg  [15:0] CD_15_0 = 0;
  reg  [ 8:0] CSALUI_8_0 = 0;
  reg  [ 1:0] CSALUM_1_0 = 0;
  reg  [15:0] CSBIT_15_0 = 0;
  reg  [ 1:0] CSCINSEL_1_0 = 0;
  reg  [ 4:0] CSIDBS_4_0 = 0;
  reg  [ 1:0] CSMIS_1_0 = 0;
  reg  [ 1:0] CSSST_1_0 = 0;
  reg  [15:0] EA_15_0 = 0;
  reg  [15:0] FIDBI_15_0 = 0;
  reg  [ 3:0] LAA_3_0 = 0;
  reg  [ 3:0] LBA_3_0 = 0;
  reg         LCZN = 1;
  reg         LDDBRN = 1;
  reg         LDGPRN = 1;
  reg         LDIRV = 0;
  reg         LDPILN = 1;
  reg         UPN = 1;
  reg         XFETCHN = 1;

  wire        BDEST, CRY, DOUBLE, F11, F15, IONI, MI, OVF, PONI, PTM, SGR, Z, ZF;
  wire [15:0] FIDBO_15_0_OUT, RB_15_0;
  wire [ 3:0] PIL_3_0;

  integer errors = 0;
  integer checks = 0;
  integer i;
  reg [31:0] lfsr;
  reg        m_sel_idbs2;

  CGA_ALU dut (
      .sysclk      (sysclk),
      .sys_rst_n   (1'b1),
      .ALUCLK_EN   (ALUCLK_EN),
      .ALUCLK      (ALUCLK),
      .A_15_0      (A_15_0),
      .B_15_0      (B_15_0),
      .CD_15_0     (CD_15_0),
      .CSALUI_8_0  (CSALUI_8_0),
      .CSALUM_1_0  (CSALUM_1_0),
      .CSBIT_15_0  (CSBIT_15_0),
      .CSCINSEL_1_0(CSCINSEL_1_0),
      .CSIDBS_4_0  (CSIDBS_4_0),
      .CSMIS_1_0   (CSMIS_1_0),
      .CSSST_1_0   (CSSST_1_0),
      .EA_15_0     (EA_15_0),
      .FIDBI_15_0  (FIDBI_15_0),
      .LAA_3_0     (LAA_3_0),
      .LBA_3_0     (LBA_3_0),
      .LCZN        (LCZN),
      .LDDBRN      (LDDBRN),
      .LDGPRN      (LDGPRN),
      .LDIRV       (LDIRV),
      .LDPILN      (LDPILN),
      .UPN         (UPN),
      .XFETCHN     (XFETCHN),
      .BDEST       (BDEST),
      .CRY         (CRY),
      .DOUBLE      (DOUBLE),
      .F11         (F11),
      .F15         (F15),
      .FIDBO_15_0_OUT(FIDBO_15_0_OUT),
      .IONI        (IONI),
      .MI          (MI),
      .OVF         (OVF),
      .PIL_3_0     (PIL_3_0),
      .PONI        (PONI),
      .PTM         (PTM),
      .RB_15_0     (RB_15_0),
      .SGR         (SGR),
      .Z           (Z),
      .ZF          (ZF)
  );

  always #5 sysclk = ~sysclk;

  initial begin
    $dumpfile("CGA_ALU_tb.vcd");
    $dumpvars(0, CGA_ALU_tb);
  end

  task chk(input [255:0] name, input [15:0] got, input [15:0] exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("FAIL %0s: got %04h exp %04h (vector %0d)", name, got, exp, i);
      end
    end
  endtask

  // ---- the wiring map, transcribed from CGA_ALU.v ----------------------
  task check_map;
    begin
      // -- CGA_ALU input ports reaching their sub-circuits --
      chk("GPR.CD",        dut.ALU_GPR.CD_15_0,       CD_15_0);
      chk("DBR.CD",        dut.ALU_DBR.CD_15_0,       CD_15_0);
      chk("CONTR.CD_10_9", dut.ALU_CONTR.CD_10_9,     CD_15_0[10:9]);
      chk("ARG.CSBIT",     dut.ALU_ARG.CSBIT_15_0,    CSBIT_15_0);
      chk("OUTMUX.FIDBI",  dut.ALU_OUTMUX.FIDBI_15_0, FIDBI_15_0);
      chk("OUTMUX.EA",     dut.ALU_OUTMUX.EA_15_0,    EA_15_0);
      chk("OUTMUX.A",      dut.ALU_OUTMUX.A_15_0,     A_15_0);
      chk("SMUX.A",        dut.ALU_SMUX.A_15_0,       A_15_0);
      chk("SMUX.B",        dut.ALU_SMUX.B_15_0,       B_15_0);
      chk("RMUX.A",        dut.ALU_RMUX.A_15_0,       A_15_0);
      chk("OUTMUX.CSIDBS", dut.ALU_OUTMUX.CSIDBS_4_0, CSIDBS_4_0);
      chk("OUTMUX.LAA_3_1",dut.ALU_OUTMUX.LAA_3_1,    LAA_3_0[3:1]);
      chk("OUTMUX.LBA_2_0",dut.ALU_OUTMUX.LBA_2_0,    LBA_3_0[2:0]);
      chk("CONTR.CSALUI",  dut.ALU_CONTR.CSALUI_8_0,  CSALUI_8_0);
      chk("CONTR.CSALUM",  dut.ALU_CONTR.CSALUM_1_0,  CSALUM_1_0);
      chk("CONTR.CSCINSEL",dut.ALU_CONTR.CSCINSEL_1_0,CSCINSEL_1_0);
      chk("CONTR.CSMIS",   dut.ALU_CONTR.CSMIS_1_0,   CSMIS_1_0);
      chk("CONTR.CSSST",   dut.ALU_CONTR.CSSST_1_0,   CSSST_1_0);
      chk("CONTR.UPN",     dut.ALU_CONTR.UPN,         UPN);
      chk("CONTR.XFETCHN", dut.ALU_CONTR.XFETCHN,     XFETCHN);
      chk("CONTR.LDGPRN",  dut.ALU_CONTR.LDGPRN,      LDGPRN);
      chk("CONTR.LDIRV",   dut.ALU_CONTR.LDIRV,       LDIRV);
      chk("CONTR.LCZN",    dut.ALU_CONTR.LCZN,        LCZN);
      chk("STS.LDPILN",    dut.ALU_STS.LDPILN,        LDPILN);
      chk("DBR.LDDBRN",    dut.ALU_DBR.LDDBRN,        LDDBRN);

      // -- sub-circuit to sub-circuit --
      chk("SHIFT.F  <- RALU.F",   dut.ALU_SHIFT.F_15_0,   dut.ALU_RALU.F_15_0);
      chk("QREG.F   <- RALU.F",   dut.ALU_QREG.F_15_0,    dut.ALU_RALU.F_15_0);
      chk("CONTR.F0 <- RALU.F0",  dut.ALU_CONTR.F0,       dut.ALU_RALU.F_15_0[0]);
      chk("CONTR.F15<- RALU.F15", dut.ALU_CONTR.F15,      dut.ALU_RALU.F_15_0[15]);
      chk("STS.FIDBO",            dut.ALU_STS.FIDBO_15_0, FIDBO_15_0_OUT);
      chk("GPR.FIDBO",            dut.ALU_GPR.FIDBO_15_0, FIDBO_15_0_OUT);
      chk("SWAP.FIDBO",           dut.ALU_SWAP.FIDBO_15_0,FIDBO_15_0_OUT);
      chk("RMUX.D <- OUTMUX.D",   dut.ALU_RMUX.D_15_0,    dut.ALU_OUTMUX.D_15_0);
      chk("SMUX.Q <- QREG.Q",     dut.ALU_SMUX.Q_15_0,    dut.ALU_QREG.Q_15_0);
      chk("RALU.RN <- RMUX.RN",   dut.ALU_RALU.RN_15_0,   dut.ALU_RMUX.RN_15_0);
      chk("RALU.S  <- SMUX.S",    dut.ALU_RALU.S_15_0,    dut.ALU_SMUX.S_15_0);
      chk("OUTMUX.GPR <- GPR",    dut.ALU_OUTMUX.GPR_15_0,dut.ALU_GPR.GPR_15_0);
      chk("OUTMUX.DBR <- DBR",    dut.ALU_OUTMUX.DBR_15_0,dut.ALU_DBR.DBR_15_0);
      chk("OUTMUX.ARG <- ARG",    dut.ALU_OUTMUX.ARG_15_0,dut.ALU_ARG.ARG_15_0);
      chk("OUTMUX.SW  <- SWAP",   dut.ALU_OUTMUX.SW_15_0, dut.ALU_SWAP.SW_15_0);
      chk("OUTMUX.STS <- STS",    dut.ALU_OUTMUX.STS_15_0,dut.ALU_STS.STS_15_0);
      chk("CONTR.GPR0",           dut.ALU_CONTR.GPR0,     dut.ALU_GPR.GPR_15_0[0]);
      chk("CONTR.DGPR0N",         dut.ALU_CONTR.DGPR0N,   dut.ALU_GPR.DGPR0N);
      chk("CONTR.Q0",             dut.ALU_CONTR.Q0,       dut.ALU_QREG.Q_15_0[0]);
      chk("CONTR.Q15",            dut.ALU_CONTR.Q15,      dut.ALU_QREG.Q_15_0[15]);
      chk("CONTR.STS6",           dut.ALU_CONTR.STS6,     dut.ALU_STS.STS_15_0[6]);
      chk("CONTR.STS7",           dut.ALU_CONTR.STS7,     dut.ALU_STS.STS_15_0[7]);
      chk("STS.CSTS <- CONTR",    dut.ALU_STS.CSTS_1_0,   dut.ALU_CONTR.CSTS_1_0);
      chk("GPR.GPRC <- CONTR",    dut.ALU_GPR.GPRC_2_0,   dut.ALU_CONTR.GPRC_2_0);
      chk("GPR.GPRLI <- CONTR",   dut.ALU_GPR.GPRLI,      dut.ALU_CONTR.GPRLI);
      chk("SHIFT.RLI <- CONTR",   dut.ALU_SHIFT.RLI,      dut.ALU_CONTR.RLI);
      chk("SHIFT.RRI <- CONTR",   dut.ALU_SHIFT.RRI,      dut.ALU_CONTR.RRI);
      chk("SHIFT.ALUI7 <- CONTR", dut.ALU_SHIFT.ALUI7,    dut.ALU_CONTR.ALUI7);
      chk("SHIFT.ALUI8N <- CONTR",dut.ALU_SHIFT.ALUI8N,   dut.ALU_CONTR.ALUI8N);
      chk("QREG.QLI <- CONTR",    dut.ALU_QREG.QLI,       dut.ALU_CONTR.QLI);
      chk("QREG.QSEL <- CONTR",   dut.ALU_QREG.QSEL_1_0,  dut.ALU_CONTR.QSEL_1_0);
      chk("RMUX.RA <- CONTR",     dut.ALU_RMUX.RA,        dut.ALU_CONTR.RA);
      chk("RMUX.RD <- CONTR.RD",  dut.ALU_RMUX.RD,        dut.ALU_CONTR.RD);
      chk("SMUX.SA <- CONTR",     dut.ALU_SMUX.SA,        dut.ALU_CONTR.SA);
      chk("SMUX.SB <- CONTR",     dut.ALU_SMUX.SB,        dut.ALU_CONTR.SB);
      chk("RALU.ALUI4 <- CONTR",  dut.ALU_RALU.ALUI4,     dut.ALU_CONTR.ALUI4);
      chk("RALU.CI <- CONTR",     dut.ALU_RALU.CI,        dut.ALU_CONTR.CI);
      chk("RALU.FSEL <- CONTR",   dut.ALU_RALU.FSEL,      dut.ALU_CONTR.FSEL);
      chk("RALU.LOG <- CONTR",    dut.ALU_RALU.LOG,       dut.ALU_CONTR.LOG);
      chk("RALU.RSN <- CONTR",    dut.ALU_RALU.RSN,       dut.ALU_CONTR.RSN);
      chk("OUTMUX.ALUD2N<-CONTR", dut.ALU_OUTMUX.ALUD2N,  dut.ALU_CONTR.ALUD2N);
      chk("STS.CRY <- RALU",      dut.ALU_STS.CRY,        dut.ALU_RALU.CRY);
      chk("STS.OVF <- RALU",      dut.ALU_STS.OVF,        dut.ALU_RALU.OVF);
      chk("STS.MI  <- CONTR",     dut.ALU_STS.MI,         dut.ALU_CONTR.MI);
      chk("CONTR.CRY <- RALU",    dut.ALU_CONTR.CRY,      dut.ALU_RALU.CRY);
      chk("OUTMUX.AARG0",         dut.ALU_OUTMUX.AARG0,   dut.s_aarg0);

      // -- CGA_ALU output taps --
      chk("BDEST tap",  BDEST,          dut.ALU_CONTR.BDEST);
      chk("CRY tap",    CRY,            dut.ALU_RALU.CRY);
      chk("OVF tap",    OVF,            dut.ALU_RALU.OVF);
      chk("SGR tap",    SGR,            dut.ALU_RALU.SGR);
      chk("ZF tap",     ZF,             dut.ALU_RALU.ZF);
      chk("MI tap",     MI,             dut.ALU_CONTR.MI);
      chk("RB tap",     RB_15_0,        dut.ALU_SHIFT.RB_15_0);
      chk("FIDBO inv",  FIDBO_15_0_OUT, ~dut.ALU_OUTMUX.G_15_0);
      chk("F11 tap",    F11,            dut.ALU_RALU.F_15_0[11]);
      chk("F15 tap",    F15,            dut.ALU_RALU.F_15_0[15]);
      chk("DOUBLE tap", DOUBLE,         dut.ALU_STS.STS_15_0[13]);
      chk("IONI tap",   IONI,           dut.ALU_STS.STS_15_0[15]);
      chk("PONI tap",   PONI,           dut.ALU_STS.STS_15_0[14]);
      chk("PTM tap",    PTM,            dut.ALU_STS.STS_15_0[0]);
      chk("Z tap",      Z,              dut.ALU_STS.STS_15_0[3]);
      chk("PIL tap",    PIL_3_0,        dut.ALU_STS.STS_15_0[11:8]);

      // -- modelled logic: the registered AARG0 selector --
      chk("sel_idbs2 register", dut.s_sel_idbs2, m_sel_idbs2);
      chk("AARG0 mux", dut.s_aarg0, m_sel_idbs2 ? LAA_3_0[0] : LBA_3_0[3]);

      // -- X-freedom of every CGA_ALU output --
      checks = checks + 1;
      if (^{BDEST, CRY, DOUBLE, F11, F15, IONI, MI, OVF, PONI, PTM, SGR, Z, ZF,
            FIDBO_15_0_OUT, RB_15_0, PIL_3_0} === 1'bx) begin
        errors = errors + 1;
        $display("FAIL X on a CGA_ALU output (vector %0d)", i);
      end
    end
  endtask

  // One ALUCLK event, valid in BOTH build modes.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
      m_sel_idbs2 = CSIDBS_4_0[2];
      #2;
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  task drive(input [31:0] r1, input [31:0] r2, input [31:0] r3);
    begin
      A_15_0       = r1[15:0];
      B_15_0       = r1[31:16];
      CD_15_0      = r2[15:0];
      CSBIT_15_0   = r2[31:16];
      EA_15_0      = 16'h0001 << r3[3:0];
      FIDBI_15_0   = {r3[15:0]};
      CSALUI_8_0   = r3[24:16];
      CSALUM_1_0   = r3[26:25];
      CSCINSEL_1_0 = r3[28:27];
      CSIDBS_4_0   = r1[20:16] ^ r3[4:0];
      CSMIS_1_0    = r2[17:16];
      CSSST_1_0    = r2[19:18];
      LAA_3_0      = r1[3:0];
      LBA_3_0      = r1[7:4];
      LCZN         = r3[29];
      LDDBRN       = r3[30];
      LDGPRN       = r3[31];
      LDIRV        = r2[20];
      LDPILN       = r2[21];
      UPN          = r2[22];
      XFETCHN      = r2[23];
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_ALU_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_ALU_tb: latch/CP mode (posedge ALUCLK capture)");
`endif

    // 1. warm-up: give every storage element a defined value before checking.
    //    The stimulus also wiggles every bus, which the shared always@(*)
    //    mux/decoder primitives need before they evaluate under Icarus.
    lfsr = 32'h9E3779B9;
    for (i = 0; i < 24; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      drive(lfsr, ~lfsr, {lfsr[15:0], ~lfsr[31:16]});
      pulse_aluclk;
    end

    // 2. + 3. the wiring map on 128 pseudo-random microcode words
    for (i = 0; i < 128; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      drive(lfsr, {lfsr[15:0], lfsr[31:16]}, ~lfsr);
      pulse_aluclk;
      check_map;
    end

    // 128 vectors x 90 checks
    if (errors == 0 && checks == 11520) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 11520 checks)", checks, errors);
    if (errors == 0 && checks == 11520) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
