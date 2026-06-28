`timescale 1ns / 1ps

module dpll_core_sine_sweep_tb;
    localparam real TWO_PI = 6.2831853071795864769;
    localparam real SAMPLE_RATE_HZ = 3125000.0;
    localparam integer SAMPLE_GAP_CYCLES = 40;
    localparam integer ADC_AMPLITUDE = 15000;
    localparam integer CASES = 7;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg signed [15:0] adc_sample = 16'sd0;
    reg config_apply = 1'b0;
    reg [47:0] center_word = 48'd0;
    reg [8:0] cic_rate_r = 9'd8;
    reg [5:0] cic_shift = 6'd4;
    real input_hz = 0.0;
    real center_hz = 0.0;
    real phase = 0.0;
    real phase_step = 0.0;

    wire [47:0] tracking_word;
    wire tracking_valid;
    wire signed [17:0] phase_error;
    wire signed [21:0] freq_error;
    wire freq_error_valid;
    wire signed [55:0] freq_correction;
    wire [3:0] loop_state;
    wire [3:0] loss_reason;
    wire signal_present;
    wire phase_locked;
    wire frequency_locked;
    wire locked;
    wire [15:0] magnitude;
    wire cic_overflow_seen;
    wire cic_illegal_config_seen;

    integer fd;
    integer case_no = 0;
    integer case_index;
    integer sample_index;
    integer idle;
    integer sample_count = 0;
    integer tracking_count = 0;
    integer fll_valid_count = 0;
    integer locked_count = 0;
    integer track_state_count = 0;
    integer nonzero_correction_count = 0;
    integer positive_tracking_delta_count = 0;

    always #4 clk = ~clk;

    dpll_single_clock_core_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .sample_valid(sample_valid),
        .loop_enable(1'b1),
        .adc_sample(adc_sample),
        .center_word(center_word),
        .config_apply(config_apply),
        .cic_rate_r(cic_rate_r),
        .cic_output_shift(cic_shift),
        .cic_flush(1'b0),
        .fll_delay_sel(2'd1),
        .kf(24'sd65536),
        .ki(24'sd2048),
        .kp(24'sd2048),
        .kf_blend(24'sd32768),
        .kf_track(24'sd8192),
        .kp_blend(24'sd1024),
        .ki_blend(24'sd1024),
        .phase_setpoint(-18'sd65536),
        .phase_lock_threshold(18'd131071),
        .freq_lock_threshold(22'd2097151),
        .mag_enter_threshold(16'd1),
        .mag_exit_threshold(16'd0),
        .acquire_dwell(16'd2),
        .blend_dwell(16'd2),
        .loss_dwell(16'd8),
        .holdover_timeout(24'd65535),
        .warmup_samples(16'd2),
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
        .loss_reason(loss_reason),
        .signal_present(signal_present),
        .phase_locked(phase_locked),
        .frequency_locked(frequency_locked),
        .locked(locked),
        .active_cic_rate_r(),
        .active_cic_output_shift(),
        .cic_overflow_seen(cic_overflow_seen),
        .cic_illegal_config_seen(cic_illegal_config_seen),
        .lo_cos(),
        .lo_sin()
    );

    function signed [15:0] sine_sample;
        input real sample_phase;
        integer rounded;
        begin
            rounded = $rtoi($sin(sample_phase) * ADC_AMPLITUDE);
            if (rounded > 32767) begin
                sine_sample = 16'sh7fff;
            end else if (rounded < -32768) begin
                sine_sample = 16'sh8000;
            end else begin
                sine_sample = rounded[15:0];
            end
        end
    endfunction

    task push_sine_sample;
        begin
            @(posedge clk);
            adc_sample = sine_sample(phase);
            sample_valid = 1'b1;
            phase = phase + phase_step;
            if (phase >= TWO_PI) begin
                phase = phase - TWO_PI;
            end
            sample_count = sample_count + 1;
            @(posedge clk);
            sample_valid = 1'b0;
            for (idle = 0; idle < SAMPLE_GAP_CYCLES - 1; idle = idle + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task configure_case;
        input integer index;
        begin
            case_no = index;
            phase = 0.0;
            sample_count = 0;
            tracking_count = 0;
            fll_valid_count = 0;
            locked_count = 0;
            track_state_count = 0;
            nonzero_correction_count = 0;
            positive_tracking_delta_count = 0;
            case (index)
                0: begin
                    center_hz = 5000.0;
                    input_hz = 5500.0;
                    center_word = 48'h0002_9f16_b11c;
                    cic_rate_r = 9'd312;
                    cic_shift = 6'd19;
                end
                1: begin
                    center_hz = 10000.0;
                    input_hz = 10500.0;
                    center_word = 48'h0005_3e2d_6239;
                    cic_rate_r = 9'd156;
                    cic_shift = 6'd16;
                end
                2: begin
                    center_hz = 20000.0;
                    input_hz = 20500.0;
                    center_word = 48'h000a_7c5a_c472;
                    cic_rate_r = 9'd78;
                    cic_shift = 6'd13;
                end
                3: begin
                    center_hz = 50000.0;
                    input_hz = 50500.0;
                    center_word = 48'h001a_36e2_eb1c;
                    cic_rate_r = 9'd31;
                    cic_shift = 6'd10;
                end
                4: begin
                    center_hz = 100000.0;
                    input_hz = 100500.0;
                    center_word = 48'h0034_6dc5_d639;
                    cic_rate_r = 9'd16;
                    cic_shift = 6'd7;
                end
                5: begin
                    center_hz = 150000.0;
                    input_hz = 150500.0;
                    center_word = 48'h004e_a4a8_c155;
                    cic_rate_r = 9'd8;
                    cic_shift = 6'd4;
                end
                default: begin
                    center_hz = 200000.0;
                    input_hz = 201000.0;
                    center_word = 48'h0068_db8b_ac71;
                    cic_rate_r = 9'd8;
                    cic_shift = 6'd4;
                end
            endcase
            phase_step = TWO_PI * input_hz / SAMPLE_RATE_HZ;
        end
    endtask

    task run_case;
        input integer index;
        begin
            configure_case(index);
            @(posedge clk);
            config_apply = 1'b1;
            @(posedge clk);
            config_apply = 1'b0;

            for (sample_index = 0; sample_index < 12000; sample_index = sample_index + 1) begin
                push_sine_sample();
            end
            repeat (240) @(posedge clk);

            if (tracking_count < 16) begin
                $display("FAIL: case %0d expected tracking updates, got %0d", index, tracking_count);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            if (track_state_count < 8) begin
                $display("FAIL: case %0d expected TRACK samples, got %0d", index, track_state_count);
                $display("FAIL_SUMMARY: case=%0d tracking=%0d fll=%0d track=%0d locked=%0d nonzero=%0d positive=%0d state=%0d loss=%0d signal=%0b phase_lock=%0b freq_lock=%0b mag=%0d",
                         index, tracking_count, fll_valid_count, track_state_count,
                         locked_count, nonzero_correction_count, positive_tracking_delta_count,
                         loop_state, loss_reason, signal_present, phase_locked,
                         frequency_locked, magnitude);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            if (locked_count < 8) begin
                $display("FAIL: case %0d expected locked samples, got %0d", index, locked_count);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            if (fll_valid_count < 16) begin
                $display("FAIL: case %0d expected FLL valid samples, got %0d", index, fll_valid_count);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            if (nonzero_correction_count < 8) begin
                $display("FAIL: case %0d expected nonzero corrections, got %0d", index, nonzero_correction_count);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            if (positive_tracking_delta_count < 4) begin
                $display("FAIL: case %0d expected positive tracking response, got %0d",
                         index, positive_tracking_delta_count);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            if (cic_illegal_config_seen || cic_overflow_seen) begin
                $display("FAIL: case %0d CIC fault illegal=%0b overflow=%0b",
                         index, cic_illegal_config_seen, cic_overflow_seen);
                $fflush(fd);
                $fclose(fd);
                $finish;
            end
            $display("PASS_CASE: sine_sweep index=%0d center=%0f input=%0f tracking=%0d track=%0d locked=%0d positive=%0d",
                     index, center_hz, input_hz, tracking_count, track_state_count,
                     locked_count, positive_tracking_delta_count);
        end
    endtask

    initial begin
        fd = $fopen("dpll_core_sine_sweep_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open dpll_core_sine_sweep_trace.csv");
            $finish;
        end
        $fdisplay(fd, "case_index,index,sample_count,fll_valid_count,input_hz,center_hz,center_word,cic_rate_r,cic_shift,tracking_word,freq_correction,phase_error,freq_error,freq_error_valid,loop_state,loss_reason,signal_present,phase_locked,frequency_locked,locked,magnitude");

        repeat (8) @(posedge clk);
        rst = 1'b0;

        for (case_index = 0; case_index < CASES; case_index = case_index + 1) begin
            run_case(case_index);
        end

        $fclose(fd);
        $display("PASS: dpll_core_sine_sweep_tb cases=%0d", CASES);
        $finish;
    end

    always @(posedge clk) begin
        #1;
        if (!rst && freq_error_valid) begin
            fll_valid_count = fll_valid_count + 1;
        end
        if (!rst && tracking_valid) begin
            $fdisplay(fd, "%0d,%0d,%0d,%0d,%0f,%0f,0x%012h,%0d,%0d,0x%012h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                      case_no, tracking_count, sample_count, fll_valid_count,
                      input_hz, center_hz, center_word, cic_rate_r, cic_shift,
                      tracking_word, freq_correction, phase_error, freq_error,
                      freq_error_valid, loop_state, loss_reason, signal_present,
                      phase_locked, frequency_locked, locked, magnitude);
            $fflush(fd);
            tracking_count = tracking_count + 1;
            if (loop_state == 4'd6) begin
                track_state_count = track_state_count + 1;
            end
            if (locked) begin
                locked_count = locked_count + 1;
            end
            if (freq_correction !== 56'sd0) begin
                nonzero_correction_count = nonzero_correction_count + 1;
            end
            if (tracking_word > center_word) begin
                positive_tracking_delta_count = positive_tracking_delta_count + 1;
            end
        end
    end
endmodule
