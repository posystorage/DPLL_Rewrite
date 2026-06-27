`timescale 1ns / 1ps

module iq_mixer_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg in_valid = 1'b0;
    reg signed [15:0] sample_in = 16'sd0;
    reg signed [15:0] cos_in = 16'sd0;
    reg signed [15:0] sin_in = 16'sd0;
    wire out_valid;
    wire signed [17:0] i_out;
    wire signed [17:0] q_out;

    iq_mixer_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .in_valid(in_valid),
        .sample_in(sample_in),
        .cos_in(cos_in),
        .sin_in(sin_in),
        .out_valid(out_valid),
        .i_out(i_out),
        .q_out(q_out)
    );

    always #4 clk_125m = ~clk_125m;

    task expect_mix;
        input signed [17:0] expected_i;
        input signed [17:0] expected_q;
        begin
            #1;
            if (out_valid !== 1'b1) begin
                $display("FAIL: out_valid expected 1 got %b", out_valid);
                $finish;
            end
            if (i_out !== expected_i) begin
                $display("FAIL: i_out expected %0d got %0d", expected_i, i_out);
                $finish;
            end
            if (q_out !== expected_q) begin
                $display("FAIL: q_out expected %0d got %0d", expected_q, q_out);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_125m);
        @(negedge clk_125m);
        rst_125m = 1'b0;

        sample_in = 16'sd1000;
        cos_in = 16'sd16384;
        sin_in = 16'sd0;
        in_valid = 1'b1;
        @(posedge clk_125m);
        expect_mix(18'sd1000, 18'sd0);

        sample_in = 16'sd1000;
        cos_in = 16'sd0;
        sin_in = 16'sd16384;
        @(posedge clk_125m);
        expect_mix(18'sd0, -18'sd1000);

        sample_in = -16'sd2000;
        cos_in = 16'sd8192;
        sin_in = -16'sd8192;
        @(posedge clk_125m);
        expect_mix(-18'sd1000, -18'sd1000);

        in_valid = 1'b0;
        @(posedge clk_125m);
        #1;
        if (out_valid !== 1'b0) begin
            $display("FAIL: out_valid expected 0 got %b", out_valid);
            $finish;
        end

        $display("PASS: iq_mixer_stage_a_tb");
        $finish;
    end
endmodule
