`timescale 1ns / 1ps
`default_nettype none

module dpll_single_clock_core_stage_a #(
    parameter integer ADC_WIDTH = 16,
    parameter integer WORD_WIDTH = 48,
    parameter integer PHASE_WIDTH = 18,
    parameter integer MIXER_WIDTH = 18,
    parameter integer CIC_WIDTH = 20,
    parameter integer FERR_WIDTH = 22,
    parameter integer COEFF_WIDTH = 24,
    parameter integer STATE_WIDTH = 56
) (
    input  wire                                  clk_125m,
    input  wire                                  rst_125m,
    input  wire                                  sample_valid,
    input  wire                                  loop_enable,
    input  wire signed [ADC_WIDTH-1:0]           adc_sample,
    input  wire [WORD_WIDTH-1:0]                 center_word,
    input  wire                                  config_apply,
    input  wire [8:0]                            cic_rate_r,
    input  wire [5:0]                            cic_output_shift,
    input  wire                                  cic_flush,
    input  wire [1:0]                            fll_delay_sel,
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
    input  wire [15:0]                           mag_enter_threshold,
    input  wire [15:0]                           mag_exit_threshold,
    input  wire [15:0]                           acquire_dwell,
    input  wire [15:0]                           blend_dwell,
    input  wire [15:0]                           loss_dwell,
    input  wire [23:0]                           holdover_timeout,
    input  wire [15:0]                           warmup_samples,
    input  wire signed [STATE_WIDTH-1:0]         positive_limit,
    input  wire signed [STATE_WIDTH-1:0]         negative_limit,
    output wire [WORD_WIDTH-1:0]                 tracking_word,
    output wire                                  tracking_valid,
    output wire signed [PHASE_WIDTH-1:0]         phase_error,
    output wire signed [FERR_WIDTH-1:0]          freq_error,
    output wire                                  freq_error_valid,
    output wire signed [CIC_WIDTH-1:0]           i_baseband,
    output wire signed [CIC_WIDTH-1:0]           q_baseband,
    output wire                                  iq_valid,
    output wire signed [STATE_WIDTH-1:0]         freq_state,
    output wire signed [STATE_WIDTH-1:0]         freq_correction,
    output wire [15:0]                           magnitude,
    output wire [3:0]                            loop_state,
    output wire [3:0]                            loss_reason,
    output wire                                  signal_present,
    output wire                                  phase_locked,
    output wire                                  frequency_locked,
    output wire                                  locked,
    output wire [8:0]                            active_cic_rate_r,
    output wire [5:0]                            active_cic_output_shift,
    output wire                                  cic_overflow_seen,
    output wire                                  cic_illegal_config_seen,
    output wire signed [15:0]                    lo_cos,
    output wire signed [15:0]                    lo_sin
);

    reg [WORD_WIDTH-1:0] tracking_word_hold;
    reg nco_word_ready;
    wire [WORD_WIDTH-1:0] nco_word;
    wire [WORD_WIDTH-1:0] phase_accum;
    wire [PHASE_WIDTH-1:0] phase_word;
    wire phase_tick;
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
    wire signed [15:0] mixer_i_rounded;
    wire signed [15:0] mixer_q_rounded;
    wire mixer_valid;
    wire signed [MIXER_WIDTH-1:0] mixer_i;
    wire signed [MIXER_WIDTH-1:0] mixer_q;
    wire cordic_valid;
    wire [31:0] cordic_data;
    wire signed [15:0] cordic_phase;
    wire [15:0] cordic_magnitude;
    wire signed [PHASE_WIDTH-1:0] cordic_phase_word;
    wire signed [PHASE_WIDTH-1:0] phase_error_next;
    wire [PHASE_WIDTH-1:0] phase_abs;
    wire [FERR_WIDTH-1:0] freq_abs;
    reg signed [PHASE_WIDTH-1:0] phase_error_hold;
    reg [15:0] cordic_magnitude_hold;
    reg freq_error_valid_d;
    reg state_measurement_valid_r;
    reg [PHASE_WIDTH-1:0] state_phase_abs_r;
    reg [FERR_WIDTH-1:0] state_freq_abs_r;
    reg [15:0] state_magnitude_r;
    wire correction_valid;
    wire [WORD_WIDTH-1:0] correction_tracking_word;
    wire loop_enable_fll;
    wire loop_enable_pll_i;
    wire loop_enable_pll_p;
    wire signed [COEFF_WIDTH-1:0] active_kf;
    wire signed [COEFF_WIDTH-1:0] active_ki;
    wire signed [COEFF_WIDTH-1:0] active_kp;
    reg hybrid_error_valid_r;
    reg hybrid_enable_fll_r;
    reg hybrid_enable_pll_i_r;
    reg hybrid_enable_pll_p_r;
    reg signed [PHASE_WIDTH-1:0] hybrid_phase_error_r;
    reg signed [FERR_WIDTH-1:0] hybrid_freq_error_r;
    reg signed [COEFF_WIDTH-1:0] hybrid_kf_r;
    reg signed [COEFF_WIDTH-1:0] hybrid_ki_r;
    reg signed [COEFF_WIDTH-1:0] hybrid_kp_r;
    wire saturated_high;
    wire saturated_low;

    assign nco_word = tracking_word_hold;
    assign tracking_word = tracking_word_hold;
    assign tracking_valid = correction_valid;
    assign magnitude = cordic_magnitude_hold;

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            tracking_word_hold <= {WORD_WIDTH{1'b0}};
            nco_word_ready <= 1'b0;
        end else if (!loop_enable) begin
            tracking_word_hold <= center_word;
            nco_word_ready <= |center_word;
        end else if (correction_valid) begin
            tracking_word_hold <= correction_tracking_word;
            nco_word_ready <= |correction_tracking_word;
        end else if (tracking_word_hold == {WORD_WIDTH{1'b0}}) begin
            tracking_word_hold <= center_word;
            nco_word_ready <= |center_word;
        end
    end

    tracking_phase_accumulator_stage_a #(
        .WORD_WIDTH(WORD_WIDTH),
        .PHASE_WIDTH(PHASE_WIDTH)
    ) tracking_phase_accumulator_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .enable(1'b1),
        .tracking_word(nco_word),
        .phase_accum(phase_accum),
        .phase_word(phase_word),
        .phase_valid(phase_tick)
    );

    LO_DDS_H tracking_lo_dds_inst (
        .aclk(clk_125m),
        .s_axis_phase_tvalid(nco_word_ready),
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
        .LEAK_SHIFT(7)
    ) dc_blocker_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .in_valid(sample_valid),
        .sample_in(adc_sample),
        .out_valid(dc_valid),
        .sample_out(adc_dc_blocked)
    );

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            adc_sample_r0 <= {ADC_WIDTH{1'b0}};
            adc_sample_r1 <= {ADC_WIDTH{1'b0}};
            lo_cos_r0 <= 16'sd0;
            lo_sin_r0 <= 16'sd0;
            lo_cos_r1 <= 16'sd0;
            lo_sin_r1 <= 16'sd0;
            mixer_input_valid_r0 <= 1'b0;
            mixer_input_valid_r1 <= 1'b0;
            mixer_product_valid <= 1'b0;
        end else begin
            mixer_input_valid_r0 <= dc_valid;
            mixer_input_valid_r1 <= mixer_input_valid_r0;
            mixer_product_valid <= mixer_input_valid_r1;
            if (dc_valid) begin
                adc_sample_r0 <= adc_dc_blocked;
                lo_cos_r0 <= dds_data[15:0];
                lo_sin_r0 <= dds_data[31:16];
            end
            if (mixer_input_valid_r0) begin
                adc_sample_r1 <= adc_sample_r0;
                lo_cos_r1 <= lo_cos_r0;
                lo_sin_r1 <= lo_sin_r0;
            end
        end
    end

    input_multiplier input_multiplier_i_inst (
        .CLK(clk_125m),
        .A(adc_sample_r1),
        .B(lo_cos_r1),
        .P(mixer_i_product)
    );

    input_multiplier input_multiplier_q_inst (
        .CLK(clk_125m),
        .A(adc_sample_r1),
        // LO_DDS_H is configured with Negative_Sine=true; use the IP output directly.
        .B(lo_sin_r1),
        .P(mixer_q_product)
    );

    assign mixer_i_rounded = (mixer_i_product + 32'sd16384) >>> 15;
    assign mixer_q_rounded = (mixer_q_product + 32'sd16384) >>> 15;
    assign mixer_i = {{(MIXER_WIDTH-16){mixer_i_rounded[15]}}, mixer_i_rounded};
    assign mixer_q = {{(MIXER_WIDTH-16){mixer_q_rounded[15]}}, mixer_q_rounded};
    assign mixer_valid = mixer_product_valid;

    post_iq_cic_stage_a #(
        .INPUT_WIDTH(MIXER_WIDTH),
        .ACC_WIDTH(44),
        .OUTPUT_WIDTH(CIC_WIDTH),
        .RATE_WIDTH(9),
        .SHIFT_WIDTH(6)
    ) post_iq_cic_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .in_valid(mixer_valid),
        .i_in(mixer_i),
        .q_in(mixer_q),
        .config_apply(config_apply),
        .shadow_rate_r(cic_rate_r),
        .shadow_output_shift(cic_output_shift),
        .flush(cic_flush),
        .out_valid(iq_valid),
        .i_out(i_baseband),
        .q_out(q_baseband),
        .active_rate_r(active_cic_rate_r),
        .active_output_shift(active_cic_output_shift),
        .overflow_seen(cic_overflow_seen),
        .illegal_config_seen(cic_illegal_config_seen)
    );

    angle_CORDIC phase_cordic_inst (
        .aclk(clk_125m),
        .s_axis_cartesian_tvalid(iq_valid),
        .s_axis_cartesian_tdata({q_baseband[CIC_WIDTH-1 -: 16], i_baseband[CIC_WIDTH-1 -: 16]}),
        .m_axis_dout_tvalid(cordic_valid),
        .m_axis_dout_tdata(cordic_data)
    );

    assign cordic_phase = cordic_data[31:16];
    assign cordic_magnitude = cordic_data[15:0];
    assign cordic_phase_word = {cordic_phase, 2'b00};
    assign phase_error_next = cordic_phase_word - phase_setpoint;
    assign phase_abs = phase_error_hold[PHASE_WIDTH-1] ?
                       (~phase_error_hold + {{(PHASE_WIDTH-1){1'b0}}, 1'b1}) :
                       phase_error_hold;
    assign freq_abs = freq_error[FERR_WIDTH-1] ?
                      (~freq_error + {{(FERR_WIDTH-1){1'b0}}, 1'b1}) :
                      freq_error;

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            phase_error_hold <= {PHASE_WIDTH{1'b0}};
            cordic_magnitude_hold <= 16'd0;
            freq_error_valid_d <= 1'b0;
            state_measurement_valid_r <= 1'b0;
            state_phase_abs_r <= {PHASE_WIDTH{1'b0}};
            state_freq_abs_r <= {FERR_WIDTH{1'b0}};
            state_magnitude_r <= 16'd0;
        end else begin
            freq_error_valid_d <= freq_error_valid;
            state_measurement_valid_r <= freq_error_valid_d;

            if (cordic_valid) begin
                phase_error_hold <= phase_error_next;
                cordic_magnitude_hold <= cordic_magnitude;
            end

            if (freq_error_valid_d) begin
                state_phase_abs_r <= phase_abs;
                state_freq_abs_r <= freq_abs;
                state_magnitude_r <= cordic_magnitude_hold;
            end
        end
    end

    assign phase_error = phase_error_hold;

    loop_state_manager_stage_a #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .FERR_WIDTH(FERR_WIDTH),
        .MAG_WIDTH(16),
        .COEFF_WIDTH(COEFF_WIDTH),
        .DWELL_WIDTH(16),
        .TIMEOUT_WIDTH(24)
    ) loop_state_manager_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .loop_enable(loop_enable),
        .config_apply(config_apply),
        .measurement_valid(state_measurement_valid_r),
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
        .loop_state(loop_state),
        .loss_reason(loss_reason),
        .signal_present(signal_present),
        .phase_locked(phase_locked),
        .frequency_locked(frequency_locked),
        .locked(locked)
    );

    fll_phase_difference_stage_a #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .FERR_WIDTH(FERR_WIDTH)
    ) fll_phase_difference_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .phase_valid(cordic_valid),
        .phase_in(phase_error_next),
        .delay_sel(fll_delay_sel),
        .freq_error_valid(freq_error_valid),
        .freq_error(freq_error),
        .ambiguous()
    );

    always @(posedge clk_125m) begin
        if (rst_125m) begin
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
            hybrid_error_valid_r <= freq_error_valid;
            if (freq_error_valid) begin
                hybrid_enable_fll_r <= loop_enable_fll;
                hybrid_enable_pll_i_r <= loop_enable_pll_i;
                hybrid_enable_pll_p_r <= loop_enable_pll_p;
                hybrid_phase_error_r <= phase_error_hold;
                hybrid_freq_error_r <= freq_error;
                hybrid_kf_r <= active_kf;
                hybrid_ki_r <= active_ki;
                hybrid_kp_r <= active_kp;
            end
        end
    end

    hybrid_fll_pll_filter_stage_a #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .FERR_WIDTH(FERR_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .STATE_WIDTH(STATE_WIDTH),
        .WORD_WIDTH(WORD_WIDTH),
        .PRODUCT_SHIFT(18)
    ) hybrid_loop_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
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
