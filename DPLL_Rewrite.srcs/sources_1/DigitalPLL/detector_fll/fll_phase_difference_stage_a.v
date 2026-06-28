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
    output reg                               freq_error_valid,
    output reg signed [FERR_WIDTH-1:0]       freq_error,
    output reg                               ambiguous
);

    reg signed [PHASE_WIDTH-1:0] phase_delay [0:7];
    reg [3:0] valid_count;
    integer idx;

    wire signed [PHASE_WIDTH-1:0] delayed_phase;
    wire signed [PHASE_WIDTH-1:0] phase_delta_wrapped;
    wire [3:0] selected_delay;

    assign selected_delay =
        (delay_sel == 2'd0) ? 4'd1 :
        (delay_sel == 2'd1) ? 4'd2 :
        (delay_sel == 2'd2) ? 4'd4 : 4'd8;

    assign delayed_phase =
        (delay_sel == 2'd0) ? phase_delay[0] :
        (delay_sel == 2'd1) ? phase_delay[1] :
        (delay_sel == 2'd2) ? phase_delay[3] : phase_delay[7];

    assign phase_delta_wrapped = phase_in - delayed_phase;

    always @(posedge clk_125m) begin
        if (rst_125m || clear) begin
            for (idx = 0; idx < 8; idx = idx + 1) begin
                phase_delay[idx] <= {PHASE_WIDTH{1'b0}};
            end
            valid_count <= 4'd0;
            freq_error_valid <= 1'b0;
            freq_error <= {FERR_WIDTH{1'b0}};
            ambiguous <= 1'b0;
        end else begin
            freq_error_valid <= 1'b0;

            if (phase_valid) begin
                phase_delay[0] <= phase_in;
                for (idx = 1; idx < 8; idx = idx + 1) begin
                    phase_delay[idx] <= phase_delay[idx-1];
                end
                if (valid_count != 4'd15) begin
                    valid_count <= valid_count + 1'b1;
                end

                if (valid_count >= selected_delay) begin
                    freq_error <= {{(FERR_WIDTH-PHASE_WIDTH){phase_delta_wrapped[PHASE_WIDTH-1]}}, phase_delta_wrapped};
                    ambiguous <= (phase_delta_wrapped == {1'b0, {(PHASE_WIDTH-1){1'b1}}})
                              || (phase_delta_wrapped == {1'b1, {(PHASE_WIDTH-1){1'b0}}});
                    freq_error_valid <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
