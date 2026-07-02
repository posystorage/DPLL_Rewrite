`timescale 1ns / 1ps

module input_multiplier_mixer_latency_tb;
    reg clk = 1'b0;
    reg signed [15:0] sample_in = 16'sd0;
    reg signed [15:0] lo_i = 16'sd0;
    reg signed [15:0] lo_q = 16'sd0;
    reg in_valid = 1'b0;

    wire signed [31:0] product_i;
    wire signed [31:0] product_q;

    reg signed [15:0] sample_r;
    reg signed [15:0] lo_i_r;
    reg signed [15:0] lo_q_r;
    reg input_valid_r;
    reg product_valid;
    integer fd;
    integer cycle = 0;
    integer idx;

    always #4 clk = ~clk;

    dpll_input_multiplier input_multiplier_i_inst (
        .CLK(clk),
        .A(sample_r),
        .B(lo_i_r),
        .P(product_i)
    );

    dpll_input_multiplier input_multiplier_q_inst (
        .CLK(clk),
        .A(sample_r),
        .B(lo_q_r),
        .P(product_q)
    );

    always @(posedge clk) begin
        input_valid_r <= in_valid;
        product_valid <= input_valid_r;
        if (in_valid) begin
            sample_r <= sample_in;
            lo_i_r <= lo_i;
            lo_q_r <= lo_q;
        end
    end

    task drive;
        input valid;
        input signed [15:0] sample;
        input signed [15:0] i_word;
        input signed [15:0] q_word;
        begin
            @(negedge clk);
            in_valid = valid;
            sample_in = sample;
            lo_i = i_word;
            lo_q = q_word;
            @(posedge clk);
            #1;
            $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d", cycle, valid, sample, i_word, q_word);
            $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d", cycle, product_valid, $signed(product_i), $signed(product_q), 0);
            cycle = cycle + 1;
        end
    endtask

    initial begin
        fd = $fopen("input_multiplier_mixer_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open input_multiplier_mixer_trace.csv");
            $finish;
        end
        $fdisplay(fd, "cycle,valid_or_product_valid,a,b,c");

        product_valid = 1'b0;
        input_valid_r = 1'b0;
        sample_r = 16'sd0;
        lo_i_r = 16'sd0;
        lo_q_r = 16'sd0;
        repeat (3) @(posedge clk);

        drive(1'b0, 16'sd111, 16'sd222, 16'sd333);
        for (idx = 0; idx < 12; idx = idx + 1) begin
            drive(1'b1,
                  16'sd1000 + idx * 16'sd37,
                  (idx[0] == 1'b0) ? 16'sd16384 : -16'sd8192,
                  (idx[1] == 1'b0) ? -16'sd4096 : 16'sd12288);
        end
        drive(1'b0, -16'sd321, 16'sd100, -16'sd100);
        drive(1'b0, 16'sd0, 16'sd0, 16'sd0);

        $fclose(fd);
        $display("PASS: input_multiplier_mixer_latency_tb");
        $finish;
    end
endmodule
