`timescale 1ns / 1ps
`default_nettype none

module tracking_phase_accumulator_stage_a #(
    parameter integer WORD_WIDTH = 48,
    parameter integer PHASE_WIDTH = 18
) (
    input  wire                         clk_125m,
    input  wire                         rst_125m,
    input  wire                         enable,
    input  wire [WORD_WIDTH-1:0]        tracking_word,
    output reg  [WORD_WIDTH-1:0]        phase_accum,
    output wire [PHASE_WIDTH-1:0]       phase_word,
    output reg                          phase_valid
);

    assign phase_word = phase_accum[WORD_WIDTH-1 -: PHASE_WIDTH];

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            phase_accum <= {WORD_WIDTH{1'b0}};
            phase_valid <= 1'b0;
        end else if (enable) begin
            phase_accum <= phase_accum + tracking_word;
            phase_valid <= 1'b1;
        end else begin
            phase_valid <= 1'b0;
        end
    end

endmodule

`default_nettype wire
