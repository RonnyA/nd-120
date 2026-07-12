/****************************************************************************
** nd_storage CDC synchronizer primitives                                  **
**                                                                         **
** The two small modules used by every clock-domain crossing in the       **
** nd_storage stack (docs/nd-storage-design.md section 4.4: all           **
** crossings are 2-flop and toggle-based).                                 **
**                                                                         **
**   nds_sync_pulse - toggle in, pulse out: the SOURCE domain flips a     **
**   toggle register; this module 2-flop-synchronizes the toggle into     **
**   the destination clock and emits a registered one-cycle pulse per     **
**   flip. Payload riding with the toggle must be held stable by the     **
**   source from the flip until the handshake answer returns: the        **
**   receiver samples it at the pulse, which is at least two             **
**   destination clocks after the flip landed.                           **
**                                                                         **
**   nds_sync_level - plain 2-flop level synchronizer, WIDTH bits, for   **
**   quasi-static levels (open_ok, grant id, err flag). Multi-bit        **
**   values may only change while no consumer acts on them (the grant    **
**   id changes only while the word bridge is idle).                     **
**                                                                         **
** Source toggles must reset to 0 in their own domain: a toggle that is  **
** already 1 when the destination leaves reset yields one spurious       **
** pulse.                                                                 **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module nds_sync_pulse (
    input  wire clk_dst,    // destination clock
    input  wire rst_dst_n,  // destination-domain reset
    input  wire tgl_src,    // toggle register in the source domain
    output reg  pulse_dst   // one-cycle pulse per source flip
);

  reg s_meta;  // first flop (metastability guard)
  reg s_sync;  // second flop (stable)
  reg s_prev;  // edge-detect history

  always @(posedge clk_dst) begin
    if (!rst_dst_n) begin
      s_meta    <= 1'b0;
      s_sync    <= 1'b0;
      s_prev    <= 1'b0;
      pulse_dst <= 1'b0;
    end else begin
      s_meta    <= tgl_src;
      s_sync    <= s_meta;
      s_prev    <= s_sync;
      pulse_dst <= s_sync ^ s_prev;
    end
  end

endmodule


module nds_sync_level #(
    parameter WIDTH = 1
) (
    input  wire             clk_dst,    // destination clock
    input  wire             rst_dst_n,  // destination-domain reset
    input  wire [WIDTH-1:0] d_src,      // level in the source domain
    output wire [WIDTH-1:0] q_dst       // synchronized level
);

  reg [WIDTH-1:0] s_meta;
  reg [WIDTH-1:0] s_sync;

  always @(posedge clk_dst) begin
    if (!rst_dst_n) begin
      s_meta <= {WIDTH{1'b0}};
      s_sync <= {WIDTH{1'b0}};
    end else begin
      s_meta <= d_src;
      s_sync <= s_meta;
    end
  end

  assign q_dst = s_sync;

endmodule
