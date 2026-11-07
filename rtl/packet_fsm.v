`timescale 1ns / 1ps

module packet_fsm (
    input  wire       clk,          // 100 MHz FPGA system clock
    input  wire       rst,          // Synchronous system reset
    input  wire [7:0] rx_data,      // Parallel byte from UART receiver
    input  wire       rx_done_tick, // 1-cycle pulse when a new rx_data byte is valid
    output reg  [2:0] active_color, // [2]=Red, [1]=Green, [0]=Blue
    output reg        blink_en,     // 1=2Hz Blink active, 0=Steady
    output reg  [1:0] dim_level     // 00=100%, 01=50%, 10=25%, 11=12.5%
);

    localparam [3:0]
        S_WAIT_AA   = 4'd0, // Byte 0: Expect 8'hAA (Frame Head)
        S_WAIT_LEN  = 4'd1, // Byte 1: Expect 8'h07 (Length without sig)
        S_WAIT_CMD  = 4'd2, // Byte 2: Expect 8'h0D (Voice Recognized)
        S_WAIT_ZERO = 4'd3, // Byte 3: Expect 8'h00 (Fixed 00 byte)
        S_WAIT_GRPM = 4'd4, // Byte 4: Expect 8'hFF (No group mode)
        S_GET_REC   = 4'd5, // Byte 5: Record ID (8'h00 to 8'h06)
        S_WAIT_RI   = 4'd6, // Byte 6: Recognizer Index (8'h00 to 8'h06)
        S_WAIT_SIGL = 4'd7, // Byte 7: Expect 8'h00 (Signature Length = 0)
        S_WAIT_END  = 4'd8; // Byte 8: Expect 8'h0A (Frame End)

    reg [3:0] state_reg;
    reg [7:0] temp_rec_id;

    always @(posedge clk) begin
        if (rst) begin
            state_reg    <= S_WAIT_AA;
            temp_rec_id  <= 8'h00;
            active_color <= 3'b000;
            blink_en     <= 1'b0;
            dim_level    <= 2'b00;
        end else if (rx_done_tick) begin
            case (state_reg)
                S_WAIT_AA: begin
                    if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                  state_reg <= S_WAIT_AA;
                end

                S_WAIT_LEN: begin
                    if (rx_data == 8'h07)      state_reg <= S_WAIT_CMD;
                    else if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                       state_reg <= S_WAIT_AA;
                end

                S_WAIT_CMD: begin
                    if (rx_data == 8'h0D)      state_reg <= S_WAIT_ZERO;
                    else if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                       state_reg <= S_WAIT_AA;
                end

                S_WAIT_ZERO: begin
                    if (rx_data == 8'h00)      state_reg <= S_WAIT_GRPM;
                    else if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                       state_reg <= S_WAIT_AA;
                end

                S_WAIT_GRPM: begin
                    if (rx_data == 8'hFF)      state_reg <= S_GET_REC;
                    else if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                       state_reg <= S_WAIT_AA;
                end

                S_GET_REC: begin
                    if (rx_data <= 8'h06) begin
                        temp_rec_id <= rx_data;
                        state_reg   <= S_WAIT_RI;
                    end else if (rx_data == 8'hAA) begin
                        state_reg   <= S_WAIT_LEN;
                    end else begin
                        state_reg   <= S_WAIT_AA;
                    end
                end

                S_WAIT_RI: begin
                    if (rx_data <= 8'h06)      state_reg <= S_WAIT_SIGL;
                    else if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                       state_reg <= S_WAIT_AA;
                end

                S_WAIT_SIGL: begin
                    if (rx_data == 8'h00)      state_reg <= S_WAIT_END;
                    else if (rx_data == 8'hAA) state_reg <= S_WAIT_LEN;
                    else                       state_reg <= S_WAIT_AA;
                end

                S_WAIT_END: begin
                    if (rx_data == 8'h0A) begin
                        state_reg <= S_WAIT_AA;
                        case (temp_rec_id)
                            8'h00: active_color <= 3'b100;           // "Red"
                            8'h01: active_color <= 3'b010;           // "Green"
                            8'h02: active_color <= 3'b001;           // "Blue"
                            8'h03: active_color <= 3'b111;           // "All"
                            8'h04: blink_en     <= ~blink_en;        // "Blink"
                            8'h05: dim_level    <= dim_level + 2'd1; // "Dim"
                            8'h06: begin                             // "Clear"
                                active_color <= 3'b000;
                                blink_en     <= 1'b0;
                                dim_level    <= 2'b00;
                            end
                            default: ;
                        endcase
                    end else if (rx_data == 8'hAA) begin
                        state_reg <= S_WAIT_LEN;
                    end else begin
                        state_reg <= S_WAIT_AA;
                    end
                end

                default: state_reg <= S_WAIT_AA;
            endcase
        end
    end

endmodule