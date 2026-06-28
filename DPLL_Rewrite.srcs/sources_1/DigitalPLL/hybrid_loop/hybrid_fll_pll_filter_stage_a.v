`timescale 1ns / 1ps
`default_nettype none

module hybrid_fll_pll_filter_stage_a #(
    parameter integer PHASE_WIDTH = 18,
    parameter integer FERR_WIDTH = 22,
    parameter integer COEFF_WIDTH = 24,
    parameter integer STATE_WIDTH = 56,
    parameter integer WORD_WIDTH = 48,
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

    reg signed [F_PRODUCT_WIDTH-1:0] fll_product_r;
    reg signed [P_PRODUCT_WIDTH-1:0] i_product_r;
    reg signed [P_PRODUCT_WIDTH-1:0] p_product_r;
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
    reg enable_fll_product_r;
    reg enable_pll_i_product_r;
    reg enable_pll_p_product_r;
    reg signed [STATE_WIDTH-1:0] fll_term_r;
    reg signed [STATE_WIDTH-1:0] i_term_r;
    reg signed [STATE_WIDTH-1:0] p_term_r;
    reg [WORD_WIDTH-1:0] center_word_r0;
    reg [WORD_WIDTH-1:0] center_word_r1;
    reg [WORD_WIDTH-1:0] center_word_operand_r;
    reg [WORD_WIDTH-1:0] center_word_product_r;
    reg signed [STATE_WIDTH-1:0] positive_limit_r0;
    reg signed [STATE_WIDTH-1:0] negative_limit_r0;
    reg signed [STATE_WIDTH-1:0] positive_limit_r1;
    reg signed [STATE_WIDTH-1:0] negative_limit_r1;
    reg signed [STATE_WIDTH-1:0] positive_limit_operand_r;
    reg signed [STATE_WIDTH-1:0] negative_limit_operand_r;
    reg signed [STATE_WIDTH-1:0] positive_limit_product_r;
    reg signed [STATE_WIDTH-1:0] negative_limit_product_r;
    reg [3:0] valid_pipe;
    (* keep = "true", dont_touch = "true" *) reg rst_pipe_r;
    (* keep = "true", dont_touch = "true" *) reg rst_output_r;

    wire signed [F_PRODUCT_WIDTH-1:0] fll_product_next;
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
    wire signed [STATE_WIDTH:0] zero_ext;
    wire signed [STATE_WIDTH:0] max_word_ext;
    wire signed [STATE_WIDTH-1:0] state_zero;
    wire push_high;
    wire push_low;
    wire allow_state_update;

    assign fll_product_next = freq_error_product_r * kf_product_r;
    assign i_product_next = phase_error_product_r * ki_product_r;
    assign p_product_next = phase_error_product_r * kp_product_r;

    assign fll_term_next = enable_fll_product_r ? {{(STATE_WIDTH-(F_PRODUCT_WIDTH-PRODUCT_SHIFT)){fll_product_r[F_PRODUCT_WIDTH-1]}}, fll_product_r[F_PRODUCT_WIDTH-1:PRODUCT_SHIFT]} : {STATE_WIDTH{1'b0}};
    assign i_term_next = enable_pll_i_product_r ? {{(STATE_WIDTH-(P_PRODUCT_WIDTH-PRODUCT_SHIFT)){i_product_r[P_PRODUCT_WIDTH-1]}}, i_product_r[P_PRODUCT_WIDTH-1:PRODUCT_SHIFT]} : {STATE_WIDTH{1'b0}};
    assign p_term_next = enable_pll_p_product_r ? {{(STATE_WIDTH-(P_PRODUCT_WIDTH-PRODUCT_SHIFT)){p_product_r[P_PRODUCT_WIDTH-1]}}, p_product_r[P_PRODUCT_WIDTH-1:PRODUCT_SHIFT]} : {STATE_WIDTH{1'b0}};

    assign state_delta_next = fll_term_r + i_term_r;
    assign state_sum_ext_next = {freq_state[STATE_WIDTH-1], freq_state} + {state_delta_next[STATE_WIDTH-1], state_delta_next};
    assign freq_state_after_update_next = allow_state_update ?
                                          sat_state(state_sum_ext_next, positive_limit_ext, negative_limit_ext) :
                                          freq_state;
    assign freq_state_after_update_ext_next = {freq_state_after_update_next[STATE_WIDTH-1], freq_state_after_update_next};
    assign correction_sum_ext_next = freq_state_after_update_ext_next + {p_term_r[STATE_WIDTH-1], p_term_r};
    assign freq_correction_sat_next = sat_state(correction_sum_ext_next, positive_limit_ext, negative_limit_ext);
    assign freq_correction_sat_ext_next = {freq_correction_sat_next[STATE_WIDTH-1], freq_correction_sat_next};
    assign center_ext_next = {{(STATE_WIDTH+1-WORD_WIDTH){1'b0}}, center_word_r1};
    assign tracking_sum_ext_next = center_ext_next + freq_correction_sat_ext_next;
    assign positive_limit_ext = {positive_limit_r1[STATE_WIDTH-1], positive_limit_r1};
    assign negative_limit_ext = {negative_limit_r1[STATE_WIDTH-1], negative_limit_r1};
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
            valid_pipe <= 4'b0000;
            enable_fll_mul_r <= 1'b0;
            enable_pll_i_mul_r <= 1'b0;
            enable_pll_p_mul_r <= 1'b0;
            enable_fll_operand_r <= 1'b0;
            enable_pll_i_operand_r <= 1'b0;
            enable_pll_p_operand_r <= 1'b0;
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
            fll_term_r <= {STATE_WIDTH{1'b0}};
            i_term_r <= {STATE_WIDTH{1'b0}};
            p_term_r <= {STATE_WIDTH{1'b0}};
            center_word_r0 <= {WORD_WIDTH{1'b0}};
            center_word_r1 <= {WORD_WIDTH{1'b0}};
            center_word_operand_r <= {WORD_WIDTH{1'b0}};
            center_word_product_r <= {WORD_WIDTH{1'b0}};
            positive_limit_r0 <= {STATE_WIDTH{1'b0}};
            negative_limit_r0 <= {STATE_WIDTH{1'b0}};
            positive_limit_r1 <= {STATE_WIDTH{1'b0}};
            negative_limit_r1 <= {STATE_WIDTH{1'b0}};
            positive_limit_operand_r <= {STATE_WIDTH{1'b0}};
            negative_limit_operand_r <= {STATE_WIDTH{1'b0}};
            positive_limit_product_r <= {STATE_WIDTH{1'b0}};
            negative_limit_product_r <= {STATE_WIDTH{1'b0}};
        end else begin
            product_valid_r <= error_valid;
            product_operand_valid_r <= product_valid_r;
            valid_pipe <= {valid_pipe[2:0], product_operand_valid_r};

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
                fll_product_r <= fll_product_next;
                i_product_r <= i_product_next;
                p_product_r <= p_product_next;
                enable_fll_product_r <= enable_fll_operand_r;
                enable_pll_i_product_r <= enable_pll_i_operand_r;
                enable_pll_p_product_r <= enable_pll_p_operand_r;
                center_word_product_r <= center_word_operand_r;
                positive_limit_product_r <= positive_limit_operand_r;
                negative_limit_product_r <= negative_limit_operand_r;
            end

            if (valid_pipe[0]) begin
                fll_term_r <= fll_term_next;
                i_term_r <= i_term_next;
                p_term_r <= p_term_next;
                center_word_r1 <= center_word_product_r;
                positive_limit_r1 <= positive_limit_product_r;
                negative_limit_r1 <= negative_limit_product_r;
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

            if (valid_pipe[1]) begin
                if (allow_state_update) begin
                    freq_state <= freq_state_after_update_next;
                end

                freq_correction <= freq_correction_sat_next;
                tracking_word <= sat_word(tracking_sum_ext_next);
                saturated_high <= (state_sum_ext_next > positive_limit_ext)
                               || (correction_sum_ext_next > positive_limit_ext);
                saturated_low <= (state_sum_ext_next < negative_limit_ext)
                              || (correction_sum_ext_next < negative_limit_ext);
                correction_valid <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
