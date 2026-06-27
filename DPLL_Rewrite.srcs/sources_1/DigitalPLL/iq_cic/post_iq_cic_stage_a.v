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
    reg signed [ACC_WIDTH-1:0] i_shifted;
    reg signed [ACC_WIDTH-1:0] q_shifted;
    reg signed [ACC_WIDTH-1:0] i_shift_stage0;
    reg signed [ACC_WIDTH-1:0] q_shift_stage0;
    reg signed [ACC_WIDTH-1:0] i_shift_stage1;
    reg signed [ACC_WIDTH-1:0] q_shift_stage1;
    reg signed [ACC_WIDTH-1:0] i_shift_stage2;
    reg signed [ACC_WIDTH-1:0] q_shift_stage2;
    reg signed [ACC_WIDTH-1:0] i_shift_stage3;
    reg signed [ACC_WIDTH-1:0] q_shift_stage3;
    reg signed [ACC_WIDTH-1:0] i_shift_stage4;
    reg signed [ACC_WIDTH-1:0] q_shift_stage4;
    reg signed [ACC_WIDTH-1:0] i_shift_stage5;
    reg signed [ACC_WIDTH-1:0] q_shift_stage5;
    reg comb0_valid;
    reg comb1_valid;
    reg comb2_valid;
    reg output_pipe_valid;
    reg [6:0] shift_pipe_valid;

    reg [RATE_WIDTH-1:0] sample_count;

    wire apply_is_legal;
    wire signed [ACC_WIDTH-1:0] i_ext;
    wire signed [ACC_WIDTH-1:0] q_ext;

    assign apply_is_legal = (shadow_rate_r >= MIN_RATE) && (shadow_rate_r <= MAX_RATE);
    assign i_ext = {{(ACC_WIDTH-INPUT_WIDTH){i_in[INPUT_WIDTH-1]}}, i_in};
    assign q_ext = {{(ACC_WIDTH-INPUT_WIDTH){q_in[INPUT_WIDTH-1]}}, q_in};

    function signed [OUTPUT_WIDTH-1:0] saturate_shifted;
        input signed [ACC_WIDTH-1:0] shifted;
        reg signed [ACC_WIDTH-1:0] max_value;
        reg signed [ACC_WIDTH-1:0] min_value;
        begin
            max_value = {{(ACC_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b0, {(OUTPUT_WIDTH-1){1'b1}}}};
            min_value = -{{(ACC_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b1, {(OUTPUT_WIDTH-1){1'b0}}}};

            if (shifted > max_value) begin
                saturate_shifted = {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
            end else if (shifted < min_value) begin
                saturate_shifted = {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};
            end else begin
                saturate_shifted = shifted[OUTPUT_WIDTH-1:0];
            end
        end
    endfunction

    function shifted_saturation_needed;
        input signed [ACC_WIDTH-1:0] shifted;
        reg signed [ACC_WIDTH-1:0] max_value;
        reg signed [ACC_WIDTH-1:0] min_value;
        begin
            max_value = {{(ACC_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b0, {(OUTPUT_WIDTH-1){1'b1}}}};
            min_value = -{{(ACC_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b1, {(OUTPUT_WIDTH-1){1'b0}}}};
            shifted_saturation_needed = (shifted > max_value) || (shifted < min_value);
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            active_rate_r <= MIN_RATE;
            active_output_shift <= {SHIFT_WIDTH{1'b0}};
            illegal_config_seen <= 1'b0;
        end else if (config_apply) begin
            if (apply_is_legal) begin
                active_rate_r <= shadow_rate_r;
                active_output_shift <= shadow_output_shift;
            end else begin
                illegal_config_seen <= 1'b1;
            end
        end
    end

    always @(posedge clk_125m) begin
        if (rst_125m || flush || (config_apply && apply_is_legal)) begin
            i_int0 <= {ACC_WIDTH{1'b0}};
            i_int1 <= {ACC_WIDTH{1'b0}};
            i_int2 <= {ACC_WIDTH{1'b0}};
            q_int0 <= {ACC_WIDTH{1'b0}};
            q_int1 <= {ACC_WIDTH{1'b0}};
            q_int2 <= {ACC_WIDTH{1'b0}};
            i_comb_d0 <= {ACC_WIDTH{1'b0}};
            i_comb_d1 <= {ACC_WIDTH{1'b0}};
            i_comb_d2 <= {ACC_WIDTH{1'b0}};
            q_comb_d0 <= {ACC_WIDTH{1'b0}};
            q_comb_d1 <= {ACC_WIDTH{1'b0}};
            q_comb_d2 <= {ACC_WIDTH{1'b0}};
            i_decim_sample <= {ACC_WIDTH{1'b0}};
            q_decim_sample <= {ACC_WIDTH{1'b0}};
            i_comb1 <= {ACC_WIDTH{1'b0}};
            q_comb1 <= {ACC_WIDTH{1'b0}};
            i_comb2 <= {ACC_WIDTH{1'b0}};
            q_comb2 <= {ACC_WIDTH{1'b0}};
            i_comb3 <= {ACC_WIDTH{1'b0}};
            q_comb3 <= {ACC_WIDTH{1'b0}};
            i_shifted <= {ACC_WIDTH{1'b0}};
            q_shifted <= {ACC_WIDTH{1'b0}};
            i_shift_stage0 <= {ACC_WIDTH{1'b0}};
            q_shift_stage0 <= {ACC_WIDTH{1'b0}};
            i_shift_stage1 <= {ACC_WIDTH{1'b0}};
            q_shift_stage1 <= {ACC_WIDTH{1'b0}};
            i_shift_stage2 <= {ACC_WIDTH{1'b0}};
            q_shift_stage2 <= {ACC_WIDTH{1'b0}};
            i_shift_stage3 <= {ACC_WIDTH{1'b0}};
            q_shift_stage3 <= {ACC_WIDTH{1'b0}};
            i_shift_stage4 <= {ACC_WIDTH{1'b0}};
            q_shift_stage4 <= {ACC_WIDTH{1'b0}};
            i_shift_stage5 <= {ACC_WIDTH{1'b0}};
            q_shift_stage5 <= {ACC_WIDTH{1'b0}};
            comb0_valid <= 1'b0;
            comb1_valid <= 1'b0;
            comb2_valid <= 1'b0;
            output_pipe_valid <= 1'b0;
            shift_pipe_valid <= 7'b0000000;
            sample_count <= {RATE_WIDTH{1'b0}};
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

            if (in_valid) begin
                i_int0 <= i_int0 + i_ext;
                i_int1 <= i_int1 + i_int0;
                i_int2 <= i_int2 + i_int1;
                q_int0 <= q_int0 + q_ext;
                q_int1 <= q_int1 + q_int0;
                q_int2 <= q_int2 + q_int1;

                if (sample_count == active_rate_r - 1'b1) begin
                    i_decim_sample <= i_int2;
                    q_decim_sample <= q_int2;
                    comb0_valid <= 1'b1;
                    sample_count <= {RATE_WIDTH{1'b0}};
                end else begin
                    sample_count <= sample_count + 1'b1;
                end
            end

            if (comb0_valid) begin
                i_comb1 <= i_decim_sample - i_comb_d0;
                q_comb1 <= q_decim_sample - q_comb_d0;
                i_comb_d0 <= i_decim_sample;
                q_comb_d0 <= q_decim_sample;
            end

            if (comb1_valid) begin
                i_comb2 <= i_comb1 - i_comb_d1;
                q_comb2 <= q_comb1 - q_comb_d1;
                i_comb_d1 <= i_comb1;
                q_comb_d1 <= q_comb1;
            end

            if (comb2_valid) begin
                i_comb3 <= i_comb2 - i_comb_d2;
                q_comb3 <= q_comb2 - q_comb_d2;
                i_comb_d2 <= i_comb2;
                q_comb_d2 <= q_comb2;
            end

            if (output_pipe_valid) begin
                i_shift_stage0 <= active_output_shift[0] ? (i_comb3 >>> 1) : i_comb3;
                q_shift_stage0 <= active_output_shift[0] ? (q_comb3 >>> 1) : q_comb3;
            end

            if (shift_pipe_valid[0]) begin
                i_shift_stage1 <= active_output_shift[1] ? (i_shift_stage0 >>> 2) : i_shift_stage0;
                q_shift_stage1 <= active_output_shift[1] ? (q_shift_stage0 >>> 2) : q_shift_stage0;
            end

            if (shift_pipe_valid[1]) begin
                i_shift_stage2 <= active_output_shift[2] ? (i_shift_stage1 >>> 4) : i_shift_stage1;
                q_shift_stage2 <= active_output_shift[2] ? (q_shift_stage1 >>> 4) : q_shift_stage1;
            end

            if (shift_pipe_valid[2]) begin
                i_shift_stage3 <= active_output_shift[3] ? (i_shift_stage2 >>> 8) : i_shift_stage2;
                q_shift_stage3 <= active_output_shift[3] ? (q_shift_stage2 >>> 8) : q_shift_stage2;
            end

            if (shift_pipe_valid[3]) begin
                i_shift_stage4 <= active_output_shift[4] ? (i_shift_stage3 >>> 16) : i_shift_stage3;
                q_shift_stage4 <= active_output_shift[4] ? (q_shift_stage3 >>> 16) : q_shift_stage3;
            end

            if (shift_pipe_valid[4]) begin
                i_shift_stage5 <= active_output_shift[5] ? (i_shift_stage4 >>> 32) : i_shift_stage4;
                q_shift_stage5 <= active_output_shift[5] ? (q_shift_stage4 >>> 32) : q_shift_stage4;
            end

            if (shift_pipe_valid[5]) begin
                i_shifted <= i_shift_stage5;
                q_shifted <= q_shift_stage5;
            end

            if (shift_pipe_valid[6]) begin
                i_out <= saturate_shifted(i_shifted);
                q_out <= saturate_shifted(q_shifted);
                overflow_seen <= overflow_seen
                    || shifted_saturation_needed(i_shifted)
                    || shifted_saturation_needed(q_shifted);
                out_valid <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
