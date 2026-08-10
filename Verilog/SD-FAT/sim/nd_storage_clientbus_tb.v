/*****************************************************************************
**  nd_storage_clientbus_tb.v                                               **
**                                                                          **
**  Full path:                                                              **
**    Verilog/SD-FAT/sim/nd_storage_clientbus_tb.v                          **
**                                                                          **
**  CLIENT BUS SLICE CONTINUITY.                                            **
**                                                                          **
**  nd_storage_devices.v hands nd_storage its per-client ports as FLAT    **
**  concatenations, one 16-bit (or 1-bit, or 10-bit) slice per client:      **
**                                                                          **
**    assign buf_rdata_w = {{((N-7)*16){1'b0}}, w_buf_rdata, {2*16{1'b0}},  **
**                          m_buf_rdata, 16'd0, f_buf_rdata, a_buf_rdata};  **
**                                                                          **
**  There are five of these. A client added later gets a new slice in each, **
**  and NOTHING checks that it was actually added - a forgotten one is a    **
**  silent tie to zero that elaborates, simulates and synthesises cleanly.  **
**                                                                          **
**  WHY THIS BENCH EXISTS - 10-AUG-2026, from silicon.                      **
**                                                                          **
**  buf_rdata_w was left in its pre-Winchester (N-4) form when the          **
**  Winchester client was added, so clients 4..7 were tied to zero and      **
**  w_buf_rdata reached nothing. Only WRITES read buf_rdata; reads travel   **
**  the other way on buf_wdata/buf_we. Reads were the only thing ever       **
**  exercised anywhere, so every Winchester write silently staged 16'd0 for **
**  every word - while the DMA fetched the payload correctly AND the        **
**  controller's own buffer held it correctly - and wrote zeros to the SD   **
**  card. No error was raised by anything, because from each module's own   **
**  point of view nothing was wrong.                                        **
**                                                                          **
**  Cost on real hardware: SINTRAN mass-loads off the Winchester, starts,   **
**  and dies with "DISC TRANSFER ERROR IN SEGMENT HANDLING" the moment the  **
**  swapper writes - after quietly overwriting the disc image's master      **
**  block with zeros. Twice, because the first time the damage was read as  **
**  a bad copy of the image rather than as something the machine did.       **
**                                                                          **
**  WHAT THIS CHECKS, AND WHY IT NEEDS NO TRANSFER                          **
**                                                                          **
**  For the two disc clients the adapter passes the device buffer straight  **
**  through combinationally (nd_storage_disc_adapter.v: assign c_buf_rdata = **
**  dbuf_rdata). So driving the wrapper's SDBUF_RDATA / WDBUF_RDATA inputs  **
**  with distinct values and reading the corresponding slice of the flat    **
**  bus proves the slice is wired - with no card, no mount, no clocking and **
**  no block transfer. Milliseconds, and it fails the instant a slice is    **
**  dropped for ANY reason.                                                 **
**                                                                          **
**  Coverage limits, stated so nobody assumes more than is here:            **
**    client 0 (tape)   - c_buf_rdata is tied 16'd0 IN THE ADAPTER, by      **
**                        construction: the tape is read-only               **
**                        (nd_storage_tape_adapter.v:95). Zero is CORRECT   **
**                        here and is asserted as such.                     **
**    client 1 (floppy) - c_buf_rdata is a REGISTERED read out of the       **
**                        adapter's own block buffer, not a wrapper port,   **
**                        so it cannot be driven from outside. Its slice is **
**                        covered by the floppy's own bench instead.        **
**    clients 2,4,5,7   - no adapter exists; zero is correct.               **
**                                                                          **
**  Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
*****************************************************************************/

