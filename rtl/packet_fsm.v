`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// College: IIT ISM DHANBAD
// Engineer: SINCHAN BANERJEE
// 
// Create Date: 14.10.2026 21:20:30
// Design Name: FSM FOR LED BLINKING
// Module Name: packet_fsm
// Project Name: VOICE CONTROLLED LED BLINKING SYSTEM
// Target Devices: TOYS
// Tool Versions: VIVADO 2019.2 
// Description: This is the first project our team is working on
// Members: Sinchan Banerjee, Shresth Porwal, Sujal Gupta  
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module packet_fsm (
    input  wire       clk,          // 100 MHz FPGA system clock
    input  wire       rst,          // Synchronous system reset
    input  wire [7:0] rx_data,      // Parallel byte from Shresth's uart_rx
    input  wire       rx_done_tick, // 1-cycle pulse when a new rx_data byte is ready
    output reg  [2:0] active_color, // [2]=Red, [1]=Green, [0]=Blue
    output reg        blink_en,     // 1 = 2Hz Blink active, 0 = Steady
    output reg  [1:0] dim_level     // Upgraded: 00=100%, 01=50%, 10=25%, 11=12.5%
);

    // 1. State Encoding (9 states for the 9-byte frame -> 4-bit register)
    localparam [3:0] S_WAIT_AA   = 4'd0, // Byte 0: Expect 8'hAA (Frame Head)
                     S_WAIT_LEN  = 4'd1, // Byte 1: Expect 8'h07 (Length without signature)
                     S_WAIT_CMD  = 4'd2, // Byte 2: Expect 8'h0D (Voice Recognized code)
                     S_WAIT_ZERO = 4'd3, // Byte 3: Expect 8'h00 (Fixed 00 byte)
                     S_WAIT_GRPM = 4'd4, // Byte 4: Expect 8'hFF (No group mode)
                     S_GET_REC   = 4'd5, // Byte 5: Record ID (8'h00 to 8'h06)
                     S_WAIT_RI   = 4'd6, // Byte 6: Recognizer Index (8'h00 to 8'h06)
                     S_WAIT_SIGL = 4'd7, // Byte 7: Expect 8'h00 (Signature Length = 0)
                     S_WAIT_END  = 4'd8; // Byte 8: Expect 8'h0A (Frame End)

    // 2. Internal State & Temporary Payload Registers
    reg [3:0] state_reg;
    reg [7:0] temp_rec_id; // Holds Byte 5 safely until Byte 8 (0x0A) confirms valid end

    // 3. Synchronous State & Output Logic
    always @(posedge clk) begin
        if (rst) begin
            state_reg    <= S_WAIT_AA;
            temp_rec_id  <= 8'h00;
            active_color <= 3'b000;
            blink_en     <= 1'b0;
            dim_level    <= 2'b00; // Default to 100% brightness on reset
        end else if (rx_done_tick) begin
            case (state_reg)
                // Byte 0: Frame Header (0xAA)
                S_WAIT_AA: begin
                    if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN;
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 1: Packet Length (0x07 when SIGLEN = 0)
                S_WAIT_LEN: begin
                    if (rx_data == 8'h07)
                        state_reg <= S_WAIT_CMD;
                    else if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN; // Resync if new 0xAA arrives
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 2: Command Code (0x0D = Voice Recognized)
                S_WAIT_CMD: begin
                    if (rx_data == 8'h0D)
                        state_reg <= S_WAIT_ZERO;
                    else if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN;
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 3: Fixed 0x00 Byte
                S_WAIT_ZERO: begin
                    if (rx_data == 8'h00)
                        state_reg <= S_WAIT_GRPM;
                    else if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN;
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 4: Group Mode Indicator (0xFF = Group Mode Disabled)
                S_WAIT_GRPM: begin
                    if (rx_data == 8'hFF)
                        state_reg <= S_GET_REC;
                    else if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN;
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 5: Capture Record Number (0x00 to 0x06)
                S_GET_REC: begin
                    if (rx_data <= 8'h06) begin
                        temp_rec_id <= rx_data;  // Save payload temporarily
                        state_reg   <= S_WAIT_RI;
                    end else if (rx_data == 8'hAA) begin
                        state_reg   <= S_WAIT_LEN;
                    end else begin
                        state_reg   <= S_WAIT_AA;
                    end
                end

                // Byte 6: Recognizer Index (0x00 to 0x06)
                S_WAIT_RI: begin
                    if (rx_data <= 8'h06)
                        state_reg <= S_WAIT_SIGL;
                    else if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN;
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 7: Signature Length (0x00 = No Signature)
                S_WAIT_SIGL: begin
                    if (rx_data == 8'h00)
                        state_reg <= S_WAIT_END;
                    else if (rx_data == 8'hAA)
                        state_reg <= S_WAIT_LEN;
                    else
                        state_reg <= S_WAIT_AA;
                end

                // Byte 8: Frame End (0x0A) -> Validate & Latch Command Outputs!
                S_WAIT_END: begin
                    if (rx_data == 8'h0A) begin
                        case (temp_rec_id)
                            8'h00: active_color <= 3'b100;         // "Red"
                            8'h01: active_color <= 3'b010;         // "Green"
                            8'h02: active_color <= 3'b001;         // "Blue"
                            8'h03: active_color <= 3'b111;         // "All"
                            8'h04: blink_en     <= ~blink_en;      // "Blink" (Toggle 2Hz)
                            8'h05: dim_level    <= dim_level + 2'd1; // "Dim" (Cycle 4 levels)
                            8'h06: begin                           // "Clear" (Reset all)
                                active_color <= 3'b000;
                                blink_en     <= 1'b0;
                                dim_level    <= 2'b00;
                            end
                            default: ; // Hold previous state on unknown ID
                        endcase
                        state_reg <= S_WAIT_AA;
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
