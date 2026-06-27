`timescale 1ns/1ps
`default_nettype none

module dpll_clock_valid_stage_a #(
    parameter integer G_SAMPLE_DIV = 40
) (
    input  wire clk_125m,
    input  wire rst_n_async,
    input  wire sw_reset_pulse,

    output wire rst_125m,
    output reg  sample_valid
);

reg [2:0] rst_sync = 3'b111;

always @(posedge clk_125m or negedge rst_n_async) begin
    if (!rst_n_async) begin
        rst_sync <= 3'b111;
    end else if (sw_reset_pulse) begin
        rst_sync <= 3'b111;
    end else begin
        rst_sync <= {rst_sync[1:0], 1'b0};
    end
end

assign rst_125m = rst_sync[2];

always @(posedge clk_125m) begin
    sample_valid <= 1'b0;
end

endmodule

`default_nettype wire
