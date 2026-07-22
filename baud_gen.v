// ============================================================================
// baud_gen.v  -  Baud tick generator
//
// Produces a single-cycle "tick" pulse at BAUD * OVERSAMPLE Hz from the
// system clock. The UART TX advances one bit every OVERSAMPLE ticks; the RX
// oversamples the line at the same rate so it can sample each bit near its
// centre.
//
// tick_rate = CLK_FREQ / (BAUD * OVERSAMPLE)
//   e.g. 50 MHz clock, 115200 baud, 16x oversample:
//        50_000_000 / (115200 * 16) = 27.13  ->  DIVISOR = 27
// ============================================================================
module baud_gen #(
    parameter integer CLK_FREQ   = 50_000_000,
    parameter integer BAUD       = 115200,
    parameter integer OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst_n,       // active-low synchronous reset
    output reg  tick         // 1-cycle pulse at BAUD*OVERSAMPLE
);
    localparam integer DIVISOR = CLK_FREQ / (BAUD * OVERSAMPLE);
    // Width wide enough to hold DIVISOR-1
    localparam integer CW = (DIVISOR <= 2) ? 1 : $clog2(DIVISOR);

    reg [CW-1:0] count;

    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 0;
            tick  <= 1'b0;
        end else if (count == DIVISOR-1) begin
            count <= 0;
            tick  <= 1'b1;         // one-cycle strobe
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end
endmodule
