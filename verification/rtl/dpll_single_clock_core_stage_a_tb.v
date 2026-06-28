`timescale 1ns / 1ps

module dpll_single_clock_core_stage_a_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg signed [15:0] adc_sample = 16'sd0;
    reg config_apply = 1'b0;

    wire [47:0] tracking_word;
    wire tracking_valid;
    wire signed [17:0] phase_error;
    wire signed [21:0] freq_error;
    wire freq_error_valid;
    wire signed [19:0] i_baseband;
    wire signed [19:0] q_baseband;
    wire iq_valid;
    wire [8:0] active_cic_rate_r;
    wire [5:0] active_cic_output_shift;
    wire cic_illegal_config_seen;

    integer n;
    integer iq_seen = 0;
    integer freq_seen = 0;
    integer tracking_seen = 0;

    always #4 clk = ~clk;

    dpll_single_clock_core_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .sample_valid(sample_valid),
        .loop_enable(1'b1),
        .adc_sample(adc_sample),
        .center_word(48'h0100_0000_0000),
        .config_apply(config_apply),
        .cic_rate_r(9'd8),
        .cic_output_shift(6'd9),
        .cic_flush(1'b0),
        .fll_delay_sel(2'd0),
        .kf(24'sd8),
        .ki(24'sd2),
        .kp(24'sd4),
        .kf_blend(24'sd4),
        .kf_track(24'sd1),
        .kp_blend(24'sd2),
        .ki_blend(24'sd1),
        .phase_setpoint(18'sd0),
        .phase_lock_threshold(18'd131071),
        .freq_lock_threshold(22'd2097151),
        .mag_enter_threshold(16'd1),
        .mag_exit_threshold(16'd0),
        .acquire_dwell(16'd1),
        .blend_dwell(16'd1),
        .loss_dwell(16'd4),
        .holdover_timeout(24'd64),
        .warmup_samples(16'd1),
        .positive_limit(56'sd140737488355327),
        .negative_limit(-56'sd140737488355328),
        .tracking_word(tracking_word),
        .tracking_valid(tracking_valid),
        .cordic_phase_out(),
        .phase_error(phase_error),
        .freq_error(freq_error),
        .freq_error_valid(freq_error_valid),
        .i_baseband(i_baseband),
        .q_baseband(q_baseband),
        .iq_valid(iq_valid),
        .freq_state(),
        .freq_correction(),
        .magnitude(),
        .loop_state(),
        .loss_reason(),
        .signal_present(),
        .phase_locked(),
        .frequency_locked(),
        .locked(),
        .active_cic_rate_r(active_cic_rate_r),
        .active_cic_output_shift(active_cic_output_shift),
        .cic_overflow_seen(),
        .cic_illegal_config_seen(cic_illegal_config_seen),
        .lo_cos(),
        .lo_sin()
    );

    task push_sample;
        input signed [15:0] value;
        begin
            @(posedge clk);
            adc_sample = value;
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (iq_valid) iq_seen = iq_seen + 1;
        if (freq_error_valid) freq_seen = freq_seen + 1;
        if (tracking_valid) tracking_seen = tracking_seen + 1;
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        config_apply = 1'b1;
        @(posedge clk);
        config_apply = 1'b0;

        for (n = 0; n < 160; n = n + 1) begin
            push_sample((n[0] == 1'b0) ? 16'sd12000 : -16'sd8000);
        end

        repeat (30) @(posedge clk);

        if (active_cic_rate_r !== 9'd8) begin
            $display("FAIL: active_cic_rate_r expected 8 got %0d", active_cic_rate_r);
            $finish;
        end
        if (active_cic_output_shift !== 6'd9) begin
            $display("FAIL: active_cic_output_shift expected 9 got %0d", active_cic_output_shift);
            $finish;
        end
        if (cic_illegal_config_seen !== 1'b0) begin
            $display("FAIL: unexpected CIC illegal config");
            $finish;
        end
        if (iq_seen < 8) begin
            $display("FAIL: expected at least 8 IQ outputs, got %0d", iq_seen);
            $finish;
        end
        if (freq_seen < 4) begin
            $display("FAIL: expected at least 4 FLL outputs, got %0d", freq_seen);
            $finish;
        end
        if (tracking_seen < 2) begin
            $display("FAIL: expected tracking updates, got %0d", tracking_seen);
            $finish;
        end
        if (tracking_word === 48'd0) begin
            $display("FAIL: tracking_word remained zero");
            $finish;
        end

        $display("PASS: dpll_single_clock_core_stage_a_tb");
        $finish;
    end
endmodule
