`timescale 1ns / 1ps
`default_nettype none

module dpll_single_clock_core_stage_a #(
    parameter integer ADC_WIDTH = 16,
    parameter integer WORD_WIDTH = 48,
    parameter integer PHASE_WIDTH = 18,
    parameter integer MIXER_WIDTH = 18,
    parameter integer CIC_WIDTH = 20,
    parameter integer MAG_WIDTH = 20,
    parameter integer FERR_WIDTH = 22,
    parameter integer COEFF_WIDTH = 24,
    parameter integer STATE_WIDTH = 56
) (
    input  wire                                  clk_125m,
    input  wire                                  rst_125m,
    input  wire                                  sample_valid,
    input  wire                                  loop_enable,
    input  wire                                  status_clear,
    input  wire signed [ADC_WIDTH-1:0]           adc_sample,
    input  wire [WORD_WIDTH-1:0]                 center_word,
    input  wire                                  config_apply,
    input  wire [8:0]                            cic_rate_r,
    input  wire [5:0]                            cic_output_shift,
    input  wire                                  cic_flush,
    input  wire [1:0]                            fll_delay_sel,
    input  wire [1:0]                            post_iir_mode,
    input  wire signed [31:0]                    post_iir_acq_b0,
    input  wire signed [31:0]                    post_iir_acq_b1,
    input  wire signed [31:0]                    post_iir_acq_b2,
    input  wire signed [31:0]                    post_iir_acq_a1,
    input  wire signed [31:0]                    post_iir_acq_a2,
    input  wire signed [31:0]                    post_iir_track_b0,
    input  wire signed [31:0]                    post_iir_track_b1,
    input  wire signed [31:0]                    post_iir_track_b2,
    input  wire signed [31:0]                    post_iir_track_a1,
    input  wire signed [31:0]                    post_iir_track_a2,
    input  wire signed [COEFF_WIDTH-1:0]         kf,
    input  wire signed [COEFF_WIDTH-1:0]         ki,
    input  wire signed [COEFF_WIDTH-1:0]         kp,
    input  wire signed [COEFF_WIDTH-1:0]         kf_blend,
    input  wire signed [COEFF_WIDTH-1:0]         kf_track,
    input  wire signed [COEFF_WIDTH-1:0]         kp_blend,
    input  wire signed [COEFF_WIDTH-1:0]         ki_blend,
    input  wire signed [PHASE_WIDTH-1:0]         phase_setpoint,
    input  wire [PHASE_WIDTH-1:0]                phase_lock_threshold,
    input  wire [FERR_WIDTH-1:0]                 freq_lock_threshold,
    input  wire [MAG_WIDTH-1:0]                  mag_enter_threshold,
    input  wire [MAG_WIDTH-1:0]                  mag_exit_threshold,
    input  wire [15:0]                           acquire_dwell,
    input  wire [15:0]                           blend_dwell,
    input  wire [15:0]                           loss_dwell,
    input  wire [23:0]                           measurement_timeout,
    input  wire [23:0]                           holdover_timeout,
    input  wire [15:0]                           warmup_samples,
    input  wire signed [STATE_WIDTH-1:0]         positive_limit,
    input  wire signed [STATE_WIDTH-1:0]         negative_limit,
    output wire [WORD_WIDTH-1:0]                 tracking_word,
    output wire                                  tracking_valid,
    output wire signed [PHASE_WIDTH-1:0]         cordic_phase_out,
    output wire signed [PHASE_WIDTH-1:0]         phase_error,
    output wire signed [FERR_WIDTH-1:0]          freq_error,
    output wire                                  freq_error_valid,
    output wire signed [CIC_WIDTH-1:0]           i_baseband,
    output wire signed [CIC_WIDTH-1:0]           q_baseband,
    output wire                                  iq_valid,
    output wire signed [STATE_WIDTH-1:0]         freq_state,
    output wire signed [STATE_WIDTH-1:0]         freq_correction,
    output wire [MAG_WIDTH-1:0]                  magnitude,
    output wire [3:0]                            loop_state,
    output wire [3:0]                            loss_reason,
    output wire                                  signal_present,
    output wire                                  phase_locked,
    output wire                                  frequency_locked,
    output wire                                  locked,
    output wire [8:0]                            active_cic_rate_r,
    output wire [5:0]                            active_cic_output_shift,
    output wire                                  post_iir_active_bypass,
    output wire                                  post_iir_active_use_track,
    output wire                                  cic_overflow_seen,
    output wire                                  cic_illegal_config_seen,
    output wire                                  cordic_input_overrun_seen,
    output wire                                  cordic_input_out_of_range_seen,
    output wire                                  cordic_output_format_error_seen,
    output wire signed [15:0]                    lo_cos,
    output wire signed [15:0]                    lo_sin
);

    reg [WORD_WIDTH-1:0] tracking_word_hold;
    reg nco_word_ready;
    wire [WORD_WIDTH-1:0] nco_word;
    wire dds_valid;
    wire [31:0] dds_data;

    wire dc_valid;
    wire signed [ADC_WIDTH-1:0] adc_dc_blocked;
    reg signed [ADC_WIDTH-1:0] adc_sample_r0;
    reg signed [ADC_WIDTH-1:0] adc_sample_r1;
    reg signed [15:0] lo_cos_r0;
    reg signed [15:0] lo_sin_r0;
    reg signed [15:0] lo_cos_r1;
    reg signed [15:0] lo_sin_r1;
    reg mixer_input_valid_r0;
    reg mixer_input_valid_r1;
    reg mixer_product_valid;
    wire signed [31:0] mixer_i_product;
    wire signed [31:0] mixer_q_product;
    reg mixer_round_valid_r;
    reg signed [31:0] mixer_i_product_r;
    reg signed [31:0] mixer_q_product_r;
    wire signed [15:0] mixer_i_rounded;
    wire signed [15:0] mixer_q_rounded;
    wire mixer_valid;
    wire signed [MIXER_WIDTH-1:0] mixer_i;
    wire signed [MIXER_WIDTH-1:0] mixer_q;
    reg mixer_cic_valid_r;
    reg signed [MIXER_WIDTH-1:0] mixer_i_cic_r;
    reg signed [MIXER_WIDTH-1:0] mixer_q_cic_r;
    wire cic_iq_valid;
    wire signed [CIC_WIDTH-1:0] cic_i_baseband;
    wire signed [CIC_WIDTH-1:0] cic_q_baseband;
    wire post_iir_state_use_track;
    wire track_iir_preheat;
    wire cordic_valid;
    wire signed [PHASE_WIDTH-1:0] cordic_phase_word;
    wire [MAG_WIDTH-1:0] cordic_magnitude;
    wire cordic_busy;
    wire signed [PHASE_WIDTH-1:0] phase_error_next;
    wire [PHASE_WIDTH-1:0] phase_abs;
    wire [FERR_WIDTH-1:0] freq_abs;
    wire cordic_signal_usable;
    wire fll_iq_valid;
    wire fll_ambiguous;
    wire freq_error_block_valid;
    wire freq_error_usable;
    wire freq_error_block_usable;
    wire post_iir_requested_bypass;
    wire post_iir_requested_track;
    wire post_iir_selection_changed;
    wire detector_reconfigure;
    reg signed [PHASE_WIDTH-1:0] phase_error_hold;
    reg [MAG_WIDTH-1:0] cordic_magnitude_hold;
    reg freq_error_block_valid_d;
    reg state_measurement_valid_r;
    reg [PHASE_WIDTH-1:0] state_phase_abs_r;
    reg [FERR_WIDTH-1:0] state_freq_abs_r;
    reg [MAG_WIDTH-1:0] state_magnitude_r;
    reg signal_present_r;
    wire correction_valid;
    wire [WORD_WIDTH-1:0] correction_tracking_word;
    wire loop_enable_fll;
    wire loop_enable_pll_i;
    wire loop_enable_pll_p;
    wire signed [COEFF_WIDTH-1:0] active_kf;
    wire signed [COEFF_WIDTH-1:0] active_ki;
    wire signed [COEFF_WIDTH-1:0] active_kp;
    reg active_enable_fll_r;
    reg active_enable_pll_i_r;
    reg active_enable_pll_p_r;
    reg signed [COEFF_WIDTH-1:0] active_kf_r;
    reg signed [COEFF_WIDTH-1:0] active_ki_r;
    reg signed [COEFF_WIDTH-1:0] active_kp_r;
    reg hybrid_error_valid_r;
    reg hybrid_enable_fll_r;
    reg hybrid_enable_pll_i_r;
    reg hybrid_enable_pll_p_r;
    reg signed [PHASE_WIDTH-1:0] hybrid_phase_error_r;
    reg signed [FERR_WIDTH-1:0] hybrid_freq_error_r;
    reg signed [COEFF_WIDTH-1:0] hybrid_kf_r;
    reg signed [COEFF_WIDTH-1:0] hybrid_ki_r;
    reg signed [COEFF_WIDTH-1:0] hybrid_kp_r;
    reg [3:0] loop_state_d;
    wire saturated_high;
    wire saturated_low;
    (* keep = "true", dont_touch = "true" *) reg rst_nco_r;
    (* keep = "true", dont_touch = "true" *) reg rst_dc_r;
    (* keep = "true", dont_touch = "true" *) reg rst_mixer_r;
    (* keep = "true", dont_touch = "true" *) reg rst_cic_r;
    (* keep = "true", dont_touch = "true" *) reg rst_detector_r;
    (* keep = "true", dont_touch = "true" *) reg rst_state_r;
    (* keep = "true", dont_touch = "true" *) reg rst_measure_r;
    (* keep = "true", dont_touch = "true" *) reg rst_hybrid_r;
    (* keep = "true", dont_touch = "true" *) reg nco_word_ready_dds_r;

    assign nco_word = config_apply ? center_word : tracking_word_hold;
    assign tracking_word = config_apply ? center_word : tracking_word_hold;
    assign tracking_valid = correction_valid | config_apply;
    assign magnitude = cordic_magnitude_hold;
    assign post_iir_state_use_track = track_iir_preheat ||
                                      (loop_state == 4'd5) || (loop_state == 4'd6);
    assign post_iir_requested_bypass = (post_iir_mode == 2'd0);
    assign post_iir_requested_track = (post_iir_mode == 2'd2) ||
                                      ((post_iir_mode == 2'd3) && post_iir_state_use_track);
    assign post_iir_selection_changed =
        (post_iir_active_bypass != post_iir_requested_bypass) ||
        (post_iir_active_use_track != post_iir_requested_track);
    assign detector_reconfigure = config_apply | cic_flush | post_iir_selection_changed;
    wire cordic_status_clear = status_clear |
                               ((loop_state == 4'd4) && (loop_state_d == 4'd3));

    always @(posedge clk_125m) begin
        rst_nco_r <= rst_125m;
        rst_dc_r <= rst_125m;
        rst_mixer_r <= rst_125m;
        rst_cic_r <= rst_125m;
        rst_detector_r <= rst_125m;
        rst_state_r <= rst_125m;
        rst_measure_r <= rst_125m;
        rst_hybrid_r <= rst_125m;
    end

    always @(posedge clk_125m) begin
        if (rst_state_r) begin
            loop_state_d <= 4'd0;
        end else begin
            loop_state_d <= loop_state;
        end
    end

    always @(posedge clk_125m) begin
        if (rst_nco_r) begin
            tracking_word_hold <= {WORD_WIDTH{1'b0}};
            nco_word_ready <= 1'b0;
            nco_word_ready_dds_r <= 1'b0;
        end else if (config_apply || !loop_enable) begin
            tracking_word_hold <= center_word;
            nco_word_ready <= |center_word;
            nco_word_ready_dds_r <= nco_word_ready;
        end else if (correction_valid) begin
            tracking_word_hold <= correction_tracking_word;
            nco_word_ready <= |correction_tracking_word;
            nco_word_ready_dds_r <= nco_word_ready;
        end else if (tracking_word_hold == {WORD_WIDTH{1'b0}}) begin
            tracking_word_hold <= center_word;
            nco_word_ready <= |center_word;
            nco_word_ready_dds_r <= nco_word_ready;
        end else begin
            nco_word_ready_dds_r <= nco_word_ready;
        end
    end

    LO_DDS_H tracking_lo_dds_inst (
        .aclk(clk_125m),
        .s_axis_phase_tvalid(nco_word_ready_dds_r),
        .s_axis_phase_tdata(nco_word),
        .m_axis_data_tvalid(dds_valid),
        .m_axis_data_tdata(dds_data),
        .m_axis_phase_tvalid(),
        .m_axis_phase_tdata()
    );

    assign lo_cos = lo_cos_r1;
    assign lo_sin = lo_sin_r1;

    dc_blocker_valid_stage_a #(
        .DATA_WIDTH(ADC_WIDTH),
        .ACC_WIDTH(48),
        .LEAK_SHIFT(10)
    ) dc_blocker_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_dc_r),
        .in_valid(sample_valid),
        .sample_in(adc_sample),
        .out_valid(dc_valid),
        .sample_out(adc_dc_blocked)
    );

    always @(posedge clk_125m) begin
        if (rst_mixer_r) begin
            adc_sample_r0 <= {ADC_WIDTH{1'b0}};
            adc_sample_r1 <= {ADC_WIDTH{1'b0}};
            lo_cos_r0 <= 16'sd0;
            lo_sin_r0 <= 16'sd0;
            lo_cos_r1 <= 16'sd0;
            lo_sin_r1 <= 16'sd0;
            mixer_input_valid_r0 <= 1'b0;
            mixer_input_valid_r1 <= 1'b0;
            mixer_product_valid <= 1'b0;
            mixer_round_valid_r <= 1'b0;
            mixer_i_product_r <= 32'sd0;
            mixer_q_product_r <= 32'sd0;
        end else begin
            mixer_input_valid_r0 <= dc_valid && dds_valid;
            mixer_input_valid_r1 <= mixer_input_valid_r0;
            mixer_product_valid <= mixer_input_valid_r1;
            mixer_round_valid_r <= mixer_product_valid;
            if (dc_valid && dds_valid) begin
                adc_sample_r0 <= adc_dc_blocked;
                lo_cos_r0 <= dds_data[15:0];
                lo_sin_r0 <= dds_data[31:16];
            end
            if (mixer_input_valid_r0) begin
                adc_sample_r1 <= adc_sample_r0;
                lo_cos_r1 <= lo_cos_r0;
                lo_sin_r1 <= lo_sin_r0;
            end
            if (mixer_product_valid) begin
                mixer_i_product_r <= mixer_i_product;
                mixer_q_product_r <= mixer_q_product;
            end
        end
    end

    dpll_input_multiplier input_multiplier_i_inst (
        .CLK(clk_125m),
        .A(adc_sample_r1),
        .B(lo_cos_r1),
        .P(mixer_i_product)
    );

    dpll_input_multiplier input_multiplier_q_inst (
        .CLK(clk_125m),
        .A(adc_sample_r1),
        // LO_DDS_H is configured with Negative_Sine=true; use the IP output directly.
        .B(lo_sin_r1),
        .P(mixer_q_product)
    );
    
    
    

//    function signed [15:0] round_product32_to_s16;
//        input signed [31:0] value;
//        reg signed [32:0] magnitude_ext;
//        reg signed [32:0] rounded_ext;
//        begin
//            if (value[31]) begin
//                magnitude_ext = -{value[31], value};
//                rounded_ext = -((magnitude_ext + 33'sd16384) >>> 15);
//            end else begin
//                rounded_ext = ({value[31], value} + 33'sd16384) >>> 15;
//            end
//            if (rounded_ext > 33'sd32767) begin
//                round_product32_to_s16 = 16'sh7fff;
//            end else if (rounded_ext < -33'sd32768) begin
//                round_product32_to_s16 = 16'sh8000;
//            end else begin
//                round_product32_to_s16 = rounded_ext[15:0];
//            end
//        end
//    endfunction

//    assign mixer_i_rounded = round_product32_to_s16(mixer_i_product_r);
//    assign mixer_q_rounded = round_product32_to_s16(mixer_q_product_r);
//    assign mixer_i = {{(MIXER_WIDTH-16){mixer_i_rounded[15]}}, mixer_i_rounded};
//    assign mixer_q = {{(MIXER_WIDTH-16){mixer_q_rounded[15]}}, mixer_q_rounded};

    wire signed [17:0] mixer_i_trunc18 = mixer_i_product_r[30:13];
    wire signed [17:0] mixer_q_trunc18 = mixer_q_product_r[30:13];
    
    wire mixer_i_pos_overflow_18 = (mixer_i_product_r[31:13] == 19'h2_0000);
    wire mixer_q_pos_overflow_18 = (mixer_q_product_r[31:13] == 19'h2_0000);
    
    assign mixer_i = mixer_i_pos_overflow_18 ? 18'sh1ffff : mixer_i_trunc18;
    assign mixer_q = mixer_q_pos_overflow_18 ? 18'sh1ffff : mixer_q_trunc18;
    assign mixer_valid = mixer_round_valid_r;

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            mixer_cic_valid_r <= 1'b0;
            mixer_i_cic_r <= {MIXER_WIDTH{1'b0}};
            mixer_q_cic_r <= {MIXER_WIDTH{1'b0}};
        end else begin
            mixer_cic_valid_r <= mixer_valid;
            if (mixer_valid) begin
                mixer_i_cic_r <= mixer_i;
                mixer_q_cic_r <= mixer_q;
            end
        end
    end

    post_iq_cic_stage_a #(
        .INPUT_WIDTH(MIXER_WIDTH),
        .ACC_WIDTH(44),
        .OUTPUT_WIDTH(CIC_WIDTH),
        .RATE_WIDTH(9),
        .SHIFT_WIDTH(6)
    ) post_iq_cic_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_cic_r),
        .in_valid(mixer_cic_valid_r),
        .i_in(mixer_i_cic_r),
        .q_in(mixer_q_cic_r),
        .config_apply(config_apply),
        .status_clear(status_clear),
        .shadow_rate_r(cic_rate_r),
        .shadow_output_shift(cic_output_shift),
        .flush(cic_flush),
        .out_valid(cic_iq_valid),
        .i_out(cic_i_baseband),
        .q_out(cic_q_baseband),
        .active_rate_r(active_cic_rate_r),
        .active_output_shift(active_cic_output_shift),
        .overflow_seen(cic_overflow_seen),
        .illegal_config_seen(cic_illegal_config_seen)
    );

    post_iir_stage_a #(
        .DATA_WIDTH(CIC_WIDTH),
        .COEFF_WIDTH(32),
        .COEFF_FRAC(30),
        .ACC_WIDTH(64)
    ) post_iir_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_detector_r),
        .clear(detector_reconfigure),
        .in_valid(cic_iq_valid),
        .i_in(cic_i_baseband),
        .q_in(cic_q_baseband),
        .mode(post_iir_mode),
        .state_use_track(post_iir_state_use_track),
        .acq_b0(post_iir_acq_b0),
        .acq_b1(post_iir_acq_b1),
        .acq_b2(post_iir_acq_b2),
        .acq_a1(post_iir_acq_a1),
        .acq_a2(post_iir_acq_a2),
        .track_b0(post_iir_track_b0),
        .track_b1(post_iir_track_b1),
        .track_b2(post_iir_track_b2),
        .track_a1(post_iir_track_a1),
        .track_a2(post_iir_track_a2),
        .out_valid(iq_valid),
        .i_out(i_baseband),
        .q_out(q_baseband),
        .active_bypass(post_iir_active_bypass),
        .active_use_track(post_iir_active_use_track)
    );

    cordic_word_serial_adapter #(
        .IQ_WIDTH(CIC_WIDTH),
        .PHASE_WIDTH(PHASE_WIDTH),
        .MAG_WIDTH(MAG_WIDTH)
    ) phase_cordic_adapter_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_detector_r),
        .clear(detector_reconfigure),
        .status_clear(cordic_status_clear),
        .in_valid(iq_valid),
        .i_in(i_baseband),
        .q_in(q_baseband),
        .out_valid(cordic_valid),
        .phase_out(cordic_phase_word),
        .magnitude_out(cordic_magnitude),
        .busy(cordic_busy),
        .input_overrun_seen(cordic_input_overrun_seen),
        .input_out_of_range_seen(cordic_input_out_of_range_seen),
        .output_format_error_seen(cordic_output_format_error_seen)
    );

    assign phase_error_next = cordic_phase_word - phase_setpoint;
    assign phase_abs = phase_error_hold[PHASE_WIDTH-1] ?
                       (~phase_error_hold + {{(PHASE_WIDTH-1){1'b0}}, 1'b1}) :
                       phase_error_hold;
    assign freq_abs = freq_error[FERR_WIDTH-1] ?
                      (~freq_error + {{(FERR_WIDTH-1){1'b0}}, 1'b1}) :
                      freq_error;
    // Keep the FLL/PI path active for weak inputs.  Magnitude remains a
    // diagnostic signal, but must not gate phase/frequency acquisition.
    assign cordic_signal_usable = 1'b1;
    assign fll_iq_valid = iq_valid;
    assign freq_error_usable = freq_error_valid && !fll_ambiguous;
    assign freq_error_block_usable = freq_error_block_valid && !fll_ambiguous;

    always @(posedge clk_125m) begin
        if (rst_measure_r) begin
            phase_error_hold <= {PHASE_WIDTH{1'b0}};
            cordic_magnitude_hold <= {MAG_WIDTH{1'b0}};
            freq_error_block_valid_d <= 1'b0;
            state_measurement_valid_r <= 1'b0;
            state_phase_abs_r <= {PHASE_WIDTH{1'b0}};
            state_freq_abs_r <= {FERR_WIDTH{1'b0}};
            state_magnitude_r <= {MAG_WIDTH{1'b0}};
            signal_present_r <= 1'b0;
        end else begin
            freq_error_block_valid_d <= freq_error_block_usable;
            state_measurement_valid_r <= freq_error_block_valid_d;

            if (cordic_valid) begin
                phase_error_hold <= phase_error_next;
                cordic_magnitude_hold <= cordic_magnitude;
                if (signal_present_r) begin
                    if ((mag_exit_threshold != {MAG_WIDTH{1'b0}}) &&
                        (cordic_magnitude < mag_exit_threshold)) begin
                        signal_present_r <= 1'b0;
                    end
                end else if ((mag_enter_threshold == {MAG_WIDTH{1'b0}}) ||
                             (cordic_magnitude >= mag_enter_threshold)) begin
                    signal_present_r <= 1'b1;
                end
            end

            if (freq_error_block_valid_d) begin
                state_phase_abs_r <= phase_abs;
                state_freq_abs_r <= freq_abs;
                state_magnitude_r <= cordic_magnitude_hold;
            end
        end
    end

    assign cordic_phase_out = cordic_phase_word;
    assign phase_error = phase_error_hold;

    loop_state_manager_stage_a #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .FERR_WIDTH(FERR_WIDTH),
        .MAG_WIDTH(MAG_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .DWELL_WIDTH(16),
        .TIMEOUT_WIDTH(24)
    ) loop_state_manager_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_state_r),
        .loop_enable(loop_enable),
        .config_apply(config_apply),
        .magnitude_valid(cordic_valid),
        .phase_valid(cordic_valid),
        .frequency_valid(state_measurement_valid_r),
        .signal_present_in(signal_present_r),
        .measurement_valid(state_measurement_valid_r),
        .measurement_timeout(measurement_timeout),
        .phase_abs(state_phase_abs_r),
        .freq_abs(state_freq_abs_r),
        .magnitude(state_magnitude_r),
        .cic_fault(cic_illegal_config_seen),
        .correction_saturated(saturated_high | saturated_low),
        .phase_lock_threshold(phase_lock_threshold),
        .freq_lock_threshold(freq_lock_threshold),
        .mag_enter_threshold(mag_enter_threshold),
        .mag_exit_threshold(mag_exit_threshold),
        .acquire_dwell(acquire_dwell),
        .blend_dwell(blend_dwell),
        .loss_dwell(loss_dwell),
        .holdover_timeout(holdover_timeout),
        .warmup_samples(warmup_samples),
        .kf_acquire(kf),
        .kf_blend(kf_blend),
        .kf_track(kf_track),
        .kp_blend(kp_blend),
        .ki_blend(ki_blend),
        .kp_track(kp),
        .ki_track(ki),
        .enable_fll(loop_enable_fll),
        .enable_pll_i(loop_enable_pll_i),
        .enable_pll_p(loop_enable_pll_p),
        .active_kf(active_kf),
        .active_ki(active_ki),
        .active_kp(active_kp),
        .track_iir_preheat(track_iir_preheat),
        .loop_state(loop_state),
        .loss_reason(loss_reason),
        .signal_present(signal_present),
        .phase_locked(phase_locked),
        .frequency_locked(frequency_locked),
        .locked(locked)
    );

    fll_cross_dot_stage_a #(
        .IQ_WIDTH(CIC_WIDTH),
        .FERR_WIDTH(FERR_WIDTH),
        .BLOCK_SAMPLES(16)
    ) fll_cross_dot_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_detector_r),
        // Magnitude is diagnostic only; do not clear the FLL accumulator for
        // weak inputs that have not crossed the display/diagnostic threshold.
        .clear(detector_reconfigure),
        .sample_valid(fll_iq_valid),
        .i_in(i_baseband),
        .q_in(q_baseband),
        .delay_sel(fll_delay_sel),
        .rate_r(cic_rate_r),
        .freq_error_valid(freq_error_valid),
        .freq_error_block_valid(freq_error_block_valid),
        .freq_error(freq_error),
        .ambiguous(fll_ambiguous)
    );

    always @(posedge clk_125m) begin
        if (rst_hybrid_r) begin
            active_enable_fll_r <= 1'b0;
            active_enable_pll_i_r <= 1'b0;
            active_enable_pll_p_r <= 1'b0;
            active_kf_r <= {COEFF_WIDTH{1'b0}};
            active_ki_r <= {COEFF_WIDTH{1'b0}};
            active_kp_r <= {COEFF_WIDTH{1'b0}};
            hybrid_error_valid_r <= 1'b0;
            hybrid_enable_fll_r <= 1'b0;
            hybrid_enable_pll_i_r <= 1'b0;
            hybrid_enable_pll_p_r <= 1'b0;
            hybrid_phase_error_r <= {PHASE_WIDTH{1'b0}};
            hybrid_freq_error_r <= {FERR_WIDTH{1'b0}};
            hybrid_kf_r <= {COEFF_WIDTH{1'b0}};
            hybrid_ki_r <= {COEFF_WIDTH{1'b0}};
            hybrid_kp_r <= {COEFF_WIDTH{1'b0}};
        end else begin
            active_enable_fll_r <= loop_enable_fll;
            active_enable_pll_i_r <= loop_enable_pll_i;
            active_enable_pll_p_r <= loop_enable_pll_p;
            active_kf_r <= active_kf;
            active_ki_r <= active_ki;
            active_kp_r <= active_kp;
            hybrid_error_valid_r <= freq_error_usable;
            if (freq_error_usable) begin
                hybrid_enable_fll_r <= active_enable_fll_r;
                hybrid_enable_pll_i_r <= active_enable_pll_i_r;
                hybrid_enable_pll_p_r <= active_enable_pll_p_r;
                hybrid_phase_error_r <= phase_error_hold;
                hybrid_freq_error_r <= freq_error;
                hybrid_kf_r <= active_kf_r;
                hybrid_ki_r <= active_ki_r;
                hybrid_kp_r <= active_kp_r;
            end
        end
    end

    hybrid_fll_pll_filter_stage_a #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .FERR_WIDTH(FERR_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .STATE_WIDTH(STATE_WIDTH),
        .WORD_WIDTH(WORD_WIDTH),
        .FLL_PRODUCT_SHIFT(16),
        .P_PRODUCT_SHIFT(12),
        .PRODUCT_SHIFT(18)
    ) hybrid_loop_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_hybrid_r),
        .clear(config_apply),
        .error_valid(hybrid_error_valid_r),
        .enable_fll(hybrid_enable_fll_r),
        .enable_pll_i(hybrid_enable_pll_i_r),
        .enable_pll_p(hybrid_enable_pll_p_r),
        .phase_error(hybrid_phase_error_r),
        .freq_error(hybrid_freq_error_r),
        .kf(hybrid_kf_r),
        .ki(hybrid_ki_r),
        .kp(hybrid_kp_r),
        .center_word(center_word),
        .positive_limit(positive_limit),
        .negative_limit(negative_limit),
        .correction_valid(correction_valid),
        .freq_state(freq_state),
        .freq_correction(freq_correction),
        .tracking_word(correction_tracking_word),
        .saturated_high(saturated_high),
        .saturated_low(saturated_low)
    );

endmodule

`default_nettype wire
