`timescale 1ns / 1ps

module fll_phase_difference_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg clear = 1'b0;
    reg phase_valid = 1'b0;
    reg signed [17:0] phase_in = 18'sd0;
    reg [1:0] delay_sel = 2'd0;
    wire freq_error_valid;
    wire signed [21:0] freq_error;
    wire ambiguous;

    fll_phase_difference_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .clear(clear),
        .phase_valid(phase_valid),
        .phase_in(phase_in),
        .delay_sel(delay_sel),
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
        if (freq_error_valid !== 1'b1 || freq_error !== 22'sd25) begin
            $display("FAIL: delay1 expected +25 valid, got valid=%b error=%0d", freq_error_valid, freq_error);
            $finish;
        end

        delay_sel = 2'd2;
        push_phase(18'sd140);
        push_phase(18'sd150);
        push_phase(18'sd175);
        push_phase(18'sd200);
        if (freq_error_valid !== 1'b1 || freq_error !== 22'sd75) begin
            $display("FAIL: delay4 expected +75, got valid=%b error=%0d", freq_error_valid, freq_error);
            $finish;
        end

        @(negedge clk_125m);
        clear = 1'b1;
        @(posedge clk_125m);
        #1;
        clear = 1'b0;
        if (freq_error_valid !== 1'b0) begin
            $display("FAIL: clear should drop freq_error_valid");
            $finish;
        end
        push_phase(18'sd300);
        push_phase(18'sd320);
        push_phase(18'sd340);
        push_phase(18'sd360);
        if (freq_error_valid !== 1'b0) begin
            $display("FAIL: FLL history did not refill after clear");
            $finish;
        end
        push_phase(18'sd380);
        if (freq_error_valid !== 1'b1 || freq_error !== 22'sd80) begin
            $display("FAIL: delay4 after clear expected +80, got valid=%b error=%0d", freq_error_valid, freq_error);
            $finish;
        end

        @(negedge clk_125m);
        clear = 1'b1;
        delay_sel = 2'd0;
        @(posedge clk_125m);
        #1;
        clear = 1'b0;
        push_phase(18'sd0);
        push_phase(18'sd131071);
        if (freq_error_valid !== 1'b1 || ambiguous !== 1'b1) begin
            $display("FAIL: half-scale phase difference should be marked ambiguous, valid=%b ambiguous=%b error=%0d",
                     freq_error_valid, ambiguous, freq_error);
            $finish;
        end

        $display("PASS: fll_phase_difference_stage_a_tb");
        $finish;
    end
endmodule
