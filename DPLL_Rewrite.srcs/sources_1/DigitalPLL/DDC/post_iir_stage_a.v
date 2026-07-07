`timescale 1ns / 1ps
`default_nettype none

module post_iir_stage_a #(
    parameter integer DATA_WIDTH = 20,
    parameter integer COEFF_WIDTH = 32,
    parameter integer COEFF_FRAC = 30,
    parameter integer ACC_WIDTH = 64
) (
    input  wire                                  clk_125m,
    input  wire                                  rst_125m,
    input  wire                                  clear,
    input  wire                                  in_valid,
    input  wire signed [DATA_WIDTH-1:0]          i_in,
    input  wire signed [DATA_WIDTH-1:0]          q_in,
    input  wire [1:0]                            mode,
    input  wire                                  state_use_track,
    input  wire signed [COEFF_WIDTH-1:0]         acq_b0,
    input  wire signed [COEFF_WIDTH-1:0]         acq_b1,
    input  wire signed [COEFF_WIDTH-1:0]         acq_b2,
    input  wire signed [COEFF_WIDTH-1:0]         acq_a1,
    input  wire signed [COEFF_WIDTH-1:0]         acq_a2,
    input  wire signed [COEFF_WIDTH-1:0]         track_b0,
    input  wire signed [COEFF_WIDTH-1:0]         track_b1,
    input  wire signed [COEFF_WIDTH-1:0]         track_b2,
    input  wire signed [COEFF_WIDTH-1:0]         track_a1,
    input  wire signed [COEFF_WIDTH-1:0]         track_a2,
    output reg                                   out_valid,
    output reg signed [DATA_WIDTH-1:0]           i_out,
    output reg signed [DATA_WIDTH-1:0]           q_out,
    output reg                                   active_bypass,
    output reg                                   active_use_track
);

    localparam integer PRODUCT_WIDTH = DATA_WIDTH + COEFF_WIDTH;
    localparam [1:0] MODE_BYPASS = 2'd0;
    localparam [1:0] MODE_ACQ    = 2'd1;
    localparam [1:0] MODE_TRACK  = 2'd2;
    localparam [1:0] MODE_AUTO   = 2'd3;

    localparam signed [ACC_WIDTH-1:0] ROUND_POS =
        {{(ACC_WIDTH-COEFF_FRAC-1){1'b0}}, 1'b1, {(COEFF_FRAC-1){1'b0}}};
    localparam signed [ACC_WIDTH-1:0] ROUND_NEG = ROUND_POS - 1'b1;

    reg signed [DATA_WIDTH-1:0] i_s1_x1;
    reg signed [DATA_WIDTH-1:0] i_s1_x2;
    reg signed [DATA_WIDTH-1:0] i_s1_y1;
    reg signed [DATA_WIDTH-1:0] i_s1_y2;
    reg signed [DATA_WIDTH-1:0] i_s2_x1;
    reg signed [DATA_WIDTH-1:0] i_s2_x2;
    reg signed [DATA_WIDTH-1:0] i_s2_y1;
    reg signed [DATA_WIDTH-1:0] i_s2_y2;
    reg signed [DATA_WIDTH-1:0] q_s1_x1;
    reg signed [DATA_WIDTH-1:0] q_s1_x2;
    reg signed [DATA_WIDTH-1:0] q_s1_y1;
    reg signed [DATA_WIDTH-1:0] q_s1_y2;
    reg signed [DATA_WIDTH-1:0] q_s2_x1;
    reg signed [DATA_WIDTH-1:0] q_s2_x2;
    reg signed [DATA_WIDTH-1:0] q_s2_y1;
    reg signed [DATA_WIDTH-1:0] q_s2_y2;

    wire request_bypass = (mode == MODE_BYPASS);
    wire request_use_track = (mode == MODE_TRACK) ||
                             ((mode == MODE_AUTO) && state_use_track);
    wire selection_changed = (active_bypass != request_bypass) ||
                             (active_use_track != request_use_track);

    wire signed [COEFF_WIDTH-1:0] b0 = request_use_track ? track_b0 : acq_b0;
    wire signed [COEFF_WIDTH-1:0] b1 = request_use_track ? track_b1 : acq_b1;
    wire signed [COEFF_WIDTH-1:0] b2 = request_use_track ? track_b2 : acq_b2;
    wire signed [COEFF_WIDTH-1:0] a1 = request_use_track ? track_a1 : acq_a1;
    wire signed [COEFF_WIDTH-1:0] a2 = request_use_track ? track_a2 : acq_a2;

    wire signed [ACC_WIDTH-1:0] i_s1_acc =
        coeff_mul(i_in, b0) + coeff_mul(i_s1_x1, b1) + coeff_mul(i_s1_x2, b2) -
        coeff_mul(i_s1_y1, a1) - coeff_mul(i_s1_y2, a2);
    wire signed [DATA_WIDTH-1:0] i_s1_next = round_sat(i_s1_acc);
    wire signed [ACC_WIDTH-1:0] i_s2_acc =
        coeff_mul(i_s1_next, b0) + coeff_mul(i_s2_x1, b1) + coeff_mul(i_s2_x2, b2) -
        coeff_mul(i_s2_y1, a1) - coeff_mul(i_s2_y2, a2);
    wire signed [DATA_WIDTH-1:0] i_s2_next = round_sat(i_s2_acc);

    wire signed [ACC_WIDTH-1:0] q_s1_acc =
        coeff_mul(q_in, b0) + coeff_mul(q_s1_x1, b1) + coeff_mul(q_s1_x2, b2) -
        coeff_mul(q_s1_y1, a1) - coeff_mul(q_s1_y2, a2);
    wire signed [DATA_WIDTH-1:0] q_s1_next = round_sat(q_s1_acc);
    wire signed [ACC_WIDTH-1:0] q_s2_acc =
        coeff_mul(q_s1_next, b0) + coeff_mul(q_s2_x1, b1) + coeff_mul(q_s2_x2, b2) -
        coeff_mul(q_s2_y1, a1) - coeff_mul(q_s2_y2, a2);
    wire signed [DATA_WIDTH-1:0] q_s2_next = round_sat(q_s2_acc);

    function signed [ACC_WIDTH-1:0] coeff_mul;
        input signed [DATA_WIDTH-1:0] sample;
        input signed [COEFF_WIDTH-1:0] coeff;
        reg signed [PRODUCT_WIDTH-1:0] product;
        begin
            product = sample * coeff;
            coeff_mul = {{(ACC_WIDTH-PRODUCT_WIDTH){product[PRODUCT_WIDTH-1]}}, product};
        end
    endfunction

    function signed [DATA_WIDTH-1:0] round_sat;
        input signed [ACC_WIDTH-1:0] value;
        reg signed [ACC_WIDTH-1:0] rounded;
        reg signed [ACC_WIDTH-1:0] shifted;
        reg signed [ACC_WIDTH-1:0] max_value;
        reg signed [ACC_WIDTH-1:0] min_value;
        begin
            rounded = value + (value[ACC_WIDTH-1] ? ROUND_NEG : ROUND_POS);
            shifted = rounded >>> COEFF_FRAC;
            max_value = {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {1'b0, {(DATA_WIDTH-1){1'b1}}}};
            min_value = -{{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {1'b1, {(DATA_WIDTH-1){1'b0}}}};

            if (shifted > max_value) begin
                round_sat = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end else if (shifted < min_value) begin
                round_sat = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                round_sat = shifted[DATA_WIDTH-1:0];
            end
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            out_valid <= 1'b0;
            i_out <= {DATA_WIDTH{1'b0}};
            q_out <= {DATA_WIDTH{1'b0}};
            active_bypass <= 1'b1;
            active_use_track <= 1'b0;
            i_s1_x1 <= {DATA_WIDTH{1'b0}};
            i_s1_x2 <= {DATA_WIDTH{1'b0}};
            i_s1_y1 <= {DATA_WIDTH{1'b0}};
            i_s1_y2 <= {DATA_WIDTH{1'b0}};
            i_s2_x1 <= {DATA_WIDTH{1'b0}};
            i_s2_x2 <= {DATA_WIDTH{1'b0}};
            i_s2_y1 <= {DATA_WIDTH{1'b0}};
            i_s2_y2 <= {DATA_WIDTH{1'b0}};
            q_s1_x1 <= {DATA_WIDTH{1'b0}};
            q_s1_x2 <= {DATA_WIDTH{1'b0}};
            q_s1_y1 <= {DATA_WIDTH{1'b0}};
            q_s1_y2 <= {DATA_WIDTH{1'b0}};
            q_s2_x1 <= {DATA_WIDTH{1'b0}};
            q_s2_x2 <= {DATA_WIDTH{1'b0}};
            q_s2_y1 <= {DATA_WIDTH{1'b0}};
            q_s2_y2 <= {DATA_WIDTH{1'b0}};
        end else begin
            active_bypass <= request_bypass;
            active_use_track <= request_use_track;

            if (clear || selection_changed) begin
                out_valid <= 1'b0;
                i_out <= {DATA_WIDTH{1'b0}};
                q_out <= {DATA_WIDTH{1'b0}};
                i_s1_x1 <= {DATA_WIDTH{1'b0}};
                i_s1_x2 <= {DATA_WIDTH{1'b0}};
                i_s1_y1 <= {DATA_WIDTH{1'b0}};
                i_s1_y2 <= {DATA_WIDTH{1'b0}};
                i_s2_x1 <= {DATA_WIDTH{1'b0}};
                i_s2_x2 <= {DATA_WIDTH{1'b0}};
                i_s2_y1 <= {DATA_WIDTH{1'b0}};
                i_s2_y2 <= {DATA_WIDTH{1'b0}};
                q_s1_x1 <= {DATA_WIDTH{1'b0}};
                q_s1_x2 <= {DATA_WIDTH{1'b0}};
                q_s1_y1 <= {DATA_WIDTH{1'b0}};
                q_s1_y2 <= {DATA_WIDTH{1'b0}};
                q_s2_x1 <= {DATA_WIDTH{1'b0}};
                q_s2_x2 <= {DATA_WIDTH{1'b0}};
                q_s2_y1 <= {DATA_WIDTH{1'b0}};
                q_s2_y2 <= {DATA_WIDTH{1'b0}};
            end else begin
                out_valid <= in_valid;
                if (in_valid) begin
                    if (request_bypass) begin
                        i_out <= i_in;
                        q_out <= q_in;
                    end else begin
                        i_out <= i_s2_next;
                        q_out <= q_s2_next;

                        i_s1_x2 <= i_s1_x1;
                        i_s1_x1 <= i_in;
                        i_s1_y2 <= i_s1_y1;
                        i_s1_y1 <= i_s1_next;
                        i_s2_x2 <= i_s2_x1;
                        i_s2_x1 <= i_s1_next;
                        i_s2_y2 <= i_s2_y1;
                        i_s2_y1 <= i_s2_next;

                        q_s1_x2 <= q_s1_x1;
                        q_s1_x1 <= q_in;
                        q_s1_y2 <= q_s1_y1;
                        q_s1_y1 <= q_s1_next;
                        q_s2_x2 <= q_s2_x1;
                        q_s2_x1 <= q_s1_next;
                        q_s2_y2 <= q_s2_y1;
                        q_s2_y1 <= q_s2_next;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
