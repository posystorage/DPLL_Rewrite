`timescale 1ns / 1ps
`default_nettype none

module fll_phase_difference_stage_a #(
    parameter integer PHASE_WIDTH = 18,
    parameter integer FERR_WIDTH = 22
) (
    input  wire                              clk_125m,
    input  wire                              rst_125m,
    input  wire                              phase_valid,
    input  wire signed [PHASE_WIDTH-1:0]     phase_in,
    input  wire [1:0]                        delay_sel,
    output reg                               freq_error_valid,
    output reg signed [FERR_WIDTH-1:0]       freq_error,
    output reg                               ambiguous
);

    reg signed [PHASE_WIDTH-1:0] phase_z1;
    reg signed [PHASE_WIDTH-1:0] phase_z2;
    reg signed [PHASE_WIDTH-1:0] phase_z4;
    reg signed [PHASE_WIDTH-1:0] phase_z8;
    reg [3:0] valid_count;

    wire signed [PHASE_WIDTH-1:0] delayed_phase;
    wire signed [PHASE_WIDTH:0] phase_delta_ext;
    wire [3:0] selected_delay;

    assign selected_delay =
        (delay_sel == 2'd0) ? 4'd1 :
        (delay_sel == 2'd1) ? 4'd2 :
        (delay_sel == 2'd2) ? 4'd4 : 4'd8;

    assign delayed_phase =
        (delay_sel == 2'd0) ? phase_z1 :
        (delay_sel == 2'd1) ? phase_z2 :
        (delay_sel == 2'd2) ? phase_z4 : phase_z8;

    assign phase_delta_ext = {phase_in[PHASE_WIDTH-1], phase_in} - {delayed_phase[PHASE_WIDTH-1], delayed_phase};

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            phase_z1 <= {PHASE_WIDTH{1'b0}};
            phase_z2 <= {PHASE_WIDTH{1'b0}};
            phase_z4 <= {PHASE_WIDTH{1'b0}};
            phase_z8 <= {PHASE_WIDTH{1'b0}};
            valid_count <= 4'd0;
            freq_error_valid <= 1'b0;
            freq_error <= {FERR_WIDTH{1'b0}};
            ambiguous <= 1'b0;
        end else begin
            freq_error_valid <= 1'b0;

            if (phase_valid) begin
                phase_z1 <= phase_in;
                phase_z2 <= phase_z1;
                phase_z4 <= phase_z2;
                phase_z8 <= phase_z4;
                if (valid_count != 4'd15) begin
                    valid_count <= valid_count + 1'b1;
                end

                if (valid_count >= selected_delay) begin
                    freq_error <= {{(FERR_WIDTH-PHASE_WIDTH-1){phase_delta_ext[PHASE_WIDTH]}}, phase_delta_ext};
                    ambiguous <= (phase_delta_ext == {1'b0, {PHASE_WIDTH{1'b1}}})
                              || (phase_delta_ext == {1'b1, {PHASE_WIDTH{1'b0}}});
                    freq_error_valid <= 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
