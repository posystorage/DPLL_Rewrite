`timescale 1ns/1ps
`default_nettype none

module dpll_clock_valid_stage_a_tb;

reg clk_125m = 1'b0;
reg rst_n_async = 1'b0;
reg sw_reset_pulse = 1'b0;
wire rst_125m;
wire sample_valid;

integer cycle_count = 0;
integer valid_count = 0;
integer last_valid_cycle = -1;
integer error_count = 0;

always #4 clk_125m = ~clk_125m;

dpll_clock_valid_stage_a #(
    .G_SAMPLE_DIV(5)
) dut (
    .clk_125m(clk_125m),
    .rst_n_async(rst_n_async),
    .sw_reset_pulse(sw_reset_pulse),
    .rst_125m(rst_125m),
    .sample_valid(sample_valid)
);

always @(posedge clk_125m) begin
    cycle_count <= cycle_count + 1;

    if (rst_125m && sample_valid) begin
        $display("FAIL sample_valid asserted during reset at cycle %0d", cycle_count);
        error_count = error_count + 1;
        $finish;
    end

    if (sample_valid) begin
        if (last_valid_cycle >= 0 && cycle_count - last_valid_cycle != 5) begin
            $display("FAIL sample_valid spacing was %0d cycles, expected 5", cycle_count - last_valid_cycle);
            error_count = error_count + 1;
            $finish;
        end
        last_valid_cycle <= cycle_count;
        valid_count <= valid_count + 1;
    end
end

initial begin
    repeat (4) @(posedge clk_125m);
    rst_n_async = 1'b1;

    wait (rst_125m == 1'b0);
    repeat (24) @(posedge clk_125m);

    if (valid_count < 4) begin
        $display("FAIL too few valid pulses before software reset: %0d", valid_count);
        error_count = error_count + 1;
        $finish;
    end

    sw_reset_pulse = 1'b1;
    @(posedge clk_125m);
    sw_reset_pulse = 1'b0;

    @(posedge clk_125m);
    if (!rst_125m) begin
        $display("FAIL software reset did not reassert synchronized reset");
        error_count = error_count + 1;
        $finish;
    end

    wait (rst_125m == 1'b0);
    last_valid_cycle = -1;
    valid_count = 0;
    repeat (20) @(posedge clk_125m);

    if (valid_count < 3) begin
        $display("FAIL too few valid pulses after software reset: %0d", valid_count);
        error_count = error_count + 1;
        $finish;
    end

    $display("PASS dpll_clock_valid_stage_a_tb");
    $finish;
end

endmodule

`default_nettype wire
