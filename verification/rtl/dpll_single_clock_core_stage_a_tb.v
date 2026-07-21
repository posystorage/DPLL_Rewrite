`timescale 1ns / 1ps

module dpll_single_clock_core_stage_a_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg signed [15:0] adc_sample = 16'sd0;
    reg controller_reacquire = 1'b0;

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
    wire cic_illegal_config_seen = 1'b0;

    integer n;
    integer iq_seen = 0;
    integer freq_seen = 0;
    integer tracking_seen = 0;
    integer hybrid_seen_before;
    integer state_seen_before;
    reg saw_track_iir_preheat = 1'b0;
    reg saw_cordic_status_clear = 1'b0;
    integer preheat_cycles = 0;

    always #4 clk = ~clk;

    dpll_single_clock_core_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .sample_valid(sample_valid),
        .loop_enable(1'b1),
        .status_clear(1'b0),
        .adc_sample(adc_sample),
        .center_word(48'h0100_0000_0000),
        .controller_reacquire(controller_reacquire),
        .detector_reconfigure(controller_reacquire),
        .cic_rate_r(9'd8),
        .cic_output_shift(6'd9),
        .cic_flush(1'b0),
        .fll_delay_sel(2'd0),
        .post_iir_mode(2'd0),
        .post_iir_acq_b0(32'sd0),
        .post_iir_acq_b1(32'sd0),
        .post_iir_acq_b2(32'sd0),
        .post_iir_acq_a1(32'sd0),
        .post_iir_acq_a2(32'sd0),
        .post_iir_track_b0(32'sd0),
        .post_iir_track_b1(32'sd0),
        .post_iir_track_b2(32'sd0),
        .post_iir_track_a1(32'sd0),
        .post_iir_track_a2(32'sd0),
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
        .mag_enter_threshold(20'd1),
        .mag_exit_threshold(20'd0),
        .acquire_dwell(16'd1),
        .blend_dwell(16'd1),
        .loss_dwell(16'd4),
        .measurement_timeout(24'd65535),
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
        .post_iir_active_bypass(),
        .post_iir_active_use_track(),
        .cic_overflow_seen(),
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
        if (dut.track_iir_preheat) saw_track_iir_preheat = 1'b1;
        if (dut.cordic_status_clear) saw_cordic_status_clear = 1'b1;
        if (!rst && dut.loop_state == 4'd4 && dut.track_iir_preheat) begin
            preheat_cycles = preheat_cycles + 1;
            if (dut.loop_enable_pll_i !== 1'b0 ||
                dut.loop_enable_pll_p !== 1'b0 ||
                dut.active_enable_pll_i_r !== 1'b0 ||
                dut.active_enable_pll_p_r !== 1'b0 ||
                dut.hybrid_enable_pll_i_r !== 1'b0 ||
                dut.hybrid_enable_pll_p_r !== 1'b0 ||
                dut.hybrid_loop_inst.enable_pll_i_mul_r !== 1'b0 ||
                dut.hybrid_loop_inst.enable_pll_p_mul_r !== 1'b0 ||
                dut.hybrid_loop_inst.enable_pll_i_operand_r !== 1'b0 ||
                dut.hybrid_loop_inst.enable_pll_p_operand_r !== 1'b0 ||
                dut.hybrid_loop_inst.enable_pll_i_product_r !== 1'b0 ||
                dut.hybrid_loop_inst.enable_pll_p_product_r !== 1'b0 ||
                dut.hybrid_loop_inst.i_term_r !== 56'sd0 ||
                dut.hybrid_loop_inst.p_term_r !== 56'sd0) begin
                $display("FAIL: PI activity reached hybrid pipeline during state-4 TRACK IIR preheat");
                $finish;
            end
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        controller_reacquire = 1'b1;
        @(posedge clk);
        #1;
        if (!tracking_valid || tracking_word !== 48'h0100_0000_0000) begin
            $display("FAIL: controller_reacquire did not present center word with valid, valid=%b word=%h",
                     tracking_valid, tracking_word);
            $finish;
        end
        controller_reacquire = 1'b0;

        // Cross-dot FLL needs delay history plus a complete 16-sample block
        // before division/replay can emit frequency results.
        for (n = 0; n < 480; n = n + 1) begin
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
        if (!saw_track_iir_preheat) begin
            $display("FAIL: core never entered TRACK IIR preheat");
            $finish;
        end
        if (preheat_cycles == 0) begin
            $display("FAIL: core did not exercise the state-4 preheat PI assertions");
            $finish;
        end
        if (!saw_cordic_status_clear) begin
            $display("FAIL: core never cleared CORDIC sticky status at state 3->4");
            $finish;
        end

        @(negedge clk);
        hybrid_seen_before = tracking_seen;
        state_seen_before = dut.loop_state_manager_inst.measurement_gap_count;
        force dut.freq_error_valid = 1'b1;
        force dut.fll_ambiguous = 1'b1;
        @(posedge clk);
        #1;
        release dut.freq_error_valid;
        release dut.fll_ambiguous;
        if (dut.freq_error_usable !== 1'b0) begin
            $display("FAIL: ambiguous FLL sample was marked usable");
            $finish;
        end
        @(posedge clk);
        #1;
        if (dut.hybrid_error_valid_r !== 1'b0) begin
            $display("FAIL: ambiguous FLL sample reached hybrid loop");
            $finish;
        end
        if (dut.state_measurement_valid_r !== 1'b0) begin
            $display("FAIL: ambiguous FLL sample reached state manager");
            $finish;
        end
        if (tracking_seen !== hybrid_seen_before) begin
            $display("FAIL: ambiguous FLL sample produced a tracking update");
            $finish;
        end
        if (dut.loop_state_manager_inst.measurement_gap_count <= state_seen_before) begin
            $display("FAIL: ambiguous FLL sample reset the state-manager measurement watchdog");
            $finish;
        end

        $display("PASS: dpll_single_clock_core_stage_a_tb");
        $finish;
    end
endmodule