`timescale 1ns / 1ps

module nd_storage_clientbus_tb;

  localparam integer N = 8;   // nd_storage_devices's client count

  // Distinct, non-zero, and not equal to each other or to any plausible
  // stuck value - so a slice wired to the WRONG client fails too, not just
  // one wired to nothing.
  localparam [15:0] SMD_MARK = 16'h5A37;
  localparam [15:0] WD_MARK  = 16'hC69E;

  integer errors = 0;

  reg clk_stor = 0;
  reg clk_cpu  = 0;
  always #18.5 clk_stor = ~clk_stor;
  always #21.7 clk_cpu  = ~clk_cpu;

  reg rst_n = 0;

  reg [15:0] fdbuf_rdata = 16'd0;
  reg [15:0] sdbuf_rdata = 16'd0;
  reg [15:0] wdbuf_rdata = 16'd0;

  // The wrapper with EVERY client enabled - that is the point: the flat
  // buses only carry all their slices in this configuration.
  nd_storage_devices #(
      .SIMULATE      (1),
      .INCLUDE_TAPE  (1),
      .INCLUDE_FLOPPY(1),
      .INCLUDE_SMD   (1),
      .INCLUDE_WD    (1)
  ) u_src (
      .clk_stor      (clk_stor),
      .rst_stor_n    (rst_n),
      .clk_cpu       (clk_cpu),
      .rst_cpu_n     (rst_n),

      .byte_req      (1'b0),
      .byte_valid    (),
      .byte_data     (),
      .source_rewind (1'b0),
      .TDISK_FAULT   (),
      .TDISK_ERR_CODE(),

      .FDISK_REQ     (1'b0),
      .FDISK_WR      (1'b0),
      .FDISK_LSECT   (16'd0),
      .FDISK_FORMAT  (2'd0),
      .FDISK_DRIVE   (2'd0),
      .FDISK_WORDCOUNT(11'd0),
      .FDISK_DONE    (),
      .FDISK_ERR     (),
      .FDISK_ERR_CODE(),
      .FDISK_MEDIA_FMT(),
      .FDBUF_ADDR    (),
      .FDBUF_WDATA   (),
      .FDBUF_WE      (),
      .FDBUF_RDATA   (fdbuf_rdata),

      .SDISK_START   (1'b0),
      .SDISK_REQ     (1'b0),
      .SDISK_WR      (1'b0),
      .SDISK_BLKADDR1(16'd0),
      .SDISK_BLKADDR2(16'd0),
      .SDISK_UNIT    (3'd0),
      .SDISK_WORDCOUNT(11'd0),
      .SDISK_DONE    (),
      .SDISK_ERR     (),
      .SDISK_ERR_CODE(),
      .SDBUF_ADDR    (),
      .SDBUF_WDATA   (),
      .SDBUF_WE      (),
      .SDBUF_RDATA   (sdbuf_rdata),

      .WDISK_START   (1'b0),
      .WDISK_REQ     (1'b0),
      .WDISK_WR      (1'b0),
      .WDISK_BLKADDR1(16'd0),
      .WDISK_BLKADDR2(16'd0),
      .WDISK_UNIT    (3'd0),
      .WDISK_WORDCOUNT(11'd0),
      .WDISK_DONE    (),
      .WDISK_ERR     (),
      .WDISK_ERR_CODE(),
      .WDBUF_ADDR    (),
      .WDBUF_WDATA   (),
      .WDBUF_WE      (),
      .WDBUF_RDATA   (wdbuf_rdata),

      .sd_clk_o      (),
      .sd_cmd_i      (1'b1),
      .sd_cmd_o      (),
      .sd_cmd_oe     (),
      .sd_dat0_i     (1'b1),
      .sd_dat0_o     (),
      .sd_dat0_oe    (),

      .mem_start     (),
      .mem_we        (),
      .mem_addr      (),
      .mem_wdata     (),
      .mem_rdata     (32'd0),
      .mem_busy      (1'b0),
      .mem_done      (1'b0),

      .DBG_STATE     (),
      .DBG_LBA       (),
      .DBG_WDATA     (),
      .DBG_RDATA     (),
      .DBG_BUFW      (),
      .DBG_BUFWE     (),
      .DBG_FSEC      (),
      .DBG_RX_STB    (),
      .DBG_RX_RAW    (),
      .DBG_RX_BYTE   (),
      .DBG_PAST_EOF  (),
      .DBG_GRANT     (),
      .sd_status     ()
  );

  task ck_slice(input integer client, input [15:0] want,
                input [255:0] what);
    reg [15:0] got;
    begin
      got = u_src.buf_rdata_w[16*client +: 16];
      if (got !== want) begin
        $display("FAIL: buf_rdata_w client %0d (%0s) = %04h, want %04h",
                 client, what, got, want);
        errors = errors + 1;
      end else begin
        $display("[ ok ] buf_rdata_w client %0d (%0s) = %04h",
                 client, what, got);
      end
    end
  endtask

  initial begin
    $display("=== client bus slice continuity ===");
    repeat (4) @(posedge clk_cpu);
    rst_n = 1;

    // Drive the two disc clients' device buffers with distinct marks. These
    // reach buf_rdata_w combinationally through the adapters, so no clock
    // edge, card or mount is needed - a settle delay is enough.
    sdbuf_rdata = SMD_MARK;
    wdbuf_rdata = WD_MARK;
    fdbuf_rdata = 16'h1234;   // floppy: registered path, NOT expected through
    #100;

    // The slices that must carry a device's data.
    ck_slice(3, SMD_MARK, "SMD");
    ck_slice(6, WD_MARK,  "Winchester");

    // The tape adapter ties c_buf_rdata to zero on purpose: it is read-only
    // and has no write path. Asserting it keeps the "zero" here documented
    // as INTENDED rather than looking like another dropped slice.
    ck_slice(0, 16'd0, "tape, read-only by construction");

    // Swap the marks: a slice wired to the wrong client passes a single
    // fixed-value check but cannot survive the values being exchanged.
    sdbuf_rdata = WD_MARK;
    wdbuf_rdata = SMD_MARK;
    #100;
    ck_slice(3, WD_MARK,  "SMD after swap");
    ck_slice(6, SMD_MARK, "Winchester after swap");

    $display("");
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #10_000_000;
    $display("TB_RESULT: FAIL global timeout");
    $finish;
  end

endmodule
