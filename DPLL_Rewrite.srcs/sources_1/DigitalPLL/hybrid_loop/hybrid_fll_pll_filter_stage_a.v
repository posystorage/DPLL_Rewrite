`timescale 1ns / 1ps
`default_nettype none

module hybrid_fll_pll_filter_stage_a #(
    parameter integer PHASE_WIDTH = 18,
    parameter integer FERR_WIDTH = 22,
    parameter integer COEFF_WIDTH = 24,
    parameter integer STATE_WIDTH = 56,
    parameter integer WORD_WIDTH = 48,
    parameter integer FLL_PRODUCT_SHIFT = 16,
    parameter integer P_PRODUCT_SHIFT = 12,
    parameter integer PRODUCT_SHIFT = 18
) (
    input  wire                                  clk_125m,
    input  wire                                  rst_125m,
    input  wire                                  clear,
    input  wire                                  error_valid,
    input  wire                                  enable_fll,
    input  wire                                  enable_pll_i,
    input  wire                                  enable_pll_p,
    input  wire signed [PHASE_WIDTH-1:0]         phase_error,
    input  wire signed [FERR_WIDTH-1:0]          freq_error,
    input  wire signed [COEFF_WIDTH-1:0]         kf,
    input  wire signed [COEFF_WIDTH-1:0]         ki,
    input  wire signed [COEFF_WIDTH-1:0]         kp,
    input  wire [WORD_WIDTH-1:0]                 center_word,
    input  wire signed [STATE_WIDTH-1:0]         positive_limit,
    input  wire signed [STATE_WIDTH-1:0]         negative_limit,
    output reg                                   correction_valid,
    output reg signed [STATE_WIDTH-1:0]          freq_state,
    output reg signed [STATE_WIDTH-1:0]          freq_correction,
    output reg [WORD_WIDTH-1:0]                  tracking_word,
    output reg                                   saturated_high,
    output reg                                   saturated_low
);

    localparam integer F_PRODUCT_WIDTH = FERR_WIDTH + COEFF_WIDTH;
    localparam integer P_PRODUCT_WIDTH = PHASE_WIDTH + COEFF_WIDTH;
    localparam integer FLL_DSP_B_WIDTH = 18;
    localparam integer FLL_COEFF_SPLIT = 17;
    localparam integer FLL_PART_WIDTH = FERR_WIDTH + FLL_DSP_B_WIDTH;

    reg signed [F_PRODUCT_WIDTH-1:0] fll_product_r;
    reg signed [P_PRODUCT_WIDTH-1:0] i_product_r;
    reg signed [P_PRODUCT_WIDTH-1:0] p_product_r;
    (* use_dsp = "yes" *) reg signed [FLL_PART_WIDTH-1:0] fll_product_lo_r;
    (* use_dsp = "yes" *) reg signed [FLL_PART_WIDTH-1:0] fll_product_hi_r;
    (* use_dsp = "yes" *) reg signed [P_PRODUCT_WIDTH-1:0] i_product_partial_r;
    (* use_dsp = "yes" *) reg signed [P_PRODUCT_WIDTH-1:0] p_product_partial_r;
    reg signed [PHASE_WIDTH-1:0] phase_error_mul_r;
    reg signed [FERR_WIDTH-1:0] freq_error_mul_r;
    reg signed [COEFF_WIDTH-1:0] kf_mul_r;
    reg signed [COEFF_WIDTH-1:0] ki_mul_r;
    reg signed [COEFF_WIDTH-1:0] kp_mul_r;
    reg enable_fll_mul_r;
    reg enable_pll_i_mul_r;
    reg enable_pll_p_mul_r;
    reg product_valid_r;
    reg signed [PHASE_WIDTH-1:0] phase_error_product_r;
    reg signed [FERR_WIDTH-1:0] freq_error_product_r;
    reg signed [COEFF_WIDTH-1:0] kf_product_r;
    reg signed [COEFF_WIDTH-1:0] ki_product_r;
    reg signed [COEFF_WIDTH-1:0] kp_product_r;
    reg enable_fll_operand_r;
    reg enable_pll_i_operand_r;
    reg enable_pll_p_operand_r;
    reg product_operand_valid_r;
    reg product_partial_valid_r;
    reg enable_fll_partial_r;
    reg enable_pll_i_partial_r;
    reg enable_pll_p_partial_r;
    reg enable_fll_product_r;
    reg enable_pll_i_product_r;
    reg enable_pll_p_product_r;
    reg signed [STATE_WIDTH-1:0] fll_term_r;
    reg signed [STATE_WIDTH-1:0] i_term_r;
    reg signed [STATE_WIDTH-1:0] p_term_r;
    reg [WORD_WIDTH-1:0] center_word_r0;
    reg [WORD_WIDTH-1:0] center_word_r1;
    reg [WORD_WIDTH-1:0] center_word_operand_r;
    reg [WORD_WIDTH-1:0] center_word_partial_r;
    reg [WORD_WIDTH-1:0] center_word_product_r;
    reg signed [STATE_WIDTH-1:0] positive_limit_r0;
    reg signed [STATE_WIDTH-1:0] negative_limit_r0;
    reg signed [STATE_WIDTH-1:0] positive_limit_r1;
    reg signed [STATE_WIDTH-1:0] negative_limit_r1;
    reg signed [STATE_WIDTH-1:0] positive_limit_operand_r;
    reg signed [STATE_WIDTH-1:0] negative_limit_operand_r;
    reg signed [STATE_WIDTH-1:0] positive_limit_partial_r;
    reg signed [STATE_WIDTH-1:0] negative_limit_partial_r;
    reg signed [STATE_WIDTH-1:0] positive_limit_product_r;
    reg signed [STATE_WIDTH-1:0] negative_limit_product_r;
    reg [6:0] valid_pipe;
    reg signed [STATE_WIDTH-1:0] state_sum_stage_current_r;
    reg signed [STATE_WIDTH-1:0] state_sum_stage_p_term_r;
    reg [WORD_WIDTH-1:0] state_sum_stage_center_word_r;
    reg signed [STATE_WIDTH-1:0] state_sum_stage_positive_limit_r;
    reg signed [STATE_WIDTH-1:0] state_sum_stage_negative_limit_r;
    reg signed [STATE_WIDTH:0] state_sum_stage_state_sum_ext_r;
    reg state_sum_stage_allow_update_r;
    reg signed [STATE_WIDTH-1:0] state_stage_state_r;
    reg signed [STATE_WIDTH-1:0] state_stage_p_term_r;
    reg [WORD_WIDTH-1:0] state_stage_center_word_r;
    reg signed [STATE_WIDTH-1:0] state_stage_positive_limit_r;
    reg signed [STATE_WIDTH-1:0] state_stage_negative_limit_r;
    reg signed [STATE_WIDTH:0] state_stage_state_sum_ext_r;
    reg state_stage_allow_update_r;
    reg signed [STATE_WIDTH-1:0] correction_stage_state_r;
    reg signed [STATE_WIDTH-1:0] correction_stage_correction_r;
    reg [WORD_WIDTH-1:0] correction_stage_center_word_r;
    reg signed [STATE_WIDTH-1:0] correction_stage_positive_limit_r;
    reg signed [STATE_WIDTH-1:0] correction_stage_negative_limit_r;
    reg signed [STATE_WIDTH:0] correction_stage_state_sum_ext_r;
    reg signed [STATE_WIDTH:0] correction_stage_correction_sum_ext_r;
    reg correction_stage_allow_update_r;
    (* keep = "true", dont_touch = "true" *) reg rst_pipe_r;
    (* keep = "true", dont_touch = "true" *) reg rst_output_r;

    wire signed [F_PRODUCT_WIDTH-1:0] fll_product_next;
    wire signed [FLL_DSP_B_WIDTH-1:0] fll_coeff_low_next;
    wire signed [FLL_DSP_B_WIDTH-1:0] fll_coeff_high_next;
    wire signed [FLL_PART_WIDTH-1:0] fll_product_lo_next;
    wire signed [FLL_PART_WIDTH-1:0] fll_product_hi_next;
    wire signed [F_PRODUCT_WIDTH-1:0] fll_product_lo_ext;
    wire signed [F_PRODUCT_WIDTH-1:0] fll_product_hi_ext;
    wire signed [P_PRODUCT_WIDTH-1:0] i_product_next;
    wire signed [P_PRODUCT_WIDTH-1:0] p_product_next;
    wire signed [STATE_WIDTH-1:0] fll_term_next;
    wire signed [STATE_WIDTH-1:0] i_term_next;
    wire signed [STATE_WIDTH-1:0] p_term_next;
    wire signed [STATE_WIDTH-1:0] state_delta_next;
    wire signed [STATE_WIDTH-1:0] freq_state_after_update_next;
    wire signed [STATE_WIDTH-1:0] freq_correction_sat_next;
    wire signed [STATE_WIDTH:0] freq_state_after_update_ext_next;
    wire signed [STATE_WIDTH:0] freq_correction_sat_ext_next;
    wire signed [STATE_WIDTH:0] state_sum_ext_next;
    wire signed [STATE_WIDTH:0] correction_sum_ext_next;
    wire signed [STATE_WIDTH:0] center_ext_next;
    wire signed [STATE_WIDTH:0] tracking_sum_ext_next;
    wire signed [STATE_WIDTH:0] positive_limit_ext;
    wire signed [STATE_WIDTH:0] negative_limit_ext;
    wire signed [STATE_WIDTH:0] state_sum_stage_positive_limit_ext;
    wire signed [STATE_WIDTH:0] state_sum_stage_negative_limit_ext;
    wire signed [STATE_WIDTH:0] state_stage_positive_limit_ext;
    wire signed [STATE_WIDTH:0] state_stage_negative_limit_ext;
    wire signed [STATE_WIDTH:0] correction_stage_positive_limit_ext;
    wire signed [STATE_WIDTH:0] correction_stage_negative_limit_ext;
    wire signed [STATE_WIDTH:0] correction_stage_correction_ext;
    wire signed [STATE_WIDTH:0] zero_ext;
    wire signed [STATE_WIDTH:0] max_word_ext;
    wire signed [STATE_WIDTH-1:0] state_zero;
    wire push_high;
    wire push_low;
    wire allow_state_update;

    // DSP48E1 accepts one signed 25-bit and one signed 18-bit operand. Split
    // the 24-bit Kf into an unsigned 17-bit low limb and a signed 7-bit high
    // limb so both partial products can use registered DSP outputs.
    assign fll_coeff_low_next = $signed({1'b0, kf_product_r[FLL_COEFF_SPLIT-1:0]});
    assign fll_coeff_high_next =
        $signed({{(FLL_DSP_B_WIDTH-(COEFF_WIDTH-FLL_COEFF_SPLIT))
                   {kf_product_r[COEFF_WIDTH-1]}},
                 kf_product_r[COEFF_WIDTH-1:FLL_COEFF_SPLIT]});
    assign fll_product_lo_next = freq_error_product_r * fll_coeff_low_next;
    assign fll_product_hi_next = freq_error_product_r * fll_coeff_high_next;
    assign fll_product_lo_ext =
        {{(F_PRODUCT_WIDTH-FLL_PART_WIDTH){fll_product_lo_r[FLL_PART_WIDTH-1]}},
         fll_product_lo_r};
    assign fll_product_hi_ext =
        {{(F_PRODUCT_WIDTH-FLL_PART_WIDTH){fll_product_hi_r[FLL_PART_WIDTH-1]}},
         fll_product_hi_r};
    assign fll_product_next =
        fll_product_lo_ext + (fll_product_hi_ext <<< FLL_COEFF_SPLIT);
    assign i_product_next = phase_error_product_r * ki_product_r;
    assign p_product_next = phase_error_product_r * kp_product_r;

    // FLL error is only about 21.47 LSB/Hz. Give it an independent scale so
    // the signed 24-bit Kf range can provide useful capture bandwidth without
    // changing the phase PI coefficient contract.
    assign fll_term_next = enable_fll_product_r ? {{(STATE_WIDTH-(F_PRODUCT_WIDTH-FLL_PRODUCT_SHIFT)){fll_product_r[F_PRODUCT_WIDTH-1]}}, fll_product_r[F_PRODUCT_WIDTH-1:FLL_PRODUCT_SHIFT]} : {STATE_WIDTH{1'b0}};
    assign i_term_next = enable_pll_i_product_r ? {{(STATE_WIDTH-(P_PRODUCT_WIDTH-PRODUCT_SHIFT)){i_product_r[P_PRODUCT_WIDTH-1]}}, i_product_r[P_PRODUCT_WIDTH-1:PRODUCT_SHIFT]} : {STATE_WIDTH{1'b0}};
    // The proportional phase path is an instantaneous frequency correction.
    // It needs substantially more word-domain gain than the per-sample phase
    // integrator; sharing PRODUCT_SHIFT made the full 24-bit Kp range too weak
    // to provide useful damping.
    assign p_term_next = enable_pll_p_product_r ? {{(STATE_WIDTH-(P_PRODUCT_WIDTH-P_PRODUCT_SHIFT)){p_product_r[P_PRODUCT_WIDTH-1]}}, p_product_r[P_PRODUCT_WIDTH-1:P_PRODUCT_SHIFT]} : {STATE_WIDTH{1'b0}};

    assign state_delta_next = fll_term_r + i_term_r;
    assign state_sum_ext_next = {freq_state[STATE_WIDTH-1], freq_state} + {state_delta_next[STATE_WIDTH-1], state_delta_next};
    assign freq_state_after_update_next = state_sum_stage_allow_update_r ?
                                          sat_state(state_sum_stage_state_sum_ext_r, state_sum_stage_positive_limit_ext, state_sum_stage_negative_limit_ext) :
                                          state_sum_stage_current_r;
    assign freq_state_after_update_ext_next = {freq_state_after_update_next[STATE_WIDTH-1], freq_state_after_update_next};
    assign correction_sum_ext_next = {state_stage_state_r[STATE_WIDTH-1], state_stage_state_r} + {state_stage_p_term_r[STATE_WIDTH-1], state_stage_p_term_r};
    assign freq_correction_sat_next = sat_state(correction_sum_ext_next, state_stage_positive_limit_ext, state_stage_negative_limit_ext);
    assign freq_correction_sat_ext_next = {freq_correction_sat_next[STATE_WIDTH-1], freq_correction_sat_next};
    assign center_ext_next = {{(STATE_WIDTH+1-WORD_WIDTH){1'b0}}, correction_stage_center_word_r};
    assign tracking_sum_ext_next = center_ext_next + correction_stage_correction_ext;
    assign positive_limit_ext = {positive_limit_r1[STATE_WIDTH-1], positive_limit_r1};
    assign negative_limit_ext = {negative_limit_r1[STATE_WIDTH-1], negative_limit_r1};
    assign state_sum_stage_positive_limit_ext = {state_sum_stage_positive_limit_r[STATE_WIDTH-1], state_sum_stage_positive_limit_r};
    assign state_sum_stage_negative_limit_ext = {state_sum_stage_negative_limit_r[STATE_WIDTH-1], state_sum_stage_negative_limit_r};
    assign state_stage_positive_limit_ext = {state_stage_positive_limit_r[STATE_WIDTH-1], state_stage_positive_limit_r};
    assign state_stage_negative_limit_ext = {state_stage_negative_limit_r[STATE_WIDTH-1], state_stage_negative_limit_r};
    assign correction_stage_positive_limit_ext = {correction_stage_positive_limit_r[STATE_WIDTH-1], correction_stage_positive_limit_r};
    assign correction_stage_negative_limit_ext = {correction_stage_negative_limit_r[STATE_WIDTH-1], correction_stage_negative_limit_r};
    assign correction_stage_correction_ext = {correction_stage_correction_r[STATE_WIDTH-1], correction_stage_correction_r};
    assign zero_ext = {STATE_WIDTH+1{1'b0}};
    assign max_word_ext = {{(STATE_WIDTH+1-WORD_WIDTH){1'b0}}, {1'b0, {(WORD_WIDTH-1){1'b1}}}};
    assign state_zero = {STATE_WIDTH{1'b0}};

    function signed [STATE_WIDTH-1:0] sat_state;
        input signed [STATE_WIDTH:0] value;
        input signed [STATE_WIDTH:0] pos_limit;
        input signed [STATE_WIDTH:0] neg_limit;
        begin
            if (value > pos_limit) begin
                sat_state = pos_limit[STATE_WIDTH-1:0];
            end else if (value < neg_limit) begin
                sat_state = neg_limit[STATE_WIDTH-1:0];
            end else begin
                sat_state = value[STATE_WIDTH-1:0];
            end
        end
    endfunction

    function [WORD_WIDTH-1:0] sat_word;
        input signed [STATE_WIDTH:0] value;
        begin
            if (value < zero_ext) begin
                sat_word = {WORD_WIDTH{1'b0}};
            end else if (value > max_word_ext) begin
                sat_word = {1'b0, {(WORD_WIDTH-1){1'b1}}};
            end else begin
                sat_word = value[WORD_WIDTH-1:0];
            end
        end
    endfunction

    assign push_high = (freq_state >= positive_limit_r1) && (state_delta_next > state_zero);
    assign push_low = (freq_state <= negative_limit_r1) && (state_delta_next < state_zero);
    assign allow_state_update = !(push_high || push_low);

    always @(posedge clk_125m) begin
        rst_pipe_r <= rst_125m;
        rst_output_r <= rst_125m;
    end

    always @(posedge clk_125m) begin
        if (rst_pipe_r || clear) begin
            product_valid_r <= 1'b0;
            product_operand_valid_r <= 1'b0;
            product_partial_valid_r <= 1'b0;
            valid_pipe <= 7'b0000000;
            enable_fll_mul_r <= 1'b0;
            enable_pll_i_mul_r <= 1'b0;
            enable_pll_p_mul_r <= 1'b0;
            enable_fll_operand_r <= 1'b0;
            enable_pll_i_operand_r <= 1'b0;
            enable_pll_p_operand_r <= 1'b0;
            enable_fll_partial_r <= 1'b0;
            enable_pll_i_partial_r <= 1'b0;
            enable_pll_p_partial_r <= 1'b0;
            enable_fll_product_r <= 1'b0;
            enable_pll_i_product_r <= 1'b0;
            enable_pll_p_product_r <= 1'b0;
            phase_error_mul_r <= {PHASE_WIDTH{1'b0}};
            freq_error_mul_r <= {FERR_WIDTH{1'b0}};
            kf_mul_r <= {COEFF_WIDTH{1'b0}};
            ki_mul_r <= {COEFF_WIDTH{1'b0}};
            kp_mul_r <= {COEFF_WIDTH{1'b0}};
            phase_error_product_r <= {PHASE_WIDTH{1'b0}};
            freq_error_product_r <= {FERR_WIDTH{1'b0}};
            kf_product_r <= {COEFF_WIDTH{1'b0}};
            ki_product_r <= {COEFF_WIDTH{1'b0}};
            kp_product_r <= {COEFF_WIDTH{1'b0}};
            fll_product_r <= {F_PRODUCT_WIDTH{1'b0}};
            i_product_r <= {P_PRODUCT_WIDTH{1'b0}};
            p_product_r <= {P_PRODUCT_WIDTH{1'b0}};
            fll_product_lo_r <= {FLL_PART_WIDTH{1'b0}};
            fll_product_hi_r <= {FLL_PART_WIDTH{1'b0}};
            i_product_partial_r <= {P_PRODUCT_WIDTH{1'b0}};
            p_product_partial_r <= {P_PRODUCT_WIDTH{1'b0}};
            fll_term_r <= {STATE_WIDTH{1'b0}};
            i_term_r <= {STATE_WIDTH{1'b0}};
            p_term_r <= {STATE_WIDTH{1'b0}};
            state_sum_stage_current_r <= {STATE_WIDTH{1'b0}};
            state_sum_stage_p_term_r <= {STATE_WIDTH{1'b0}};
            state_sum_stage_center_word_r <= {WORD_WIDTH{1'b0}};
            state_sum_stage_positive_limit_r <= {STATE_WIDTH{1'b0}};
            state_sum_stage_negative_limit_r <= {STATE_WIDTH{1'b0}};
            state_sum_stage_state_sum_ext_r <= {(STATE_WIDTH+1){1'b0}};
            state_sum_stage_allow_update_r <= 1'b0;
            state_stage_state_r <= {STATE_WIDTH{1'b0}};
            state_stage_p_term_r <= {STATE_WIDTH{1'b0}};
            state_stage_center_word_r <= {WORD_WIDTH{1'b0}};
            state_stage_positive_limit_r <= {STATE_WIDTH{1'b0}};
            state_stage_negative_limit_r <= {STATE_WIDTH{1'b0}};
            state_stage_state_sum_ext_r <= {(STATE_WIDTH+1){1'b0}};
            state_stage_allow_update_r <= 1'b0;
            correction_stage_state_r <= {STATE_WIDTH{1'b0}};
            correction_stage_correction_r <= {STATE_WIDTH{1'b0}};
            correction_stage_center_word_r <= {WORD_WIDTH{1'b0}};
            correction_stage_positive_limit_r <= {STATE_WIDTH{1'b0}};
            correction_stage_negative_limit_r <= {STATE_WIDTH{1'b0}};
            correction_stage_state_sum_ext_r <= {(STATE_WIDTH+1){1'b0}};
            correction_stage_correction_sum_ext_r <= {(STATE_WIDTH+1){1'b0}};
            correction_stage_allow_update_r <= 1'b0;
            center_word_r0 <= {WORD_WIDTH{1'b0}};
            center_word_r1 <= {WORD_WIDTH{1'b0}};
            center_word_operand_r <= {WORD_WIDTH{1'b0}};
            center_word_partial_r <= {WORD_WIDTH{1'b0}};
            center_word_product_r <= {WORD_WIDTH{1'b0}};
            positive_limit_r0 <= {STATE_WIDTH{1'b0}};
            negative_limit_r0 <= {STATE_WIDTH{1'b0}};
            positive_limit_r1 <= {STATE_WIDTH{1'b0}};
            negative_limit_r1 <= {STATE_WIDTH{1'b0}};
            positive_limit_operand_r <= {STATE_WIDTH{1'b0}};
            negative_limit_operand_r <= {STATE_WIDTH{1'b0}};
            positive_limit_partial_r <= {STATE_WIDTH{1'b0}};
            negative_limit_partial_r <= {STATE_WIDTH{1'b0}};
            positive_limit_product_r <= {STATE_WIDTH{1'b0}};
            negative_limit_product_r <= {STATE_WIDTH{1'b0}};
        end else begin
            product_valid_r <= error_valid;
            product_operand_valid_r <= product_valid_r;
            product_partial_valid_r <= product_operand_valid_r;
            valid_pipe <= {valid_pipe[5:0], product_partial_valid_r};

            if (error_valid) begin
                phase_error_mul_r <= phase_error;
                freq_error_mul_r <= freq_error;
                kf_mul_r <= kf;
                ki_mul_r <= ki;
                kp_mul_r <= kp;
                enable_fll_mul_r <= enable_fll;
                enable_pll_i_mul_r <= enable_pll_i;
                enable_pll_p_mul_r <= enable_pll_p;
                center_word_r0 <= center_word;
                positive_limit_r0 <= positive_limit;
                negative_limit_r0 <= negative_limit;
            end

            if (product_valid_r) begin
                phase_error_product_r <= phase_error_mul_r;
                freq_error_product_r <= freq_error_mul_r;
                kf_product_r <= kf_mul_r;
                ki_product_r <= ki_mul_r;
                kp_product_r <= kp_mul_r;
                enable_fll_operand_r <= enable_fll_mul_r;
                enable_pll_i_operand_r <= enable_pll_i_mul_r;
                enable_pll_p_operand_r <= enable_pll_p_mul_r;
                center_word_operand_r <= center_word_r0;
                positive_limit_operand_r <= positive_limit_r0;
                negative_limit_operand_r <= negative_limit_r0;
            end

            if (product_operand_valid_r) begin
                fll_product_lo_r <= fll_product_lo_next;
                fll_product_hi_r <= fll_product_hi_next;
                i_product_partial_r <= i_product_next;
                p_product_partial_r <= p_product_next;
                enable_fll_partial_r <= enable_fll_operand_r;
                enable_pll_i_partial_r <= enable_pll_i_operand_r;
                enable_pll_p_partial_r <= enable_pll_p_operand_r;
                center_word_partial_r <= center_word_operand_r;
                positive_limit_partial_r <= positive_limit_operand_r;
                negative_limit_partial_r <= negative_limit_operand_r;
            end

            if (product_partial_valid_r) begin
                fll_product_r <= fll_product_next;
                i_product_r <= i_product_partial_r;
                p_product_r <= p_product_partial_r;
                enable_fll_product_r <= enable_fll_partial_r;
                enable_pll_i_product_r <= enable_pll_i_partial_r;
                enable_pll_p_product_r <= enable_pll_p_partial_r;
                center_word_product_r <= center_word_partial_r;
                positive_limit_product_r <= positive_limit_partial_r;
                negative_limit_product_r <= negative_limit_partial_r;
            end

            if (valid_pipe[0]) begin
                fll_term_r <= fll_term_next;
                i_term_r <= i_term_next;
                p_term_r <= p_term_next;
                center_word_r1 <= center_word_product_r;
                positive_limit_r1 <= positive_limit_product_r;
                negative_limit_r1 <= negative_limit_product_r;
            end

            if (valid_pipe[1]) begin
                state_sum_stage_current_r <= freq_state;
                state_sum_stage_p_term_r <= p_term_r;
                state_sum_stage_center_word_r <= center_word_r1;
                state_sum_stage_positive_limit_r <= positive_limit_r1;
                state_sum_stage_negative_limit_r <= negative_limit_r1;
                state_sum_stage_state_sum_ext_r <= state_sum_ext_next;
                state_sum_stage_allow_update_r <= allow_state_update;
            end

            if (valid_pipe[2]) begin
                state_stage_state_r <= freq_state_after_update_next;
                state_stage_p_term_r <= state_sum_stage_p_term_r;
                state_stage_center_word_r <= state_sum_stage_center_word_r;
                state_stage_positive_limit_r <= state_sum_stage_positive_limit_r;
                state_stage_negative_limit_r <= state_sum_stage_negative_limit_r;
                state_stage_state_sum_ext_r <= state_sum_stage_state_sum_ext_r;
                state_stage_allow_update_r <= state_sum_stage_allow_update_r;
            end

            if (valid_pipe[3]) begin
                correction_stage_state_r <= state_stage_state_r;
                correction_stage_correction_r <= freq_correction_sat_next;
                correction_stage_center_word_r <= state_stage_center_word_r;
                correction_stage_positive_limit_r <= state_stage_positive_limit_r;
                correction_stage_negative_limit_r <= state_stage_negative_limit_r;
                correction_stage_state_sum_ext_r <= state_stage_state_sum_ext_r;
                correction_stage_correction_sum_ext_r <= correction_sum_ext_next;
                correction_stage_allow_update_r <= state_stage_allow_update_r;
            end

        end
    end

    always @(posedge clk_125m) begin
        if (rst_output_r || clear) begin
            correction_valid <= 1'b0;
            freq_state <= {STATE_WIDTH{1'b0}};
            freq_correction <= {STATE_WIDTH{1'b0}};
            tracking_word <= {WORD_WIDTH{1'b0}};
            saturated_high <= 1'b0;
            saturated_low <= 1'b0;
        end else begin
            correction_valid <= 1'b0;

            if (valid_pipe[4]) begin
                if (correction_stage_allow_update_r) begin
                    freq_state <= correction_stage_state_r;
                end

                freq_correction <= correction_stage_correction_r;
                tracking_word <= sat_word(tracking_sum_ext_next);
                saturated_high <= (correction_stage_state_sum_ext_r > correction_stage_positive_limit_ext)
                               || (correction_stage_correction_sum_ext_r > correction_stage_positive_limit_ext);
                saturated_low <= (correction_stage_state_sum_ext_r < correction_stage_negative_limit_ext)
                              || (correction_stage_correction_sum_ext_r < correction_stage_negative_limit_ext);
                correction_valid <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
