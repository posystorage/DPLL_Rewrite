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

function integer clog2;
    input integer value;
    integer shifted;
    begin
        shifted = value - 1;
        for (clog2 = 0; shifted > 0; clog2 = clog2 + 1) begin
            shifted = shifted >> 1;
        end
        if (clog2 < 1) begin
            clog2 = 1;
        end
    end
endfunction

localparam integer C_COUNTER_W = clog2(G_SAMPLE_DIV);

reg [2:0] rst_sync = 3'b111;
reg [C_COUNTER_W-1:0] sample_count = {C_COUNTER_W{1'b0}};

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
    if (rst_125m) begin
        sample_count <= {C_COUNTER_W{1'b0}};
        sample_valid <= 1'b0;
    end else if (sample_count == G_SAMPLE_DIV - 1) begin
        sample_count <= {C_COUNTER_W{1'b0}};
        sample_valid <= 1'b1;
    end else begin
        sample_count <= sample_count + {{C_COUNTER_W-1{1'b0}}, 1'b1};
        sample_valid <= 1'b0;
    end
end

endmodule

`default_nettype wire
