`timescale 1ns / 1ps

module led_driver #(
    parameter BLINK_MAX = 25'd24_999_999 // 0.25s half-period at 100 MHz (2 Hz blink)
)(
    input  wire       clk,          // 100 MHz system clock
    input  wire       rst,          // System reset
    input  wire [2:0] active_color, // From FSM: [2]=Red, [1]=Green, [0]=Blue
    input  wire       blink_en,     // From FSM: 1=2Hz Blink, 0=Steady
    input  wire [1:0] dim_level,    // From FSM: 00=100%, 01=50%, 10=25%, 11=12.5%
    output wire [2:0] led_out       // Physical FPGA LED pins
);

    reg [24:0] blink_counter;
    reg        blink_wave;

    always @(posedge clk) begin
        if (rst) begin
            blink_counter <= 25'd0;
            blink_wave    <= 1'b0;
        end else if (blink_counter == BLINK_MAX) begin
            blink_counter <= 25'd0;
            blink_wave    <= ~blink_wave;
        end else begin
            blink_counter <= blink_counter + 25'd1;
        end
    end

    reg [7:0] pwm_counter;
    always @(posedge clk) begin
        if (rst) pwm_counter <= 8'd0;
        else     pwm_counter <= pwm_counter + 8'd1;
    end

    reg pwm_mask;
    always @(*) begin
        case (dim_level)
            2'b00:   pwm_mask = 1'b1;                                               // 100%
            2'b01:   pwm_mask = ~pwm_counter[7];                                    // 50%
            2'b10:   pwm_mask = ~(pwm_counter[7] | pwm_counter[6]);                 // 25%
            2'b11:   pwm_mask = ~(pwm_counter[7] | pwm_counter[6] | pwm_counter[5]);// 12.5%
            default: pwm_mask = 1'b1;
        endcase
    end

    wire blink_mask    = blink_wave | ~blink_en;
    wire master_enable = pwm_mask & blink_mask;

    assign led_out = active_color & {3{master_enable}};

endmodule