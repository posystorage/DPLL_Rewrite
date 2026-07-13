`timescale 1ns / 1ps

module fast_frequency_accumulator_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] phase_increment = 32'd3;
    reg [31:0] interval_cycles = 32'd4;
    wire [79:0] result;
    wire [31:0] result_interval_cycles;
    wire [30:0] update_sequence;
    wire result_valid;

    always #4 clk = ~clk;

    fast_frequency_accumulator dut (
        .clk(clk),
        .rst(rst),
        .phase_increment(phase_increment),
        .interval_cycles(interval_cycles),
        .result(result),
        .result_interval_cycles(result_interval_cycles),
        .update_sequence(update_sequence),
        .result_valid(result_valid)
    );

    task wait_and_check;
        input [30:0] expected_sequence;
        input [79:0] expected_result;
        input [31:0] expected_interval;
        integer timeout;
        begin
            timeout = 0;
            while ((update_sequence !== expected_sequence) && (timeout < 32)) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if ((update_sequence !== expected_sequence) ||
                (result !== expected_result) ||
                (result_interval_cycles !== expected_interval) ||
                (result_valid !== 1'b1)) begin
                $display("FAIL: seq=%0d result=%0d interval=%0d valid=%b",
                         update_sequence, result, result_interval_cycles, result_valid);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        if ((result_valid !== 1'b0) || (update_sequence !== 31'd0)) begin
            $display("FAIL: result became valid during reset");
            $finish;
        end

        @(negedge clk);
        rst = 1'b0;
        wait_and_check(31'd1, 80'd12, 32'd4);

        @(negedge clk);
        interval_cycles = 32'd3;
        wait_and_check(31'd2, 80'd12, 32'd4);
        wait_and_check(31'd3, 80'd9, 32'd3);

        @(negedge clk);
        interval_cycles = 32'd0;
        wait_and_check(31'd4, 80'd9, 32'd3);
        wait_and_check(31'd5, 80'd3, 32'd1);
        wait_and_check(31'd6, 80'd3, 32'd1);

        $display("PASS: fast_frequency_accumulator_tb");
        $finish;
    end
endmodule
