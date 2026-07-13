`timescale 1ns / 1ps
`default_nettype none

module fll_phase_difference_stage_a #(
    parameter integer PHASE_WIDTH = 18,
    parameter integer FERR_WIDTH = 22
) (
    input  wire                              clk_125m,
    input  wire                              rst_125m,
    input  wire                              clear,
    input  wire                              phase_valid,
    input  wire signed [PHASE_WIDTH-1:0]     phase_in,
    input  wire [1:0]                        delay_sel,
    input  wire [8:0]                        rate_r,
    output reg                               freq_error_valid,
    output reg signed [FERR_WIDTH-1:0]       freq_error,
    output reg                               ambiguous
);

    localparam integer UNWRAPPED_WIDTH = PHASE_WIDTH + 5;
    localparam integer DELTA_WIDTH = UNWRAPPED_WIDTH + 1;
    localparam integer SUM_WIDTH = UNWRAPPED_WIDTH + 2;

    localparam signed [DELTA_WIDTH-1:0] HALF_TURN =
        (1 <<< (PHASE_WIDTH-1));
    localparam signed [DELTA_WIDTH-1:0] FULL_TURN =
        (1 <<< PHASE_WIDTH);
    localparam signed [UNWRAPPED_WIDTH-1:0] UNWRAPPED_POS_LIMIT =
        (1 <<< (PHASE_WIDTH+3)) - 1'b1;
    localparam signed [UNWRAPPED_WIDTH-1:0] UNWRAPPED_NEG_LIMIT =
        -(1 <<< (PHASE_WIDTH+3));

    reg signed [PHASE_WIDTH-1:0] wrapped_phase_prev;
    reg wrapped_phase_prev_valid;
    reg signed [UNWRAPPED_WIDTH-1:0] unwrapped_phase_current;
    reg unwrapped_phase_saturated_current;
    reg signed [UNWRAPPED_WIDTH-1:0] unwrapped_phase_delay [0:7];
    reg unwrapped_phase_saturated_delay [0:7];
    reg [3:0] valid_count;
    integer idx;

    wire signed [UNWRAPPED_WIDTH-1:0] delayed_unwrapped_phase;
    wire delayed_unwrapped_saturated;
    wire signed [DELTA_WIDTH-1:0] wrapped_phase_delta_raw;
    wire signed [DELTA_WIDTH-1:0] wrapped_phase_delta_unwrapped;
    wire wrapped_phase_delta_ambiguous;
    wire signed [SUM_WIDTH-1:0] unwrapped_phase_sum_next;
    wire signed [UNWRAPPED_WIDTH-1:0] unwrapped_phase_next;
    wire unwrapped_phase_saturated_next;
    wire signed [DELTA_WIDTH-1:0] instantaneous_phase_delta;
    wire [3:0] selected_delay;
    wire [12:0] normalization_denominator;
    wire [DELTA_WIDTH-1:0] instantaneous_phase_delta_abs;
    reg [DELTA_WIDTH-1:0] normalization_abs_pending;
    reg [12:0] normalization_denominator_pending;
    reg normalization_negative_pending;
    reg normalization_ambiguous_pending;
    reg normalization_pending;
    wire [31:0] normalization_numerator_abs;

    reg divide_busy;
    reg [5:0] divide_count;
    reg [31:0] divide_dividend;
    reg [31:0] divide_quotient;
    reg [13:0] divide_remainder;
    reg [12:0] divide_divisor;
    reg divide_negative;
    reg ambiguous_pending;
    wire [13:0] divide_remainder_shift;
    wire divide_quotient_bit;
    wire [13:0] divide_remainder_next;
    wire [31:0] divide_quotient_next;
    wire signed [32:0] divide_signed_result_next;

    assign selected_delay =
        (delay_sel == 2'd0) ? 4'd1 :
        (delay_sel == 2'd1) ? 4'd2 :
        (delay_sel == 2'd2) ? 4'd4 : 4'd8;

    assign delayed_unwrapped_phase =
        (delay_sel == 2'd0) ? unwrapped_phase_delay[0] :
        (delay_sel == 2'd1) ? unwrapped_phase_delay[1] :
        (delay_sel == 2'd2) ? unwrapped_phase_delay[3] : unwrapped_phase_delay[7];

    assign delayed_unwrapped_saturated =
        (delay_sel == 2'd0) ? unwrapped_phase_saturated_delay[0] :
        (delay_sel == 2'd1) ? unwrapped_phase_saturated_delay[1] :
        (delay_sel == 2'd2) ? unwrapped_phase_saturated_delay[3] :
                               unwrapped_phase_saturated_delay[7];

    assign wrapped_phase_delta_raw =
        {{(DELTA_WIDTH-PHASE_WIDTH){phase_in[PHASE_WIDTH-1]}}, phase_in} -
        {{(DELTA_WIDTH-PHASE_WIDTH){wrapped_phase_prev[PHASE_WIDTH-1]}}, wrapped_phase_prev};
    assign wrapped_phase_delta_unwrapped =
        !wrapped_phase_prev_valid ? {{(DELTA_WIDTH-PHASE_WIDTH){phase_in[PHASE_WIDTH-1]}}, phase_in} :
        (wrapped_phase_delta_raw > HALF_TURN) ? (wrapped_phase_delta_raw - FULL_TURN) :
        (wrapped_phase_delta_raw < -HALF_TURN) ? (wrapped_phase_delta_raw + FULL_TURN) :
        wrapped_phase_delta_raw;
    assign wrapped_phase_delta_ambiguous =
        wrapped_phase_prev_valid &&
        ((wrapped_phase_delta_raw == HALF_TURN) || (wrapped_phase_delta_raw == -HALF_TURN));
    assign unwrapped_phase_sum_next =
        !wrapped_phase_prev_valid ?
            {{(SUM_WIDTH-PHASE_WIDTH){phase_in[PHASE_WIDTH-1]}}, phase_in} :
            {{(SUM_WIDTH-UNWRAPPED_WIDTH){unwrapped_phase_current[UNWRAPPED_WIDTH-1]}}, unwrapped_phase_current} +
            {{(SUM_WIDTH-DELTA_WIDTH){wrapped_phase_delta_unwrapped[DELTA_WIDTH-1]}}, wrapped_phase_delta_unwrapped};
    assign unwrapped_phase_next = saturate_unwrapped_phase(unwrapped_phase_sum_next);
    assign unwrapped_phase_saturated_next =
        (unwrapped_phase_sum_next > $signed({{(SUM_WIDTH-UNWRAPPED_WIDTH){UNWRAPPED_POS_LIMIT[UNWRAPPED_WIDTH-1]}}, UNWRAPPED_POS_LIMIT})) ||
        (unwrapped_phase_sum_next < $signed({{(SUM_WIDTH-UNWRAPPED_WIDTH){UNWRAPPED_NEG_LIMIT[UNWRAPPED_WIDTH-1]}}, UNWRAPPED_NEG_LIMIT}));

    assign instantaneous_phase_delta =
        {{(DELTA_WIDTH-UNWRAPPED_WIDTH){unwrapped_phase_next[UNWRAPPED_WIDTH-1]}}, unwrapped_phase_next} -
        {{(DELTA_WIDTH-UNWRAPPED_WIDTH){delayed_unwrapped_phase[UNWRAPPED_WIDTH-1]}}, delayed_unwrapped_phase};
    // Normalize instantaneous frequency to the R=312, M=8 reference interval.
    // The absolute-value stage and constant multiply are registered before the
    // sequential divider so no variable division or long multiply chain reaches
    // 125 MHz.
    assign normalization_denominator = rate_r * selected_delay;
    assign instantaneous_phase_delta_abs = instantaneous_phase_delta[DELTA_WIDTH-1]
        ? (~instantaneous_phase_delta + 1'b1) : instantaneous_phase_delta;
    assign normalization_numerator_abs =
        {{(32-DELTA_WIDTH){1'b0}}, normalization_abs_pending} << 8;

    assign divide_remainder_shift = {divide_remainder[12:0], divide_dividend[31]};
    assign divide_quotient_bit =
        divide_remainder_shift >= {1'b0, divide_divisor};
    assign divide_remainder_next = divide_quotient_bit
        ? divide_remainder_shift - {1'b0, divide_divisor}
        : divide_remainder_shift;
    assign divide_quotient_next = {divide_quotient[30:0], divide_quotient_bit};
    assign divide_signed_result_next = divide_negative
        ? -$signed({1'b0, divide_quotient_next})
        :  $signed({1'b0, divide_quotient_next});

    function signed [FERR_WIDTH-1:0] saturate_normalized;
        input signed [32:0] value;
        begin
            if (value > ((33'sd1 <<< (FERR_WIDTH-1)) - 1))
                saturate_normalized = {1'b0, {(FERR_WIDTH-1){1'b1}}};
            else if (value < -(33'sd1 <<< (FERR_WIDTH-1)))
                saturate_normalized = {1'b1, {(FERR_WIDTH-1){1'b0}}};
            else
                saturate_normalized = value[FERR_WIDTH-1:0];
        end
    endfunction

    function signed [UNWRAPPED_WIDTH-1:0] saturate_unwrapped_phase;
        input signed [SUM_WIDTH-1:0] value;
        begin
            if (value > $signed({{(SUM_WIDTH-UNWRAPPED_WIDTH){UNWRAPPED_POS_LIMIT[UNWRAPPED_WIDTH-1]}}, UNWRAPPED_POS_LIMIT}))
                saturate_unwrapped_phase = UNWRAPPED_POS_LIMIT;
            else if (value < $signed({{(SUM_WIDTH-UNWRAPPED_WIDTH){UNWRAPPED_NEG_LIMIT[UNWRAPPED_WIDTH-1]}}, UNWRAPPED_NEG_LIMIT}))
                saturate_unwrapped_phase = UNWRAPPED_NEG_LIMIT;
            else
                saturate_unwrapped_phase = value[UNWRAPPED_WIDTH-1:0];
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m || clear) begin
            for (idx = 0; idx < 8; idx = idx + 1) begin
                unwrapped_phase_delay[idx] <= {UNWRAPPED_WIDTH{1'b0}};
                unwrapped_phase_saturated_delay[idx] <= 1'b0;
            end
            wrapped_phase_prev <= {PHASE_WIDTH{1'b0}};
            wrapped_phase_prev_valid <= 1'b0;
            unwrapped_phase_current <= {UNWRAPPED_WIDTH{1'b0}};
            unwrapped_phase_saturated_current <= 1'b0;
            valid_count <= 4'd0;
            freq_error_valid <= 1'b0;
            freq_error <= {FERR_WIDTH{1'b0}};
            ambiguous <= 1'b0;
            normalization_abs_pending <= {DELTA_WIDTH{1'b0}};
            normalization_denominator_pending <= 13'd0;
            normalization_negative_pending <= 1'b0;
            normalization_ambiguous_pending <= 1'b0;
            normalization_pending <= 1'b0;
            divide_busy <= 1'b0;
            divide_count <= 6'd0;
            divide_dividend <= 32'd0;
            divide_quotient <= 32'd0;
            divide_remainder <= 14'd0;
            divide_divisor <= 13'd0;
            divide_negative <= 1'b0;
            ambiguous_pending <= 1'b0;
        end else begin
            freq_error_valid <= 1'b0;

            if (normalization_pending && !divide_busy) begin
                normalization_pending <= 1'b0;
                divide_busy <= 1'b1;
                divide_count <= 6'd32;
                divide_dividend <= normalization_numerator_abs;
                divide_quotient <= 32'd0;
                divide_remainder <= 14'd0;
                divide_divisor <= normalization_denominator_pending;
                divide_negative <= normalization_negative_pending;
                ambiguous_pending <= normalization_ambiguous_pending;
            end

            if (divide_busy) begin
                divide_dividend <= {divide_dividend[30:0], 1'b0};
                divide_quotient <= divide_quotient_next;
                divide_remainder <= divide_remainder_next;
                divide_count <= divide_count - 1'b1;
                if (divide_count == 6'd1) begin
                    freq_error <= saturate_normalized(divide_signed_result_next);
                    ambiguous <= ambiguous_pending;
                    freq_error_valid <= 1'b1;
                    divide_busy <= 1'b0;
                end
            end

            if (phase_valid) begin
                wrapped_phase_prev <= phase_in;
                wrapped_phase_prev_valid <= 1'b1;
                unwrapped_phase_current <= unwrapped_phase_next;
                unwrapped_phase_saturated_current <= unwrapped_phase_saturated_next;
                unwrapped_phase_delay[0] <= unwrapped_phase_next;
                unwrapped_phase_saturated_delay[0] <= unwrapped_phase_saturated_next;
                for (idx = 1; idx < 8; idx = idx + 1) begin
                    unwrapped_phase_delay[idx] <= unwrapped_phase_delay[idx-1];
                    unwrapped_phase_saturated_delay[idx] <= unwrapped_phase_saturated_delay[idx-1];
                end
                if (valid_count != 4'd15) begin
                    valid_count <= valid_count + 1'b1;
                end

                if (valid_count >= selected_delay && !divide_busy &&
                    !normalization_pending && normalization_denominator != 13'd0) begin
                    normalization_abs_pending <= instantaneous_phase_delta_abs;
                    normalization_denominator_pending <= normalization_denominator;
                    normalization_negative_pending <= instantaneous_phase_delta[DELTA_WIDTH-1];
                    normalization_ambiguous_pending <=
                        wrapped_phase_delta_ambiguous ||
                        unwrapped_phase_saturated_next ||
                        delayed_unwrapped_saturated;
                    normalization_pending <= 1'b1;
                end
            end
        end
    end

endmodule

module fll_cross_dot_stage_a #(
    parameter integer IQ_WIDTH = 20,
    parameter integer FERR_WIDTH = 22,
    parameter integer BLOCK_SAMPLES = 16
) (
    input  wire                              clk_125m,
    input  wire                              rst_125m,
    input  wire                              clear,
    input  wire                              sample_valid,
    input  wire signed [IQ_WIDTH-1:0]        i_in,
    input  wire signed [IQ_WIDTH-1:0]        q_in,
    input  wire [1:0]                        delay_sel,
    input  wire [8:0]                        rate_r,
    output reg                               freq_error_valid,
    output reg                               freq_error_block_valid,
    output reg signed [FERR_WIDTH-1:0]       freq_error,
    output reg                               ambiguous
);

    localparam integer PRODUCT_WIDTH = 2 * IQ_WIDTH;
    localparam integer DOT_WIDTH = PRODUCT_WIDTH + 1;
    localparam integer ACC_WIDTH = DOT_WIDTH + 6;
    localparam integer SCALE_WIDTH = 24;
    localparam integer DEN_WIDTH = 13;
    localparam integer DIVIDEND_WIDTH = ACC_WIDTH + SCALE_WIDTH;

    localparam [1:0] MATH_IDLE  = 2'd0;
    localparam [1:0] MATH_ISSUE = 2'd1;
    localparam [1:0] MATH_DRAIN = 2'd2;
    localparam [1:0] SCALE_IDLE = 2'd0;
    localparam [1:0] SCALE_RUN  = 2'd1;

    // round(2^18 / (2*pi) * 256). This keeps freq_error scaling compatible
    // with fll_phase_difference_stage_a: about 21.4748 LSB/Hz.
    localparam [SCALE_WIDTH-1:0] ANGLE_FREQ_SCALE = 24'd10680836;
    localparam [FERR_WIDTH-1:0] FERR_POS_MAX = {1'b0, {(FERR_WIDTH-1){1'b1}}};
    localparam [FERR_WIDTH-1:0] FERR_NEG_MIN = {1'b1, {(FERR_WIDTH-1){1'b0}}};

    reg signed [IQ_WIDTH-1:0] i_delay [0:7];
    reg signed [IQ_WIDTH-1:0] q_delay [0:7];
    reg [3:0] valid_count;
    reg [5:0] block_count;
    reg signed [ACC_WIDTH-1:0] dot_acc;
    reg signed [ACC_WIDTH-1:0] cross_acc;
    reg signed [ACC_WIDTH-1:0] block_dot_sum_r;
    reg signed [ACC_WIDTH-1:0] block_cross_sum_r;
    reg [DEN_WIDTH-1:0]        block_normalization_r;
    reg                        block_result_pending_r;
    integer idx;

    // A sample transaction captures the pre-shift delay history and the
    // normalization setting. The arithmetic pipeline never reads live input
    // or history registers after this point.
    reg signed [IQ_WIDTH-1:0] sample_i_r;
    reg signed [IQ_WIDTH-1:0] sample_q_r;
    reg signed [IQ_WIDTH-1:0] delayed_i_r;
    reg signed [IQ_WIDTH-1:0] delayed_q_r;
    reg [DEN_WIDTH-1:0] sample_normalization_r;
    reg sample_history_ready_r;
    reg [1:0] sample_math_state;
    reg       sample_term_r;
    wire      sample_math_busy = (sample_math_state != MATH_IDLE);

    // One independent multiplier pipeline serves dot and one serves cross.
    // The two terms are issued on consecutive clocks.
    reg signed [IQ_WIDTH-1:0] dot_mul_a_r;
    reg signed [IQ_WIDTH-1:0] dot_mul_b_r;
    reg signed [IQ_WIDTH-1:0] cross_mul_a_r;
    reg signed [IQ_WIDTH-1:0] cross_mul_b_r;
    (* use_dsp = "yes" *) reg signed [PRODUCT_WIDTH-1:0] dot_mul_product_r;
    (* use_dsp = "yes" *) reg signed [PRODUCT_WIDTH-1:0] cross_mul_product_r;
    reg       mul_issue_valid_r;
    reg       mul_issue_term_r;
    reg       mul_return_valid_r;
    reg       mul_return_term_r;
    reg signed [PRODUCT_WIDTH-1:0] dot_term0_r;
    reg signed [PRODUCT_WIDTH-1:0] cross_term0_r;

    reg divide_busy;
    reg [7:0] divide_count;
    reg [DIVIDEND_WIDTH-1:0] divide_dividend;
    reg [DIVIDEND_WIDTH-1:0] divide_quotient;
    reg [DIVIDEND_WIDTH:0] divide_remainder;
    reg [DIVIDEND_WIDTH:0] divide_divisor;
    reg divide_negative;
    reg [5:0] replay_count;
    reg signed [FERR_WIDTH-1:0] replay_freq_error;
    reg replay_ambiguous;

    // The result pipeline starts only after the last product has retired.
    // result_busy deliberately covers both the DSP-free shift-add and the
    // existing serial divider.
    reg [1:0] scale_state;
    reg [4:0] serial_count;
    reg [ACC_WIDTH-1:0] serial_cross_abs;
    reg [ACC_WIDTH-1:0] serial_dot_abs;
    reg [DEN_WIDTH-1:0] serial_normalization;
    reg                  serial_negative;
    reg [DIVIDEND_WIDTH-1:0] serial_numerator;
    reg [ACC_WIDTH+DEN_WIDTH-1:0] serial_denominator;
    wire result_busy = (scale_state != SCALE_IDLE) || divide_busy;

    wire [3:0] selected_delay;
    wire [DEN_WIDTH-1:0] normalization_denominator;
    wire [DEN_WIDTH-1:0] rate_ext;
    wire signed [IQ_WIDTH-1:0] delayed_i;
    wire signed [IQ_WIDTH-1:0] delayed_q;
    wire enough_history;
    wire block_done_next;

    wire signed [DOT_WIDTH-1:0] dot_sample;
    wire signed [DOT_WIDTH-1:0] cross_sample;
    wire signed [ACC_WIDTH-1:0] dot_sample_ext;
    wire signed [ACC_WIDTH-1:0] cross_sample_ext;
    wire signed [ACC_WIDTH-1:0] dot_sum_next;
    wire signed [ACC_WIDTH-1:0] cross_sum_next;
    wire [ACC_WIDTH-1:0] dot_sum_abs;
    wire [ACC_WIDTH-1:0] cross_sum_abs;
    wire dot_sum_positive;
    wire [ACC_WIDTH-1:0] block_dot_abs;
    wire [ACC_WIDTH-1:0] block_cross_abs;
    wire block_dot_positive;
    wire division_ready;

    wire [DIVIDEND_WIDTH-1:0] serial_cross_ext;
    wire [ACC_WIDTH+DEN_WIDTH-1:0] serial_dot_ext;
    wire [DIVIDEND_WIDTH-1:0] serial_numerator_add;
    reg [ACC_WIDTH+DEN_WIDTH-1:0] serial_denominator_add;
    wire [DIVIDEND_WIDTH-1:0] serial_numerator_next;
    wire [ACC_WIDTH+DEN_WIDTH-1:0] serial_denominator_next;
    wire [DIVIDEND_WIDTH:0] division_divisor_next;

    wire [DIVIDEND_WIDTH:0] divide_remainder_shift;
    wire divide_quotient_bit;
    wire [DIVIDEND_WIDTH:0] divide_remainder_next;
    wire [DIVIDEND_WIDTH-1:0] divide_quotient_next;

    assign selected_delay =
        (delay_sel == 2'd0) ? 4'd1 :
        (delay_sel == 2'd1) ? 4'd2 :
        (delay_sel == 2'd2) ? 4'd4 : 4'd8;

    // selected_delay is always a power of two. Keeping this as a shift avoids
    // inferring an extra multiplier for the small normalization product.
    assign rate_ext = {{(DEN_WIDTH-9){1'b0}}, rate_r};
    assign normalization_denominator =
        (selected_delay == 4'd1) ? rate_ext :
        (selected_delay == 4'd2) ? (rate_ext << 1) :
        (selected_delay == 4'd4) ? (rate_ext << 2) : (rate_ext << 3);

    assign delayed_i =
        (delay_sel == 2'd0) ? i_delay[0] :
        (delay_sel == 2'd1) ? i_delay[1] :
        (delay_sel == 2'd2) ? i_delay[3] : i_delay[7];
    assign delayed_q =
        (delay_sel == 2'd0) ? q_delay[0] :
        (delay_sel == 2'd1) ? q_delay[1] :
        (delay_sel == 2'd2) ? q_delay[3] : q_delay[7];
    assign enough_history = valid_count >= selected_delay;
    assign block_done_next = block_count >= (BLOCK_SAMPLES - 1);

    assign dot_sample =
        $signed({{(DOT_WIDTH-PRODUCT_WIDTH){dot_term0_r[PRODUCT_WIDTH-1]}}, dot_term0_r}) +
        $signed({{(DOT_WIDTH-PRODUCT_WIDTH){dot_mul_product_r[PRODUCT_WIDTH-1]}}, dot_mul_product_r});
    assign cross_sample =
        $signed({{(DOT_WIDTH-PRODUCT_WIDTH){cross_term0_r[PRODUCT_WIDTH-1]}}, cross_term0_r}) -
        $signed({{(DOT_WIDTH-PRODUCT_WIDTH){cross_mul_product_r[PRODUCT_WIDTH-1]}}, cross_mul_product_r});
    assign dot_sample_ext = {{(ACC_WIDTH-DOT_WIDTH){dot_sample[DOT_WIDTH-1]}}, dot_sample};
    assign cross_sample_ext = {{(ACC_WIDTH-DOT_WIDTH){cross_sample[DOT_WIDTH-1]}}, cross_sample};
    assign dot_sum_next = $signed(dot_acc) + $signed(dot_sample_ext);
    assign cross_sum_next = $signed(cross_acc) + $signed(cross_sample_ext);
    assign dot_sum_abs = dot_sum_next[ACC_WIDTH-1] ? abs_acc(dot_sum_next) : dot_sum_next;
    assign cross_sum_abs = abs_acc(cross_sum_next);
    assign dot_sum_positive = !dot_sum_next[ACC_WIDTH-1] &&
                              (dot_sum_next != {ACC_WIDTH{1'b0}});
    assign block_dot_abs = block_dot_sum_r[ACC_WIDTH-1] ?
                           abs_acc(block_dot_sum_r) : block_dot_sum_r;
    assign block_cross_abs = abs_acc(block_cross_sum_r);
    assign block_dot_positive = !block_dot_sum_r[ACC_WIDTH-1] &&
                                (block_dot_sum_r != {ACC_WIDTH{1'b0}});
    assign division_ready = block_dot_positive &&
                            (block_normalization_r != {DEN_WIDTH{1'b0}});

    assign serial_cross_ext = {{(DIVIDEND_WIDTH-ACC_WIDTH){1'b0}}, serial_cross_abs};
    assign serial_dot_ext = {{DEN_WIDTH{1'b0}}, serial_dot_abs};
    assign serial_numerator_add = ANGLE_FREQ_SCALE[serial_count] ?
                                  (serial_cross_ext << serial_count) :
                                  {DIVIDEND_WIDTH{1'b0}};
    assign serial_numerator_next = serial_numerator + serial_numerator_add;
    assign serial_denominator_next = serial_denominator + serial_denominator_add;
    assign division_divisor_next =
        {{(DIVIDEND_WIDTH+1-(ACC_WIDTH+DEN_WIDTH)){1'b0}}, serial_denominator_next};

    always @* begin
        serial_denominator_add = {(ACC_WIDTH+DEN_WIDTH){1'b0}};
        if ((serial_count < DEN_WIDTH) && serial_normalization[serial_count]) begin
            serial_denominator_add = serial_dot_ext << serial_count;
        end
    end

    assign divide_remainder_shift = {divide_remainder[DIVIDEND_WIDTH-1:0],
                                     divide_dividend[DIVIDEND_WIDTH-1]};
    assign divide_quotient_bit = divide_remainder_shift >= divide_divisor;
    assign divide_remainder_next = divide_quotient_bit ?
                                   (divide_remainder_shift - divide_divisor) :
                                   divide_remainder_shift;
    assign divide_quotient_next = {divide_quotient[DIVIDEND_WIDTH-2:0],
                                   divide_quotient_bit};

    function [ACC_WIDTH-1:0] abs_acc;
        input signed [ACC_WIDTH-1:0] value;
        begin
            abs_acc = value[ACC_WIDTH-1] ? (~value + {{(ACC_WIDTH-1){1'b0}}, 1'b1}) : value;
        end
    endfunction

    function signed [FERR_WIDTH-1:0] saturate_divide_result;
        input [DIVIDEND_WIDTH-1:0] magnitude;
        input negative;
        reg [DIVIDEND_WIDTH-1:0] pos_limit;
        reg [DIVIDEND_WIDTH-1:0] neg_limit;
        reg signed [FERR_WIDTH-1:0] signed_magnitude;
        begin
            pos_limit = {{(DIVIDEND_WIDTH-FERR_WIDTH){1'b0}}, FERR_POS_MAX};
            neg_limit = {{(DIVIDEND_WIDTH-FERR_WIDTH){1'b0}}, FERR_NEG_MIN};
            if (!negative) begin
                saturate_divide_result =
                    (magnitude > pos_limit) ? FERR_POS_MAX : magnitude[FERR_WIDTH-1:0];
            end else if (magnitude >= neg_limit) begin
                saturate_divide_result = FERR_NEG_MIN;
            end else begin
                signed_magnitude = $signed(magnitude[FERR_WIDTH-1:0]);
                saturate_divide_result = -signed_magnitude;
            end
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m || clear) begin
            for (idx = 0; idx < 8; idx = idx + 1) begin
                i_delay[idx] <= {IQ_WIDTH{1'b0}};
                q_delay[idx] <= {IQ_WIDTH{1'b0}};
            end
            valid_count <= 4'd0;
            block_count <= 6'd0;
            dot_acc <= {ACC_WIDTH{1'b0}};
            cross_acc <= {ACC_WIDTH{1'b0}};
            block_dot_sum_r <= {ACC_WIDTH{1'b0}};
            block_cross_sum_r <= {ACC_WIDTH{1'b0}};
            block_normalization_r <= {DEN_WIDTH{1'b0}};
            block_result_pending_r <= 1'b0;
            sample_i_r <= {IQ_WIDTH{1'b0}};
            sample_q_r <= {IQ_WIDTH{1'b0}};
            delayed_i_r <= {IQ_WIDTH{1'b0}};
            delayed_q_r <= {IQ_WIDTH{1'b0}};
            sample_normalization_r <= {DEN_WIDTH{1'b0}};
            sample_history_ready_r <= 1'b0;
            sample_math_state <= MATH_IDLE;
            sample_term_r <= 1'b0;
            dot_mul_a_r <= {IQ_WIDTH{1'b0}};
            dot_mul_b_r <= {IQ_WIDTH{1'b0}};
            cross_mul_a_r <= {IQ_WIDTH{1'b0}};
            cross_mul_b_r <= {IQ_WIDTH{1'b0}};
            dot_mul_product_r <= {PRODUCT_WIDTH{1'b0}};
            cross_mul_product_r <= {PRODUCT_WIDTH{1'b0}};
            mul_issue_valid_r <= 1'b0;
            mul_issue_term_r <= 1'b0;
            mul_return_valid_r <= 1'b0;
            mul_return_term_r <= 1'b0;
            dot_term0_r <= {PRODUCT_WIDTH{1'b0}};
            cross_term0_r <= {PRODUCT_WIDTH{1'b0}};
            scale_state <= SCALE_IDLE;
            serial_count <= 5'd0;
            serial_cross_abs <= {ACC_WIDTH{1'b0}};
            serial_dot_abs <= {ACC_WIDTH{1'b0}};
            serial_normalization <= {DEN_WIDTH{1'b0}};
            serial_negative <= 1'b0;
            serial_numerator <= {DIVIDEND_WIDTH{1'b0}};
            serial_denominator <= {(ACC_WIDTH+DEN_WIDTH){1'b0}};
            freq_error_valid <= 1'b0;
            freq_error_block_valid <= 1'b0;
            freq_error <= {FERR_WIDTH{1'b0}};
            ambiguous <= 1'b0;
            divide_busy <= 1'b0;
            divide_count <= 8'd0;
            divide_dividend <= {DIVIDEND_WIDTH{1'b0}};
            divide_quotient <= {DIVIDEND_WIDTH{1'b0}};
            divide_remainder <= {(DIVIDEND_WIDTH+1){1'b0}};
            divide_divisor <= {(DIVIDEND_WIDTH+1){1'b0}};
            divide_negative <= 1'b0;
            replay_count <= 6'd0;
            replay_freq_error <= {FERR_WIDTH{1'b0}};
            replay_ambiguous <= 1'b0;
        end else begin
            freq_error_valid <= 1'b0;
            freq_error_block_valid <= 1'b0;

            // The product and valid/tag pipelines advance independently of
            // the sample and result schedulers.
            dot_mul_product_r <= dot_mul_a_r * dot_mul_b_r;
            cross_mul_product_r <= cross_mul_a_r * cross_mul_b_r;
            mul_return_valid_r <= mul_issue_valid_r;
            mul_return_term_r <= mul_issue_term_r;
            mul_issue_valid_r <= 1'b0;

            if (divide_busy) begin
                divide_dividend <= {divide_dividend[DIVIDEND_WIDTH-2:0], 1'b0};
                divide_quotient <= divide_quotient_next;
                divide_remainder <= divide_remainder_next;
                divide_count <= divide_count - 1'b1;
                if (divide_count == 8'd1) begin
                    replay_freq_error <= saturate_divide_result(divide_quotient_next, divide_negative);
                    replay_ambiguous <= 1'b0;
                    replay_count <= BLOCK_SAMPLES;
                    divide_busy <= 1'b0;
                end
            end

            // Serial scaling is deliberately shift-add. The final additions
            // are passed directly to the divider so no bit is lost at the
            // handoff.
            if (scale_state == SCALE_RUN) begin
                serial_numerator <= serial_numerator_next;
                serial_denominator <= serial_denominator_next;
                if (serial_count == SCALE_WIDTH - 1) begin
                    scale_state <= SCALE_IDLE;
                    divide_busy <= 1'b1;
                    divide_count <= DIVIDEND_WIDTH;
                    divide_dividend <= serial_numerator_next;
                    divide_quotient <= {DIVIDEND_WIDTH{1'b0}};
                    divide_remainder <= {(DIVIDEND_WIDTH+1){1'b0}};
                    divide_divisor <= division_divisor_next;
                    divide_negative <= serial_negative;
                end else begin
                    serial_count <= serial_count + 1'b1;
                end
            end

            // Block sums are consumed one clock after the final sample
            // product retires. This register boundary keeps the 47-bit
            // accumulator and the replay/result control out of one path.
            if (block_result_pending_r) begin
                block_result_pending_r <= 1'b0;
                if (!result_busy) begin
                    if (division_ready) begin
                        scale_state <= SCALE_RUN;
                        serial_count <= 5'd0;
                        serial_cross_abs <= block_cross_abs;
                        serial_dot_abs <= block_dot_abs;
                        serial_normalization <= block_normalization_r;
                        serial_negative <= block_cross_sum_r[ACC_WIDTH-1];
                        serial_numerator <= {DIVIDEND_WIDTH{1'b0}};
                        serial_denominator <= {(ACC_WIDTH+DEN_WIDTH){1'b0}};
                    end else begin
                        replay_freq_error <= {FERR_WIDTH{1'b0}};
                        replay_ambiguous <= 1'b1;
                        replay_count <= BLOCK_SAMPLES;
                    end
                end
            end

            // A valid sample is accepted only while the sample arithmetic
            // engine is idle. Legal system cadences are much slower than the
            // five-cycle transaction; the assertion below diagnoses misuse.
            if (sample_valid && !sample_math_busy) begin
                if (replay_count != 6'd0) begin
                    freq_error <= replay_freq_error;
                    ambiguous <= replay_ambiguous;
                    freq_error_valid <= 1'b1;
                    if (replay_count == BLOCK_SAMPLES) begin
                        freq_error_block_valid <= 1'b1;
                    end
                    replay_count <= replay_count - 1'b1;
                end

                sample_i_r <= i_in;
                sample_q_r <= q_in;
                delayed_i_r <= delayed_i;
                delayed_q_r <= delayed_q;
                sample_normalization_r <= normalization_denominator;
                sample_history_ready_r <= enough_history;

                i_delay[0] <= i_in;
                q_delay[0] <= q_in;
                for (idx = 1; idx < 8; idx = idx + 1) begin
                    i_delay[idx] <= i_delay[idx-1];
                    q_delay[idx] <= q_delay[idx-1];
                end

                if (valid_count != 4'd15) begin
                    valid_count <= valid_count + 1'b1;
                end

                if (enough_history) begin
                    sample_math_state <= MATH_ISSUE;
                    sample_term_r <= 1'b0;
                end
            end

            // Retire the two products only after both pipelines have returned.
            // The term-1 product is explicitly included in dot_sum_next and
            // cross_sum_next, avoiding a nonblocking-assignment off-by-one.
            if (mul_return_valid_r) begin
                if (!mul_return_term_r) begin
                    dot_term0_r <= dot_mul_product_r;
                    cross_term0_r <= cross_mul_product_r;
                end else if (sample_history_ready_r) begin
                    if (block_done_next) begin
                        dot_acc <= {ACC_WIDTH{1'b0}};
                        cross_acc <= {ACC_WIDTH{1'b0}};
                        block_count <= 6'd0;
                        block_dot_sum_r <= dot_sum_next;
                        block_cross_sum_r <= cross_sum_next;
                        block_normalization_r <= sample_normalization_r;
                        block_result_pending_r <= 1'b1;
                    end else begin
                        dot_acc <= dot_sum_next;
                        cross_acc <= cross_sum_next;
                        block_count <= block_count + 1'b1;
                    end
                end
            end

            case (sample_math_state)
                MATH_ISSUE: begin
                    if (!sample_term_r) begin
                        dot_mul_a_r <= sample_i_r;
                        dot_mul_b_r <= delayed_i_r;
                        cross_mul_a_r <= sample_q_r;
                        cross_mul_b_r <= delayed_i_r;
                    end else begin
                        dot_mul_a_r <= sample_q_r;
                        dot_mul_b_r <= delayed_q_r;
                        cross_mul_a_r <= sample_i_r;
                        cross_mul_b_r <= delayed_q_r;
                    end
                    mul_issue_valid_r <= 1'b1;
                    mul_issue_term_r <= sample_term_r;
                    if (!sample_term_r) begin
                        sample_term_r <= 1'b1;
                    end else begin
                        sample_math_state <= MATH_DRAIN;
                    end
                end

                MATH_DRAIN: begin
                    if (mul_return_valid_r && mul_return_term_r) begin
                        sample_math_state <= MATH_IDLE;
                    end
                end

                default: begin
                    // MATH_IDLE accepts samples in the block above.
                end
            endcase
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_125m) begin
        if (!rst_125m && !clear && sample_valid && sample_math_busy) begin
            $fatal(1, "fll_cross_dot_stage_a sample arithmetic overrun");
        end
        if (!rst_125m && !clear && mul_return_valid_r && mul_return_term_r &&
            sample_history_ready_r && block_done_next && result_busy) begin
            $fatal(1, "fll_cross_dot_stage_a block result overrun");
        end
    end
`endif

endmodule

`default_nettype wire
