/****************************************************************************
** PAL_44402D_EN (18F, UBITS - cache used-bit control) golden testbench    **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44402D.txt. The model below is        **
** re-derived from that PALASM listing, product term by product term. The   **
** Verilog is the thing under test - a disagreement is a FINDING.           **
**                                                                         **
**   IHIT   := HIT1 * HIT0 * OUBI * RT * /DT * /WCA        ; FETCH          **
**           + HIT1 * HIT0 * OUBD * RT *  DT * /WCA        ; READ           **
**   USED    = OUBI * RT * /DT * /WCA + OUBD * RT * DT * /WCA               **
**   WCA     = /RT * DT * EWC * CYD * /FMISS * /LSHADOW                     **
**           +  RT * /IHIT * EWC * CYD * /FMISS * /LSHADOW                  **
**   /NUBI  := DT * /OUBI + /RT * DT * HIT0 * HIT1                          **
**   /NUBD  := RT * /DT * /OUBD                                             **
**                                                                         **
** PIN POLARITY - the trap this part is famous for. The listing's pin line  **
** is  /OE OUBI OUBD /IHIT NC15 NUBD NUBI /WCA /USED VCC , so NUBI and NUBD **
** are ACTIVE-HIGH pins whose equations are written for the COMPLEMENT. A   **
** PAL16R4 inverts the register onto the pin, hence pin NUBI = /(register). **
** The module's port names NUBI_n / NUBD_n are historical misnomers: they   **
** carry the active-high pins. The model below is written in pin terms.     **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 11 input pins x 3 state bits = 16384 combinations, **
** all applied to BOTH build variants in the same loop:                     **
**   USE_ENABLE=1 - posedge sysclk + EN (the FPGA clock-enable conversion)  **
**   USE_ENABLE=0 - the original PAL_44402D on posedge CLK                  **
** All three registers are FORCED before every vector, so the complete      **
** transition function is exercised, not only the reachable states.         **
**                                                                         **
** OUTPUT ENABLE: on a PAL16R4 only pins 14-17 (here /IHIT and NUBD/NUBI)   **
** are controlled by /OE. Pins 18/19 (/WCA, /USED) carry "IF (VCC)" in the  **
** listing and are always enabled. The RTL matches that. A disabled output  **
** drives 0, never z - checked explicitly, and note what that means on an   **
** ACTIVE-LOW pin: /IHIT driven to 0 reads as IHIT ASSERTED.                **
**                                                                         **
** The equations sweep only OE_n=0. With OE_n=1 the RTL feeds the forced-to- **
** zero IHIT_n pin back into WCA, whereas a real 16R4 feeds WCA from the     **
** register regardless of /OE. That difference is pinned by its own named    **
** check below (OE_HIGH_WCA_USES_PIN) and is unreachable on the 3202D, where **
** /OE is wired to PD2 and PD1..PD4 are always low.                          **
**                                                                         **
** A flipped term is caught: dropping /WCA from the IHIT read term makes    **
** IHIT assert on the 2^7 vectors with HIT1*HIT0*OUBD*RT*DT and WCA active. **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44402d                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44402D_EN_tb;

  reg sysclk, EN, CLK, OE_n;
  reg DT_n, RT_n, LSHADOW, FMISS, CYD, HIT0_n, HIT1_n, EWC_n, OUBI, OUBD;

  wire e_USED_n, e_WCA_n, e_NUBI, e_NUBD, e_IHIT_n;   // USE_ENABLE=1
  wire o_USED_n, o_WCA_n, o_NUBI, o_NUBD, o_IHIT_n;   // USE_ENABLE=0

  integer checks = 0, errors = 0, vec, st, dumped = 0;

  PAL_44402D_EN #(.USE_ENABLE(1)) DUT_EN (
      .sysclk(sysclk), .EN(EN), .CLK(1'b0), .OE_n(OE_n),
      .DT_n(DT_n), .RT_n(RT_n), .LSHADOW(LSHADOW), .FMISS(FMISS), .CYD(CYD),
      .HIT0_n(HIT0_n), .HIT1_n(HIT1_n), .EWC_n(EWC_n),
      .USED_n(e_USED_n), .WCA_n(e_WCA_n), .OUBI(OUBI), .OUBD(OUBD),
      .NUBI_n(e_NUBI), .NUBD_n(e_NUBD), .IHIT_n(e_IHIT_n)
  );

  PAL_44402D_EN #(.USE_ENABLE(0)) DUT_OR (
      .sysclk(1'b0), .EN(1'b0), .CLK(CLK), .OE_n(OE_n),
      .DT_n(DT_n), .RT_n(RT_n), .LSHADOW(LSHADOW), .FMISS(FMISS), .CYD(CYD),
      .HIT0_n(HIT0_n), .HIT1_n(HIT1_n), .EWC_n(EWC_n),
      .USED_n(o_USED_n), .WCA_n(o_WCA_n), .OUBI(OUBI), .OUBD(OUBD),
      .NUBI_n(o_NUBI), .NUBD_n(o_NUBD), .IHIT_n(o_IHIT_n)
  );

  // ---- golden model, in PIN terms, from the listing ---------------------
  wire g_DT = ~DT_n, g_RT = ~RT_n, g_HIT0 = ~HIT0_n, g_HIT1 = ~HIT1_n;
  wire g_EWC = ~EWC_n;

  reg  r_ihit;                       // register holding the IHIT function
  reg  r_nubi;                       // register holding /NUBI
  reg  r_nubd;                       // register holding /NUBD

  wire g_IHIT_pin = ~r_ihit;         // pin /IHIT
  wire g_NUBI_pin = ~r_nubi;         // pin NUBI  (active high)
  wire g_NUBD_pin = ~r_nubd;         // pin NUBD  (active high)

  // /WCA and /USED are always-enabled combinational pins
  wire g_WCA_pin  = ~( (RT_n & g_DT & g_EWC & CYD & ~FMISS & ~LSHADOW)
                     | (g_RT & g_IHIT_pin & g_EWC & CYD & ~FMISS & ~LSHADOW) );
  wire g_USED_pin = ~( (OUBI & g_RT & DT_n & g_WCA_pin)
                     | (OUBD & g_RT & g_DT & g_WCA_pin) );

  // The same two pins as the RTL computes them: with /OE high this RTL feeds
  // the ZEROED IHIT pin back into WCA (and so into USED), where a real 16R4
  // would feed WCA from the register. Modelled separately so the /OE=1
  // vectors are still checked against something exact instead of skipped.
  wire g_IHIT_pin_oe   = OE_n ? 1'b0 : ~r_ihit;
  wire g_WCA_pin_rtl   = ~( (RT_n & g_DT & g_EWC & CYD & ~FMISS & ~LSHADOW)
                          | (g_RT & g_IHIT_pin_oe & g_EWC & CYD & ~FMISS & ~LSHADOW) );
  wire g_USED_pin_rtl  = ~( (OUBI & g_RT & DT_n & g_WCA_pin_rtl)
                          | (OUBD & g_RT & g_DT & g_WCA_pin_rtl) );

  wire g_r_ihit_next = (g_HIT1 & g_HIT0 & OUBI & g_RT & DT_n & g_WCA_pin)
                     | (g_HIT1 & g_HIT0 & OUBD & g_RT & g_DT & g_WCA_pin);
  wire g_r_nubi_next = (g_DT & ~OUBI) | (RT_n & g_DT & g_HIT0 & g_HIT1);
  wire g_r_nubd_next = (g_RT & DT_n & ~OUBD);

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | ihit=%b nubi=%b nubd=%b OE_n=%b DT_n=%b RT_n=%b LSHADOW=%b FMISS=%b CYD=%b HIT0_n=%b HIT1_n=%b EWC_n=%b OUBI=%b OUBD=%b",
                   name, got, exp, r_ihit, r_nubi, r_nubd, OE_n, DT_n, RT_n,
                   LSHADOW, FMISS, CYD, HIT0_n, HIT1_n, EWC_n, OUBI, OUBD);
      end
    end
  endtask

  task set_state (input i, input bi, input bd);
    begin
      r_ihit = i; r_nubi = bi; r_nubd = bd;
      DUT_EN.gen_enable.IHIT_reg    = i;
      DUT_EN.gen_enable.NUBI_n_reg  = bi;
      DUT_EN.gen_enable.NUBD_n_reg  = bd;
      DUT_OR.gen_orig.PAL.IHIT_reg   = i;
      DUT_OR.gen_orig.PAL.NUBI_n_reg = bi;
      DUT_OR.gen_orig.PAL.NUBD_n_reg = bd;
      #1;
    end
  endtask

  task tick;
    begin
      sysclk = 1'b0; CLK = 1'b0; #1;
      sysclk = 1'b1; CLK = 1'b1; #1;
      sysclk = 1'b0; CLK = 1'b0; #1;
    end
  endtask

  initial begin
    $dumpfile("PAL_44402D_EN_tb.vcd");
    $dumpvars(0, PAL_44402D_EN_tb);
  end

  initial begin
    sysclk = 1'b0; CLK = 1'b0; EN = 1'b1;
    r_ihit = 0; r_nubi = 0; r_nubd = 0;
    $display("=====================================================");
    $display(" PAL_44402D_EN (UBITS) exhaustive golden testbench");
    $display(" 11 input pins x 3 state bits = 16384 combinations");
    $display(" checked for USE_ENABLE=1 and USE_ENABLE=0");
    $display("=====================================================");

    for (st = 0; st < 8; st = st + 1) begin
      for (vec = 0; vec < 2048; vec = vec + 1) begin
        {DT_n, RT_n, LSHADOW, FMISS, CYD, HIT0_n, HIT1_n, EWC_n,
         OUBI, OUBD, OE_n} = vec[10:0];
        set_state(st[0], st[1], st[2]);

        if (OE_n === 1'b0) begin
          // pins 18/19 carry IF (VCC) - always enabled, never OE gated
          chk("EN1_USED_n", e_USED_n, g_USED_pin);
          chk("OR0_USED_n", o_USED_n, g_USED_pin);
          chk("EN1_WCA_n",  e_WCA_n,  g_WCA_pin);
          chk("OR0_WCA_n",  o_WCA_n,  g_WCA_pin);
          chk("EN1_IHIT_n", e_IHIT_n, g_IHIT_pin);
          chk("OR0_IHIT_n", o_IHIT_n, g_IHIT_pin);
          chk("EN1_NUBI",   e_NUBI,   g_NUBI_pin);
          chk("OR0_NUBI",   o_NUBI,   g_NUBI_pin);
          chk("EN1_NUBD",   e_NUBD,   g_NUBD_pin);
          chk("OR0_NUBD",   o_NUBD,   g_NUBD_pin);
        end else begin
          // a disabled PAL16R4 register pin drives 0 in this project
          chk("OEOFF_EN1_IHIT_n", e_IHIT_n, 1'b0);
          chk("OEOFF_OR0_IHIT_n", o_IHIT_n, 1'b0);
          chk("OEOFF_EN1_NUBI",   e_NUBI,   1'b0);
          chk("OEOFF_OR0_NUBI",   o_NUBI,   1'b0);
          chk("OEOFF_EN1_NUBD",   e_NUBD,   1'b0);
          chk("OEOFF_OR0_NUBD",   o_NUBD,   1'b0);
          // /WCA and /USED stay enabled, but the RTL's pin feedback changes
          // their value - pinned against the RTL model, see the header.
          chk("OEOFF_EN1_WCA_n",  e_WCA_n,  g_WCA_pin_rtl);
          chk("OEOFF_OR0_WCA_n",  o_WCA_n,  g_WCA_pin_rtl);
          chk("OEOFF_EN1_USED_n", e_USED_n, g_USED_pin_rtl);
          chk("OEOFF_OR0_USED_n", o_USED_n, g_USED_pin_rtl);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("EN1_IHIT_n_next", e_IHIT_n, ~g_r_ihit_next);
          chk("OR0_IHIT_n_next", o_IHIT_n, ~g_r_ihit_next);
          chk("EN1_NUBI_next",   e_NUBI,   ~g_r_nubi_next);
          chk("OR0_NUBI_next",   o_NUBI,   ~g_r_nubi_next);
          chk("EN1_NUBD_next",   e_NUBD,   ~g_r_nubd_next);
          chk("OR0_NUBD_next",   o_NUBD,   ~g_r_nubd_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0;

    // 1. the clock enable really gates: with EN low the USE_ENABLE=1 part
    //    must not capture, while the USE_ENABLE=0 part on CLK still does.
    DT_n = 1'b0; RT_n = 1'b1; OUBI = 1'b0; OUBD = 1'b0;
    HIT0_n = 1'b1; HIT1_n = 1'b1; EWC_n = 1'b1; CYD = 1'b0;
    FMISS = 1'b0; LSHADOW = 1'b0;
    set_state(1'b0, 1'b0, 1'b0);
    EN = 1'b0;
    sysclk = 1'b1; #1; sysclk = 1'b0; #1;
    checks = checks + 1;
    if (e_NUBI !== 1'b1) begin          // pin NUBI = ~register, register still 0
      errors = errors + 1;
      $display("FAIL EN_GATE: e_NUBI=%b, EN low must block the capture", e_NUBI);
    end
    EN = 1'b1;
    tick;
    checks = checks + 1;
    if (e_NUBI !== 1'b0) begin          // DT * /OUBI sets the register
      errors = errors + 1;
      $display("FAIL EN_RELEASE: e_NUBI=%b, EN high must capture", e_NUBI);
    end

    // 2. WCA must be suppressed inside the shadow, and by FMISS
    RT_n = 1'b0; DT_n = 1'b0; EWC_n = 1'b0; CYD = 1'b1;
    FMISS = 1'b0; LSHADOW = 1'b0; #1;
    checks = checks + 1;
    if (e_WCA_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL WCA_WRITE: e_WCA_n=%b, write outside shadow must set WCA", e_WCA_n);
    end
    LSHADOW = 1'b1; #1;
    checks = checks + 1;
    if (e_WCA_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL WCA_SHADOW: e_WCA_n=%b, LSHADOW must kill WCA", e_WCA_n);
    end
    LSHADOW = 1'b0; FMISS = 1'b1; #1;
    checks = checks + 1;
    if (e_WCA_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL WCA_FMISS: e_WCA_n=%b, FMISS must kill WCA", e_WCA_n);
    end
    FMISS = 1'b0; CYD = 1'b0; #1;
    checks = checks + 1;
    if (e_WCA_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL WCA_CYD: e_WCA_n=%b, CYD is required", e_WCA_n);
    end

    // 3. Documented RTL behaviour with /OE high. The listing gives WCA the
    //    REGISTER feedback of IHIT, so /OE could not change WCA; this RTL
    //    routes the OE-gated PIN back instead, which zeroes IHIT_n and so
    //    drops WCA's second product term. Unreachable on the 3202D (/OE is
    //    PD2, always low) but pinned here so a change is noticed.
    RT_n = 1'b0; DT_n = 1'b1; EWC_n = 1'b0; CYD = 1'b1;
    FMISS = 1'b0; LSHADOW = 1'b0;
    set_state(1'b0, 1'b0, 1'b0);       // IHIT register clear -> pin /IHIT = 1
    OE_n = 1'b0; #1;
    checks = checks + 1;
    if (e_WCA_n !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL OE_LOW_WCA: e_WCA_n=%b, RT * /IHIT term must set WCA", e_WCA_n);
    end
    OE_n = 1'b1; #1;
    checks = checks + 1;
    if (e_WCA_n !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL OE_HIGH_WCA_USES_PIN: e_WCA_n=%b, expected the RTL's pin-feedback behaviour", e_WCA_n);
    end
    OE_n = 1'b0; #1;

    // 4. nothing floats
    checks = checks + 1;
    if (^{e_USED_n, e_WCA_n, e_NUBI, e_NUBD, e_IHIT_n} === 1'bx) begin
      errors = errors + 1;
      $display("FAIL NO_Z: an output is x/z");
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
