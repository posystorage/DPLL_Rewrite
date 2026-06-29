`timescale 1ns / 1ps

module dpll_core_nonzero_tracking_tb;
    localparam [47:0] CENTER_WORD = 48'h000a_7c5a_c472;

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
    wire signed [55:0] freq_correction;
    wire [3:0] loop_state;
    wire locked;
    wire [15:0] magnitude;
    wire cic_overflow_seen;
    wire cic_illegal_config_seen;

    integer n;
    integer fd;
    integer tracking_count = 0;
    integer nonzero_correction_count = 0;

    always #4 clk = ~clk;

    dpll_single_clock_core_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .sample_valid(sample_valid),
        .loop_enable(1'b1),
        .adc_sample(adc_sample),
        .center_word(CENTER_WORD),
        .config_apply(config_apply),
        .cic_rate_r(9'd8),
        .cic_output_shift(6'd4),
        .cic_flush(1'b0),
        .fll_delay_sel(2'd1),
        .kf(24'sd16384),
        .ki(24'sd8192),
        .kp(24'sd4096),
        .kf_blend(24'sd8192),
        .kf_track(24'sd4096),
        .kp_blend(24'sd4096),
        .ki_blend(24'sd2048),
        .phase_setpoint(18'sd0),
        .phase_lock_threshold(18'd131071),
        .freq_lock_threshold(22'd2097151),
        .mag_enter_threshold(16'd1),
        .mag_exit_threshold(16'd0),
        .acquire_dwell(16'd1),
        .blend_dwell(16'd1),
        .loss_dwell(16'd6),
        .measurement_timeout(24'd65535),
        .holdover_timeout(24'd256),
        .warmup_samples(16'd1),
        .positive_limit(56'sd140737488355327),
        .negative_limit(-56'sd140737488355328),
        .tracking_word(tracking_word),
        .tracking_valid(tracking_valid),
        .cordic_phase_out(),
        .phase_error(phase_error),
        .freq_error(freq_error),
        .freq_error_valid(freq_error_valid),
        .i_baseband(),
        .q_baseband(),
        .iq_valid(),
        .freq_state(),
        .freq_correction(freq_correction),
        .magnitude(magnitude),
        .loop_state(loop_state),
        .loss_reason(),
        .signal_present(),
        .phase_locked(),
        .frequency_locked(),
        .locked(locked),
        .active_cic_rate_r(),
        .active_cic_output_shift(),
        .cic_overflow_seen(cic_overflow_seen),
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

    function signed [15:0] stimulus_sample;
        input integer sample_index;
        begin
            case (sample_index % 8)
                0: stimulus_sample = 16'sd14000;
                1: stimulus_sample = 16'sd9000;
                2: stimulus_sample = -16'sd3000;
                3: stimulus_sample = -16'sd12000;
                4: stimulus_sample = -16'sd15000;
                5: stimulus_sample = -16'sd7000;
                6: stimulus_sample = 16'sd5000;
                default: stimulus_sample = 16'sd13000;
            endcase
        end
    endfunction

    initial begin
        fd = $fopen("dpll_core_nonzero_tracking_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open dpll_core_nonzero_tracking_trace.csv");
            $finish;
        end
        $fdisplay(fd, "index,center_word,tracking_word,freq_correction,phase_error,freq_error,freq_error_valid,loop_state,locked,magnitude");

        repeat (6) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        config_apply = 1'b1;
        @(posedge clk);
        config_apply = 1'b0;

        for (n = 0; n < 520; n = n + 1) begin
            push_sample(stimulus_sample(n));
        end

        repeat (120) @(posedge clk);

        if (tracking_count < 8) begin
            $display("FAIL: expected at least 8 nonzero-gain tracking updates, got %0d", tracking_count);
            $finish;
        end
        if (nonzero_correction_count < 4) begin
            $display("FAIL: expected nonzero frequency corrections, got %0d", nonzero_correction_count);
            $finish;
        end
        if (cic_illegal_config_seen || cic_overflow_seen) begin
            $display("FAIL: CIC fault illegal=%0b overflow=%0b", cic_illegal_config_seen, cic_overflow_seen);
            $finish;
        end

        $fclose(fd);
        $display("PASS: dpll_core_nonzero_tracking_tb tracking=%0d nonzero=%0d",
                 tracking_count, nonzero_correction_count);
        $finish;
    end

    always @(posedge clk) begin
        #1;
        if (!rst && tracking_valid) begin
            $fdisplay(fd, "%0d,0x%012h,0x%012h,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                      tracking_count, CENTER_WORD, tracking_word, freq_correction,
                      phase_error, freq_error, freq_error_valid, loop_state, locked,
                      magnitude);
            tracking_count = tracking_count + 1;
            if (freq_correction !== 56'sd0 && tracking_word !== CENTER_WORD) begin
                nonzero_correction_count = nonzero_correction_count + 1;
            end
        end
    end
endmodule
