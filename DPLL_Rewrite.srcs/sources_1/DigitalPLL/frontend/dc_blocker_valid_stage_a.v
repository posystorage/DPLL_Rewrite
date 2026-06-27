`timescale 1ns / 1ps
`default_nettype none

module dc_blocker_valid_stage_a #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ACC_WIDTH = 48,
    parameter integer LEAK_SHIFT = 7
) (
    input  wire                              clk_125m,
    input  wire                              rst_125m,
    input  wire                              in_valid,
    input  wire signed [DATA_WIDTH-1:0]      sample_in,
    output reg                               out_valid,
    output reg signed [DATA_WIDTH-1:0]       sample_out
);

    localparam integer INPUT_SHIFT = ACC_WIDTH - DATA_WIDTH - LEAK_SHIFT - 2;
    localparam integer OUTPUT_SHIFT = ACC_WIDTH - DATA_WIDTH - 1;

    reg signed [ACC_WIDTH-1:0] dc_accumulator;
    reg signed [ACC_WIDTH-1:0] hp_value;

    wire signed [ACC_WIDTH-1:0] sample_ext =
        {{(ACC_WIDTH-DATA_WIDTH){sample_in[DATA_WIDTH-1]}}, sample_in};
    wire signed [ACC_WIDTH-1:0] next_accumulator =
        dc_accumulator - (dc_accumulator >>> LEAK_SHIFT) + (sample_ext <<< INPUT_SHIFT);
    wire signed [ACC_WIDTH-1:0] next_hp_value =
        (sample_ext <<< (OUTPUT_SHIFT - 1)) - dc_accumulator
        + ({{(ACC_WIDTH-1){1'b0}}, 1'b1} <<< (OUTPUT_SHIFT - 2));
    wire signed [ACC_WIDTH-1:0] shifted_hp = hp_value >>> OUTPUT_SHIFT;

    function signed [DATA_WIDTH-1:0] saturate_to_data;
        input signed [ACC_WIDTH-1:0] value;
        reg signed [ACC_WIDTH-1:0] max_value;
        reg signed [ACC_WIDTH-1:0] min_value;
        begin
            max_value = {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {1'b0, {(DATA_WIDTH-1){1'b1}}}};
            min_value = -{{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {1'b1, {(DATA_WIDTH-1){1'b0}}}};
            if (value > max_value) begin
                saturate_to_data = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end else if (value < min_value) begin
                saturate_to_data = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                saturate_to_data = value[DATA_WIDTH-1:0];
            end
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            dc_accumulator <= {ACC_WIDTH{1'b0}};
            hp_value <= {ACC_WIDTH{1'b0}};
            sample_out <= {DATA_WIDTH{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                dc_accumulator <= next_accumulator;
                hp_value <= next_hp_value;
            end
            if (out_valid) begin
                sample_out <= saturate_to_data(shifted_hp);
            end
        end
    end

endmodule

`default_nettype wire
