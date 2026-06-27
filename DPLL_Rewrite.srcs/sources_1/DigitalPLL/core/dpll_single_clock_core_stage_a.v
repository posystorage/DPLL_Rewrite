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
    output wire [8:0]                            active_cic_rate_r,
    output wire [5:0]                            active_cic_output_shift,
    output wire                                  cic_overflow_seen,
    output wire                                  cic_illegal_config_seen,
    output wire signed [15:0]                    lo_cos,
    output wire signed [15:0]                    lo_sin
);

    localparam signed [15:0] LO_ONE = 16'sd16384;

    reg [WORD_WIDTH-1:0] tracking_word_hold;
    wire [WORD_WIDTH-1:0] nco_word;
    wire [WORD_WIDTH-1:0] phase_accum;
    wire [PHASE_WIDTH-1:0] phase_word;
    wire phase_valid;

    reg signed [ADC_WIDTH-1:0] adc_sample_r;
    reg signed [15:0] lo_cos_r;
    reg signed [15:0] lo_sin_r;
    reg mixer_input_valid_r;
    wire signed [15:0] lo_cos_next;
    wire signed [15:0] lo_sin_next;
    wire mixer_valid;
    wire signed [MIXER_WIDTH-1:0] mixer_i;
    wire signed [MIXER_WIDTH-1:0] mixer_q;
    wire signed [PHASE_WIDTH-1:0] phase_error_next;
    wire correction_valid;
    wire [WORD_WIDTH-1:0] correction_tracking_word;

    assign nco_word = tracking_word_hold;
    assign tracking_word = tracking_word_hold;
    assign tracking_valid = correction_valid;

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            tracking_word_hold <= {WORD_WIDTH{1'b0}};
        end else if (!loop_enable) begin
            tracking_word_hold <= center_word;
        end else if (correction_valid) begin
            tracking_word_hold <= correction_tracking_word;
        end else if (tracking_word_hold == {WORD_WIDTH{1'b0}}) begin
            tracking_word_hold <= center_word;
        end
    end

    tracking_phase_accumulator_stage_a #(
        .WORD_WIDTH(WORD_WIDTH),
        .PHASE_WIDTH(PHASE_WIDTH)
    ) tracking_phase_accumulator_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .enable(sample_valid),
        .tracking_word(nco_word),
        .phase_accum(phase_accum),
        .phase_word(phase_word),
        .phase_valid(phase_valid)
    );

    assign lo_cos_next = (phase_word[PHASE_WIDTH-1:PHASE_WIDTH-2] == 2'b00) ?  LO_ONE :
                         (phase_word[PHASE_WIDTH-1:PHASE_WIDTH-2] == 2'b10) ? -LO_ONE : 16'sd0;
    assign lo_sin_next = (phase_word[PHASE_WIDTH-1:PHASE_WIDTH-2] == 2'b01) ?  LO_ONE :
                         (phase_word[PHASE_WIDTH-1:PHASE_WIDTH-2] == 2'b11) ? -LO_ONE : 16'sd0;
    assign lo_cos = lo_cos_r;
    assign lo_sin = lo_sin_r;

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            adc_sample_r <= {ADC_WIDTH{1'b0}};
            lo_cos_r <= 16'sd0;
            lo_sin_r <= 16'sd0;
            mixer_input_valid_r <= 1'b0;
        end else begin
            mixer_input_valid_r <= phase_valid;
            if (sample_valid) begin
                adc_sample_r <= adc_sample;
            end
            if (phase_valid) begin
                lo_cos_r <= lo_cos_next;
                lo_sin_r <= lo_sin_next;
            end
        end
    end

    iq_mixer_stage_a #(
        .SAMPLE_WIDTH(ADC_WIDTH),
        .LO_WIDTH(16),
        .OUTPUT_WIDTH(MIXER_WIDTH),
        .LO_FRAC_BITS(14)
    ) iq_mixer_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .in_valid(mixer_input_valid_r),
        .sample_in(adc_sample_r),
        .cos_in(lo_cos_r),
        .sin_in(lo_sin_r),
        .out_valid(mixer_valid),
        .i_out(mixer_i),
        .q_out(mixer_q)
    );

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

    assign phase_error_next = q_baseband[CIC_WIDTH-1 -: PHASE_WIDTH];
    assign phase_error = phase_error_next;

    fll_phase_difference_stage_a #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .FERR_WIDTH(FERR_WIDTH)
    ) fll_phase_difference_inst (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .phase_valid(iq_valid),
        .phase_in(phase_error_next),
        .delay_sel(fll_delay_sel),
        .freq_error_valid(freq_error_valid),
        .freq_error(freq_error),
        .ambiguous()
    );

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
        .error_valid(freq_error_valid),
        .enable_fll(loop_enable),
        .enable_pll_i(loop_enable),
        .enable_pll_p(loop_enable),
        .phase_error(phase_error_next),
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
        .tracking_word(correction_tracking_word),
        .saturated_high(),
        .saturated_low()
    );

endmodule

`default_nettype wire
