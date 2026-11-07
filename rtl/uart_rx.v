`timescale 1ns / 1ps

module uart_rx (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    input  wire       s_tick,
    output reg  [7:0] rx_data,
    output reg        rx_done_tick
);

    // FSM State Encoding
    localparam [1:0] 
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    reg [1:0] state_reg, state_next;
    reg [3:0] s_reg, s_next;       // Counts 16 ticks for oversampling
    reg [2:0] n_reg, n_next;       // Counts 8 data bits
    reg [7:0] b_reg, b_next;       // Shift register for assembled data

    always @(posedge clk) begin
        if (rst) begin
            state_reg <= IDLE;
            s_reg     <= 4'd0;
            n_reg     <= 3'd0;
            b_reg     <= 8'd0;
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
        end
    end

    always @(*) begin
        // Defaults
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        rx_done_tick = 1'b0;
        rx_data      = b_reg;

        case (state_reg)
            IDLE: begin
                if (~rx) begin // Start bit detected (drop to 0)
                    state_next = START;
                    s_next     = 4'd0;
                end
            end

            START: begin
                if (s_tick) begin
                    if (s_reg == 4'd7) begin // Sample at middle of start bit
                        state_next = DATA;
                        s_next     = 4'd0;
                        n_next     = 3'd0;
                    end else begin
                        s_next = s_reg + 4'd1;
                    end
                end
            end

            DATA: begin
                if (s_tick) begin
                    if (s_reg == 4'd15) begin // Sample at middle of data bit
                        s_next = 4'd0;
                        b_next = {rx, b_reg[7:1]}; // Shift right (LSB first)
                        if (n_reg == 3'd7)
                            state_next = STOP;
                        else
                            n_next = n_reg + 3'd1;
                    end else begin
                        s_next = s_reg + 4'd1;
                    end
                end
            end

            STOP: begin
                if (s_tick) begin
                    if (s_reg == 4'd15) begin // Sample at middle of stop bit
                        state_next   = IDLE;
                        rx_done_tick = 1'b1; // Output a 1-clock-cycle pulse
                    end else begin
                        s_next = s_reg + 4'd1;
                    end
                end
            end
        endcase
    end

endmodule