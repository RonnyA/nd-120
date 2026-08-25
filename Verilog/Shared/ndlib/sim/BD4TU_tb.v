/****************************************************************************
** BD4TU - self-checking testbench, and a BUG REPORT IN EXECUTABLE FORM    **
**                                                                         **
** BD4TU is the bidirectional data buffer drawn on CGA sheet 5/10 page 6.  **
** Ports: A (write data in), IO (bidirectional pin), EN, TN, ZI (read      **
** data out). Its own comment says:                                        **
**     "EN. H = READ from BUF to ZI, L = WRITE from A to BUF"              **
**                                                                         **
** WHAT THE RTL ACTUALLY DOES - measured, not assumed:                     **
**                                                                         **
**   1. THE READ PATH IS DEAD. ZI is driven by                             **
**          assign ZI = TN ? ZI_REG : 1'b0;                                **
**      and ZI_REG is DECLARED AND NEVER ASSIGNED ANYWHERE in the file.    **
**      The always block writes internalData, not ZI_REG. So with TN high  **
**      - and TN is documented as tied permanently HIGH (PTSTN) - ZI is    **
**      UNKNOWN (x) for every input combination, forever. The only way to  **
**      get a defined ZI out of this cell today is to pull TN low, which   **
**      forces ZI to 0 and is not what TN is for.                          **
**                                                                         **
**   2. IN READ MODE THE CELL FIGHTS THE BUS. The output driver is         **
**          assign IO = (EN == 1'b0) ? internalData : 1'b0;                **
**      so when EN is high (read) it does not release IO - it actively     **
**      DRIVES ZERO onto it. Against an external driver holding 1 the net  **
**      resolves to x. The repo convention "a disabled output drives 0,    **
**      never z" is right for a one-way bus that gets OR-ed, but on a      **
**      genuinely bidirectional pin it makes the read direction unusable.  **
**                                                                         **
**   3. The write path DOES work: with EN low, IO follows A.               **
**                                                                         **
** BD4TU is instantiated NOWHERE in the repository (checked across every   **
** .v file under Verilog/ on 20-AUG-2026), which is why nothing has broken **
** yet. This testbench asserts the behaviour as it is TODAY, including the **
** x on ZI, so that:                                                       **
**   - nobody wires this cell up believing the read path works, and        **
**   - the day someone fixes ZI_REG, these checks fail loudly and force a  **
**     deliberate update rather than a silent change of meaning.           **
**                                                                         **
** There is no clock, no reset and no preset on this cell, so those cases  **
** do not exist here; EN held in each state, an idle bus, and a bus with   **
** no driver at all are covered instead.                                   **
**                                                                         **
** BUILD MODE: no `ifdef - latch mode and -DFPGA_FF_MODE are identical.    **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-bd4tu                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module BD4TU_tb;

  integer checks = 0;
  integer errors = 0;

`define CHK(NM, GOT, EXP) \
  begin \
    checks = checks + 1; \
    if ((GOT) !== (EXP)) begin \
      errors = errors + 1; \
      $display("FAIL t=%0t %0s : got=%b expected=%b", $time, NM, (GOT), (EXP)); \
    end \
  end

  reg A = 1'b0;
  reg EN = 1'b0;      // L = write A to the bus, H = "read" (see header)
  reg TN = 1'b1;      // tied high in the drawings (PTSTN)
  reg ext_drive = 1'b0;
  reg ext_val = 1'b0;

  wire IO;
  wire ZI;

  // the far end of the bidirectional pin
  assign IO = ext_drive ? ext_val : 1'bz;

  BD4TU DUT (.A(A), .IO(IO), .EN(EN), .TN(TN), .ZI(ZI));

  initial begin
    $dumpfile("BD4TU_tb.vcd");
    $dumpvars(0, BD4TU_tb);
  end

  initial begin
    #1;

    // ---- 1. WRITE direction (EN low). This is the half that works. ----
    ext_drive = 1'b0;             // nothing else on the bus
    A = 1'b1; EN = 1'b0; #5;
    `CHK("EN=0, A=1: the cell drives 1 onto IO", IO, 1'b1)
    A = 1'b0; #5;
    `CHK("EN=0, A=0: the cell drives 0 onto IO", IO, 1'b0)
    A = 1'b1; #5;
    `CHK("EN=0, A back to 1: IO follows with no clock", IO, 1'b1)

    // EN held low over many A changes - the write path is combinational,
    // so every change must appear, and none may be held over.
    A = 1'b0; #2; `CHK("EN held low, A=0", IO, 1'b0)
    A = 1'b1; #2; `CHK("EN held low, A=1", IO, 1'b1)
    A = 1'b0; #2; `CHK("EN held low, A=0 again", IO, 1'b0)

    // ---- 2. THE READ PATH IS DEAD: ZI is x whatever happens ----
    `CHK("EN=0, TN=1: ZI is UNKNOWN (ZI_REG never assigned)", ZI, 1'bx)

    EN = 1'b1;
    ext_drive = 1'b1; ext_val = 1'b1; #5;
    `CHK("EN=1, external driver 1: ZI STILL UNKNOWN", ZI, 1'bx)
    ext_val = 1'b0; #5;
    `CHK("EN=1, external driver 0: ZI STILL UNKNOWN", ZI, 1'bx)
    ext_drive = 1'b0; #5;
    `CHK("EN=1, nobody driving: ZI STILL UNKNOWN", ZI, 1'bx)

    // ---- 3. IN READ MODE THE CELL DRIVES 0 ONTO IO AND FIGHTS ----
    ext_drive = 1'b0; #3;
    `CHK("EN=1 with no external driver: the cell drives 0, not z", IO, 1'b0)
    ext_drive = 1'b1; ext_val = 1'b0; #3;
    `CHK("EN=1, external 0 agrees with the cell's 0", IO, 1'b0)
    ext_drive = 1'b1; ext_val = 1'b1; #3;
    `CHK("EN=1, external 1 CONTENDS with the cell's 0 -> x", IO, 1'bx)

    // ---- 4. TN low is the only way to get a defined ZI, and it is 0 ----
    TN = 1'b0; #3;
    `CHK("TN=0 forces ZI to 0 regardless of everything else", ZI, 1'b0)
    ext_val = 1'b0; #3;
    `CHK("TN=0, external 0: ZI still 0", ZI, 1'b0)
    EN = 1'b0; A = 1'b1; #3;
    `CHK("TN=0 in write mode: ZI still 0", ZI, 1'b0)
    TN = 1'b1; #3;
    `CHK("TN back high: ZI returns to UNKNOWN", ZI, 1'bx)

    // ---- 5. write direction still intact after all the contention ----
    ext_drive = 1'b0; EN = 1'b0;
    A = 1'b0; #3; `CHK("write path survives: A=0", IO, 1'b0)
    A = 1'b1; #3; `CHK("write path survives: A=1", IO, 1'b1)

    $display("BD4TU_tb: checks=%0d failures=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire
