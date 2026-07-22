// ============================================================================
// uart_rx.v  -  UART receiver (8-N-1) with 16x oversampling
//
// Key idea: we sample the line OVERSAMPLE times per bit. After detecting the
// falling edge of the start bit, we wait OVERSAMPLE/2 ticks to land in the
// MIDDLE of the start bit (best noise margin), verify it is still low, then
// sample every OVERSAMPLE ticks thereafter to catch each data bit at its
// centre. This mid-bit sampling is what makes a real UART robust.
//
// Two flip-flops synchronise the asynchronous rx line into our clock domain
// before use -> a standard 2-FF synchroniser that prevents metastability.
// ============================================================================
module uart_rx #(
    parameter integer OVERSAMPLE = 16
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,          // from baud_gen (BAUD*OVERSAMPLE)
    input  wire       rx,            // asynchronous serial input
    output reg [7:0]  data,          // received byte
    output reg        valid          // 1-cycle pulse when `data` is ready
);
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    // 2-FF synchroniser for the async input
    reg rx_sync0, rx_sync1;
    always @(posedge clk) begin
        if (!rst_n) begin rx_sync0 <= 1'b1; rx_sync1 <= 1'b1; end
        else        begin rx_sync0 <= rx;   rx_sync1 <= rx_sync0; end
    end
    wire rx_in = rx_sync1;

    reg [1:0] state;
    reg [7:0] shreg;
    reg [2:0] bit_idx;
    reg [$clog2(OVERSAMPLE):0] tick_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            data     <= 8'd0;
            valid    <= 1'b0;
            shreg    <= 8'd0;
            bit_idx  <= 3'd0;
            tick_cnt <= 0;
        end else begin
            valid <= 1'b0;             // default: pulse is only 1 cycle
            case (state)
                // ---- watch for start-bit falling edge ---------------------
                S_IDLE: begin
                    if (tick && rx_in == 1'b0) begin
                        tick_cnt <= 0;
                        state    <= S_START;
                    end
                end

                // ---- align to the centre of the start bit -----------------
                S_START: begin
                    if (tick) begin
                        if (tick_cnt == (OVERSAMPLE/2)-1) begin
                            // we are mid-start-bit; confirm it is still low
                            if (rx_in == 1'b0) begin
                                tick_cnt <= 0;
                                bit_idx  <= 3'd0;
                                state    <= S_DATA;
                            end else begin
                                state <= S_IDLE;   // false start / glitch
                            end
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                // ---- sample each data bit at its centre -------------------
                S_DATA: begin
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt        <= 0;
                            shreg           <= {rx_in, shreg[7:1]}; // LSB first
                            if (bit_idx == 3'd7)
                                state <= S_STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                // ---- sample the stop bit, flag the byte valid -------------
                S_STOP: begin
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            if (rx_in == 1'b1) begin  // valid stop bit
                                data  <= shreg;
                                valid <= 1'b1;
                            end
                            state <= S_IDLE;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
