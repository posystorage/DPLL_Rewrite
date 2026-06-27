`timescale 1ns / 1ps
`default_nettype none

module iq_mixer_stage_a #(
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer LO_WIDTH = 16,
    parameter integer OUTPUT_WIDTH = 18,
    parameter integer LO_FRAC_BITS = 14
) (
    input  wire                              clk_125m,
    input  wire                              rst_125m,
    input  wire                              in_valid,
    input  wire signed [SAMPLE_WIDTH-1:0]   sample_in,
    input  wire signed [LO_WIDTH-1:0]       cos_in,
    input  wire signed [LO_WIDTH-1:0]       sin_in,
    output reg                              out_valid,
    output reg signed [OUTPUT_WIDTH-1:0]    i_out,
    output reg signed [OUTPUT_WIDTH-1:0]    q_out
);

    localparam integer PRODUCT_WIDTH = SAMPLE_WIDTH + LO_WIDTH;

    wire signed [PRODUCT_WIDTH-1:0] i_product;
    wire signed [PRODUCT_WIDTH-1:0] q_product;
    wire signed [LO_WIDTH-1:0]      neg_sin;
    wire signed [PRODUCT_WIDTH-1:0] i_scaled;
    wire signed [PRODUCT_WIDTH-1:0] q_scaled;

    assign neg_sin   = -sin_in;
    assign i_product = sample_in * cos_in;
    assign q_product = sample_in * neg_sin;
    assign i_scaled  = i_product >>> LO_FRAC_BITS;
    assign q_scaled  = q_product >>> LO_FRAC_BITS;

    function signed [OUTPUT_WIDTH-1:0] saturate_to_output;
        input signed [PRODUCT_WIDTH-1:0] value;
        reg signed [PRODUCT_WIDTH-1:0] max_value;
        reg signed [PRODUCT_WIDTH-1:0] min_value;
        begin
            max_value = {{(PRODUCT_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b0, {(OUTPUT_WIDTH-1){1'b1}}}};
            min_value = -{{(PRODUCT_WIDTH-OUTPUT_WIDTH){1'b0}}, {1'b1, {(OUTPUT_WIDTH-1){1'b0}}}};
            if (value > max_value) begin
                saturate_to_output = {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
            end else if (value < min_value) begin
                saturate_to_output = {1'b1, {(OUTPUT_WIDTH-1){1'b0}}};
            end else begin
                saturate_to_output = value[OUTPUT_WIDTH-1:0];
            end
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            out_valid <= 1'b0;
            i_out <= {OUTPUT_WIDTH{1'b0}};
            q_out <= {OUTPUT_WIDTH{1'b0}};
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                i_out <= saturate_to_output(i_scaled);
                q_out <= saturate_to_output(q_scaled);
            end
        end
    end

endmodule

`default_nettype wire
