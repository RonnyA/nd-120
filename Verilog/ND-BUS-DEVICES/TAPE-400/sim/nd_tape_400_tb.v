/**************************************************************************
** TESTBENCH: ND_TAPE_400 through ND_BUS_SLAVE                           **
**                                                                       **
** DUT: ND-BUS-DEVICES/TAPE-400/circuit/ND_TAPE_400.v                    **
** Same scripted CPU-side bus master as the FLOPPY/BUS-IF tbs; the byte  **
** source is a tape array in the tb (serves a byte src_delay cycles      **
** after byte_req, 0x00 past end-of-tape like the C model's blank tape). **
**                                                                       **
** Covered: reset state, IOX 400/402 reads and 403 control writes,       **
** iox_sel per-core decode + iox_hit gating (foreign addresses get no    **
** BDRY/BINPUT answer), RFT preset/clear, activate -> byte_req ->        **
** byte_valid -> RFT stream (full 16-byte tape readout), end-of-tape,    **
** device clear (buffer wipe + source_rewind), level-12 interrupt,       **
** IDENT 02 on level 12 only + clear-on-IDENT + grant daisy chain,       **
** and a seeded random soak against a register-level model.              **
**                                                                       **
** Golden reference: the nd100x emulator papertape model                 **
** (src/devices/papertape/devicePapertape.c). Divergences of the RTL     **
** from that oracle are PINNED here as RTL behavior, marked "PIN-Dn":    **
**   PIN-D1  reset: oracle sets readyForTransfer=1 after reset, the      **
**           RTL resets RFT to 0 (RFT first rises on preset/byte).       **
**   PIN-D2  control write: the oracle sets readyForTransfer=1 after     **
**           EVERY control-word write regardless of the data; the RTL    **
**           loads RFT from control bit 3 (preset) and forces it 0      **
**           while an activate fetch is outstanding.                     **
**   PIN-D3  device clear (bit 4): the oracle leaves RFT=1 (set          **
**           unconditionally after the clear), the RTL forces RFT=0.     **
**   PIN-D4  activate (bit 2): the oracle fetches the byte inside the    **
**           control write (RFT back to 1 instantly); the RTL raises     **
**           RFT only when byte_valid arrives (documented in the RTL     **
**           header - the polling loader tolerates this by design).      **
** Where they agree (data-read clears RFT, status bit layout, ident 02   **
** level 12, IDENT clears interrupt-enable but keeps RFT, device clear   **
** rewinds the tape and wipes the buffer) the oracle behavior is         **
** encoded as the golden expectation.                                    **
**                                                                       **
** Verdict: TB_RESULT: PASS (<n> checks) with a hard expected count,     **
** TB_RESULT: FAIL otherwise. Teeth-proven against a status-bit-swap     **
** mutant compiled from a scratch copy.                                  **
**                                                                       **
** Last reviewed: 01-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

`timescale 1ns / 1ps

module nd_tape_400_tb;

  // Hard gate: the run must perform exactly this many checks to pass.
  localparam EXPECTED_CHECKS = 355;

  reg sysclk = 0;
  reg sys_rst_n = 0;
  always #10 sysclk = ~sysclk;

  // CPU-side bus
  reg  [23:0] bd_out = 24'hFFFFFF;
  wire [23:0] bd_in;
  reg  bapr_n = 1, bioxe_n = 1, binack_n = 1, outident_n = 1;
  wire binput_n, bdap_n, bdry_n;
  wire bint10_n, bint11_n, bint12_n, bint13_n;

  wire [15:0] iox_addr, iox_wdata, iox_rdata;
  wire iox_wr, iox_rd;
  wire ident_strobe;
  wire [3:0] ident_level;
  wire [3:0] intp;
  wire ident_hit;
  wire [15:0] ident_code;
  wire tape_sel;
  wire tape_grant_out;

  // iox_hit is the tape core's own address decode: a foreign address must
  // leave the slave silent (CPU bus timeout path).
  ND_BUS_SLAVE u_slave (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .BD_23_0_n_OUT(bd_out), .BD_23_0_n_IN(bd_in),
      .BAPR_n(bapr_n), .BIOXE_n(bioxe_n), .BINACK_n(binack_n),
      .OUTIDENT_n(outident_n),
      .BINPUT_n(binput_n), .BDAP_n(bdap_n), .BDRY_n(bdry_n),
      .BINT10_n(bint10_n), .BINT11_n(bint11_n),
      .BINT12_n(bint12_n), .BINT13_n(bint13_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata), .iox_hit(tape_sel),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_hit(ident_hit), .ident_code(ident_code)
  );

  // Byte source wires
  wire       byte_req;
  reg        byte_valid = 0;
  reg  [7:0] byte_data = 0;
  wire       source_rewind;

  ND_TAPE_400 u_tape (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .iox_addr(iox_addr), .iox_wr(iox_wr), .iox_wdata(iox_wdata),
      .iox_rd(iox_rd), .iox_rdata(iox_rdata),
      .iox_sel(tape_sel),
      .int_pending(intp),
      .ident_strobe(ident_strobe), .ident_level(ident_level),
      .ident_grant_in(1'b1), .ident_grant_out(tape_grant_out),
      .ident_hit(ident_hit), .ident_code(ident_code),
      .byte_req(byte_req), .byte_valid(byte_valid),
      .byte_data(byte_data), .source_rewind(source_rewind)
  );

  // ---- tape source model (file image stand-in) ----
  // Serves tape[tape_pos] src_delay cycles after byte_req; past the end it
  // serves 0x00, the C model's blank-tape/EOF behavior. source_rewind
  // resets the position (the C model's tapePosition = 0 on device clear).
  localparam TAPE_LEN = 16;
  reg [7:0] tape[0:TAPE_LEN-1];
  integer tape_pos = 0;
  integer src_delay = 4;
  integer ii;
  initial begin
    for (ii = 0; ii < TAPE_LEN; ii = ii + 1)
      tape[ii] = 8'h11 + ii[7:0] * 8'h13;  // nonzero, all distinct
  end

  always @(posedge sysclk) begin
    if (source_rewind) tape_pos <= 0;
    else if (byte_req) begin
      repeat (src_delay) @(posedge sysclk);
      byte_data  <= (tape_pos < TAPE_LEN) ? tape[tape_pos] : 8'd0;
      byte_valid <= 1'b1;
      tape_pos   <= tape_pos + 1;
      @(posedge sysclk);
      byte_valid <= 1'b0;
    end
  end

  // ---- strobe monitors (1-cycle pulses the test thread cannot sample) ----
  reg saw_req = 0, saw_rewind = 0;
  reg mon_strobe_seen = 0, mon_grant_out = 1'bx, mon_hit = 1'bx;
  always @(posedge sysclk) begin
    if (byte_req) saw_req <= 1'b1;
    if (source_rewind) saw_rewind <= 1'b1;
    if (ident_strobe) begin
      mon_strobe_seen <= 1'b1;
      mon_grant_out   <= tape_grant_out;
      mon_hit         <= ident_hit;
    end
  end

  integer errors = 0;
  integer checks = 0;

  task check(input cond, input [255:0] what);
    begin
      checks = checks + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s (time %0t)", what, $time);
      end
    end
  endtask

  // ---- bus master tasks (same sequences as the FLOPPY/BUS-IF tbs) ----

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
      bus_apr(addr | 16'd1);
      bd_out  = ~{8'd0, data};
      bioxe_n = 0;
      guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk); guard = guard + 1;
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
      bus_apr(addr & 16'hFFFE);
      bioxe_n = 0;
      guard = 0;
      while (binput_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk); guard = guard + 1;
      end
      check(binput_n === 1'b0, "iox_read: BINPUT_n never asserted");
      binack_n = 0;
      guard = 0;
      while (bdry_n !== 1'b0 && guard < 50) begin
        @(negedge sysclk); guard = guard + 1;
      end
      check(bdry_n === 1'b0, "iox_read: BDRY_n never asserted");
      data = ~bd_in[15:0];
      binack_n = 1;
      bioxe_n  = 1;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  // Foreign-address transactions: the slave must stay silent (iox_hit=0),
  // which on the real bus ends in a timeout -> level-14 IOX error.
  task iox_write_noans(input [15:0] addr, input [15:0] data);
    begin
      bus_apr(addr | 16'd1);
      check(tape_sel === 1'b0, "foreign write: iox_sel asserted");
      bd_out  = ~{8'd0, data};
      bioxe_n = 0;
      repeat (20) @(negedge sysclk);
      check(bdry_n === 1'b1, "foreign write: BDRY_n answered");
      bioxe_n = 1;
      bd_out  = 24'hFFFFFF;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  task iox_read_noans(input [15:0] addr);
    begin
      bus_apr(addr & 16'hFFFE);
      check(tape_sel === 1'b0, "foreign read: iox_sel asserted");
      bioxe_n = 0;
      repeat (20) @(negedge sysclk);
      check(binput_n === 1'b1, "foreign read: BINPUT_n answered");
      bioxe_n = 1;
      @(negedge sysclk);
      @(negedge sysclk);
    end
  endtask

  task ident(input [15:0] levelcode, output hit, output [15:0] code);
    integer guard;
    begin
      mon_strobe_seen = 0;
      bus_apr(levelcode);
      outident_n = 0;
      guard = 0;
      while (binput_n !== 1'b0 && guard < 10) begin
        @(negedge sysclk); guard = guard + 1;
      end
      if (binput_n === 1'b0) begin
        hit = 1;
        binack_n = 0;
        guard = 0;
        while (bdry_n !== 1'b0 && guard < 50) begin
          @(negedge sysclk); guard = guard + 1;
        end
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

  // Poll status until RFT (bit 3), as the real polling loader does.
  // Deterministic: the source delay is fixed, so the poll count is fixed.
  task wait_rft;
    integer guard;
    reg [15:0] st;
    begin
      guard = 0;
      st = 0;
      while (!(st & 16'o000010) && guard < 200) begin
        iox_read(16'o000402, st);
        guard = guard + 1;
      end
      check((st & 16'o000010) !== 0, "RFT never rose after activate");
    end
  endtask

  reg [15:0] rdata;
  reg        ihit;
  reg [15:0] icode;
  integer    i;

  // soak model state
  integer seed;
  integer r, op, b0, b3;
  reg        m_int, m_rft;
  reg [7:0]  m_buf;
  integer    m_pos;

  initial begin
`ifdef DUMPFILE
    $dumpfile("nd_tape_400_tb.vcd");
    $dumpvars(0, nd_tape_400_tb);
`endif
    repeat (5) @(negedge sysclk);
    sys_rst_n = 1;
    repeat (5) @(negedge sysclk);

    // A: reset state.
    // PIN-D1: the oracle (PaperTape_Reset) sets readyForTransfer=1 after
    // reset; the RTL resets RFT to 0. Pinned as RTL behavior.
    iox_read(16'o000402, rdata);
    check(rdata === 16'd0, "status not 0 after reset (PIN-D1)");
    iox_read(16'o000400, rdata);
    check(rdata === 16'd0, "data buffer not 0 after reset");
    iox_read(16'o000402, rdata);
    check(rdata === 16'd0, "status changed by a data read at reset");
    check(bint10_n & bint11_n & bint12_n & bint13_n,
          "an interrupt line asserted after reset");

    // B: iox_sel decode + iox_hit gating.
    // This core owns 400-403 only; 404-407 is paper tape reader 2 (oracle
    // thumbwheel 1) and must NOT answer here.
    bus_apr(16'o000400);
    check(tape_sel === 1'b1, "iox_sel not asserted for 400");
    bus_apr(16'o000402);
    check(tape_sel === 1'b1, "iox_sel not asserted for 402");
    bus_apr(16'o000404);
    check(tape_sel === 1'b0, "iox_sel asserted for foreign 404");
    bus_apr(16'o000377);
    check(tape_sel === 1'b0, "iox_sel asserted for foreign 377");
    iox_write_noans(16'o000407, 16'o000037);
    iox_read_noans(16'o000406);
    iox_read(16'o000402, rdata);
    check(rdata === 16'd0, "foreign control write reached this core");

    // C: control-word RFT preset semantics.
    // PIN-D2: the oracle sets readyForTransfer=1 after EVERY control write;
    // the RTL loads RFT from control bit 3. Pinned as RTL behavior.
    iox_write(16'o000403, 16'o000010);       // RFT preset
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000010, "RFT preset (bit 3) did not set status");
    check(bint12_n === 1'b1, "interrupt pending without enable");
    iox_write(16'o000403, 16'o000001);       // int enable, bit3=0
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000001, "control 001 status wrong (PIN-D2: RTL clears RFT)");
    check(bint12_n === 1'b1, "interrupt pending with RFT clear");
    iox_write(16'o000403, 16'o000011);       // int enable + RFT
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000011, "control 011 status wrong");
    check(bint12_n === 1'b0, "BINT12_n not asserted with enable+RFT");
    check(bint10_n & bint11_n & bint13_n, "wrong interrupt level asserted");
    iox_write(16'o000403, 16'o000000);       // all off
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000000, "control 000 did not clear status");
    check(bint12_n === 1'b1, "BINT12_n not released by control 000");

    // D: activate with a slow source - the RFT-wait window is observable.
    // PIN-D4: the oracle fetches the byte inside the control write; the RTL
    // waits for byte_valid, so status shows readActive=1/RFT=0 meanwhile.
    src_delay = 60;
    saw_req = 0;
    iox_write(16'o000403, 16'o000004);       // activate
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000004, "readActive/RFT wrong while fetch pending (PIN-D4)");
    check(saw_req === 1'b1, "byte_req did not pulse on activate");
    wait_rft();
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000010, "readActive not cleared when byte arrived");
    iox_read(16'o000400, rdata);
    check(rdata === {8'd0, tape[0]}, "first tape byte wrong");
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000000, "data read did not clear RFT");

    // E: full character-stream readout, bytes 1..15.
    src_delay = 4;
    for (i = 1; i < TAPE_LEN; i = i + 1) begin
      iox_write(16'o000403, 16'o000004);
      wait_rft();
      iox_read(16'o000400, rdata);
      check(rdata === {8'd0, tape[i]}, "stream byte wrong");
    end

    // F: end of tape - the source serves 0x00 (C model blank-tape/EOF),
    // RFT still rises.
    iox_write(16'o000403, 16'o000004);
    wait_rft();
    iox_read(16'o000400, rdata);
    check(rdata === 16'd0, "EOF byte not 0");

    // G: device clear (bit 4): buffer wiped, tape rewound.
    // PIN-D3: the oracle leaves RFT=1 after device clear; RTL forces RFT=0.
    saw_rewind = 0;
    iox_write(16'o000403, 16'o000020);
    check(saw_rewind === 1'b1, "source_rewind did not pulse on device clear");
    iox_read(16'o000402, rdata);
    check(rdata === 16'd0, "status not 0 after device clear (PIN-D3)");
    iox_read(16'o000400, rdata);
    check(rdata === 16'd0, "buffer not wiped by device clear");
    iox_write(16'o000403, 16'o000004);       // rewound: byte 0 again
    wait_rft();
    iox_read(16'o000400, rdata);
    check(rdata === {8'd0, tape[0]}, "rewind did not restart the tape");
    iox_write(16'o000403, 16'o000004);       // fetch byte 1 into the buffer
    wait_rft();
    iox_write(16'o000403, 16'o000020);       // clear again (buffer loaded)
    iox_read(16'o000400, rdata);
    check(rdata === 16'd0, "loaded buffer survived device clear");
    // clear+enable: bit 0 is honored alongside bit 4 (both sides agree)
    iox_write(16'o000403, 16'o000021);
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000001, "int enable lost during device clear");
    check(bint12_n === 1'b1, "pending after device clear (RFT=0)");
    iox_write(16'o000403, 16'o000000);

    // H: interrupt + IDENT. Ident code 02, level 12 only; IDENT clears the
    // enable bit but keeps RFT (data still readable) - oracle agrees.
    iox_write(16'o000403, 16'o000005);       // enable + activate
    wait_rft();
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000011, "status wrong before IDENT");
    check(bint12_n === 1'b0, "BINT12_n not asserted");
    check(bint10_n & bint11_n & bint13_n, "wrong level asserted");
    ident(16'o000011, ihit, icode);          // IDENT PL11: not our level
    check(ihit === 1'b0, "IDENT PL11 unexpectedly hit");
    check(mon_strobe_seen === 1'b1, "no ident strobe on PL11 poll");
    check(mon_grant_out === 1'b1, "grant not passed on when not answering");
    check(bint12_n === 1'b0, "BINT12_n dropped by a foreign-level IDENT");
    ident(16'o000022, ihit, icode);          // IDENT PL12: ours
    check(ihit === 1'b1, "IDENT PL12 no hit");
    check(icode === 16'o000002, "IDENT code not 02");
    check(mon_grant_out === 1'b0, "grant passed on while answering");
    check(bint12_n === 1'b1, "BINT12_n not released after IDENT");
    iox_read(16'o000402, rdata);
    check(rdata === 16'o000010, "IDENT did not keep RFT / clear enable");
    iox_read(16'o000400, rdata);
    check(rdata === {8'd0, tape[0]}, "data lost across IDENT");
    ident(16'o000022, ihit, icode);
    check(ihit === 1'b0, "second IDENT PL12 unexpectedly hit");

    // I: seeded random soak vs a register-level model of the pinned RTL
    // semantics (fixed seed -> deterministic op mix and check count).
    seed  = 32'd1;
    m_int = 0; m_rft = 0; m_buf = tape[0]; m_pos = 1;
    for (i = 0; i < 32; i = i + 1) begin
      r  = $random(seed);
      op = r & 3;
      b0 = (r >> 2) & 1;
      b3 = (r >> 3) & 1;
      case (op)
        0: begin  // plain control write
          iox_write(16'o000403, {12'd0, b3[0], 2'b00, b0[0]});
          m_int = b0[0]; m_rft = b3[0];
        end
        1: begin  // status readback vs model
          iox_read(16'o000402, rdata);
          check(rdata === {12'd0, m_rft, 3'b000} + {15'd0, m_int},
                "soak: status mismatch");
        end
        2: begin  // activate (with random enable), wait for the byte
          iox_write(16'o000403, {12'd0, 1'b0, 1'b1, 1'b0, b0[0]});
          m_int = b0[0];
          wait_rft();
          m_buf = (m_pos < TAPE_LEN) ? tape[m_pos] : 8'd0;
          m_pos = m_pos + 1;
          m_rft = 1;
        end
        3: begin  // data readback vs model
          iox_read(16'o000400, rdata);
          check(rdata === {8'd0, m_buf}, "soak: data mismatch");
          m_rft = 0;
        end
      endcase
      check(bint12_n === ~(m_int & m_rft), "soak: BINT12_n mismatch");
    end

    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else begin
      $display("%0d errors, %0d checks (expected %0d)",
               errors, checks, EXPECTED_CHECKS);
      $display("TB_RESULT: FAIL");
    end
    $finish;
  end

  initial begin
    #20000000;
    $display("TIMEOUT");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
