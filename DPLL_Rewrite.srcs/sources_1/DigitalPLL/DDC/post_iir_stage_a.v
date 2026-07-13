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
    localparam integer MUL_LATENCY = 2;
    localparam [1:0] MODE_BYPASS = 2'd0;
    localparam [1:0] MODE_ACQ    = 2'd1;
    localparam [1:0] MODE_TRACK  = 2'd2;
    localparam [1:0] MODE_AUTO   = 2'd3;

    localparam [1:0] FILTER_IDLE  = 2'd0;
    localparam [1:0] FILTER_ISSUE = 2'd1;
    localparam [1:0] FILTER_DRAIN = 2'd2;

    localparam signed [ACC_WIDTH-1:0] ROUND_POS =
        {{(ACC_WIDTH-COEFF_FRAC-1){1'b0}}, 1'b1, {(COEFF_FRAC-1){1'b0}}};
    localparam signed [ACC_WIDTH-1:0] ROUND_NEG = ROUND_POS - 1'b1;

    // Committed I/Q histories. They are updated only when a complete IQ
    // transaction has retired.
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

    // Transaction snapshot. Coefficients and histories cannot change while
    // the five terms of each section are being issued.
    reg signed [DATA_WIDTH-1:0] tx_i_in;
    reg signed [DATA_WIDTH-1:0] tx_q_in;
    reg signed [DATA_WIDTH-1:0] tx_i_s1_x1;
    reg signed [DATA_WIDTH-1:0] tx_i_s1_x2;
    reg signed [DATA_WIDTH-1:0] tx_i_s1_y1;
    reg signed [DATA_WIDTH-1:0] tx_i_s1_y2;
    reg signed [DATA_WIDTH-1:0] tx_i_s2_x1;
    reg signed [DATA_WIDTH-1:0] tx_i_s2_x2;
    reg signed [DATA_WIDTH-1:0] tx_i_s2_y1;
    reg signed [DATA_WIDTH-1:0] tx_i_s2_y2;
    reg signed [DATA_WIDTH-1:0] tx_q_s1_x1;
    reg signed [DATA_WIDTH-1:0] tx_q_s1_x2;
    reg signed [DATA_WIDTH-1:0] tx_q_s1_y1;
    reg signed [DATA_WIDTH-1:0] tx_q_s1_y2;
    reg signed [DATA_WIDTH-1:0] tx_q_s2_x1;
    reg signed [DATA_WIDTH-1:0] tx_q_s2_x2;
    reg signed [DATA_WIDTH-1:0] tx_q_s2_y1;
    reg signed [DATA_WIDTH-1:0] tx_q_s2_y2;
    reg signed [COEFF_WIDTH-1:0] tx_b0;
    reg signed [COEFF_WIDTH-1:0] tx_b1;
    reg signed [COEFF_WIDTH-1:0] tx_b2;
    reg signed [COEFF_WIDTH-1:0] tx_a1;
    reg signed [COEFF_WIDTH-1:0] tx_a2;

    reg signed [DATA_WIDTH-1:0] tx_i_s1_next;
    reg signed [DATA_WIDTH-1:0] tx_q_s1_next;

    reg [1:0] filter_state;
    reg       section_r;
    reg [2:0] term_r;
    wire      filter_busy = (filter_state != FILTER_IDLE);

    reg signed [ACC_WIDTH-1:0] i_accum_r;
    reg signed [ACC_WIDTH-1:0] q_accum_r;
    reg signed [ACC_WIDTH-1:0] i_final_sum_r;
    reg signed [ACC_WIDTH-1:0] q_final_sum_r;
    reg                         final_pending_r;
    reg                         final_section_r;
    reg signed [ACC_WIDTH-1:0] i_round_sum_r;
    reg signed [ACC_WIDTH-1:0] q_round_sum_r;
    reg                         round_sum_pending_r;
    reg                         round_sum_section_r;

    // One independent signed wide multiplier pipeline per channel. These are
    // the only two multiplication expressions in this module.
    reg signed [DATA_WIDTH-1:0] i_mul_sample_r;
    reg signed [COEFF_WIDTH-1:0] i_mul_coeff_r;
    reg signed [DATA_WIDTH-1:0] q_mul_sample_r;
    reg signed [COEFF_WIDTH-1:0] q_mul_coeff_r;
    reg                          mul_issue_valid_r;
    reg                          mul_issue_section_r;
    reg [2:0]                    mul_issue_term_r;
    reg                          mul_issue_subtract_r;

    reg signed [PRODUCT_WIDTH-1:0] i_mul_product_pipe_r;
    reg signed [PRODUCT_WIDTH-1:0] q_mul_product_pipe_r;
    (* use_dsp = "yes" *) reg signed [PRODUCT_WIDTH-1:0] i_mul_product_r;
    (* use_dsp = "yes" *) reg signed [PRODUCT_WIDTH-1:0] q_mul_product_r;
    reg                          mul_product_valid_r;
    reg                          mul_product_section_r;
    reg [2:0]                    mul_product_term_r;
    reg                          mul_product_subtract_r;
    reg                          mul_return_valid_r;
    reg                          mul_return_section_r;
    reg [2:0]                    mul_return_term_r;
    reg                          mul_return_subtract_r;

    wire request_bypass = (mode == MODE_BYPASS);
    wire request_use_track = (mode == MODE_TRACK) ||
                             ((mode == MODE_AUTO) && state_use_track);
    wire selection_changed = (active_bypass != request_bypass) ||
                             (active_use_track != request_use_track);

    reg signed [DATA_WIDTH-1:0] issue_i_sample;
    reg signed [DATA_WIDTH-1:0] issue_q_sample;
    reg signed [COEFF_WIDTH-1:0] issue_coeff;
    reg issue_subtract;

    always @* begin
        issue_i_sample = {DATA_WIDTH{1'b0}};
        issue_q_sample = {DATA_WIDTH{1'b0}};
        issue_coeff = {COEFF_WIDTH{1'b0}};
        issue_subtract = 1'b0;

        if (filter_state == FILTER_ISSUE) begin
            if (!section_r) begin
                case (term_r)
                    3'd0: begin
                        issue_i_sample = tx_i_in;
                        issue_q_sample = tx_q_in;
                        issue_coeff = tx_b0;
                    end
                    3'd1: begin
                        issue_i_sample = tx_i_s1_x1;
                        issue_q_sample = tx_q_s1_x1;
                        issue_coeff = tx_b1;
                    end
                    3'd2: begin
                        issue_i_sample = tx_i_s1_x2;
                        issue_q_sample = tx_q_s1_x2;
                        issue_coeff = tx_b2;
                    end
                    3'd3: begin
                        issue_i_sample = tx_i_s1_y1;
                        issue_q_sample = tx_q_s1_y1;
                        issue_coeff = tx_a1;
                        issue_subtract = 1'b1;
                    end
                    default: begin
                        issue_i_sample = tx_i_s1_y2;
                        issue_q_sample = tx_q_s1_y2;
                        issue_coeff = tx_a2;
                        issue_subtract = 1'b1;
                    end
                endcase
            end else begin
                case (term_r)
                    3'd0: begin
                        issue_i_sample = tx_i_s1_next;
                        issue_q_sample = tx_q_s1_next;
                        issue_coeff = tx_b0;
                    end
                    3'd1: begin
                        issue_i_sample = tx_i_s2_x1;
                        issue_q_sample = tx_q_s2_x1;
                        issue_coeff = tx_b1;
                    end
                    3'd2: begin
                        issue_i_sample = tx_i_s2_x2;
                        issue_q_sample = tx_q_s2_x2;
                        issue_coeff = tx_b2;
                    end
                    3'd3: begin
                        issue_i_sample = tx_i_s2_y1;
                        issue_q_sample = tx_q_s2_y1;
                        issue_coeff = tx_a1;
                        issue_subtract = 1'b1;
                    end
                    default: begin
                        issue_i_sample = tx_i_s2_y2;
                        issue_q_sample = tx_q_s2_y2;
                        issue_coeff = tx_a2;
                        issue_subtract = 1'b1;
                    end
                endcase
            end
        end
    end

    wire signed [ACC_WIDTH-1:0] i_product_ext =
        {{(ACC_WIDTH-PRODUCT_WIDTH){i_mul_product_r[PRODUCT_WIDTH-1]}}, i_mul_product_r};
    wire signed [ACC_WIDTH-1:0] q_product_ext =
        {{(ACC_WIDTH-PRODUCT_WIDTH){q_mul_product_r[PRODUCT_WIDTH-1]}}, q_mul_product_r};
    wire signed [ACC_WIDTH-1:0] i_product_signed =
        mul_return_subtract_r ? -i_product_ext : i_product_ext;
    wire signed [ACC_WIDTH-1:0] q_product_signed =
        mul_return_subtract_r ? -q_product_ext : q_product_ext;
    wire signed [ACC_WIDTH-1:0] i_accum_with_product = i_accum_r + i_product_signed;
    wire signed [ACC_WIDTH-1:0] q_accum_with_product = q_accum_r + q_product_signed;

    function signed [DATA_WIDTH-1:0] saturate_rounded;
        input signed [ACC_WIDTH-1:0] rounded;
        reg signed [ACC_WIDTH-1:0] shifted;
        reg signed [ACC_WIDTH-1:0] max_value;
        reg signed [ACC_WIDTH-1:0] min_value;
        begin
            shifted = rounded >>> COEFF_FRAC;
            max_value = {{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {1'b0, {(DATA_WIDTH-1){1'b1}}}};
            min_value = -{{(ACC_WIDTH-DATA_WIDTH){1'b0}}, {1'b1, {(DATA_WIDTH-1){1'b0}}}};

            if (shifted > max_value) begin
                saturate_rounded = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end else if (shifted < min_value) begin
                saturate_rounded = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                saturate_rounded = shifted[DATA_WIDTH-1:0];
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

            tx_i_in <= {DATA_WIDTH{1'b0}};
            tx_q_in <= {DATA_WIDTH{1'b0}};
            tx_i_s1_x1 <= {DATA_WIDTH{1'b0}};
            tx_i_s1_x2 <= {DATA_WIDTH{1'b0}};
            tx_i_s1_y1 <= {DATA_WIDTH{1'b0}};
            tx_i_s1_y2 <= {DATA_WIDTH{1'b0}};
            tx_i_s2_x1 <= {DATA_WIDTH{1'b0}};
            tx_i_s2_x2 <= {DATA_WIDTH{1'b0}};
            tx_i_s2_y1 <= {DATA_WIDTH{1'b0}};
            tx_i_s2_y2 <= {DATA_WIDTH{1'b0}};
            tx_q_s1_x1 <= {DATA_WIDTH{1'b0}};
            tx_q_s1_x2 <= {DATA_WIDTH{1'b0}};
            tx_q_s1_y1 <= {DATA_WIDTH{1'b0}};
            tx_q_s1_y2 <= {DATA_WIDTH{1'b0}};
            tx_q_s2_x1 <= {DATA_WIDTH{1'b0}};
            tx_q_s2_x2 <= {DATA_WIDTH{1'b0}};
            tx_q_s2_y1 <= {DATA_WIDTH{1'b0}};
            tx_q_s2_y2 <= {DATA_WIDTH{1'b0}};
            tx_b0 <= {COEFF_WIDTH{1'b0}};
            tx_b1 <= {COEFF_WIDTH{1'b0}};
            tx_b2 <= {COEFF_WIDTH{1'b0}};
            tx_a1 <= {COEFF_WIDTH{1'b0}};
            tx_a2 <= {COEFF_WIDTH{1'b0}};
            tx_i_s1_next <= {DATA_WIDTH{1'b0}};
            tx_q_s1_next <= {DATA_WIDTH{1'b0}};

            filter_state <= FILTER_IDLE;
            section_r <= 1'b0;
            term_r <= 3'd0;
            i_accum_r <= {ACC_WIDTH{1'b0}};
            q_accum_r <= {ACC_WIDTH{1'b0}};
            i_final_sum_r <= {ACC_WIDTH{1'b0}};
            q_final_sum_r <= {ACC_WIDTH{1'b0}};
            final_pending_r <= 1'b0;
            final_section_r <= 1'b0;
            i_round_sum_r <= {ACC_WIDTH{1'b0}};
            q_round_sum_r <= {ACC_WIDTH{1'b0}};
            round_sum_pending_r <= 1'b0;
            round_sum_section_r <= 1'b0;

            i_mul_sample_r <= {DATA_WIDTH{1'b0}};
            i_mul_coeff_r <= {COEFF_WIDTH{1'b0}};
            q_mul_sample_r <= {DATA_WIDTH{1'b0}};
            q_mul_coeff_r <= {COEFF_WIDTH{1'b0}};
            mul_issue_valid_r <= 1'b0;
            mul_issue_section_r <= 1'b0;
            mul_issue_term_r <= 3'd0;
            mul_issue_subtract_r <= 1'b0;
            i_mul_product_pipe_r <= {PRODUCT_WIDTH{1'b0}};
            q_mul_product_pipe_r <= {PRODUCT_WIDTH{1'b0}};
            i_mul_product_r <= {PRODUCT_WIDTH{1'b0}};
            q_mul_product_r <= {PRODUCT_WIDTH{1'b0}};
            mul_product_valid_r <= 1'b0;
            mul_product_section_r <= 1'b0;
            mul_product_term_r <= 3'd0;
            mul_product_subtract_r <= 1'b0;
            mul_return_valid_r <= 1'b0;
            mul_return_section_r <= 1'b0;
            mul_return_term_r <= 3'd0;
            mul_return_subtract_r <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            active_bypass <= request_bypass;
            active_use_track <= request_use_track;

            // Input-register -> two product-register pipeline. The extra
            // product register lets both DSPs in each 20x32 cascade use a
            // pipeline register at 125 MHz.
            i_mul_product_pipe_r <= i_mul_sample_r * i_mul_coeff_r;
            q_mul_product_pipe_r <= q_mul_sample_r * q_mul_coeff_r;
            i_mul_product_r <= i_mul_product_pipe_r;
            q_mul_product_r <= q_mul_product_pipe_r;
            mul_product_valid_r <= mul_issue_valid_r;
            mul_product_section_r <= mul_issue_section_r;
            mul_product_term_r <= mul_issue_term_r;
            mul_product_subtract_r <= mul_issue_subtract_r;
            mul_return_valid_r <= mul_product_valid_r;
            mul_return_section_r <= mul_product_section_r;
            mul_return_term_r <= mul_product_term_r;
            mul_return_subtract_r <= mul_product_subtract_r;
            mul_issue_valid_r <= 1'b0;

            if (clear || selection_changed) begin
                out_valid <= 1'b0;
                i_out <= {DATA_WIDTH{1'b0}};
                q_out <= {DATA_WIDTH{1'b0}};
                filter_state <= FILTER_IDLE;
                section_r <= 1'b0;
                term_r <= 3'd0;
                i_accum_r <= {ACC_WIDTH{1'b0}};
                q_accum_r <= {ACC_WIDTH{1'b0}};
                i_final_sum_r <= {ACC_WIDTH{1'b0}};
                q_final_sum_r <= {ACC_WIDTH{1'b0}};
                final_pending_r <= 1'b0;
                final_section_r <= 1'b0;
                i_round_sum_r <= {ACC_WIDTH{1'b0}};
                q_round_sum_r <= {ACC_WIDTH{1'b0}};
                round_sum_pending_r <= 1'b0;
                round_sum_section_r <= 1'b0;
                mul_issue_valid_r <= 1'b0;
                mul_product_valid_r <= 1'b0;
                mul_return_valid_r <= 1'b0;

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
                // Add the round constant in its own stage. The following
                // stage performs the shift/saturation and commits the
                // section, keeping both the 64-bit add and the compare chain
                // out of a single routed timing path.
                if (final_pending_r) begin
                    final_pending_r <= 1'b0;
                    i_round_sum_r <= i_final_sum_r +
                                     (i_final_sum_r[ACC_WIDTH-1] ? ROUND_NEG : ROUND_POS);
                    q_round_sum_r <= q_final_sum_r +
                                     (q_final_sum_r[ACC_WIDTH-1] ? ROUND_NEG : ROUND_POS);
                    round_sum_section_r <= final_section_r;
                    round_sum_pending_r <= 1'b1;
                end

                if (round_sum_pending_r) begin
                    round_sum_pending_r <= 1'b0;
                    if (!round_sum_section_r) begin
                        tx_i_s1_next <= saturate_rounded(i_round_sum_r);
                        tx_q_s1_next <= saturate_rounded(q_round_sum_r);
                        section_r <= 1'b1;
                        term_r <= 3'd0;
                        filter_state <= FILTER_ISSUE;
                    end else begin
                        i_out <= saturate_rounded(i_round_sum_r);
                        q_out <= saturate_rounded(q_round_sum_r);
                        out_valid <= 1'b1;

                        i_s1_x2 <= tx_i_s1_x1;
                        i_s1_x1 <= tx_i_in;
                        i_s1_y2 <= tx_i_s1_y1;
                        i_s1_y1 <= tx_i_s1_next;
                        i_s2_x2 <= tx_i_s2_x1;
                        i_s2_x1 <= tx_i_s1_next;
                        i_s2_y2 <= tx_i_s2_y1;
                        i_s2_y1 <= saturate_rounded(i_round_sum_r);

                        q_s1_x2 <= tx_q_s1_x1;
                        q_s1_x1 <= tx_q_in;
                        q_s1_y2 <= tx_q_s1_y1;
                        q_s1_y1 <= tx_q_s1_next;
                        q_s2_x2 <= tx_q_s2_x1;
                        q_s2_x1 <= tx_q_s1_next;
                        q_s2_y2 <= tx_q_s2_y1;
                        q_s2_y1 <= saturate_rounded(q_round_sum_r);

                        filter_state <= FILTER_IDLE;
                    end
                end

                // Retire a product before issuing the next term. The final
                // product is explicitly included in the registered section
                // sum; it is never rounded from the old accumulator.
                if (mul_return_valid_r) begin
                    if (mul_return_term_r == 3'd4) begin
                        i_final_sum_r <= i_accum_with_product;
                        q_final_sum_r <= q_accum_with_product;
                        final_section_r <= mul_return_section_r;
                        final_pending_r <= 1'b1;
                        i_accum_r <= {ACC_WIDTH{1'b0}};
                        q_accum_r <= {ACC_WIDTH{1'b0}};
                    end else begin
                        i_accum_r <= i_accum_with_product;
                        q_accum_r <= q_accum_with_product;
                    end
                end

                case (filter_state)
                    FILTER_IDLE: begin
                        if (request_bypass) begin
                            if (in_valid) begin
                                i_out <= i_in;
                                q_out <= q_in;
                                out_valid <= 1'b1;
                            end
                        end else if (in_valid) begin
                            tx_i_in <= i_in;
                            tx_q_in <= q_in;
                            tx_i_s1_x1 <= i_s1_x1;
                            tx_i_s1_x2 <= i_s1_x2;
                            tx_i_s1_y1 <= i_s1_y1;
                            tx_i_s1_y2 <= i_s1_y2;
                            tx_i_s2_x1 <= i_s2_x1;
                            tx_i_s2_x2 <= i_s2_x2;
                            tx_i_s2_y1 <= i_s2_y1;
                            tx_i_s2_y2 <= i_s2_y2;
                            tx_q_s1_x1 <= q_s1_x1;
                            tx_q_s1_x2 <= q_s1_x2;
                            tx_q_s1_y1 <= q_s1_y1;
                            tx_q_s1_y2 <= q_s1_y2;
                            tx_q_s2_x1 <= q_s2_x1;
                            tx_q_s2_x2 <= q_s2_x2;
                            tx_q_s2_y1 <= q_s2_y1;
                            tx_q_s2_y2 <= q_s2_y2;
                            tx_b0 <= request_use_track ? track_b0 : acq_b0;
                            tx_b1 <= request_use_track ? track_b1 : acq_b1;
                            tx_b2 <= request_use_track ? track_b2 : acq_b2;
                            tx_a1 <= request_use_track ? track_a1 : acq_a1;
                            tx_a2 <= request_use_track ? track_a2 : acq_a2;
                            i_accum_r <= {ACC_WIDTH{1'b0}};
                            q_accum_r <= {ACC_WIDTH{1'b0}};
                            section_r <= 1'b0;
                            term_r <= 3'd0;
                            filter_state <= FILTER_ISSUE;
                        end
                    end

                    FILTER_ISSUE: begin
                        i_mul_sample_r <= issue_i_sample;
                        i_mul_coeff_r <= issue_coeff;
                        q_mul_sample_r <= issue_q_sample;
                        q_mul_coeff_r <= issue_coeff;
                        mul_issue_valid_r <= 1'b1;
                        mul_issue_section_r <= section_r;
                        mul_issue_term_r <= term_r;
                        mul_issue_subtract_r <= issue_subtract;

                        if (term_r == 3'd4) begin
                            filter_state <= FILTER_DRAIN;
                        end else begin
                            term_r <= term_r + 1'b1;
                        end
                    end

                    default: begin
                        // FILTER_DRAIN waits for the final tagged product.
                        // The retire block above advances the section or
                        // commits the complete IQ transaction.
                        // final_pending_r advances the section after the
                        // registered sum has been rounded.
                    end
                endcase
            end
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk_125m) begin
        if (!rst_125m && !clear && !selection_changed && filter_busy && in_valid) begin
            $fatal(1, "post_iir_stage_a filtered input overrun");
        end
    end
`endif

endmodule

`default_nettype wire
