`timescale 1ns / 1ps

module pll_vco_mul_div_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg [47:0] data_in = 48'd0;
    reg [15:0] mul_factor = 16'd1;
    reg [15:0] div_factor = 16'd1;
    wire [47:0] data_out;
    wire config_error;

    integer seen_first;

    always #4 clk = ~clk;

    PLL_VCO_MUL_DIV dut (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .data_in(data_in),
        .data_out(data_out),
        .PLL_Mul_factor(mul_factor),
        .PLL_Div_factor(div_factor),
        .config_error(config_error)
    );

    task push_sample;
        input [47:0] word_value;
        input [15:0] mul_value;
        input [15:0] div_value;
        begin
            @(negedge clk);
            data_in = word_value;
            mul_factor = mul_value;
            div_factor = div_value;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
            sample_valid = 1'b0;
        end
    endtask

    task wait_output;
        input [47:0] expected;
        integer timeout;
        begin
            timeout = 0;
            while (data_out !== expected && timeout < 96) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if (data_out !== expected) begin
                $display("FAIL: expected output %0d got %0d", expected, data_out);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        push_sample(48'd1000, 16'd3, 16'd2);
        wait_output(48'd1500);

        push_sample(48'd1001, 16'd1, 16'd2);
        wait_output(48'd501);

        push_sample(48'd5, 16'd7, 16'd0);
        repeat (96) @(posedge clk);
        #1;
        if (data_out !== 48'd501 || config_error !== 1'b1) begin
            $display("FAIL: DIV=0 should preserve previous output and set config_error, got out=%0d err=%b",
                     data_out, config_error);
            $finish;
        end

        push_sample(48'd65535, 16'd1, 16'hffff);
        wait_output(48'd1);

        push_sample(48'd1234, 16'd0, 16'd1);
        repeat (96) @(posedge clk);
        #1;
        if (data_out !== 48'd1 || config_error !== 1'b1) begin
            $display("FAIL: MUL=0 should be rejected without output change, got out=%0d err=%b",
                     data_out, config_error);
            $finish;
        end

        push_sample({48{1'b1}}, 16'hFFFF, 16'd1);
        wait_output({48{1'b1}});

        push_sample(48'd100, 16'd1, 16'd1);
        push_sample(48'd200, 16'd1, 16'd1);
        push_sample(48'd300, 16'd1, 16'd1);
        wait_output(48'd100);
        wait_output(48'd300);
        if (data_out === 48'd200) begin
            $display("FAIL: stale middle pending value reached output");
            $finish;
        end

        $display("PASS: pll_vco_mul_div_tb");
        $finish;
    end
endmodule
