`timescale 1ns / 1ps

module tracking_phase_accumulator_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg enable = 1'b0;
    reg [15:0] tracking_word = 16'h1000;
    wire [15:0] phase_accum;
    wire [7:0] phase_word;
    wire phase_valid;

    tracking_phase_accumulator_stage_a #(
        .WORD_WIDTH(16),
        .PHASE_WIDTH(8)
    ) dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .enable(enable),
        .tracking_word(tracking_word),
        .phase_accum(phase_accum),
        .phase_word(phase_word),
        .phase_valid(phase_valid)
    );

    always #4 clk_125m = ~clk_125m;

    task expect_state;
        input [15:0] expected_accum;
        input [7:0] expected_word;
        input expected_valid;
        begin
            #1;
            if (phase_accum !== expected_accum) begin
                $display("FAIL: phase_accum expected %h got %h", expected_accum, phase_accum);
                $finish;
            end
            if (phase_word !== expected_word) begin
                $display("FAIL: phase_word expected %h got %h", expected_word, phase_word);
                $finish;
            end
            if (phase_valid !== expected_valid) begin
                $display("FAIL: phase_valid expected %b got %b", expected_valid, phase_valid);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk_125m);
        @(negedge clk_125m);
        rst_125m = 1'b0;
        enable = 1'b1;

        @(posedge clk_125m);
        expect_state(16'h1000, 8'h10, 1'b1);

        @(posedge clk_125m);
        expect_state(16'h2000, 8'h20, 1'b1);

        tracking_word = 16'hf000;
        @(posedge clk_125m);
        expect_state(16'h1000, 8'h10, 1'b1);

        enable = 1'b0;
        @(posedge clk_125m);
        expect_state(16'h1000, 8'h10, 1'b0);

        $display("PASS: tracking_phase_accumulator_stage_a_tb");
        $finish;
    end
endmodule
