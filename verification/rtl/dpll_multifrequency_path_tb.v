`timescale 1ns / 1ps

module dpll_multifrequency_path_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg signed [15:0] adc_sample = 16'sd0;
    reg config_apply = 1'b0;
    reg [47:0] center_word = 48'd0;

    wire [47:0] tracking_word;
    wire tracking_valid;
    wire signed [17:0] phase_error;
    wire signed [21:0] freq_error;
    wire freq_error_valid;
    wire signed [19:0] i_baseband;
    wire signed [19:0] q_baseband;
    wire iq_valid;
    wire [15:0] magnitude;
    wire [3:0] loop_state;
    wire [3:0] loss_reason;
    wire signal_present;
    wire phase_locked;
    wire frequency_locked;
    wire locked;
    wire [8:0] active_cic_rate_r;
    wire [5:0] active_cic_output_shift;
    wire cic_overflow_seen;
    wire cic_illegal_config_seen;
    wire signed [15:0] lo_cos;
    wire signed [15:0] lo_sin;

    integer n;
    integer freq_index;
    integer iq_seen;
    integer freq_seen;
    integer tracking_seen;
    integer phase_activity;
    integer nonzero_iq_seen;
    integer lo_nonzero_seen;
    integer trace_fd;
    reg collect_case = 1'b0;
    reg signed [17:0] prev_phase_error;
    reg [47:0] freq_words [0:6];

    always #4 clk = ~clk;

    dpll_single_clock_core_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .sample_valid(sample_valid),
        .loop_enable(1'b1),
        .adc_sample(adc_sample),
        .center_word(center_word),
        .config_apply(config_apply),
        .cic_rate_r(9'd8),
        .cic_output_shift(6'd4),
        .cic_flush(1'b0),
        .fll_delay_sel(2'd1),
        .kf(24'sd0),
        .ki(24'sd0),
        .kp(24'sd0),
        .kf_blend(24'sd0),
        .kf_track(24'sd0),
        .kp_blend(24'sd0),
        .ki_blend(24'sd0),
        .phase_setpoint(18'sd0),
        .phase_lock_threshold(18'd131071),
        .freq_lock_threshold(22'd2097151),
        .mag_enter_threshold(16'd1),
        .mag_exit_threshold(16'd0),
        .acquire_dwell(16'd1),
        .blend_dwell(16'd1),
        .loss_dwell(16'd4),
        .measurement_timeout(24'd65535),
        .holdover_timeout(24'd128),
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
        .magnitude(magnitude),
        .loop_state(loop_state),
        .loss_reason(loss_reason),
        .signal_present(signal_present),
        .phase_locked(phase_locked),
        .frequency_locked(frequency_locked),
        .locked(locked),
        .active_cic_rate_r(active_cic_rate_r),
        .active_cic_output_shift(active_cic_output_shift),
        .cic_overflow_seen(cic_overflow_seen),
        .cic_illegal_config_seen(cic_illegal_config_seen),
        .lo_cos(lo_cos),
        .lo_sin(lo_sin)
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

    task wait_idle;
        input integer cycles;
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge clk);
            end
        end
    endtask

    function signed [15:0] stimulus_sample;
        input integer sample_index;
        input integer case_no;
        begin
            case ((sample_index + case_no) % 7)
                0: stimulus_sample = 16'sd12000;
                1: stimulus_sample = -16'sd4000;
                2: stimulus_sample = 16'sd9000;
                3: stimulus_sample = -16'sd11000;
                4: stimulus_sample = 16'sd3000;
                5: stimulus_sample = 16'sd15000;
                default: stimulus_sample = -16'sd7000;
            endcase
        end
    endfunction

    task run_frequency_case;
        input integer case_no;
        input [47:0] word;
        begin
            center_word = word;
            iq_seen = 0;
            freq_seen = 0;
            tracking_seen = 0;
            phase_activity = 0;
            nonzero_iq_seen = 0;
            lo_nonzero_seen = 0;
            prev_phase_error = 18'sd0;
            collect_case = 1'b1;

            @(posedge clk);
            config_apply = 1'b1;
            @(posedge clk);
            config_apply = 1'b0;

            for (n = 0; n < 360; n = n + 1) begin
                push_sample(stimulus_sample(n, case_no));
            end

            wait_idle(80);
            collect_case = 1'b0;

            if (iq_seen < 16) begin
                $display("FAIL: case %0d expected IQ outputs, got %0d", case_no, iq_seen);
                $finish;
            end
            if (freq_seen < 8) begin
                $display("FAIL: case %0d expected frequency outputs, got %0d", case_no, freq_seen);
                $finish;
            end
            if (tracking_seen < 4) begin
                $display("FAIL: case %0d expected tracking updates, got %0d", case_no, tracking_seen);
                $finish;
            end
            if (nonzero_iq_seen == 0) begin
                $display("FAIL: case %0d IQ path stayed zero iq=%0d freq=%0d tracking=%0d lo_nz=%0d last_i=%0d last_q=%0d mag=%0d",
                         case_no, iq_seen, freq_seen, tracking_seen, lo_nonzero_seen,
                         i_baseband, q_baseband, magnitude);
                $finish;
            end
            if (phase_activity == 0) begin
                $display("FAIL: case %0d phase path showed no activity iq=%0d freq=%0d tracking=%0d last_phase=%0d mag=%0d",
                         case_no, iq_seen, freq_seen, tracking_seen, phase_error, magnitude);
                $finish;
            end
            if (tracking_word === 48'd0) begin
                $display("FAIL: case %0d tracking word stayed zero", case_no);
                $finish;
            end
            if (cic_illegal_config_seen || cic_overflow_seen) begin
                $display("FAIL: case %0d CIC fault illegal=%0b overflow=%0b",
                         case_no, cic_illegal_config_seen, cic_overflow_seen);
                $finish;
            end
            if (active_cic_rate_r !== 9'd8 || active_cic_output_shift !== 6'd4) begin
                $display("FAIL: case %0d active CIC config R=%0d shift=%0d",
                         case_no, active_cic_rate_r, active_cic_output_shift);
                $finish;
            end

            $display("PASS_CASE: index=%0d word=0x%012h iq=%0d freq=%0d tracking=%0d state=%0d loss=%0d signal=%0b phase_lock=%0b freq_lock=%0b locked=%0b mag=%0d",
                     case_no, word, iq_seen, freq_seen, tracking_seen, loop_state,
                     loss_reason, signal_present, phase_locked, frequency_locked, locked, magnitude);
            $fdisplay(trace_fd, "%0d,0x%012h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%012h,%0d,%0d,%0d,%0d,%0d,%0d",
                      case_no, word, iq_seen, freq_seen, tracking_seen, loop_state,
                      loss_reason, signal_present, phase_locked, frequency_locked, locked,
                      magnitude, tracking_word, phase_error, freq_error, active_cic_rate_r,
                      active_cic_output_shift, cic_illegal_config_seen, cic_overflow_seen);
        end
    endtask

    initial begin
        trace_fd = $fopen("dpll_multifrequency_path_trace.csv", "w");
        if (trace_fd == 0) begin
            $display("FAIL: could not open dpll_multifrequency_path_trace.csv");
            $finish;
        end
        $fdisplay(trace_fd, "case_index,word,iq_seen,freq_seen,tracking_seen,loop_state,loss_reason,signal_present,phase_locked,frequency_locked,locked,magnitude,tracking_word,phase_error,freq_error,active_cic_rate_r,active_cic_output_shift,cic_illegal_config_seen,cic_overflow_seen");

        freq_words[0] = 48'h0002_9f16_b11c; // 5 kHz at 125 MHz
        freq_words[1] = 48'h0005_3e2d_6239; // 10 kHz
        freq_words[2] = 48'h000a_7c5a_c472; // 20 kHz
        freq_words[3] = 48'h001a_36e2_eb1c; // 50 kHz
        freq_words[4] = 48'h0034_6dc5_d639; // 100 kHz
        freq_words[5] = 48'h004e_a4a8_c155; // 150 kHz
        freq_words[6] = 48'h0068_db8b_ac71; // 200 kHz

        repeat (6) @(posedge clk);
        rst = 1'b0;
        wait_idle(8);

        for (freq_index = 0; freq_index < 7; freq_index = freq_index + 1) begin
            run_frequency_case(freq_index, freq_words[freq_index]);
        end

        $display("PASS: dpll_multifrequency_path_tb");
        $fclose(trace_fd);
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && collect_case) begin
            if (iq_valid) begin
                iq_seen = iq_seen + 1;
                if ((i_baseband !== 20'sd0) || (q_baseband !== 20'sd0)) begin
                    nonzero_iq_seen = nonzero_iq_seen + 1;
                end
            end
            if (freq_error_valid) begin
                freq_seen = freq_seen + 1;
                if (phase_error !== prev_phase_error) begin
                    phase_activity = phase_activity + 1;
                end
                prev_phase_error = phase_error;
            end
            if (tracking_valid) begin
                tracking_seen = tracking_seen + 1;
            end
            if ((lo_cos !== 16'sd0) || (lo_sin !== 16'sd0)) begin
                lo_nonzero_seen = lo_nonzero_seen + 1;
            end
        end
    end
endmodule
