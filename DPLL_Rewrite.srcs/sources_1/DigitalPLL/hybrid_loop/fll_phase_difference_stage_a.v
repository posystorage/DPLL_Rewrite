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

`default_nettype wire
