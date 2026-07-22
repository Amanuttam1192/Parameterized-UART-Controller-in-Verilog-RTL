// ============================================================================
// uart_top.v  -  Top-level UART: baud generator + transmitter + receiver
//
// A single shared baud generator drives both TX and RX. This is the block you
// would instantiate in a real SoC and connect to a register interface.
// ============================================================================
module uart_top #(
    parameter integer CLK_FREQ   = 50_000_000,
    parameter integer BAUD       = 115200,
    parameter integer OVERSAMPLE = 16
)(
    input  wire       clk,
    input  wire       rst_n,

    // transmit side
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx,
    output wire       tx_busy,

    // receive side
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_valid
);
    wire tick;

    baud_gen #(
        .CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .OVERSAMPLE(OVERSAMPLE)
    ) u_baud (
        .clk(clk), .rst_n(rst_n), .tick(tick)
    );

    uart_tx #(.OVERSAMPLE(OVERSAMPLE)) u_tx (
        .clk(clk), .rst_n(rst_n), .tick(tick),
        .start(tx_start), .data(tx_data),
        .tx(tx), .busy(tx_busy)
    );

    uart_rx #(.OVERSAMPLE(OVERSAMPLE)) u_rx (
        .clk(clk), .rst_n(rst_n), .tick(tick),
        .rx(rx),
        .data(rx_data), .valid(rx_valid)
    );
endmodule
