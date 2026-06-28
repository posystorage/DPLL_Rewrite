`timescale 1ns / 1ps

module hybrid_fll_pll_filter_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg error_valid = 1'b0;
    reg enable_fll = 1'b1;
    reg enable_pll_i = 1'b1;
    reg enable_pll_p = 1'b1;
    reg signed [17:0] phase_error = 18'sd0;
    reg signed [21:0] freq_error = 22'sd0;
    reg signed [23:0] kf = 24'sd262144;
    reg signed [23:0] ki = 24'sd262144;
    reg signed [23:0] kp = 24'sd262144;
    reg [47:0] center_word = 48'd1000;
    reg signed [55:0] positive_limit = 56'sd2000;
    reg signed [55:0] negative_limit = -56'sd2000;
    wire correction_valid;
    wire signed [55:0] freq_state;
    wire signed [55:0] freq_correction;
    wire [47:0] tracking_word;
    wire saturated_high;
    wire saturated_low;

    hybrid_fll_pll_filter_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .error_valid(error_valid),
        .enable_fll(enable_fll),
        .enable_pll_i(enable_pll_i),
        .enable_pll_p(enable_pll_p),
        .phase_error(phase_error),
        .freq_error(freq_error),
        .kf(kf),
        .ki(ki),
        .kp(kp),
        .center_word(center_word),
        .positive_limit(positive_limit),
        .negative_limit(negative_limit),
        .correction_valid(correction_valid),
        .freq_state(freq_state),
        .freq_correction(freq_correction),
        .tracking_word(tracking_word),
        .saturated_high(saturated_high),
        .saturated_low(saturated_low)
    );

    always #4 clk_125m = ~clk_125m;

    task push_error;
        input signed [17:0] phase_value;
        input signed [21:0] freq_value;
        begin
            @(negedge clk_125m);
            phase_error = phase_value;
            freq_error = freq_value;
            error_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            error_valid = 1'b0;
        end
    endtask

    task wait_correction;
        integer timeout;
        begin
            timeout = 0;
            while (correction_valid !== 1'b1 && timeout < 12) begin
                @(posedge clk_125m);
                #1;
                timeout = timeout + 1;
            end
            if (correction_valid !== 1'b1) begin
                $display("FAIL: correction_valid timeout");
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_125m);
        @(negedge clk_125m);
        rst_125m = 1'b0;

        push_error(18'sd3, 22'sd5);
        wait_correction();
        if (freq_state !== 56'sd8) begin
            $display("FAIL: expected state 8, valid=1 got state=%0d valid=%b", freq_state, correction_valid);
            $finish;
        end
        if (freq_correction !== 56'sd11) begin
            $display("FAIL: expected correction 11 got %0d", freq_correction);
            $finish;
        end
        if (tracking_word !== 48'd1011) begin
            $display("FAIL: expected tracking word 1011 got %0d", tracking_word);
            $finish;
        end

        push_error(18'sd3000, 22'sd3000);
        wait_correction();
        if (saturated_high !== 1'b1) begin
            $display("FAIL: expected saturation high");
            $finish;
        end

        $display("PASS: hybrid_fll_pll_filter_stage_a_tb");
        $finish;
    end
endmodule
