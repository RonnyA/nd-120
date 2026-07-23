/**************************************************************************
** TESTBENCH: ND_BUS_SLAVE + two ND_TAPE_400 cores                       **
**                                                                       **
** A scripted CPU-side bus master drives the exact signal sequences the  **
** C reference model (simDevices/NDBus.cpp) documents:                   **
**   IOX write:  BAPR(addr,lsb=1) -> BIOXE low w/ data -> BDRY -> release**
**   IOX read:   BAPR(addr,lsb=0) -> BIOXE low -> BINPUT -> BINACK ->    **
**               BDAP+BDRY w/ data -> release                            **
**   IDENT:      BAPR(levelcode) -> OUTIDENT low -> BINPUT -> BINACK ->  **
**               BDAP+BDRY w/ ident code -> release                      **
**                                                                       **
** Two tape cores (base 400 ident 02, base 404 ident 022, both level 12) **
** prove the daisy-chain priority and the clear-on-IDENT rule.           **
**                                                                       **
** Verdict line: TB_RESULT: PASS / TB_RESULT: FAIL                       **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_bus_slave_tb;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;  // 50 MHz

  // CPU-side bus (driven by the master tasks)
  reg  [23:0] bd_out = 24'hFFFFFF;  // CPU drives this (active low)
  wire [23:0] bd_in;                // devices drive this (active low)
  reg         bapr_n = 1;
  reg         bioxe_n = 1;
  reg         binack_n = 1;
  reg         outident_n = 1;
  wire        binput_n, bdap_n, bdry_n;
  wire        bint10_n, bint11_n, bint12_n, bint13_n;

  // Device bus
  wire [15:0] iox_addr;
  wire        iox_wr, iox_rd;
  wire [15:0] iox_wdata;
  wire [15:0] iox_rdata;
  wire        ident_strobe;
  wire [3:0]  ident_level;

  // Per-core OR-bus contributions
  wire [15:0] rdata_a, rdata_b;
  wire [3:0]  intp_a, intp_b;
  wire        hit_a, hit_b;
  wire [15:0] code_a, code_b;
  wire        grant_ab;  // chain: core A -> core B

  assign iox_rdata = rdata_a | rdata_b;

  ND_BUS_SLAVE u_slave (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .BD_23_0_n_OUT(bd_out),
      .BD_23_0_n_IN(bd_in),
      .BAPR_n(bapr_n),
      .BIOXE_n(bioxe_n),
      .BINACK_n(binack_n),
      .OUTIDENT_n(outident_n),
      .BINPUT_n(binput_n),
      .BDAP_n(bdap_n),
      .BDRY_n(bdry_n),
      .BINT10_n(bint10_n),
      .BINT11_n(bint11_n),
      .BINT12_n(bint12_n),
      .BINT13_n(bint13_n),
      .iox_addr(iox_addr),
      .iox_wr(iox_wr),
      .iox_wdata(iox_wdata),
      .iox_rd(iox_rd),
      .iox_rdata(iox_rdata),
      .int_pending(intp_a | intp_b),
      .ident_strobe(ident_strobe),
      .ident_level(ident_level),
      .ident_hit(hit_a | hit_b),
      .ident_code(code_a | code_b)
  );

  // Byte sources: tiny tape images
  reg [7:0] tape_a_mem [0:15];
  reg [7:0] tape_b_mem [0:15];
  integer   tape_a_pos = 0;
  integer   tape_b_pos = 0;

  wire byte_req_a, byte_req_b, rewind_a, rewind_b;
  reg  byte_valid_a = 0, byte_valid_b = 0;
  reg [7:0] byte_data_a = 0, byte_data_b = 0;

  // Serve byte requests with a 3-cycle latency (like a real source)
  always @(posedge sysclk) begin
    byte_valid_a <= 1'b0;
    byte_valid_b <= 1'b0;
    if (rewind_a) tape_a_pos <= 0;
    if (rewind_b) tape_b_pos <= 0;
    if (byte_req_a) begin
      repeat (3) @(posedge sysclk);
      byte_data_a  <= tape_a_mem[tape_a_pos];
      tape_a_pos   <= tape_a_pos + 1;
      byte_valid_a <= 1'b1;
    end
    if (byte_req_b) begin
      repeat (3) @(posedge sysclk);
      byte_data_b  <= tape_b_mem[tape_b_pos];
      tape_b_pos   <= tape_b_pos + 1;
      byte_valid_b <= 1'b1;
    end
  end

  ND_TAPE_400 #(
      .BASE_ADDR (16'o000400),
      .IDENT_CODE(16'o000002),
      .INT_LEVEL (4'd12)
  ) u_tape_a (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr),
      .iox_wr(iox_wr),
      .iox_wdata(iox_wdata),
      .iox_rd(iox_rd),
      .iox_rdata(rdata_a),
      .int_pending(intp_a),
      .ident_strobe(ident_strobe),
      .ident_level(ident_level),
      .ident_grant_in(1'b1),
      .ident_grant_out(grant_ab),
      .ident_hit(hit_a),
      .ident_code(code_a),
      .byte_req(byte_req_a),
      .byte_valid(byte_valid_a),
      .byte_data(byte_data_a),
      .source_rewind(rewind_a)
  );

  ND_TAPE_400 #(
      .BASE_ADDR (16'o000404),
      .IDENT_CODE(16'o000022),
      .INT_LEVEL (4'd12)
  ) u_tape_b (
      .sysclk(sysclk),
      .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr),
      .iox_wr(iox_wr),
      .iox_wdata(iox_wdata),
      .iox_rd(iox_rd),
      .iox_rdata(rdata_b),
      .int_pending(intp_b),
      .ident_strobe(ident_strobe),
      .ident_level(ident_level),
      .ident_grant_in(grant_ab),
      .ident_grant_out(),
      .ident_hit(hit_b),
      .ident_code(code_b),
      .byte_req(byte_req_b),
      .byte_valid(byte_valid_b),
      .byte_data(byte_data_b),
      .source_rewind(rewind_b)
  );

  integer errors = 0;

  task check(input cond, input [255:0] what);
    begin
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s (time %0t)", what, $time);
      end
    end
  endtask

  // ---------- CPU-side bus master tasks (the NDBus.cpp sequences) ----------

  task bus_apr(input [15:0] addr);
    begin
      @(negedge sysclk);
      bd_out = ~{8'd0, addr};
      bapr_n = 0;
      @(negedge sysclk);
      @(negedge sysclk);
      bapr_n = 1;
      bd_out = 24'hFFFFFF;
      @(negedge sysclk);
    end
  endtask

  task iox_write(input [15:0] addr, input [15:0] data);
    integer guard;
    begin
      bus_apr(addr | 16'd1);  // LSB=1 -> write
      bd_out  = ~{8'd0, data};
      bioxe_n = 0;
      guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk);
        guard = guard + 1;
      end
      check(bdry_n === 1'b0, "iox_write: BDRY_n never asserted");
      @(negedge sysclk);
      bioxe_n = 1;
      bd_out  = 24'hFFFFFF;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  task iox_read(input [15:0] addr, output [15:0] data);
    integer guard;
    begin
      bus_apr(addr & 16'hFFFE);  // LSB=0 -> read
      bioxe_n = 0;
      guard = 0;
      while (binput_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk);
        guard = guard + 1;
      end
      check(binput_n === 1'b0, "iox_read: BINPUT_n never asserted");
      binack_n = 0;
      guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk);
        guard = guard + 1;
      end
      check(bdry_n === 1'b0, "iox_read: BDRY_n never asserted");
      check(bdap_n === 1'b0, "iox_read: BDAP_n not asserted with BDRY_n");
      data = ~bd_in[15:0];
      binack_n = 1;
      bioxe_n  = 1;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  // IDENT PL<level>: levelcode = 004/011/022/043 for 10/11/12/13
  task ident(input [15:0] levelcode, output hit, output [15:0] code);
    integer guard;
    begin
      bus_apr(levelcode);
      outident_n = 0;
      guard = 0;
      while (binput_n !== 1'b0 && guard < 10) begin
        @(negedge sysclk);
        guard = guard + 1;
      end
      if (binput_n === 1'b0) begin
        hit = 1;
        binack_n = 0;
        guard = 0;
        while (bdry_n !== 1'b0 && guard < 50) begin
          @(negedge sysclk);
          guard = guard + 1;
        end
        check(bdry_n === 1'b0, "ident: BDRY_n never asserted");
        code = ~bd_in[15:0];
        binack_n = 1;
      end else begin
        hit  = 0;
        code = 0;
      end
      outident_n = 1;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  // ---------- Test sequence ----------

  reg [15:0] rdata;
  reg        ihit;
  reg [15:0] icode;
  integer    i, guard;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_bus_slave_tb.vcd");
    $dumpvars(0, nd_bus_slave_tb);
`endif
    for (i = 0; i < 16; i = i + 1) begin
      tape_a_mem[i] = 8'hA0 + i[7:0];
      tape_b_mem[i] = 8'h50 + i[7:0];
    end

    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // 1: status starts empty; unclaimed address reads 0
    iox_read(16'o000402, rdata);
    check(rdata === 16'd0, "initial status not 0");
    iox_read(16'o000500, rdata);
    check(rdata === 16'd0, "unclaimed address not 0");

    // 2: activate (control bit2) -> RFT rises when the byte arrives
    iox_write(16'o000403, 16'o000004);
    guard = 0;
    rdata = 0;
    while (!(rdata & 16'o000010) && guard < 30) begin
      iox_read(16'o000402, rdata);
      guard = guard + 1;
    end
    check((rdata & 16'o000010) !== 0, "RFT never rose after activate");
    check(bint12_n === 1'b1, "BINT12 asserted without interrupt enable");

    // 3: read data register: first tape byte, and RFT clears
    iox_read(16'o000400, rdata);
    check(rdata === 16'h00A0, "tape A byte 0 wrong");
    iox_read(16'o000402, rdata);
    check((rdata & 16'o000010) === 0, "RFT did not clear on data read");

    // 4: stream 3 more bytes the way the microcode loader does
    for (i = 1; i <= 3; i = i + 1) begin
      iox_write(16'o000403, 16'o000004);
      guard = 0;
      rdata = 0;
      while (!(rdata & 16'o000010) && guard < 30) begin
        iox_read(16'o000402, rdata);
        guard = guard + 1;
      end
      iox_read(16'o000400, rdata);
      check(rdata === (16'h00A0 + i[15:0]), "tape A byte stream wrong");
    end

    // 5: device clear rewinds; next byte is byte 0 again
    iox_write(16'o000403, 16'o000020);
    iox_write(16'o000403, 16'o000004);
    guard = 0;
    rdata = 0;
    while (!(rdata & 16'o000010) && guard < 30) begin
      iox_read(16'o000402, rdata);
      guard = guard + 1;
    end
    iox_read(16'o000400, rdata);
    check(rdata === 16'h00A0, "rewind did not restart tape A");

    // 6: interrupts + IDENT daisy chain. Enable+activate BOTH tapes.
    iox_write(16'o000403, 16'o000005);  // tape A: IE + activate
    iox_write(16'o000407, 16'o000005);  // tape B: IE + activate
    guard = 0;
    while (bint12_n !== 1'b0 && guard < 60) begin
      @(negedge sysclk);
      guard = guard + 1;
    end
    check(bint12_n === 1'b0, "BINT12_n not asserted with IE and RFT");
    check(bint10_n === 1'b1 && bint11_n === 1'b1 && bint13_n === 1'b1,
          "wrong BINT level asserted");

    // First IDENT PL12: chain head (tape A, ident 02) answers
    ident(16'o000022, ihit, icode);
    check(ihit === 1'b1, "first IDENT PL12 no hit");
    check(icode === 16'o000002, "first IDENT code not 02");
    check(bint12_n === 1'b0, "BINT12_n released while tape B still pending");

    // Second IDENT PL12: tape B (ident 022) answers
    ident(16'o000022, ihit, icode);
    check(ihit === 1'b1, "second IDENT PL12 no hit");
    check(icode === 16'o000022, "second IDENT code not 022");
    check(bint12_n === 1'b1, "BINT12_n still low after both cleared");

    // Third IDENT PL12: nobody left
    ident(16'o000022, ihit, icode);
    check(ihit === 1'b0, "third IDENT PL12 unexpectedly hit");

    // IDENT on a level nobody uses
    ident(16'o000011, ihit, icode);
    check(ihit === 1'b0, "IDENT PL11 unexpectedly hit");

    // 7: after IDENT the enable bit is cleared, data is still there
    iox_read(16'o000402, rdata);
    check((rdata & 16'o000001) === 0, "IE not cleared by IDENT");
    check((rdata & 16'o000010) !== 0, "RFT lost by IDENT");
    iox_read(16'o000400, rdata);
    check(rdata === 16'h00A1, "tape A data lost by IDENT");  // step 6 fetched byte 1

    // 8: second device address decode (tape B data at 404)
    iox_read(16'o000404, rdata);
    check(rdata === 16'h0050, "tape B byte 0 wrong");

    if (errors == 0) $display("TB_RESULT: PASS");
    else begin
      $display("%0d errors", errors);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #4000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
