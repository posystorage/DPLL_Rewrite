`timescale 1ns / 1ps
`default_nettype none

module post_iq_cic_stage_a #(
    parameter integer INPUT_WIDTH = 18,
    parameter integer ACC_WIDTH = 44,
    parameter integer OUTPUT_WIDTH = 20,
    parameter integer RATE_WIDTH = 9,
    parameter integer SHIFT_WIDTH = 6
) (
    input  wire                             clk_125m,
    input  wire                             rst_125m,
    input  wire                             in_valid,
    input  wire signed [INPUT_WIDTH-1:0]    i_in,
    input  wire signed [INPUT_WIDTH-1:0]    q_in,
    input  wire                             config_apply,
    input  wire [RATE_WIDTH-1:0]            shadow_rate_r,
    input  wire [SHIFT_WIDTH-1:0]           shadow_output_shift,
    input  wire                             flush,
    output reg                              out_valid,
    output reg signed [OUTPUT_WIDTH-1:0]    i_out,
    output reg signed [OUTPUT_WIDTH-1:0]    q_out,
    output reg [RATE_WIDTH-1:0]             active_rate_r,
    output reg [SHIFT_WIDTH-1:0]            active_output_shift,
    output reg                              overflow_seen,
    output reg                              illegal_config_seen
);

    localparam [RATE_WIDTH-1:0] MIN_RATE = {{(RATE_WIDTH-4){1'b0}}, 4'd8};
    localparam [RATE_WIDTH-1:0] MAX_RATE = 9'd312;
    localparam integer ROUND_WIDTH = ACC_WIDTH + 1;
    localparam [2:0] WARMUP_OUTPUT_COUNT = 3'd3;

    reg signed [ACC_WIDTH-1:0] i_int0;
    reg signed [ACC_WIDTH-1:0] i_int1;
    reg signed [ACC_WIDTH-1:0] i_int2;
    reg signed [ACC_WIDTH-1:0] q_int0;
    reg signed [ACC_WIDTH-1:0] q_int1;
    reg signed [ACC_WIDTH-1:0] q_int2;

    reg signed [ACC_WIDTH-1:0] i_comb_d0;
    reg signed [ACC_WIDTH-1:0] i_comb_d1;
    reg signed [ACC_WIDTH-1:0] i_comb_d2;
    reg signed [ACC_WIDTH-1:0] q_comb_d0;
    reg signed [ACC_WIDTH-1:0] q_comb_d1;
    reg signed [ACC_WIDTH-1:0] q_comb_d2;

    reg signed [ACC_WIDTH-1:0] i_decim_sample;
    reg signed [ACC_WIDTH-1:0] q_decim_sample;
    reg signed [ACC_WIDTH-1:0] i_comb1;
    reg signed [ACC_WIDTH-1:0] q_comb1;
    reg signed [ACC_WIDTH-1:0] i_comb2;
    reg signed [ACC_WIDTH-1:0] q_comb2;
    reg signed [ACC_WIDTH-1:0] i_comb3;
    reg signed [ACC_WIDTH-1:0] q_comb3;
    reg signed [ROUND_WIDTH-1:0] i_shifted;
    reg signed [ROUND_WIDTH-1:0] q_shifted;
    reg signed [ROUND_WIDTH-1:0] i_shift_stage0;
    reg signed [ROUND_WIDTH-1:0] q_shift_stage0;
    reg signed [ROUND_WIDTH-1:0] i_shift_stage1;
    reg signed [ROUND_WIDTH-1:0] q_shift_stage1;
    reg signed [ROUND_WIDTH-1:0] i_shift_stage2;
    reg signed [ROUND_WIDTH-1:0] q_shift_stage2;
    reg signed [ROUND_WIDTH-1:0] i_shift_stage3;
    reg signed [ROUND_WIDTH-1:0] q_shift_stage3;
    reg signed [ROUND_WIDTH-1:0] i_shift_stage4;
    reg signed [ROUND_WIDTH-1:0] q_shift_stage4;
    reg signed [ROUND_WIDTH-1:0] i_shift_stage5;
    reg signed [ROUND_WIDTH-1:0] q_shift_stage5;
    reg signed [ROUND_WIDTH-1:0] i_rounded;
    reg signed [ROUND_WIDTH-1:0] q_rounded;
    reg comb0_valid;
    reg comb1_valid;
    reg comb2_valid;
    reg output_pipe_valid;
    reg [6:0] shift_pipe_valid;
    reg rounded_output_valid;

    reg [RATE_WIDTH-1:0] sample_count;
    reg [2:0] warmup_outputs_remaining;
    reg signed [ROUND_WIDTH-1:0] active_rounding_bias;
    reg clear_control;
    reg clear_i_integrators;
    reg clear_q_integrators;
    reg clear_comb_delay;
    reg clear_comb_pipeline;
    reg clear_shift_pipeline;

    wire apply_is_legal;
    wire clear_request;
    wire signed [ACC_WIDTH-1:0] i_ext;
    wire signed [ACC_WIDTH-1:0] q_ext;
    wire signed [ROUND_WIDTH-1:0] i_comb3_ext;
    wire signed [ROUND_WIDTH-1:0] q_comb3_ext;
    wire signed [ROUND_WIDTH-1:0] i_rounding_bias_signed;
    wire signed [ROUND_WIDTH-1:0] q_rounding_bias_signed;

    assign apply_is_legal = (shadow_rate_r >= MIN_RATE) && (shadow_rate_r <= MAX_RATE);
    assign clear_request = rst_125m || flush || (config_apply && apply_is_legal);
    assign i_ext = {{(ACC_WIDTH-INPUT_WIDTH){i_in[INPUT_WIDTH-1]}}, i_in};
    assign q_ext = {{(ACC_WIDTH-INPUT_WIDTH){q_in[INPUT_WIDTH-1]}}, q_in};
    assign i_comb3_ext = {i_comb3[ACC_WIDTH-1], i_comb3};
    assign q_comb3_ext = {q_comb3[ACC_WIDTH-1], q_comb3};
    assign i_rounding_bias_signed = i_comb3[ACC_WIDTH-1] ? -active_rounding_bias : active_rounding_bias;
    assign q_rounding_bias_signed = q_comb3[ACC_WIDTH-1] ? -active_rounding_bias : active_rounding_bias;

    function signed [OUTPUT_WIDTH-1:0] saturate_shifted;
        input signed [ROUND_WIDTH-1:0] shifted;
        reg signed [ROUND_WIDTH-1:0] max_value;
        reg signed [ROUND_WIDTH-1:0] min_value;
        begin
            max_value = {{(ROUND_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b0, {(OUTPUT_WIDTH-1){1'b1}}}};
            min_value = -{{(ROUND_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b1, {(OUTPUT_WIDTH-1){1'b0}}}};

            if (shifted > max_value) begin
                saturate_shifted = {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
            end else if (shifted < min_value) begin
                saturate_shifted = {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};
            end else begin
                saturate_shifted = shifted[OUTPUT_WIDTH-1:0];
            end
        end
    endfunction

    function signed [ROUND_WIDTH-1:0] rounding_bias_for_shift;
        input [SHIFT_WIDTH-1:0] shift;
        begin
            if (shift == {SHIFT_WIDTH{1'b0}}) begin
                rounding_bias_for_shift = {ROUND_WIDTH{1'b0}};
            end else if (shift >= ROUND_WIDTH) begin
                rounding_bias_for_shift = {ROUND_WIDTH{1'b0}};
            end else begin
                rounding_bias_for_shift = {{(ROUND_WIDTH-1){1'b0}}, 1'b1} << (shift - 1'b1);
            end
        end
    endfunction

    function shifted_saturation_needed;
        input signed [ROUND_WIDTH-1:0] shifted;
        reg signed [ROUND_WIDTH-1:0] max_value;
        reg signed [ROUND_WIDTH-1:0] min_value;
        begin
            max_value = {{(ROUND_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b0, {(OUTPUT_WIDTH-1){1'b1}}}};
            min_value = -{{(ROUND_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b1, {(OUTPUT_WIDTH-1){1'b0}}}};
            shifted_saturation_needed = (shifted > max_value) || (shifted < min_value);
        end
    endfunction

    always @(posedge clk_125m) begin
        clear_control <= clear_request;
        clear_i_integrators <= clear_request;
        clear_q_integrators <= clear_request;
        clear_comb_delay <= clear_request;
        clear_comb_pipeline <= clear_request;
        clear_shift_pipeline <= clear_request;
    end

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            active_rate_r <= MIN_RATE;
            active_output_shift <= {SHIFT_WIDTH{1'b0}};
            active_rounding_bias <= {ROUND_WIDTH{1'b0}};
            illegal_config_seen <= 1'b0;
        end else if (config_apply) begin
            if (apply_is_legal) begin
                active_rate_r <= shadow_rate_r;
                active_output_shift <= shadow_output_shift;
                active_rounding_bias <= rounding_bias_for_shift(shadow_output_shift);
            end else begin
                illegal_config_seen <= 1'b1;
            end
        end
    end

    always @(posedge clk_125m) begin
        if (clear_control) begin
            comb0_valid <= 1'b0;
            comb1_valid <= 1'b0;
            comb2_valid <= 1'b0;
            output_pipe_valid <= 1'b0;
            shift_pipe_valid <= 7'b0000000;
            rounded_output_valid <= 1'b0;
            sample_count <= {RATE_WIDTH{1'b0}};
            warmup_outputs_remaining <= WARMUP_OUTPUT_COUNT;
            out_valid <= 1'b0;
            i_out <= {OUTPUT_WIDTH{1'b0}};
            q_out <= {OUTPUT_WIDTH{1'b0}};
            overflow_seen <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            comb0_valid <= 1'b0;
            comb1_valid <= comb0_valid;
            comb2_valid <= comb1_valid;
            output_pipe_valid <= comb2_valid;
            shift_pipe_valid <= {shift_pipe_valid[5:0], output_pipe_valid};
            rounded_output_valid <= 1'b0;

            if (in_valid) begin
                if (sample_count == active_rate_r - 1'b1) begin
                    comb0_valid <= 1'b1;
                    sample_count <= {RATE_WIDTH{1'b0}};
                end else begin
                    sample_count <= sample_count + 1'b1;
                end
            end

            if (shift_pipe_valid[6]) begin
                if (warmup_outputs_remaining != 3'd0) begin
                    warmup_outputs_remaining <= warmup_outputs_remaining - 1'b1;
                end else begin
                    rounded_output_valid <= 1'b1;
                end
            end

            if (rounded_output_valid) begin
                i_out <= saturate_shifted(i_rounded);
                q_out <= saturate_shifted(q_rounded);
                overflow_seen <= overflow_seen
                    || shifted_saturation_needed(i_rounded)
                    || shifted_saturation_needed(q_rounded);
                out_valid <= 1'b1;
            end
        end

        if (clear_i_integrators) begin
            i_int0 <= {ACC_WIDTH{1'b0}};
            i_int1 <= {ACC_WIDTH{1'b0}};
            i_int2 <= {ACC_WIDTH{1'b0}};
        end else if (in_valid && !clear_control) begin
            i_int0 <= i_int0 + i_ext;
            i_int1 <= i_int1 + i_int0;
            i_int2 <= i_int2 + i_int1;
        end

        if (clear_q_integrators) begin
            q_int0 <= {ACC_WIDTH{1'b0}};
            q_int1 <= {ACC_WIDTH{1'b0}};
            q_int2 <= {ACC_WIDTH{1'b0}};
        end else if (in_valid && !clear_control) begin
            q_int0 <= q_int0 + q_ext;
            q_int1 <= q_int1 + q_int0;
            q_int2 <= q_int2 + q_int1;
        end

        if (clear_comb_delay) begin
            i_comb_d0 <= {ACC_WIDTH{1'b0}};
            i_comb_d1 <= {ACC_WIDTH{1'b0}};
            i_comb_d2 <= {ACC_WIDTH{1'b0}};
            q_comb_d0 <= {ACC_WIDTH{1'b0}};
            q_comb_d1 <= {ACC_WIDTH{1'b0}};
            q_comb_d2 <= {ACC_WIDTH{1'b0}};
        end else if (!clear_control) begin
            if (comb0_valid) begin
                i_comb_d0 <= i_decim_sample;
                q_comb_d0 <= q_decim_sample;
            end

            if (comb1_valid) begin
                i_comb_d1 <= i_comb1;
                q_comb_d1 <= q_comb1;
            end

            if (comb2_valid) begin
                i_comb_d2 <= i_comb2;
                q_comb_d2 <= q_comb2;
            end
        end

        if (clear_comb_pipeline) begin
            i_decim_sample <= {ACC_WIDTH{1'b0}};
            q_decim_sample <= {ACC_WIDTH{1'b0}};
            i_comb1 <= {ACC_WIDTH{1'b0}};
            q_comb1 <= {ACC_WIDTH{1'b0}};
            i_comb2 <= {ACC_WIDTH{1'b0}};
            q_comb2 <= {ACC_WIDTH{1'b0}};
            i_comb3 <= {ACC_WIDTH{1'b0}};
            q_comb3 <= {ACC_WIDTH{1'b0}};
        end else if (!clear_control) begin
            if (in_valid && (sample_count == active_rate_r - 1'b1)) begin
                i_decim_sample <= i_int2;
                q_decim_sample <= q_int2;
            end

            if (comb0_valid) begin
                i_comb1 <= i_decim_sample - i_comb_d0;
                q_comb1 <= q_decim_sample - q_comb_d0;
            end

            if (comb1_valid) begin
                i_comb2 <= i_comb1 - i_comb_d1;
                q_comb2 <= q_comb1 - q_comb_d1;
            end

            if (comb2_valid) begin
                i_comb3 <= i_comb2 - i_comb_d2;
                q_comb3 <= q_comb2 - q_comb_d2;
            end
        end

        if (clear_shift_pipeline) begin
            i_shifted <= {ROUND_WIDTH{1'b0}};
            q_shifted <= {ROUND_WIDTH{1'b0}};
            i_shift_stage0 <= {ROUND_WIDTH{1'b0}};
            q_shift_stage0 <= {ROUND_WIDTH{1'b0}};
            i_shift_stage1 <= {ROUND_WIDTH{1'b0}};
            q_shift_stage1 <= {ROUND_WIDTH{1'b0}};
            i_shift_stage2 <= {ROUND_WIDTH{1'b0}};
            q_shift_stage2 <= {ROUND_WIDTH{1'b0}};
            i_shift_stage3 <= {ROUND_WIDTH{1'b0}};
            q_shift_stage3 <= {ROUND_WIDTH{1'b0}};
            i_shift_stage4 <= {ROUND_WIDTH{1'b0}};
            q_shift_stage4 <= {ROUND_WIDTH{1'b0}};
            i_shift_stage5 <= {ROUND_WIDTH{1'b0}};
            q_shift_stage5 <= {ROUND_WIDTH{1'b0}};
            i_rounded <= {ROUND_WIDTH{1'b0}};
            q_rounded <= {ROUND_WIDTH{1'b0}};
        end else if (!clear_control) begin
            if (output_pipe_valid) begin
                i_shift_stage0 <= i_comb3_ext + i_rounding_bias_signed;
                q_shift_stage0 <= q_comb3_ext + q_rounding_bias_signed;
            end

            if (shift_pipe_valid[0]) begin
                i_shift_stage1 <= active_output_shift[0] ? (i_shift_stage0 >>> 1) : i_shift_stage0;
                q_shift_stage1 <= active_output_shift[0] ? (q_shift_stage0 >>> 1) : q_shift_stage0;
            end

            if (shift_pipe_valid[1]) begin
                i_shift_stage2 <= active_output_shift[1] ? (i_shift_stage1 >>> 2) : i_shift_stage1;
                q_shift_stage2 <= active_output_shift[1] ? (q_shift_stage1 >>> 2) : q_shift_stage1;
            end

            if (shift_pipe_valid[2]) begin
                i_shift_stage3 <= active_output_shift[2] ? (i_shift_stage2 >>> 4) : i_shift_stage2;
                q_shift_stage3 <= active_output_shift[2] ? (q_shift_stage2 >>> 4) : q_shift_stage2;
            end

            if (shift_pipe_valid[3]) begin
                i_shift_stage4 <= active_output_shift[3] ? (i_shift_stage3 >>> 8) : i_shift_stage3;
                q_shift_stage4 <= active_output_shift[3] ? (q_shift_stage3 >>> 8) : q_shift_stage3;
            end

            if (shift_pipe_valid[4]) begin
                i_shift_stage5 <= active_output_shift[4] ? (i_shift_stage4 >>> 16) : i_shift_stage4;
                q_shift_stage5 <= active_output_shift[4] ? (q_shift_stage4 >>> 16) : q_shift_stage4;
            end

            if (shift_pipe_valid[5]) begin
                i_shifted <= active_output_shift[5] ? (i_shift_stage5 >>> 32) : i_shift_stage5;
                q_shifted <= active_output_shift[5] ? (q_shift_stage5 >>> 32) : q_shift_stage5;
            end

            if (shift_pipe_valid[6]) begin
                if (warmup_outputs_remaining == 3'd0) begin
                    i_rounded <= i_shifted;
                    q_rounded <= q_shifted;
                end
            end
        end
    end

endmodule

`default_nettype wire
