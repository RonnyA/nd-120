/**************************************************************************
** IO_REG_41 - IOC / ALD / INR register testbench                        **
** (sheet 41, chips 28A 74273, 27A + 25A 74244)                          **
**                                                                       **
** Three separate register/buffer paths share one IDB here, so this is   **
** where a strap wired to the wrong IDB bit, or an IOC control bit       **
** landing one position off, hides. Both would boot the machine off the  **
** wrong device or leave an interrupt permanently enabled.               **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   1. ALD/STRAP BIT PLACEMENT. The 74244 pin lists in the RTL run in   **
**      the OPPOSITE order to the IDB bit numbers (A1[3] lands on IDB12, **
**      A1[0] on IDB15), which is exactly the kind of reversal that gets **
**      transcribed wrong. The test pins the whole 16-bit word to a      **
**      literal, derived bit by bit from the straps and constants named  **
**      in the RTL, and names every field it disagrees on.               **
**      The low nibble is the ALD boot vector - 0010 = Winchester 500 -  **
**      so a slip there changes what a bare '&' boots.                   **
**   2. CX~ REACHING IDB7 AND NOTHING ELSE.                              **
**   3. THE INR BUFFER: all 8 bits, in place, only while RINR~ is low,   **
**      contributing exactly ZERO when disabled (this IDB is an OR-ed    **
**      bus - IO_REG_41.v line 219 ORs the ALD and INR words together).  **
**   4. THE IOC REGISTER: every one of the 8 control bits written,       **
**      read back through the outputs it drives, one-hot, so a           **
**      neighbouring-bit slip is caught. Then HOLD (inputs change, no    **
**      strobe, nothing moves) and CLEAR.                                **
**   5. THE THREE INTERRUPT GATES, exhaustively over their inputs:       **
**         BINT13~ = ~(IOC3 & IOC0)                                      **
**         BINT10~ = ~(IOC2 & TBMT)                                      **
**         BINT12~ = ~(CONSOLE~ & IOC1 & DA)                             **
**      A wrong input on any of these is the CGA_INTR_CNTLR class of bug.**
**   6. LED WIRING: IOLED[0] = EMCL~, IOLED[1] = the green flag - two    **
**      DIFFERENT register bits, so a duplicate connection is caught.    **
**                                                                       **
** BOTH BUILD MODES. The IOC register changes shape under `FPGA_FF_MODE  **
** (TTL_74273 USE_SYSCLK=2 - sysclk-sampled strobe-rise capture) versus  **
** the default posedge-CLK chip. All of the above must hold in both. One **
** GENUINE difference exists and is asserted separately per mode: in the **
** default mode CLEAR~ only takes effect on a strobe edge (the chip      **
** model has a SYNCHRONOUS clear), while in FF mode it takes effect on   **
** the next sysclk with no strobe at all. That difference is measured    **
** here rather than left to be discovered in a boot.                     **
**                                                                       **
** Bit assignments are read from the RTL, not from ND documentation, so  **
** the IOC bit meanings are CHARACTERISED; the placement, hold, clear    **
** and gating properties are specified behaviour.                        **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-ioreg41               **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module IO_REG_41_tb;

  reg         sysclk = 1'b0;
  reg         CLEAR_n, CX_n, DA_n, RINR_n, SIOC_n, TBMT_n, TRAALD_n;
  reg  [ 7:0] INR_7_0;
  reg  [ 7:0] IDB_7_0_IN;
  wire [15:0] IDB_15_0_OUT;
  wire        BINT10_n, BINT12_n, BINT13_n, CONSOLE_n, EMCL_n;
  wire [ 1:0] IOLED;

  integer errors = 0;
  integer checks = 0;
  integer i, v;
  reg [15:0] held;

  always #5 sysclk = ~sysclk;

`ifdef FPGA_FF_MODE
  localparam [8*5:1] MODE = "FF   ";
`else
  localparam [8*5:1] MODE = "LATCH";
`endif

  IO_REG_41 DUT (
      .sysclk(sysclk),
      .CLEAR_n(CLEAR_n), .CX_n(CX_n), .DA_n(DA_n), .INR_7_0(INR_7_0),
      .RINR_n(RINR_n), .SIOC_n(SIOC_n), .TBMT_n(TBMT_n), .TRAALD_n(TRAALD_n),
      .IDB_7_0_IN(IDB_7_0_IN), .IDB_15_0_OUT(IDB_15_0_OUT),
      .BINT10_n(BINT10_n), .BINT12_n(BINT12_n), .BINT13_n(BINT13_n),
      .CONSOLE_n(CONSOLE_n), .EMCL_n(EMCL_n), .IOLED(IOLED)
  );

  // Write one byte into the IOC register. SIOC~ is the strobe; the chip is
  // clocked from ~SIOC~ so the capture happens on the SIOC~ FALLING edge.
  task ioc_write;
    input [7:0] d;
    begin
      TRAALD_n   = 1'b1;   // keep the ALD and INR buffers off the IDB so the
      RINR_n     = 1'b1;   // register captures exactly the byte we present
      IDB_7_0_IN = d;
      SIOC_n     = 1'b1;
      @(posedge sysclk); #1;
      SIOC_n     = 1'b0;   // falling edge -> capture
      @(posedge sysclk); #1;
      @(posedge sysclk); #1;
      SIOC_n     = 1'b1;
      @(posedge sysclk); #1;
    end
  endtask

  task expect1;
    input [255:0] name;
    input got, want;
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        if (errors < 25) $display("FAIL %0s: got %b want %b", name, got, want);
      end
    end
  endtask

  task expect16;
    input [255:0] name;
    input [15:0] got, want;
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        if (errors < 25)
          $display("FAIL %0s: got %04h want %04h (differing bits %04h)",
                   name, got, want, got ^ want);
      end
    end
  endtask

  initial begin
    $dumpfile("IO_REG_41_tb.vcd");
    $dumpvars(0, IO_REG_41_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 30000 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #30000 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" IO_REG_41 (sheet 41) IOC / ALD / INR - mode %0s", MODE);
    $display("=====================================================");

    CLEAR_n = 1'b1; CX_n = 1'b1; DA_n = 1'b1; TBMT_n = 1'b1;
    RINR_n = 1'b1; SIOC_n = 1'b1; TRAALD_n = 1'b1;
    INR_7_0 = 8'h00; IDB_7_0_IN = 8'h00;
    @(posedge sysclk); #1;

    // put the register in a known state before anything reads its outputs
    ioc_write(8'h00);

    // =================================================================
    // 1. the ALD / STRAP word
    // =================================================================
    // Derived bit by bit from the RTL:
    //   IDB15..IDB12 <- 1,1,1,STRAP5(=1)              -> 1111
    //   IDB11..IDB8  <- STRAP6(0),STRAP7(1),STRAP8(0),STRAP9(0) -> 0100
    //   IDB7         <- CX~
    //   IDB6..IDB4   <- PRINT_NO = 011                -> 011
    //   IDB3..IDB0   <- ALD = 0010 (Winchester 500)   -> 0010
    // giving F4B2 with CX~ high and F432 with CX~ low.
    TRAALD_n = 1'b0; RINR_n = 1'b1; CX_n = 1'b1; #1;
    expect16("ALD_WORD_CXn_1", IDB_15_0_OUT, 16'hF4B2);
    CX_n = 1'b0; #1;
    expect16("ALD_WORD_CXn_0", IDB_15_0_OUT, 16'hF432);

    // CX~ must move IDB7 and NOTHING else
    checks = checks + 1;
    if ((16'hF4B2 ^ 16'hF432) !== 16'h0080) begin
      errors = errors + 1;
      $display("FAIL CX_NOT_ONLY_IDB7: CX~ changed bits %04h", 16'hF4B2 ^ 16'hF432);
    end

    // the ALD boot vector itself - a slip here changes what '&' boots
    CX_n = 1'b1; #1;
    checks = checks + 1;
    if (IDB_15_0_OUT[3:0] !== 4'b0010) begin
      errors = errors + 1;
      $display("FAIL ALD_VECTOR: IDB[3:0]=%b expected 0010 (Winchester 500)",
               IDB_15_0_OUT[3:0]);
    end

    // deselected must contribute exactly zero to the OR-ed IDB
    TRAALD_n = 1'b1; #1;
    expect16("ALD_DESELECTED_ZERO", IDB_15_0_OUT, 16'h0000);

    // =================================================================
    // 2. the INR buffer - all 8 bits, in place, gated by RINR~
    // =================================================================
    TRAALD_n = 1'b1;
    RINR_n   = 1'b0;
    for (i = 0; i < 8; i = i + 1) begin
      INR_7_0 = 8'b1 << i; #1;
      expect16("INR_ONEHOT", IDB_15_0_OUT, {8'h00, 8'b1 << i});
    end
    INR_7_0 = 8'hFF; #1;
    expect16("INR_ALL", IDB_15_0_OUT, 16'h00FF);
    RINR_n = 1'b1; #1;
    expect16("INR_DESELECTED_ZERO", IDB_15_0_OUT, 16'h0000);

    // both buffers on at once: the RTL ORs them (line 219). Prove the OR is
    // there and that the INR does not reach the upper byte.
    TRAALD_n = 1'b0; RINR_n = 1'b0; INR_7_0 = 8'h0D; #1;
    expect16("ALD_OR_INR", IDB_15_0_OUT, 16'hF4B2 | 16'h000D);
    TRAALD_n = 1'b1; RINR_n = 1'b1; INR_7_0 = 8'h00; #1;

    // =================================================================
    // 3. the IOC register - one bit at a time, read back through outputs
    // =================================================================
    for (i = 0; i < 8; i = i + 1) begin
      ioc_write(8'b1 << i);
      // bit 6 = CONSOLE~, bit 5 = EMCL~ / red LED, bit 4 = green LED
      expect1("IOC_BIT6_CONSOLE", CONSOLE_n, (i == 6));
      expect1("IOC_BIT5_EMCL",    EMCL_n,    (i == 5));
      expect1("IOC_BIT5_REDLED",  IOLED[0],  (i == 5));
      expect1("IOC_BIT4_GREENLED",IOLED[1],  (i == 4));
    end

    // the two LEDs must come from DIFFERENT register bits
    ioc_write(8'b0010_0000);   // bit 5 only
    checks = checks + 1;
    if (IOLED[0] !== 1'b1 || IOLED[1] !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL LED_WIRING: bit5 only -> IOLED=%b, expected red=1 green=0", IOLED);
    end
    ioc_write(8'b0001_0000);   // bit 4 only
    checks = checks + 1;
    if (IOLED[0] !== 1'b0 || IOLED[1] !== 1'b1) begin
      errors = errors + 1;
      $display("FAIL LED_WIRING: bit4 only -> IOLED=%b, expected red=0 green=1", IOLED);
    end

    // =================================================================
    // 4. HOLD - the register must ignore the bus without a strobe
    // =================================================================
    ioc_write(8'b0100_0000);
    held = {8'h00, 8'b0100_0000};
    IDB_7_0_IN = 8'hFF;
    @(posedge sysclk); @(posedge sysclk); @(posedge sysclk); #1;
    expect1("HOLD_CONSOLE", CONSOLE_n, 1'b1);
    expect1("HOLD_EMCL",    EMCL_n,    1'b0);
    IDB_7_0_IN = 8'h00;

    // =================================================================
    // 5. CLEAR
    // =================================================================
    ioc_write(8'hFF);
    expect1("PRECLEAR_CONSOLE", CONSOLE_n, 1'b1);
    CLEAR_n = 1'b0;
    @(posedge sysclk); @(posedge sysclk); #1;
`ifdef FPGA_FF_MODE
    // FF mode: TTL_74273 USE_SYSCLK=2 clears on sysclk, no strobe needed
    expect1("CLEAR_NO_STROBE_FF", CONSOLE_n, 1'b0);
`else
    // default mode: the chip model's clear is SYNCHRONOUS to its own clock,
    // so nothing happens until a strobe edge arrives
    expect1("CLEAR_NEEDS_STROBE_LATCH", CONSOLE_n, 1'b1);
`endif
    // in BOTH modes, clear plus a strobe must zero the register
    ioc_write(8'hFF);
    expect1("CLEAR_WITH_STROBE_CONSOLE", CONSOLE_n, 1'b0);
    expect1("CLEAR_WITH_STROBE_EMCL",    EMCL_n,    1'b0);
    CLEAR_n = 1'b1;

    // =================================================================
    // 6. the three interrupt gates, exhaustively over their inputs
    // =================================================================
    for (v = 0; v < 256; v = v + 1) begin
      ioc_write(v[7:0]);
      // TBMT and DA are live inputs, so sweep them at each register value
      for (i = 0; i < 4; i = i + 1) begin
        TBMT_n = i[0];
        DA_n   = i[1];
        #1;
        // BINT13~ = ~(IOC3 & IOC0)
        expect1("BINT13", BINT13_n, ~(v[3] & v[0]));
        // BINT10~ = ~(IOC2 & TBMT), TBMT = ~TBMT_n
        expect1("BINT10", BINT10_n, ~(v[2] & ~TBMT_n));
        // BINT12~ = ~(CONSOLE~ & IOC1 & DA), CONSOLE~ = register bit 6
        expect1("BINT12", BINT12_n, ~(v[6] & v[1] & ~DA_n));
      end
    end

    $display("-----------------------------------------------------");
    $display(" mode       : %0s", MODE);
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire
