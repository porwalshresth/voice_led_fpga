`timescale 1ns / 1ps

module top_voice_led #(
    parameter DVSR      = 10'd650,
    parameter BLINK_MAX = 25'd24_999_999
)(
    input  wire       clk,         // 100 MHz onboard FPGA oscillator
    input  wire       rst,         // Active-high system reset pushbutton
    input  wire       uart_rx_pin, // 3.3V level-shifted serial input from V3 TXD
    output wire [2:0] led_out      // Physical FPGA LED pins: [2]=Red, [1]=Green, [0]=Blue
);

    // 1. 2-Flip-Flop Synchronizer (Prevents Metastability on External UART Pin)
    reg rx_sync1;
    reg rx_sync2;
    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1; // UART idle state is HIGH (1'b1)
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= uart_rx_pin;
            rx_sync2 <= rx_sync1;
        end
    end
    wire rx_synced = rx_sync2;

    // 2. Internal Interconnect Buses
    wire       s_tick;
    wire [7:0] rx_data;
    wire       rx_done_tick;
    wire [2:0] active_color;
    wire       blink_en;
    wire [1:0] dim_level;

    // 3. Sub-Module Instantiations
    baud_gen #(
        .DVSR(DVSR)
    ) u_baud_gen (
        .clk    (clk),
        .rst    (rst),
        .s_tick (s_tick)
    );

    uart_rx u_uart_rx (
        .clk          (clk),
        .rst          (rst),
        .rx           (rx_synced),
        .s_tick       (s_tick),
        .rx_data      (rx_data),
        .rx_done_tick (rx_done_tick)
    );

    packet_fsm u_packet_fsm (
        .clk          (clk),
        .rst          (rst),
        .rx_data      (rx_data),
        .rx_done_tick (rx_done_tick),
        .active_color (active_color),
        .blink_en     (blink_en),
        .dim_level    (dim_level)
    );

    led_driver #(
        .BLINK_MAX(BLINK_MAX)
    ) u_led_driver (
        .clk          (clk),
        .rst          (rst),
        .active_color (active_color),
        .blink_en     (blink_en),
        .dim_level    (dim_level),
        .led_out      (led_out)
    );

endmodule