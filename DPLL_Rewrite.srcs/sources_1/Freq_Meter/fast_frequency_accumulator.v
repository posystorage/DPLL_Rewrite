`timescale 1ns / 1ps
`default_nettype none

// Continuous reference accumulator for display and host monitoring.
// The triggered precision accumulator in Digital_Freq_Meter remains separate.
module fast_frequency_accumulator (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] phase_increment,
    input  wire [31:0] interval_cycles,
    output reg  [79:0] result,
    output reg  [31:0] result_interval_cycles,
    output reg  [30:0] update_sequence,
    output reg         result_valid
);

reg [79:0] accumulator;
reg [31:0] elapsed_cycles;
reg [31:0] active_interval_cycles;

wire [31:0] sanitized_interval_cycles;
assign sanitized_interval_cycles = (interval_cycles == 32'd0) ? 32'd1 : interval_cycles;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        accumulator            <= 80'd0;
        elapsed_cycles         <= 32'd0;
        active_interval_cycles <= 32'd0;
        result                 <= 80'd0;
        result_interval_cycles <= 32'd0;
        update_sequence        <= 31'd0;
        result_valid           <= 1'b0;
    end
    else if (active_interval_cycles == 32'd0) begin
        accumulator            <= {{48{1'b0}}, phase_increment};
        elapsed_cycles         <= 32'd1;
        active_interval_cycles <= sanitized_interval_cycles;
    end
    else if (elapsed_cycles >= active_interval_cycles) begin
        result                 <= accumulator;
        result_interval_cycles <= active_interval_cycles;
        update_sequence        <= update_sequence + 1'b1;
        result_valid           <= 1'b1;

        accumulator            <= {{48{1'b0}}, phase_increment};
        elapsed_cycles         <= 32'd1;
        active_interval_cycles <= sanitized_interval_cycles;
    end
    else begin
        accumulator    <= accumulator + phase_increment;
        elapsed_cycles <= elapsed_cycles + 1'b1;
    end
end

endmodule

`default_nettype wire
