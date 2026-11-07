`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: IIT ISM DHANBAD
// Engineer: SINCHAN BANERJEE
// 
// Create Date: 26.10.2026 11:22:00
// Design Name: TOP MODULE INTEGRATOR
// Module Name: top_voice_led
// Project Name: VOICE CONTROLLED LED BLINKING SYSTEM
// Target Devices: TOYS AND FANCY DECOR LIGHTING
// Tool Versions: 
// Description: 
// Members: Sujal Gupta, Shresth Porwal, Sinchan Banerjee
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_voice_led (
    input  wire       clk,         // 100 MHz onboard FPGA oscillator
    input  wire       rst,         // Active-high system reset pushbutton
    input  wire       uart_rx_pin, // 3.3V level-shifted serial input from V3 TXD
    output wire [2:0] led_out      // Physical FPGA LED pins: [2]=Red, [1]=Green, [0]=Blue
);

    // =========================================================================
    // 1. 2-Flip-Flop Synchronizer (Prevents Metastability on External UART Pin)
    // =========================================================================
    reg rx_sync1;
    reg rx_sync2;

    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1; // UART idle state is HIGH (1'b1)
            rx_sync2 <= 1'b1; // Prevents false Start-Bit detection on reset
        end else begin
            rx_sync1 <= uart_rx_pin;
            rx_sync2 <= rx_sync1;
        end
    end

    wire rx_synced = rx_sync2;

    // =========================================================================
    // 2. Internal Interconnect Wires (The "Traces" Between Sub-Modules)
    // =========================================================================
    // Wires between Shresth's UART domain and Sinchan's Packet FSM
    wire       s_tick;       // 16x oversampling tick (153,600 Hz) from baud_gen
    wire [7:0] rx_data;      // Reconstructed 8-bit byte from uart_rx
    wire       rx_done_tick; // 1-clock-cycle valid pulse from uart_rx

    // Wires between Sinchan's Packet FSM and LED Driver
    wire [2:0] active_color; // Selected LED channels
    wire       blink_en;     // 2Hz blink enable flag
    wire [1:0] dim_level;    // 4-stage PWM brightness level

    // =========================================================================
    // 3. Module Instantiations (Plugging the Blocks Together)
    // =========================================================================

    // Block A: Shresth's Baud Rate Generator (100 MHz / 651 -> 153.6 kHz tick)
    baud_gen u_baud_gen (
        .clk    (clk),
        .rst    (rst),
        .s_tick (s_tick)
    );

    // Block B: Shresth's 9600-Baud UART Receiver (8N1)
    uart_rx u_uart_rx (
        .clk          (clk),
        .rst          (rst),
        .rx           (rx_synced),    // Feeds clean, synchronized serial signal
        .s_tick       (s_tick),
        .rx_data      (rx_data),
        .rx_done_tick (rx_done_tick)
    );

    // Block C: Sinchan's 9-Byte Elechouse V3 Packet Decoder FSM
    packet_fsm u_packet_fsm (
        .clk          (clk),
        .rst          (rst),
        .rx_data      (rx_data),
        .rx_done_tick (rx_done_tick),
        .active_color (active_color),
        .blink_en     (blink_en),
        .dim_level    (dim_level)
    );

    // Block D: Sinchan's Multi-Level PWM & 2Hz Blink LED Engine
    led_driver u_led_driver (
        .clk          (clk),
        .rst          (rst),
        .active_color (active_color),
        .blink_en     (blink_en),
        .dim_level    (dim_level),
        .led_out      (led_out)
    );

endmodule
