// ============================================================================
// tb_uart.v  -  Self-checking loopback testbench
//
// Strategy: wire TX -> RX (loopback), transmit a set of test bytes, and check
// that every byte the RX recovers equals the byte we sent. A self-checking
// testbench PASSES/FAILS on its own instead of forcing you to eyeball waves --
// this is exactly the verification mindset TI's digital teams look for.
//
// To keep simulation fast we use a small clock/baud ratio; the RTL is
// parameterised so the same design runs at real rates on hardware.
// ============================================================================
`timescale 1ns/1ps

module tb_uart;
    // Small ratio for a quick sim: 16 clocks per bit (DIVISOR=1, 16x OS)
    localparam integer CLK_FREQ   = 1_600_000;
    localparam integer BAUD       = 100_000;
    localparam integer OVERSAMPLE = 16;

    reg        clk = 0;
    reg        rst_n = 0;
    reg        tx_start = 0;
    reg  [7:0] tx_data = 8'd0;
    wire       tx_line;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_valid;

    integer errors = 0;
    integer sent   = 0;
    integer recvd  = 0;

    // DUT with TX looped back into RX
    uart_top #(
        .CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .OVERSAMPLE(OVERSAMPLE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx_line), .tx_busy(tx_busy),
        .rx(tx_line),                 // <-- loopback
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // Reference queue of bytes we expect to receive
    reg [7:0] expected [0:15];

    // Checker: every time RX flags a valid byte, compare against expectation
    always @(posedge clk) begin
        if (rx_valid) begin
            if (rx_data === expected[recvd]) begin
                $display("  [PASS] byte %0d: sent 0x%02x, received 0x%02x",
                         recvd, expected[recvd], rx_data);
            end else begin
                $display("  [FAIL] byte %0d: sent 0x%02x, received 0x%02x",
                         recvd, expected[recvd], rx_data);
                errors = errors + 1;
            end
            recvd = recvd + 1;
        end
    end

    // Task: send one byte and wait for the transmitter to finish.
    // We record the expected byte BEFORE starting, since in loopback the RX
    // checker may fire as soon as the frame completes.
    task send_byte(input [7:0] b);
        begin
            @(posedge clk);
            expected[sent] = b;       // record expectation first
            sent = sent + 1;
            tx_data  <= b;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;
            // wait until the frame has been fully transmitted
            @(posedge clk);
            wait (tx_busy == 1'b0);
        end
    endtask

    integer i;
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, tb_uart);

        // reset
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("=== UART loopback self-check ===");

        // Test vector: mix of patterns, walking bits, ASCII
        send_byte(8'h55);   // 0101_0101
        send_byte(8'hAA);   // 1010_1010
        send_byte(8'h00);
        send_byte(8'hFF);
        send_byte(8'h01);
        send_byte(8'h80);
        send_byte(8'h54);   // 'T'
        send_byte(8'h49);   // 'I'

        // let the last byte propagate through RX
        repeat (200) @(posedge clk);

        $display("--------------------------------");
        $display("sent = %0d, received = %0d, errors = %0d", sent, recvd, errors);
        if (errors == 0 && recvd == sent)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: TEST FAILED");
        $finish;
    end

    // safety timeout
    initial begin
        #500000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
