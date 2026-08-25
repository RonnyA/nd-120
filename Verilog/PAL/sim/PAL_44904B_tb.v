/****************************************************************************
** PAL_44904B (7G, SIZEIND - memory size indicator) golden testbench       **
**                                                                         **
** SPEC: DesignDocuments/PAL-Code/SRC/44904B.txt. The model is re-derived   **
** from that PALASM listing term by term; the Verilog is under test, and a  **
** disagreement is a FINDING to report, never a licence to edit the RTL.    **
**                                                                         **
**   pins: CLK /MSIZE0 /MSIZE1 /MOFF NC5..NC9 GND                           **
**         /OE /EHI /EMID /ELOW NC15 DBIT CBIT BBIT ABIT VCC                **
**                                                                         **
**   EHI   := EMID + ELOW * EHI + /ELOW * /EHI      ; enable digit 3        **
**   EMID  := ELOW * /EMID * /EHI                   ; enable digit 2        **
**   ELOW  := /ELOW * /EMID * EHI                   ; enable digit 1        **
**   /ABIT := MOFF + MSIZE0 * EMID + EHI + ELOW                             **
**   /BBIT := MOFF + /MSIZE1 * /MSIZE0 * EMID + MSIZE1 * MSIZE0 * EMID      **
**          + EHI + ELOW                                                    **
**   /CBIT := /MSIZE1 * ELOW + /MSIZE0 * ELOW + EHI + EMID + MOFF           **
**   /DBIT := VCC                        (so the DBIT pin is always 0)      **
**                                                                         **
** ELOW, EMID and EHI are a three-phase ring that walks the 7-segment digit **
** enables; the size code MSIZE1:MSIZE0 then picks which segments light in  **
** each phase (2MB / 4MB / 6MB / 1MB per the listing's own table).          **
**                                                                         **
** COVERAGE: EXHAUSTIVE. 4 input pins x 7 state bits = 2048 combinations,   **
** every one applied, with all seven registers FORCED before each vector.   **
** The ring therefore gets checked from all eight ELOW/EMID/EHI states,     **
** including the illegal ones, not only the three it walks through.         **
**                                                                         **
** OUTPUT ENABLE: a PAL16R8 puts all eight outputs under /OE and the RTL    **
** matches. A disabled output drives 0, never z - checked explicitly. The   **
** equations are swept with OE_n=0 only: the RTL routes the /ELOW and /EHI  **
** feedback in the EHI equation through the OE-gated ports, where a real    **
** 16R8 feeds back from the registers. /OE is PD4 on the 3202D and is       **
** always low (PAL_44904B.v:27), so the difference cannot occur.            **
**                                                                         **
** A flipped term is caught: swapping /EHI for EHI in the ELOW equation     **
** breaks the ring - ELOW would re-arm one phase early, and the mismatch    **
** shows on every vector with EHI clear and ELOW/EMID clear.                **
**                                                                         **
** Run: cd Verilog/PAL/sim && make test-pal44904b                           **
**                                                                         **
** Last reviewed: 20-AUG-2026                                               **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module PAL_44904B_tb;

  reg CK, OE_n;
  reg MSIZE0_n, MSIZE1_n, MOFF_n;

  wire ABIT, BBIT, CBIT, DBIT, ELOW_n, EMID_n, EHI_n;

  integer checks = 0, errors = 0, vec, st, dumped = 0, phase;

  PAL_44904B DUT (
      .CK(CK), .OE_n(OE_n),
      .MSIZE0_n(MSIZE0_n), .MSIZE1_n(MSIZE1_n), .MOFF_n(MOFF_n),
      .ABIT(ABIT), .BBIT(BBIT), .CBIT(CBIT), .DBIT(DBIT),
      .ELOW_n(ELOW_n), .EMID_n(EMID_n), .EHI_n(EHI_n)
  );

  // ---- golden model from the listing ------------------------------------
  wire g_MSIZE0 = ~MSIZE0_n, g_MSIZE1 = ~MSIZE1_n, g_MOFF = ~MOFF_n;

  reg r_ehi, r_emid, r_elow, r_abit_n, r_bbit_n, r_cbit_n, r_dbit_n;

  wire g_ehi_next  = r_emid | (r_elow & r_ehi) | (~r_elow & ~r_ehi);
  wire g_emid_next = r_elow & ~r_emid & ~r_ehi;
  wire g_elow_next = ~r_elow & ~r_emid & r_ehi;

  wire g_abit_n_next = g_MOFF | (g_MSIZE0 & r_emid) | r_ehi | r_elow;
  wire g_bbit_n_next = g_MOFF
                     | (MSIZE1_n & MSIZE0_n & r_emid)
                     | (g_MSIZE1 & g_MSIZE0 & r_emid)
                     | r_ehi | r_elow;
  wire g_cbit_n_next = (MSIZE1_n & r_elow) | (MSIZE0_n & r_elow)
                     | r_ehi | r_emid | g_MOFF;
  wire g_dbit_n_next = 1'b1;

  task chk (input [127:0] name, input got, input exp);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (errors < 12)
          $display("FAIL %0s: got=%b exp=%b | ehi=%b emid=%b elow=%b abit_n=%b bbit_n=%b cbit_n=%b dbit_n=%b | OE_n=%b MSIZE0_n=%b MSIZE1_n=%b MOFF_n=%b",
                   name, got, exp, r_ehi, r_emid, r_elow, r_abit_n, r_bbit_n,
                   r_cbit_n, r_dbit_n, OE_n, MSIZE0_n, MSIZE1_n, MOFF_n);
      end
    end
  endtask

  task set_state (input [6:0] s);
    begin
      {r_dbit_n, r_cbit_n, r_bbit_n, r_abit_n, r_elow, r_emid, r_ehi} = s;
      DUT.EHI_reg    = s[0];
      DUT.EMID_reg   = s[1];
      DUT.ELOW_reg   = s[2];
      DUT.ABIT_n_reg = s[3];
      DUT.BBIT_n_reg = s[4];
      DUT.CBIT_n_reg = s[5];
      DUT.DBIT_n_reg = s[6];
      #1;
    end
  endtask

  task tick; begin CK = 1'b0; #1; CK = 1'b1; #1; CK = 1'b0; #1; end endtask

  initial begin
    $dumpfile("PAL_44904B_tb.vcd");
    $dumpvars(0, PAL_44904B_tb);
  end

  initial begin
    CK = 1'b0;
    {r_dbit_n, r_cbit_n, r_bbit_n, r_abit_n, r_elow, r_emid, r_ehi} = 7'b0;
    $display("=====================================================");
    $display(" PAL_44904B (SIZEIND) exhaustive golden testbench");
    $display(" 4 input pins x 7 state bits = 2048 combinations");
    $display("=====================================================");

    for (st = 0; st < 128; st = st + 1) begin
      for (vec = 0; vec < 16; vec = vec + 1) begin
        {MSIZE0_n, MSIZE1_n, MOFF_n, OE_n} = vec[3:0];
        set_state(st[6:0]);

        if (OE_n === 1'b0) begin
          chk("ABIT",   ABIT,   ~r_abit_n);
          chk("BBIT",   BBIT,   ~r_bbit_n);
          chk("CBIT",   CBIT,   ~r_cbit_n);
          chk("DBIT",   DBIT,   ~r_dbit_n);
          chk("ELOW_n", ELOW_n, ~r_elow);
          chk("EMID_n", EMID_n, ~r_emid);
          chk("EHI_n",  EHI_n,  ~r_ehi);
        end else begin
          chk("OEOFF_ABIT",   ABIT,   1'b0);
          chk("OEOFF_BBIT",   BBIT,   1'b0);
          chk("OEOFF_CBIT",   CBIT,   1'b0);
          chk("OEOFF_DBIT",   DBIT,   1'b0);
          chk("OEOFF_ELOW_n", ELOW_n, 1'b0);
          chk("OEOFF_EMID_n", EMID_n, 1'b0);
          chk("OEOFF_EHI_n",  EHI_n,  1'b0);
        end

        tick;
        if (OE_n === 1'b0) begin
          chk("ABIT_next",   ABIT,   ~g_abit_n_next);
          chk("BBIT_next",   BBIT,   ~g_bbit_n_next);
          chk("CBIT_next",   CBIT,   ~g_cbit_n_next);
          chk("DBIT_next",   DBIT,   ~g_dbit_n_next);
          chk("ELOW_n_next", ELOW_n, ~g_elow_next);
          chk("EMID_n_next", EMID_n, ~g_emid_next);
          chk("EHI_n_next",  EHI_n,  ~g_ehi_next);
        end

        dumped = dumped + 1;
        if (dumped == 40) $dumpoff;
      end
    end

    // ---- named property checks -----------------------------------------
    OE_n = 1'b0; MOFF_n = 1'b1; MSIZE0_n = 1'b1; MSIZE1_n = 1'b1;

    // 1. /DBIT is tied to VCC in the listing, so the DBIT pin is ALWAYS 0.
    //    Nothing may move it.
    for (vec = 0; vec < 16; vec = vec + 1) begin
      {MSIZE0_n, MSIZE1_n, MOFF_n} = vec[2:0];
      set_state(7'b0000_000);
      tick;
      checks = checks + 1;
      if (DBIT !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL DBIT_TIED: DBIT=%b with inputs %0d, /DBIT is VCC", DBIT, vec);
      end
    end
    MOFF_n = 1'b1; MSIZE0_n = 1'b1; MSIZE1_n = 1'b1;

    // 2. THE DIGIT RING: exactly one of ELOW / EMID / EHI may be enabled at
    //    a time once the ring is running, and it must walk ELOW -> EMID ->
    //    EHI -> ELOW. Start it at ELOW and follow six steps.
    set_state(7'b0000_100);                    // ELOW set
    for (phase = 0; phase < 6; phase = phase + 1) begin
      tick;
      checks = checks + 1;
      case (phase % 3)
        0: if (EMID_n !== 1'b0 || ELOW_n !== 1'b1 || EHI_n !== 1'b1) begin
             errors = errors + 1;
             $display("FAIL RING_EMID at step %0d: ELOW_n=%b EMID_n=%b EHI_n=%b",
                      phase, ELOW_n, EMID_n, EHI_n);
           end
        1: if (EHI_n !== 1'b0 || ELOW_n !== 1'b1 || EMID_n !== 1'b1) begin
             errors = errors + 1;
             $display("FAIL RING_EHI at step %0d: ELOW_n=%b EMID_n=%b EHI_n=%b",
                      phase, ELOW_n, EMID_n, EHI_n);
           end
        2: if (ELOW_n !== 1'b0 || EMID_n !== 1'b1 || EHI_n !== 1'b1) begin
             errors = errors + 1;
             $display("FAIL RING_ELOW at step %0d: ELOW_n=%b EMID_n=%b EHI_n=%b",
                      phase, ELOW_n, EMID_n, EHI_n);
           end
      endcase
    end

    // 3. MOFF blanks every segment bit, in every ring phase
    MOFF_n = 1'b0;
    for (phase = 0; phase < 3; phase = phase + 1) begin
      case (phase)
        0: set_state(7'b0000_100);   // ELOW
        1: set_state(7'b0000_010);   // EMID
        2: set_state(7'b0000_001);   // EHI
      endcase
      tick;
      checks = checks + 1;
      if (ABIT !== 1'b0 || BBIT !== 1'b0 || CBIT !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL MOFF_BLANK phase %0d: ABIT=%b BBIT=%b CBIT=%b",
                 phase, ABIT, BBIT, CBIT);
      end
    end
    MOFF_n = 1'b1;

    // 4. the size code only reaches the segment bits in the phase the
    //    listing puts it in: MSIZE0 * EMID for ABIT, and ELOW for CBIT.
    //    In the EHI phase every segment bit is blanked whatever the code is.
    for (vec = 0; vec < 4; vec = vec + 1) begin
      {MSIZE1_n, MSIZE0_n} = ~vec[1:0];
      set_state(7'b0000_001);        // EHI phase
      tick;
      checks = checks + 1;
      if (ABIT !== 1'b0 || BBIT !== 1'b0 || CBIT !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL EHI_BLANK code %0d: ABIT=%b BBIT=%b CBIT=%b",
                 vec, ABIT, BBIT, CBIT);
      end
    end

    // 5. nothing floats
    checks = checks + 1;
    if (^{ABIT, BBIT, CBIT, DBIT, ELOW_n, EMID_n, EHI_n} === 1'bx) begin
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
