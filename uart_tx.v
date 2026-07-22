// ============================================================================
// uart_tx.v  -  UART transmitter (8-N-1) as a 4-state FSM
//
// Frame on the wire:  START(0)  D0 D1 ... D7 (LSB first)  STOP(1)
// The line idles high. One bit lasts OVERSAMPLE baud ticks, so we count
// ticks to know when to advance.
//
// Handshake:
//   assert start with data valid for one clock while busy is low ->
//   the byte is latched and transmission begins; busy stays high until
//   the stop bit completes.
// ============================================================================
module uart_tx #(
    parameter integer OVERSAMPLE = 16
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,        // from baud_gen (BAUD*OVERSAMPLE)
    input  wire       start,       // request to send `data`
    input  wire [7:0] data,        // byte to transmit
    output reg        tx,          // serial output line
    output reg        busy         // high while a frame is in flight
);
    // FSM state encoding
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg [7:0] shreg;                     // shift register of data bits
    reg [2:0] bit_idx;                   // which of the 8 data bits (0..7)
    reg [$clog2(OVERSAMPLE):0] tick_cnt; // counts ticks within one bit

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            tx       <= 1'b1;            // idle line is high
            busy     <= 1'b0;
            shreg    <= 8'd0;
            bit_idx  <= 3'd0;
            tick_cnt <= 0;
        end else begin
            case (state)
                // ---- wait for a send request ------------------------------
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        shreg    <= data;   // latch the byte
                        busy     <= 1'b1;
                        tick_cnt <= 0;
                        state    <= S_START;
                    end
                end

                // ---- drive the start bit (0) for one bit-time -------------
                S_START: begin
                    tx <= 1'b0;
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            bit_idx  <= 3'd0;
                            state    <= S_DATA;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                // ---- shift out 8 data bits, LSB first ---------------------
                S_DATA: begin
                    tx <= shreg[0];
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            shreg    <= {1'b0, shreg[7:1]};  // shift right
                            if (bit_idx == 3'd7)
                                state <= S_STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end

                // ---- drive the stop bit (1) then return to idle -----------
                S_STOP: begin
                    tx <= 1'b1;
                    if (tick) begin
                        if (tick_cnt == OVERSAMPLE-1) begin
                            tick_cnt <= 0;
                            state    <= S_IDLE;
                        end else
                            tick_cnt <= tick_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
