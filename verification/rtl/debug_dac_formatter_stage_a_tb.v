`timescale 1ns / 1ps

module debug_dac_formatter_stage_a_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg source_valid = 1'b0;
    reg signed [31:0] source_word = 32'sd0;
    reg [31:0] format_word = 32'd0;
    reg signed [15:0] gain = 16'sd32767;
    reg signed [15:0] offset = 16'sd0;
    wire signed [15:0] dac_sample;

    always #4 clk = ~clk;

    debug_dac_formatter_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .source_valid(source_valid),
        .source_word(source_word),
        .format_word(format_word),
        .gain(gain),
        .offset(offset),
        .dac_sample(dac_sample)
    );

    task push_and_expect;
        input signed [31:0] source_value;
        input [31:0] format_value;
        input signed [15:0] gain_value;
        input signed [15:0] offset_value;
        input signed [15:0] expected;
        begin
            @(negedge clk);
            source_word = source_value;
            format_word = format_value;
            gain = gain_value;
            offset = offset_value;
            source_valid = 1'b1;
            @(posedge clk);
            #1;
            source_valid = 1'b0;
            repeat (4) @(posedge clk);
            #1;
            if (dac_sample !== expected) begin
                $display("FAIL: expected %0d got %0d format=0x%08x source=0x%08x",
                         expected, dac_sample, format_value, source_value);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;

        // Raw bit-window mode: bits [19:4] become the DAC sample.
        push_and_expect(32'h0012_3456, 32'h0000_0004, 16'sd32767, 16'sd0, 16'h2345);

        // Arithmetic mode: (source >>> 4) * 0.5 + 10.
        push_and_expect(32'sd1600, 32'h0000_0104, 16'sd16384, 16'sd10, 16'sd60);

        // Signed saturation high.
        push_and_expect(32'sd2000000000, 32'h0000_0100, 16'sd32767, 16'sd0, 16'sd32767);

        // Signed saturation low.
        push_and_expect(-32'sd2000000000, 32'h0000_0100, 16'sd32767, 16'sd0, -16'sd32768);

        // Unsigned mode saturates to positive full scale.
        push_and_expect(32'hFFFF_FFFF, 32'h0000_0200, 16'sd32767, 16'sd0, 16'sd32767);

        // Invert is applied after formatting and saturation.
        push_and_expect(32'sd64, 32'h0000_0500, 16'sd32767, 16'sd0, -16'sd63);

        // Hold-last keeps the last formatted output after its valid sample.
        push_and_expect(32'sd128, 32'h0000_0900, 16'sd32767, 16'sd0, 16'sd127);
        @(negedge clk);
        source_valid = 1'b0;
        repeat (5) @(posedge clk);
        #1;
        if (dac_sample !== 16'sd127) begin
            $display("FAIL: hold-last expected 127 got %0d", dac_sample);
            $finish;
        end

        $display("PASS: debug_dac_formatter_stage_a_tb");
        $finish;
    end
endmodule
