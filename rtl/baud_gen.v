`timescale 1ns / 1ps

module baud_gen #(
    parameter DVSR = 10'd650 // 100MHz / (9600 * 16) = 651 cycles (0 to 650)
)(
    input  wire clk,
    input  wire rst,
    output wire s_tick
);

    reg  [9:0] r_reg;
    wire [9:0] r_next;

    always @(posedge clk) begin
        if (rst)
            r_reg <= 10'd0;
        else
            r_reg <= r_next;
    end

    // Reset to 0 when reaching DVSR (650), else increment
    assign r_next = (r_reg == DVSR) ? 10'd0 : r_reg + 10'd1;

    // Assert tick for one clock cycle every 651 cycles
    assign s_tick = (r_reg == DVSR);

endmodule