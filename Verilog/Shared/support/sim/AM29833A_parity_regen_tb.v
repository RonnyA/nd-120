/****************************************************************************
** AM29833A parity-convention testbench: REGENERATED parity must not fault  **
**                                                                          **
** WHY THIS EXISTS                                                          **
** No ND-120 memory backend stores parity (policy, 3-AUG-2026). Every       **
** sheet-49 backend drops DD[8] / DD[17] on write and regenerates them on    **
** read as ODD parity of the byte:  PAR = ~^data.                           **
**                                                                          **
** That is only safe if the regenerated bit is what the AM29833A - the chip  **
** that actually checks parity on the board (MEM_DATA_46 CHIP_1H / CHIP_2H) **
** - considers CORRECT. If the polarity were backwards, every memory read    **
** would be a parity error the day MEM_43's LPERR_n mask is removed, and     **
** nothing else in the suite would notice, because the mask hides it today.  **
**                                                                          **
** So this tb feeds the chip a regenerated word over all 256 byte values and **
** asserts ERR_n never fires; then it INVERTS the parity bit over all 256    **
** and asserts ERR_n fires every time (the teeth: a tb that only checks the  **
** good case would pass with the error logic dead).                          **
**                                                                          **
** MODE - READ THIS BEFORE CHANGING THE TB                                   **
** The check is driven in TRANSMIT mode (OET_n=0, OER_n=1) because that is    **
** the only mode AM29833A.v currently evaluates in: AM29833A.v:126 guards the **
** error register with `else if (!ReceiveMode)`. The datasheet text quoted at **
** the top of AM29833A.v says the parity test belongs to RECEIVE mode, and    **
** MEM_DATA_46 wires T to the memory bus and R to LBD - so a memory READ is   **
** receive mode, and the board's parity check does not evaluate there today.  **
** That discrepancy is logged in Verilog/TODO.md; it is NOT this tb's job to  **
** decide it. What this tb does prove is the POLARITY: whatever mode the      **
** check finally runs in, ~^data is the value the chip calls correct.         **
**                                                                          **
** Prints "TB_RESULT: PASS" on success.                                     **
**                                                                          **
** Last reviewed: 3-AUG-2026                                                **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps

module AM29833A_parity_regen_tb;

  reg sysclk = 0;
  always #5 sysclk = ~sysclk;

  reg        CLK = 0;
  reg        CLR_n = 1;
  reg  [7:0] T = 8'd0;
  reg        PAR = 1'b0;
  wire       ERR_n;
  wire [7:0] R_OUT;
  wire [7:0] T_OUT;
  wire       PAR_OUT;

  integer errors = 0;
  integer i;

  // TRANSMIT mode (OET_n=0, OER_n=1) - the mode this model evaluates the
  // parity check in; see the MODE note in the header.
  AM29833A DUT (
      .sysclk (sysclk),
      .CLK    (CLK),
      .CLR_n  (CLR_n),
      .ERR_n  (ERR_n),
      .OER_n  (1'b1),
      .OET_n  (1'b0),
      .PAR    (PAR),
      .PAR_OUT(PAR_OUT),
      .R      (8'd0),
      .R_OUT  (R_OUT),
      .T      (T),
      .T_OUT  (T_OUT)
  );

  // Clock one parity evaluation into the error register and return it.
  task strobe;
    begin
      CLR_n = 0; #10; CLR_n = 1; #10;   // clear any previous verdict
      CLK = 0; #10; CLK = 1; #10; CLK = 0; #10;
    end
  endtask

  initial begin
    // ---- 1. regenerated parity must NEVER fault -------------------------
    for (i = 0; i < 256; i = i + 1) begin
      T   = i[7:0];
      PAR = ~(^i[7:0]);          // exactly what the memory backends generate
      strobe;
      if (ERR_n !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL: regenerated parity faulted for data=%02h (PAR=%b)",
                 i[7:0], PAR);
      end
    end

    // ---- 2. teeth: the INVERTED bit must ALWAYS fault --------------------
    for (i = 0; i < 256; i = i + 1) begin
      T   = i[7:0];
      PAR = ^i[7:0];             // wrong polarity - what "return 0" gets right
      strobe;                    // only by accident, half the time
      if (ERR_n !== 1'b0) begin
        errors = errors + 1;
        $display("FAIL: inverted parity did NOT fault for data=%02h (PAR=%b)",
                 i[7:0], PAR);
      end
    end

    // ---- 3. the constant-0 bit the old FPGA path returned ----------------
    // Not a separate rule, just the concrete consequence: it is correct only
    // for bytes of ODD population, i.e. wrong for 128 of the 256 values.
    begin : const_zero_case
      integer bad;
      bad = 0;
      for (i = 0; i < 256; i = i + 1) begin
        T   = i[7:0];
        PAR = 1'b0;
        strobe;
        if (ERR_n === 1'b0) bad = bad + 1;
      end
      if (bad != 128) begin
        errors = errors + 1;
        $display("FAIL: constant-0 parity faulted %0d of 256 (expected 128)", bad);
      end else begin
        $display("NOTE: constant-0 parity faults %0d of 256 values, as expected",
                 bad);
      end
    end

    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #500000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule
