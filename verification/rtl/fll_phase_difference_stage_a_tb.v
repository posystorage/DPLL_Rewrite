`timescale 1ns / 1ps

module fll_phase_difference_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg clear = 1'b0;
    reg phase_valid = 1'b0;
    reg signed [17:0] phase_in = 18'sd0;
    reg [1:0] delay_sel = 2'd0;
    reg [8:0] rate_r = 9'd8;
    wire freq_error_valid;
    wire signed [21:0] freq_error;
    wire ambiguous;

    integer wait_cycles;

    fll_phase_difference_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .clear(clear),
        .phase_valid(phase_valid),
        .phase_in(phase_in),
        .delay_sel(delay_sel),
        .rate_r(rate_r),
        .freq_error_valid(freq_error_valid),
        .freq_error(freq_error),
        .ambiguous(ambiguous)
    );

    always #4 clk_125m = ~clk_125m;

    task push_phase;
        input signed [17:0] value;
        begin
            @(negedge clk_125m);
            phase_in = value;
            phase_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            phase_valid = 1'b0;
        end
    endtask

    task expect_result;
        input signed [21:0] expected;
        input expected_ambiguous;
        begin
            wait_cycles = 0;
            while (freq_error_valid !== 1'b1 && wait_cycles < 40) begin
                @(posedge clk_125m);
                #1;
                wait_cycles = wait_cycles + 1;
            end
            if (freq_error_valid !== 1'b1 || freq_error !== expected ||
                ambiguous !== expected_ambiguous) begin
                $display("FAIL: expected error=%0d ambiguous=%0b, got valid=%0b error=%0d ambiguous=%0b after %0d cycles",
                         expected, expected_ambiguous, freq_error_valid,
                         freq_error, ambiguous, wait_cycles);
                $finish;
            end
        end
    endtask

    task pulse_clear;
        begin
            @(negedge clk_125m);
            clear = 1'b1;
            @(posedge clk_125m);
            #1;
            clear = 1'b0;
            if (freq_error_valid !== 1'b0) begin
                $display("FAIL: clear should drop freq_error_valid");
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_125m);
        @(negedge clk_125m);
        rst_125m = 1'b0;
        delay_sel = 2'd0;

        push_phase(18'sd100);
        if (freq_error_valid !== 1'b0) begin
            $display("FAIL: first sample should not be valid");
            $finish;
        end
        push_phase(18'sd125);
        expect_result(22'sd800, 1'b0);

        pulse_clear();
        delay_sel = 2'd2;
        push_phase(18'sd100);
        push_phase(18'sd125);
        push_phase(18'sd140);
        push_phase(18'sd150);
        push_phase(18'sd175);
        expect_result(22'sd600, 1'b0);

        pulse_clear();
        push_phase(18'sd300);
        push_phase(18'sd320);
        push_phase(18'sd340);
        push_phase(18'sd360);
        if (freq_error_valid !== 1'b0) begin
            $display("FAIL: FLL history did not refill after clear");
            $finish;
        end
        push_phase(18'sd380);
        expect_result(22'sd640, 1'b0);

        pulse_clear();
        delay_sel = 2'd0;
        push_phase(18'sd0);
        push_phase(18'sd131071);
        expect_result(22'sd2097151, 1'b1);

        // Equivalent physical slope at R=16,M=2: raw delta is 4x larger,
        // while normalized error must remain identical to R=8,M=1.
        pulse_clear();
        rate_r = 9'd16;
        delay_sel = 2'd1;
        push_phase(18'sd0);
        push_phase(18'sd50);
        push_phase(18'sd100);
        expect_result(22'sd800, 1'b0);

        // Negative slope must retain its sign through magnitude division.
        pulse_clear();
        rate_r = 9'd8;
        delay_sel = 2'd0;
        push_phase(18'sd125);
        push_phase(18'sd100);
        expect_result(-22'sd800, 1'b0);

        $display("PASS: fll_phase_difference_stage_a_tb");
        $finish;
    end
endmodule