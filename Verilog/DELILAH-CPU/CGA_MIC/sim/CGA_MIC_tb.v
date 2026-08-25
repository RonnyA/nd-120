/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_MIC top-level testbench (INTEGRATION / WIRING MAP + LAA/LBA path)  **
**                                                                       **
** SCOPE - read this before trusting the verdict.                        **
** CGA_MIC.v (drawing pages 9-13) is the microprogram sequencer: about    **
** thirty discrete gates, a dozen flip-flops and eight sub-circuits       **
** (INCOUNT, CONDREG, IINC, STACK, MASEL, WCAREG, IPOS, CSEL) wired       **
** together. Reproducing the whole next-address machine would mean        **
** re-modelling every one of those sub-circuits, and that model would be  **
** a copy of the RTL rather than an independent reference - so this       **
** testbench does NOT attempt it. Each sub-circuit has its own testbench  **
** in this directory (CGA_MIC_CONDREG_tb, CGA_MIC_CSEL_tb,                **
** CGA_MIC_IINC_tb, CGA_MIC_INCOUNT_tb, CGA_MIC_IPOS_tb,                  **
** CGA_MIC_MASEL_tb, CGA_MIC_STACK_tb, CGA_MIC_WCAREG_tb).                **
**                                                                       **
** Two things ARE verified here.                                          **
**                                                                       **
** (A) The wiring map. Every check asserts that a named CGA_MIC port, or  **
** a named sub-circuit port, carries exactly the signal the netlist says. **
** A single crossed port connection at integration level - the bug class  **
** this project keeps finding - fails. The map was transcribed from       **
** Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v, so it is double-entry   **
** bookkeeping and a REGRESSION guard (a later Logisim regeneration or    **
** hand edit that rewires a port fails at once), NOT proof that the       **
** original schematic transcription was right. Stated plainly so nobody   **
** over-reads the PASS.                                                   **
**                                                                       **
** (B) Real logic, modelled independently from the gates:                 **
**   - the IR latch: L8 IRLATCH with L=LDIRV and A..G = CD_15_0[6:0], so  **
**     s_ir_6_0 follows CD_15_0[6:0] while LDIRV is high                  **
**   - the A-operand select. MUX41P selects on {B,A} = CSRASEL_1_0, then  **
**     R41P_EN LAA_REG captures on the MCLK rise and CGA_MIC inverts the  **
**     QxN outputs again, so                                              **
**       LAA_3_0 <= sel 0 : CSBIT_15_0[15:12]                             **
**                  sel 1 : PIL_3_0                                       **
**                  sel 2 : {s_laa3_d2_input, ir[5], ir[4], ir[3]}        **
**                  sel 3 : s_lc_3_0                                      **
**   - the B-operand select, same structure on CSRBSEL_1_0:               **
**       LBA_3_0 <= sel 0 : CSRB_3_0                                      **
**                  sel 1 : {1'b0, ir[2], ir[1], ir[0]}                   **
**                  sel 2 : {1'b0, ir[5], ir[4], ir[3]}                   **
**                  sel 3 : s_lc_3_0                                      **
**     (the two GND taps on LBA bit 3 are what the netlist has - recorded **
**      as read, not judged)                                              **
**   - COND comes from D_FLIPFLOP MEMORY_32 fed by CSEL's CONDN and read  **
**     out on qBar, so after an MCLK rise COND = ~CONDN(pre-edge)         **
**   - UPN = ~s_up_out and LCZN/s_lcz are complements of each other       **
**   - XMIC_DBG (default build, no trace define) =                        **
**       {CSBIT20, SC_6_3[3], MCLK_EN, 1'b0, CSBIT_15_0[11:0]}            **
**   s_laa3_d2_input, s_ir_6_0 and s_lc_3_0 are READ from the DUT as      **
**   reference inputs to the operand model - the model then proves the    **
**   mux select and the register capture, not those three sources.        **
**                                                                       **
** Test plan:                                                            **
**   1. warm-up MCLK cycles so no storage element is still undefined      **
**   2. EXHAUSTIVE over all 4 x 4 CSRASEL/CSRBSEL combinations x 16       **
**      pseudo-random data sets: one full MCLK cycle each, then the       **
**      operand model and the whole wiring map are checked                **
**   3. 128 further fixed-seed pseudo-random microcode words              **
**   4. an X-freedom check on every CGA_MIC output on every vector        **
**                                                                       **
** Build switches that reach this module: FPGA_FF_MODE (the MCLK-domain   **
** registers move to sysclk+MCLK_EN / MCLK_FALL_EN) and                   **
** USE_TRANSPARENT_LATCHES (the L8/LATCH primitives inside IRLATCH, CSEL  **
** and MASEL). The Makefile target test-mic-top runs all four             **
** combinations and all four must print PASS.                             **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_MIC/sim && make test-mic-top              **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).           **
**                                                                       **
** 20-AUG-2026                                                            **
** Ronny Hansen                                                           **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_MIC_tb;

  reg         sysclk = 0;
  reg         MCLK_EN = 0;
  reg         MCLK_FALL_EN = 0;
  reg         MCLK = 0;
  reg         ALUCLK = 0;
  reg  [15:0] CD_15_0 = 0;
  reg         CFETCH = 0;
  reg         CLFFN = 1;
  reg         CRY = 0;
  reg         CSALUI8 = 0;
  reg         CSBIT20 = 0;
  reg  [15:0] CSBIT_15_0 = 0;
  reg         CSCOND = 0;
  reg         CSECOND = 0;
  reg         CSLOOP = 0;
  reg         CSMIS0 = 0;
  reg  [ 1:0] CSRASEL_1_0 = 0;
  reg  [ 1:0] CSRBSEL_1_0 = 0;
  reg  [ 3:0] CSRB_3_0 = 0;
  reg  [ 3:0] CSTS_6_3 = 0;
  reg         CSVECT = 0;
  reg         CSXRF3 = 0;
  reg         EWCAN = 1;
  reg         F11 = 0;
  reg         F15 = 0;
  reg         ILCSN = 1;
  reg         IRQ = 0;
  reg         LDIRV = 0;
  reg         LDLCN = 1;
  reg         LWCAN = 1;
  reg         MAPN = 1;
  reg         MI = 0;
  reg         MRN = 1;
  reg         OVF = 0;
  reg  [ 3:0] PIL_3_0 = 0;
  reg         RESTR = 0;
  reg         SPARE = 0;
  reg         STP = 0;
  reg         TRAPN = 1;
  reg  [ 3:0] TVEC_3_0 = 0;
  reg         ZF = 0;

  wire        ACONDN, COND, DEEP, DZD, LCZN, OOD, PN, TN, UPN, WCSN;
  wire [ 3:0] LAA_3_0, LBA_3_0, SC_6_3;
  wire [12:0] MA_12_0;
  wire [ 1:0] RF_1_0;
  wire [15:0] XMIC_DBG;

  integer errors = 0;
  integer checks = 0;
  integer i, a, b;
  reg [31:0] lfsr;

  // model state, sampled just before each MCLK rise
  reg [3:0] m_laa, m_lba;
  reg       m_cond;

  CGA_MIC dut (
      .sysclk      (sysclk),
      .sys_rst_n   (1'b1),
      .MCLK_EN     (MCLK_EN),
      .MCLK_FALL_EN(MCLK_FALL_EN),
      .ALUCLK      (ALUCLK),
      .CD_15_0     (CD_15_0),
      .CFETCH      (CFETCH),
      .CLFFN       (CLFFN),
      .CRY         (CRY),
      .CSALUI8     (CSALUI8),
      .CSBIT20     (CSBIT20),
      .CSBIT_15_0  (CSBIT_15_0),
      .CSCOND      (CSCOND),
      .CSECOND     (CSECOND),
      .CSLOOP      (CSLOOP),
      .CSMIS0      (CSMIS0),
      .CSRASEL_1_0 (CSRASEL_1_0),
      .CSRBSEL_1_0 (CSRBSEL_1_0),
      .CSRB_3_0    (CSRB_3_0),
      .CSTS_6_3    (CSTS_6_3),
      .CSVECT      (CSVECT),
      .CSXRF3      (CSXRF3),
      .EWCAN       (EWCAN),
      .F11         (F11),
      .F15         (F15),
      .ILCSN       (ILCSN),
      .IRQ         (IRQ),
      .LDIRV       (LDIRV),
      .LDLCN       (LDLCN),
      .LWCAN       (LWCAN),
      .MAPN        (MAPN),
      .MCLK        (MCLK),
      .MI          (MI),
      .MRN         (MRN),
      .OVF         (OVF),
      .PIL_3_0     (PIL_3_0),
      .RESTR       (RESTR),
      .SPARE       (SPARE),
      .STP         (STP),
      .TRAPN       (TRAPN),
      .TVEC_3_0    (TVEC_3_0),
      .ZF          (ZF),
      .ACONDN      (ACONDN),
      .COND        (COND),
      .DEEP        (DEEP),
      .DZD         (DZD),
      .LAA_3_0     (LAA_3_0),
      .LBA_3_0     (LBA_3_0),
      .LCZN        (LCZN),
      .MA_12_0     (MA_12_0),
      .OOD         (OOD),
      .PN          (PN),
      .RF_1_0      (RF_1_0),
      .SC_6_3      (SC_6_3),
      .TN          (TN),
      .UPN         (UPN),
      .WCSN        (WCSN),
      .XMIC_DBG    (XMIC_DBG)
  );

  always #5 sysclk = ~sysclk;

  initial begin
    $dumpfile("CGA_MIC_tb.vcd");
    $dumpvars(0, CGA_MIC_tb);
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

  function [3:0] sel4(input [1:0] s, input [3:0] d0, input [3:0] d1,
                      input [3:0] d2, input [3:0] d3);
    begin
      case (s)
        2'd0: sel4 = d0;
        2'd1: sel4 = d1;
        2'd2: sel4 = d2;
        default: sel4 = d3;
      endcase
    end
  endfunction

  // One complete MCLK cycle, valid in BOTH build modes. The operand model is
  // sampled just before the rising edge.
  task pulse_mclk;
    begin
      @(negedge sysclk);
      MCLK_EN = 1;
      // sample the pre-edge sources for the modelled operand path
      m_laa = sel4(CSRASEL_1_0, CSBIT_15_0[15:12], PIL_3_0,
                   {dut.s_laa3_d2_input, dut.s_ir_6_0[5], dut.s_ir_6_0[4],
                    dut.s_ir_6_0[3]}, dut.s_lc_3_0);
      m_lba = sel4(CSRBSEL_1_0, CSRB_3_0,
                   {1'b0, dut.s_ir_6_0[2], dut.s_ir_6_0[1], dut.s_ir_6_0[0]},
                   {1'b0, dut.s_ir_6_0[5], dut.s_ir_6_0[4], dut.s_ir_6_0[3]},
                   dut.s_lc_3_0);
      m_cond = ~dut.s_cond_n;
      @(posedge sysclk);
      #1 MCLK = 1;
      @(negedge sysclk);
      MCLK_EN = 0;
      @(negedge sysclk);
      MCLK_FALL_EN = 1;
      @(posedge sysclk);
      #1 MCLK = 0;
      @(negedge sysclk);
      MCLK_FALL_EN = 0;
      #2;
    end
  endtask

  // Checked immediately after the rising edge, before MCLK falls.
  task check_after_rise;
    begin
      chk("LAA_3_0 operand select", LAA_3_0, m_laa);
      chk("LBA_3_0 operand select", LBA_3_0, m_lba);
      chk("COND from CSEL.CONDN",   COND,    m_cond);
    end
  endtask

  task check_map;
    begin
      // -- CGA_MIC input ports reaching their sub-circuits --
      chk("CONDREG.CSBIT_11_0", dut.CONDREG.CSBIT_11_0, CSBIT_15_0[11:0]);
      chk("CONDREG.CSSCOND",    dut.CONDREG.CSSCOND,    CSCOND);
      chk("CONDREG.LCSN",       dut.CONDREG.LCSN,       ILCSN);
      chk("MASEL.CSBIT20",      dut.MIC_MASEL.CSBIT20,  CSBIT20);
      chk("MASEL.CSBIT_11_0",   dut.MIC_MASEL.CSBIT_11_0, CSBIT_15_0[11:0]);
      chk("MASEL.MRN",          dut.MIC_MASEL.MRN,      MRN);
      chk("WCAREG.CD",          dut.MIC_WCAREG.CD_15_0, CD_15_0);
      chk("WCAREG.LCSN",        dut.MIC_WCAREG.LCSN,    ILCSN);
      chk("WCAREG.LWCAN",       dut.MIC_WCAREG.LWCAN,   LWCAN);
      chk("IPOS.CD",            dut.MIC_IPOS.CD_15_0,   CD_15_0);
      chk("IPOS.EWCAN",         dut.MIC_IPOS.EWCAN,     EWCAN);
      chk("IPOS.MAPN",          dut.MIC_IPOS.MAPN,      MAPN);
      chk("IPOS.TRAPN",         dut.MIC_IPOS.TRAPN,     TRAPN);
      chk("IPOS.TVEC",          dut.MIC_IPOS.TVEC_3_0,  TVEC_3_0);
      chk("INCOUNT.CD0",        dut.MIC_INCOUNT.CD0,    CD_15_0[0]);
      chk("INCOUNT.CD1",        dut.MIC_INCOUNT.CD1,    CD_15_0[1]);
      chk("INCOUNT.LWCAN",      dut.MIC_INCOUNT.LWCAN,  LWCAN);
      chk("INCOUNT.MRN",        dut.MIC_INCOUNT.MRN,    MRN);
      chk("CSEL.CFETCH",        dut.CSEL.CFETCH,        CFETCH);
      chk("CSEL.CRY",           dut.CSEL.CRY,           CRY);
      chk("CSEL.F11",           dut.CSEL.F11,           F11);
      chk("CSEL.F15",           dut.CSEL.F15,           F15);
      chk("CSEL.IRQ",           dut.CSEL.IRQ,           IRQ);
      chk("CSEL.OVF",           dut.CSEL.OVF,           OVF);
      chk("CSEL.RESTR",         dut.CSEL.RESTR,         RESTR);
      chk("CSEL.SPARE",         dut.CSEL.SPARE,         SPARE);
      chk("CSEL.STP",           dut.CSEL.STP,           STP);
      chk("CSEL.ZF",            dut.CSEL.ZF,            ZF);
      chk("LC_HI.NL",           dut.LC_HI.NL,           LDLCN);
      chk("LC_LO.NL",           dut.LC_LO.NL,           LDLCN);

      // -- sub-circuit to sub-circuit --
      chk("MASEL.NEXT <- IINC",  dut.MIC_MASEL.NEXT_12_0, dut.MIC_IINC.NEXT_12_0);
      chk("STACK.NEXT <- IINC",  dut.MIC_STACK.NEXT_12_0, dut.MIC_IINC.NEXT_12_0);
      chk("MASEL.RET  <- STACK", dut.MIC_MASEL.RET_12_0,  dut.MIC_STACK.RET_12_0);
      chk("IINC.IW    <- MASEL", dut.MIC_IINC.IW_12_0,    dut.MIC_MASEL.IW_12_0);
      chk("IPOS.W     <- MASEL", dut.MIC_IPOS.W_12_0,     dut.MIC_MASEL.W_12_0);
      chk("IPOS.WCA   <- WCAREG",dut.MIC_IPOS.WCA_12_0,   dut.MIC_WCAREG.WCA_12_0);
      chk("CSEL.TSEL  <- CONDREG", dut.CSEL.TSEL_3_0,     dut.CONDREG.TSEL_3_0);
      chk("STACK.SC3  <- SC[0]", dut.MIC_STACK.SC3,       SC_6_3[0]);
      chk("STACK.SC4  <- SC[1]", dut.MIC_STACK.SC4,       SC_6_3[1]);
      chk("MASEL.SC5  <- SC[2]", dut.MIC_MASEL.SC5,       SC_6_3[2]);
      chk("MASEL.SC6  <- SC[3]", dut.MIC_MASEL.SC6,       SC_6_3[3]);
      chk("CSEL.DZD   <- DZD",   dut.CSEL.DZD,            DZD);
      chk("CSEL.OOD   <- OOD",   dut.CSEL.OOD,            OOD);
      chk("CSEL.COND  <- COND",  dut.CSEL.COND,           COND);
      chk("CSEL.LCZ   <- ~LCZN", dut.CSEL.LCZ,            !LCZN);
      chk("MASEL.JMP  <- s_jmp", dut.MIC_MASEL.JMP_3_0,   dut.s_jmp_3_0);

      // -- output taps --
      chk("ACONDN tap", ACONDN,  dut.CONDREG.ACONDN);
      chk("DEEP tap",   DEEP,    dut.MIC_STACK.DEEP);
      chk("MA tap",     MA_12_0, dut.MIC_IPOS.MA_12_0);
      chk("WCSN tap",   WCSN,    dut.MIC_WCAREG.WCSN);
      chk("PN tap",     PN,      dut.LC_LO.PN);
      chk("TN tap",     TN,      dut.LC_LO.CON);
      chk("UPN = ~UP",  UPN,     !dut.s_up_out);
      chk("XMIC_DBG",   XMIC_DBG,
          {CSBIT20, SC_6_3[3], MCLK_EN, 1'b0, CSBIT_15_0[11:0]});

      // -- X-freedom of every CGA_MIC output --
      checks = checks + 1;
      if (^{ACONDN, COND, DEEP, DZD, LCZN, OOD, PN, TN, UPN, WCSN,
            LAA_3_0, LBA_3_0, SC_6_3, MA_12_0, RF_1_0, XMIC_DBG} === 1'bx) begin
        errors = errors + 1;
        $display("FAIL X on a CGA_MIC output (vector %0d)", i);
      end
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  task drive(input [31:0] r1, input [31:0] r2);
    begin
      CD_15_0    = r1[15:0];
      CSBIT_15_0 = r1[31:16];
      CFETCH     = r2[0];
      CLFFN      = r2[1];
      CRY        = r2[2];
      CSALUI8    = r2[3];
      CSBIT20    = r2[4];
      CSCOND     = r2[5];
      CSECOND    = r2[6];
      CSLOOP     = r2[7];
      CSMIS0     = r2[8];
      CSRB_3_0   = r2[12:9];
      CSTS_6_3   = r2[16:13];
      CSVECT     = r2[17];
      CSXRF3     = r2[18];
      EWCAN      = r2[19];
      F11        = r2[20];
      F15        = r2[21];
      ILCSN      = r2[22];
      IRQ        = r2[23];
      LDIRV      = r2[24];
      LDLCN      = r2[25];
      LWCAN      = r2[26];
      MAPN       = r2[27];
      MI         = r2[28];
      MRN        = r2[29];
      OVF        = r2[30];
      PIL_3_0    = r1[3:0] ^ r2[31:28];
      RESTR      = r1[4];
      SPARE      = r1[5];
      STP        = r1[6];
      TRAPN      = r1[7];
      TVEC_3_0   = r1[11:8];
      ZF         = r1[12];
    end
  endtask

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_MIC_tb: FPGA_FF_MODE=1");
`else
    $display("CGA_MIC_tb: FPGA_FF_MODE=0");
`endif
`ifdef USE_TRANSPARENT_LATCHES
    $display("CGA_MIC_tb: USE_TRANSPARENT_LATCHES=1");
`else
    $display("CGA_MIC_tb: USE_TRANSPARENT_LATCHES=0");
`endif

    // 1. warm-up. Also wiggles every bus, which the shared always @(*)
    //    mux/decoder primitives need before they will evaluate under Icarus.
    lfsr = 32'hA5A5F00D;
    for (i = 0; i < 24; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      drive(lfsr, ~lfsr);
      LDIRV       = 1'b1;  // keep the IR latch loaded so ir[] is defined
      CSRASEL_1_0 = i[1:0];
      CSRBSEL_1_0 = i[3:2];
      pulse_mclk;
    end

    // 2. exhaustive CSRASEL x CSRBSEL, 16 data sets each
    for (a = 0; a < 4; a = a + 1)
      for (b = 0; b < 4; b = b + 1)
        for (i = 0; i < 16; i = i + 1) begin
          lfsr        = lfsr_next(lfsr);
          drive(lfsr, {lfsr[15:0], lfsr[31:16]});
          CSRASEL_1_0 = a[1:0];
          CSRBSEL_1_0 = b[1:0];
          #2;
          // the IR latch is a transparent latch on LDIRV
          checks = checks + 1;
          if (LDIRV && (dut.s_ir_6_0 !== CD_15_0[6:0])) begin
            errors = errors + 1;
            $display("FAIL IR latch open: ir=%02h exp %02h", dut.s_ir_6_0,
                     CD_15_0[6:0]);
          end
          pulse_mclk;
          check_after_rise;
          check_map;
        end

    // 3. pseudo-random microcode words
    for (i = 0; i < 128; i = i + 1) begin
      lfsr        = lfsr_next(lfsr);
      drive(lfsr, ~{lfsr[7:0], lfsr[31:8]});
      CSRASEL_1_0 = lfsr[9:8];
      CSRBSEL_1_0 = lfsr[11:10];
      pulse_mclk;
      check_after_rise;
      check_map;
    end

    // 256 exhaustive-phase vectors x (1 IR + 3 after-rise + 55 map) = 15104
    // plus 128 random vectors x (3 after-rise + 55 map) = 7424 -> 22528
    if (errors == 0 && checks == 22528) $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 22528 checks)", checks, errors);
    if (errors == 0 && checks == 22528) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire
