// ============================================================================
// QMTECH XC7A35T core board - stage-1 LED smoke test
//
// Proves the bring-up basics end to end:
//   - Platform Cable USB II programming path (build.tcl programs over JTAG)
//   - 50 MHz crystal on R2 is alive          -> led_n[0] blinks at 1 Hz
//   - both user LEDs drivable (active-low)   -> led_n[1] on while key held
//   - user key on H18 reachable (active-low)
//
// All time counts derive from CLK_FREQ (lesson from the OPCOM RTC bug:
// never hard-code cycle counts for one board's clock).
// ============================================================================
module led_test_top #(
    parameter CLK_FREQ = 50_000_000   // R2 crystal, Hz
) (
    input  wire       sys_clk,
    input  wire       key_n,     // user key, active-low (4.7k pull-up)
    output wire [1:0] led_n      // user LEDs, active-low (0 = lit)
);

    localparam HALF_PERIOD = CLK_FREQ / 2;   // 1 Hz blink = 0.5 s per phase

    reg [31:0] s_count = 32'd0;
    reg        s_blink = 1'b0;

    always @(posedge sys_clk) begin
        if (s_count == HALF_PERIOD - 1) begin
            s_count <= 32'd0;
            s_blink <= ~s_blink;
        end else begin
            s_count <= s_count + 32'd1;
        end
    end

    assign led_n[0] = ~s_blink;   // heartbeat: lit half the time
    assign led_n[1] = key_n;      // key pressed (low) -> LED lit

endmodule
