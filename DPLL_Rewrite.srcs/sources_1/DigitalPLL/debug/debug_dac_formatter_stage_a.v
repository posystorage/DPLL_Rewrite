`timescale 1ns / 1ps
`default_nettype none

module debug_dac_formatter_stage_a (
    input  wire                    clk_125m,
    input  wire                    rst_125m,
    input  wire                    source_valid,
    input  wire signed [31:0]      source_word,
    input  wire [31:0]             format_word,
    input  wire signed [15:0]      gain,
    input  wire signed [15:0]      offset,
    output reg  signed [15:0]      dac_sample
);

    localparam [1:0] MODE_RAW_BIT_WINDOW = 2'd0;
    localparam [1:0] MODE_ARITH_SHIFT_SAT = 2'd1;
    localparam [1:0] MODE_UNSIGNED_SAT = 2'd2;

    reg signed [31:0] source_r0;
    reg [5:0] shift_or_lsb_r0;
    reg [1:0] mode_r0;
    reg invert_r0;
    reg hold_last_r0;
    reg signed [15:0] gain_r0;
    reg signed [15:0] offset_r0;
    reg valid_r0;

    reg signed [15:0] raw_window_r1;
    reg [31:0] shifted_unsigned_r1;
    reg signed [47:0] product_r1;
    reg [1:0] mode_r1;
    reg invert_r1;
    reg hold_last_r1;
    reg signed [15:0] offset_r1;
    reg valid_r1;

    reg signed [31:0] formatted_r2;
    reg signed [15:0] raw_window_r2;
    reg [1:0] mode_r2;
    reg invert_r2;
    reg hold_last_r2;
    reg valid_r2;

    wire [4:0] raw_lsb = (shift_or_lsb_r0 > 6'd16) ? 5'd16 : shift_or_lsb_r0[4:0];
    wire [4:0] shift_amount = (shift_or_lsb_r0 > 6'd31) ? 5'd31 : shift_or_lsb_r0[4:0];
    wire signed [31:0] shifted_signed = source_r0 >>> shift_amount;
    wire [31:0] shifted_unsigned = $unsigned(source_r0) >> shift_amount;
    wire signed [31:0] scaled_plus_offset =
        product_r1[46:15] + {{16{offset_r1[15]}}, offset_r1};

    function signed [15:0] sat_signed16;
        input signed [31:0] value;
        begin
            if (value > 32'sd32767) begin
                sat_signed16 = 16'sd32767;
            end else if (value < -32'sd32768) begin
                sat_signed16 = -16'sd32768;
            end else begin
                sat_signed16 = value[15:0];
            end
        end
    endfunction

    function signed [15:0] sat_unsigned15;
        input [31:0] value;
        begin
            if (value > 32'd32767) begin
                sat_unsigned15 = 16'sd32767;
            end else begin
                sat_unsigned15 = {1'b0, value[14:0]};
            end
        end
    endfunction

    function signed [15:0] apply_invert;
        input signed [15:0] value;
        input invert;
        begin
            if (!invert) begin
                apply_invert = value;
            end else if (value == -16'sd32768) begin
                apply_invert = 16'sd32767;
            end else begin
                apply_invert = -value;
            end
        end
    endfunction

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            source_r0 <= 32'sd0;
            shift_or_lsb_r0 <= 6'd0;
            mode_r0 <= MODE_RAW_BIT_WINDOW;
            invert_r0 <= 1'b0;
            hold_last_r0 <= 1'b0;
            gain_r0 <= 16'sd32767;
            offset_r0 <= 16'sd0;
            valid_r0 <= 1'b0;

            raw_window_r1 <= 16'sd0;
            shifted_unsigned_r1 <= 32'd0;
            product_r1 <= 48'sd0;
            mode_r1 <= MODE_RAW_BIT_WINDOW;
            invert_r1 <= 1'b0;
            hold_last_r1 <= 1'b0;
            offset_r1 <= 16'sd0;
            valid_r1 <= 1'b0;

            formatted_r2 <= 32'sd0;
            raw_window_r2 <= 16'sd0;
            mode_r2 <= MODE_RAW_BIT_WINDOW;
            invert_r2 <= 1'b0;
            hold_last_r2 <= 1'b0;
            valid_r2 <= 1'b0;
            dac_sample <= 16'sd0;
        end else begin
            valid_r0 <= source_valid;
            if (source_valid) begin
                source_r0 <= source_word;
                shift_or_lsb_r0 <= format_word[5:0];
                mode_r0 <= format_word[9:8];
                invert_r0 <= format_word[10];
                hold_last_r0 <= format_word[11];
                gain_r0 <= gain;
                offset_r0 <= offset;
            end

            valid_r1 <= valid_r0;
            if (valid_r0) begin
                raw_window_r1 <= source_r0[raw_lsb +: 16];
                shifted_unsigned_r1 <= shifted_unsigned;
                product_r1 <= shifted_signed * gain_r0;
                mode_r1 <= mode_r0;
                invert_r1 <= invert_r0;
                hold_last_r1 <= hold_last_r0;
                offset_r1 <= offset_r0;
            end

            valid_r2 <= valid_r1;
            if (valid_r1) begin
                raw_window_r2 <= raw_window_r1;
                mode_r2 <= mode_r1;
                invert_r2 <= invert_r1;
                hold_last_r2 <= hold_last_r1;
                case (mode_r1)
                    MODE_RAW_BIT_WINDOW: formatted_r2 <= {{16{raw_window_r1[15]}}, raw_window_r1};
                    MODE_ARITH_SHIFT_SAT: formatted_r2 <= scaled_plus_offset;
                    MODE_UNSIGNED_SAT: formatted_r2 <= {16'd0, sat_unsigned15(shifted_unsigned_r1)};
                    default: formatted_r2 <= 32'sd0;
                endcase
            end

            if (valid_r2) begin
                case (mode_r2)
                    MODE_RAW_BIT_WINDOW: dac_sample <= apply_invert(raw_window_r2, invert_r2);
                    MODE_ARITH_SHIFT_SAT: dac_sample <= apply_invert(sat_signed16(formatted_r2), invert_r2);
                    MODE_UNSIGNED_SAT: dac_sample <= apply_invert(sat_signed16(formatted_r2), invert_r2);
                    default: dac_sample <= hold_last_r2 ? dac_sample : 16'sd0;
                endcase
            end else if (!hold_last_r2) begin
                dac_sample <= 16'sd0;
            end
        end
    end

endmodule

`default_nettype wire
