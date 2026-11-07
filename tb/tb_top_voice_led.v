`timescale 1ns / 1ps

module tb_top_voice_led;

    // 100 MHz clock (10 ns period)
    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        uart_rx_pin = 1'b1; // Idle HIGH
    wire [2:0] led_out;

    always #5 clk = ~clk;

    // Exact 9600 baud bit period = 1 / 9600 s = 104,167 ns
    localparam integer BIT_PERIOD_NS = 104167;

    // Instantiate DUT
    // BLINK_MAX is scaled to 25'd50_000 (0.5 ms half-period) in simulation so
    // blink_wave toggles visibly in GTKWave without generating a multi-GB VCD file.
    top_voice_led #(
        .DVSR      (10'd650),
        .BLINK_MAX (25'd50_000)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .uart_rx_pin (uart_rx_pin),
        .led_out     (led_out)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    // Task: Transmit 1 UART byte (8N1, LSB first) at 9600 baud
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            // Start bit (LOW)
            uart_rx_pin = 1'b0;
            #(BIT_PERIOD_NS);

            // 8 Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = data[i];
                #(BIT_PERIOD_NS);
            end

            // Stop bit (HIGH)
            uart_rx_pin = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    // Task: Transmit full 9-byte Elechouse V3 recognition frame
    // Format: AA 07 0D 00 FF [rec_id] [rec_idx] 00 [end_byte]
    task send_v3_packet(
        input [7:0] rec_id,
        input [7:0] rec_idx,
        input [7:0] end_byte
    );
        begin
            send_uart_byte(8'hAA);     // Byte 0: Frame Head
            send_uart_byte(8'h07);     // Byte 1: Length
            send_uart_byte(8'h0D);     // Byte 2: Command (Voice Recognized)
            send_uart_byte(8'h00);     // Byte 3: Fixed 00
            send_uart_byte(8'hFF);     // Byte 4: Group Mode (0xFF = Recognizer)
            send_uart_byte(rec_id);    // Byte 5: Record ID
            send_uart_byte(rec_idx);   // Byte 6: Recognizer Index
            send_uart_byte(8'h00);     // Byte 7: Signature Length (0)
            send_uart_byte(end_byte);  // Byte 8: Frame End (0x0A)
        end
    endtask

    // Task: Self-checking state assertion
    task check_state(
        input [255:0] test_name,
        input [2:0]   exp_color,
        input         exp_blink,
        input [1:0]   exp_dim
    );
        begin
            if (dut.active_color === exp_color &&
                dut.blink_en     === exp_blink &&
                dut.dim_level    === exp_dim) begin
                $display("[PASS] %0s | color=%b, blink=%b, dim=%b",
                         test_name, dut.active_color, dut.blink_en, dut.dim_level);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s | Expected (color=%b, blink=%b, dim=%b), Got (color=%b, blink=%b, dim=%b)",
                         test_name, exp_color, exp_blink, exp_dim,
                         dut.active_color, dut.blink_en, dut.dim_level);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Task: Measure PWM High Cycles out of 256 clocks (1 PWM period = 2560 ns)
    task check_pwm_duty(
        input [255:0] test_name,
        input integer exp_high_cycles
    );
        integer k, high_cnt;
        begin
            high_cnt = 0;
            // Synchronize to pwm_counter == 0
            wait (dut.u_led_driver.pwm_counter == 8'd0);
            for (k = 0; k < 256; k = k + 1) begin
                @(posedge clk);
                if (led_out != 3'b000)
                    high_cnt = high_cnt + 1;
            end
            if (high_cnt == exp_high_cycles) begin
                $display("[PASS] %0s | Measured ON cycles = %0d / 256", test_name, high_cnt);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s | Expected %0d / 256, Got %0d / 256",
                         test_name, exp_high_cycles, high_cnt);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Dump only key signals or top hierarchy to keep VCD fast and responsive
        $dumpfile("voice_led_sim.vcd");
        $dumpvars(0, tb_top_voice_led);

        $display("==========================================================");
        $display("   STARTING OFFLINE VOICE-CONTROLLED FPGA LED SIMULATION  ");
        $display("==========================================================");

        // 0. Reset Release & Idle Verification
        #200;
        rst = 1'b0;
        #200;
        check_state("Reset & CDC Idle State", 3'b000, 1'b0, 2'b00);

        // 1. Command 0: "Red" (8'h00)
        send_v3_packet(8'h00, 8'h00, 8'h0A);
        check_state("Cmd 0: 'Red' (8'h00)", 3'b100, 1'b0, 2'b00);

        // 2. Command 1: "Green" (8'h01)
        send_v3_packet(8'h01, 8'h01, 8'h0A);
        check_state("Cmd 1: 'Green' (8'h01)", 3'b010, 1'b0, 2'b00);

        // 3. Command 2: "Blue" (8'h02)
        send_v3_packet(8'h02, 8'h02, 8'h0A);
        check_state("Cmd 2: 'Blue' (8'h02)", 3'b001, 1'b0, 2'b00);

        // 4. Command 3: "All" (8'h03)
        send_v3_packet(8'h03, 8'h03, 8'h0A);
        check_state("Cmd 3: 'All' (8'h03)", 3'b111, 1'b0, 2'b00);
        check_pwm_duty("PWM 100% Duty Check (dim=00)", 256);

        // 5. Command 5: "Dim" (8'h05) - Test all 4 brightness levels
        send_v3_packet(8'h05, 8'h05, 8'h0A);
        check_state("Cmd 5: 'Dim' Step 1 (50%)", 3'b111, 1'b0, 2'b01);
        check_pwm_duty("PWM 50% Duty Check (dim=01)", 128);

        send_v3_packet(8'h05, 8'h05, 8'h0A);
        check_state("Cmd 5: 'Dim' Step 2 (25%)", 3'b111, 1'b0, 2'b10);
        check_pwm_duty("PWM 25% Duty Check (dim=10)", 64);

        send_v3_packet(8'h05, 8'h05, 8'h0A);
        check_state("Cmd 5: 'Dim' Step 3 (12.5%)", 3'b111, 1'b0, 2'b11);
        check_pwm_duty("PWM 12.5% Duty Check (dim=11)", 32);

        send_v3_packet(8'h05, 8'h05, 8'h0A);
        check_state("Cmd 5: 'Dim' Step 4 (Wrap 100%)", 3'b111, 1'b0, 2'b00);

        // 6. Command 4: "Blink" (8'h04) Toggle ON then OFF
        send_v3_packet(8'h04, 8'h04, 8'h0A);
        check_state("Cmd 4: 'Blink' Toggle ON", 3'b111, 1'b1, 2'b00);

        send_v3_packet(8'h04, 8'h04, 8'h0A);
        check_state("Cmd 4: 'Blink' Toggle OFF", 3'b111, 1'b0, 2'b00);

        // 7. Edge Case A: Corrupted Frame End (Byte 8 = 0xFF instead of 0x0A)
        // Attempt to change color to Red (0x00), but corrupt the final byte
        send_v3_packet(8'h00, 8'h00, 8'hFF);
        check_state("Hazard: Corrupted Frame End (Rejected)", 3'b111, 1'b0, 2'b00);

        // 8. Edge Case B: 0x0A Data Collision Hazard (0x0A inside Byte 5)
        send_v3_packet(8'h0A, 8'h00, 8'h0A);
        check_state("Hazard: 0x0A Collision in Payload (Rejected)", 3'b111, 1'b0, 2'b00);

        // 9. Edge Case C: Mid-Packet Cut-Off Resynchronization
        // Send partial packet (AA 07 0D 00), abort, then immediately send valid "Red" packet
        send_uart_byte(8'hAA);
        send_uart_byte(8'h07);
        send_uart_byte(8'h0D);
        send_uart_byte(8'h00);
        // Immediate new packet starting with 0xAA:
        send_v3_packet(8'h00, 8'h00, 8'h0A);
        check_state("Hazard: Mid-Packet 0xAA Resync to 'Red'", 3'b100, 1'b0, 2'b00);

        // 10. Command 6: "Clear" (8'h06)
        // First turn ON Blink and Dim so we verify Clear wipes all 3 registers
        send_v3_packet(8'h04, 8'h04, 8'h0A); // Blink ON
        send_v3_packet(8'h05, 8'h05, 8'h0A); // Dim 50%
        send_v3_packet(8'h06, 8'h06, 8'h0A); // Clear!
        check_state("Cmd 6: 'Clear' Resets All States", 3'b000, 1'b0, 2'b00);

        $display("==========================================================");
        $display("   SIMULATION COMPLETE: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==========================================================");
        $finish;
    end

endmodule