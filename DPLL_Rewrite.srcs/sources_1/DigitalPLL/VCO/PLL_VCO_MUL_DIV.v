`timescale 1ns / 1ps
`default_nettype none

module PLL_VCO_MUL_DIV(
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_valid,
    input  wire [47:0] data_in,
    output reg  [47:0] data_out,
    input  wire [15:0] PLL_Mul_factor,
    input  wire [15:0] PLL_Div_factor,
    output reg         config_error
);

localparam [2:0] ST_IDLE      = 3'd0;
localparam [2:0] ST_MULT_WAIT = 3'd1;
localparam [2:0] ST_DIV_SEND  = 3'd2;
localparam [2:0] ST_DIV_WAIT  = 3'd3;
localparam [2:0] ST_DIV_ROUND = 3'd4;
localparam [2:0] ST_DIV_OUT   = 3'd5;
localparam integer MULT_LATENCY = 8;

reg [2:0] state = ST_IDLE;
reg [47:0] pending_word = 48'd0;
reg [15:0] pending_mul = 16'd1;
reg [15:0] pending_div = 16'd1;
reg pending_valid = 1'b0;

reg [47:0] mult_a = 48'd0;
reg [15:0] mult_b = 16'd1;
wire [63:0] mult_product;
reg [3:0] mult_wait_count = 4'd0;
reg [63:0] dividend_reg = 64'd0;
reg [15:0] divisor_reg = 16'd1;

reg divisor_valid = 1'b0;
reg dividend_valid = 1'b0;
wire divisor_ready;
wire dividend_ready;
wire div_result_valid;
wire [79:0] div_result;

reg [63:0] quotient_integer_reg = 64'd0;
reg round_bit_reg = 1'b0;
reg [64:0] rounded_quotient_reg = 65'd0;

wire requested_config_is_legal = (PLL_Mul_factor != 16'd0) &&
                                 (PLL_Div_factor != 16'd0);

function [47:0] sat_quotient_48;
    input [64:0] rounded_value;
    begin
        if (|rounded_value[64:48]) begin
            sat_quotient_48 = {48{1'b1}};
        end else begin
            sat_quotient_48 = rounded_value[47:0];
        end
    end
endfunction

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        pending_word <= 48'd0;
        pending_mul <= 16'd1;
        pending_div <= 16'd1;
        pending_valid <= 1'b0;
        mult_a <= 48'd0;
        mult_b <= 16'd1;
        mult_wait_count <= 4'd0;
        dividend_reg <= 64'd0;
        divisor_reg <= 16'd1;
        divisor_valid <= 1'b0;
        dividend_valid <= 1'b0;
        quotient_integer_reg <= 64'd0;
        round_bit_reg <= 1'b0;
        rounded_quotient_reg <= 65'd0;
        data_out <= 48'd0;
        config_error <= 1'b0;
    end else begin
        if (sample_valid) begin
            if (requested_config_is_legal) begin
                pending_word <= data_in;
                pending_mul <= PLL_Mul_factor;
                pending_div <= PLL_Div_factor;
                pending_valid <= 1'b1;
            end else begin
                config_error <= 1'b1;
            end
        end

        case (state)
            ST_IDLE: begin
                divisor_valid <= 1'b0;
                dividend_valid <= 1'b0;
                if (pending_valid) begin
                    mult_a <= pending_word;
                    mult_b <= pending_mul;
                    divisor_reg <= pending_div;
                    mult_wait_count <= MULT_LATENCY[3:0];
                    pending_valid <= 1'b0;
                    state <= ST_MULT_WAIT;
                end
            end

            ST_MULT_WAIT: begin
                if (mult_wait_count != 4'd0) begin
                    mult_wait_count <= mult_wait_count - 1'b1;
                end else begin
                    dividend_reg <= mult_product;
                    divisor_valid <= 1'b1;
                    dividend_valid <= 1'b1;
                    state <= ST_DIV_SEND;
                end
            end

            ST_DIV_SEND: begin
                if (divisor_valid && divisor_ready) begin
                    divisor_valid <= 1'b0;
                end
                if (dividend_valid && dividend_ready) begin
                    dividend_valid <= 1'b0;
                end
                if ((!divisor_valid || divisor_ready) &&
                    (!dividend_valid || dividend_ready)) begin
                    divisor_valid <= 1'b0;
                    dividend_valid <= 1'b0;
                    state <= ST_DIV_WAIT;
                end
            end

            ST_DIV_WAIT: begin
                if (div_result_valid) begin
                    quotient_integer_reg <= div_result[79:16];
                    round_bit_reg <= div_result[15];
                    state <= ST_DIV_ROUND;
                end
            end

            ST_DIV_ROUND: begin
                rounded_quotient_reg <= {1'b0, quotient_integer_reg} + {64'd0, round_bit_reg};
                state <= ST_DIV_OUT;
            end

            ST_DIV_OUT: begin
                data_out <= sat_quotient_48(rounded_quotient_reg);
                if (pending_valid) begin
                    mult_a <= pending_word;
                    mult_b <= pending_mul;
                    divisor_reg <= pending_div;
                    mult_wait_count <= MULT_LATENCY[3:0];
                    pending_valid <= 1'b0;
                    state <= ST_MULT_WAIT;
                end else begin
                    state <= ST_IDLE;
                end
            end

            default: begin
                divisor_valid <= 1'b0;
                dividend_valid <= 1'b0;
                mult_wait_count <= 4'd0;
                quotient_integer_reg <= 64'd0;
                round_bit_reg <= 1'b0;
                rounded_quotient_reg <= 65'd0;
                state <= ST_IDLE;
            end
        endcase
    end
end

mult_gen_pll VCO0_Multiplier(
    .CLK(clk),
    .A(mult_a),
    .B(mult_b),
    .P(mult_product)
);

div_gen_pll_u VCO0_Divider(
    .aclk(clk),
    .s_axis_divisor_tvalid(divisor_valid),
    .s_axis_divisor_tready(divisor_ready),
    .s_axis_divisor_tdata(divisor_reg),
    .s_axis_dividend_tvalid(dividend_valid),
    .s_axis_dividend_tready(dividend_ready),
    .s_axis_dividend_tdata(dividend_reg),
    .m_axis_dout_tvalid(div_result_valid),
    .m_axis_dout_tdata(div_result)
);

endmodule

`default_nettype wire
