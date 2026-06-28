`timescale 1ns / 1ps

module angle_cordic_ip_trace_tb;
    reg clk = 1'b0;
    reg in_valid = 1'b0;
    reg signed [15:0] i_in = 16'sd0;
    reg signed [15:0] q_in = 16'sd0;

    wire out_valid;
    wire [31:0] dout;
    wire signed [15:0] phase = dout[31:16];
    wire [15:0] magnitude = dout[15:0];

    integer fd;
    integer cycle = 0;
    integer valid_outputs = 0;

    always #4 clk = ~clk;

    angle_CORDIC dut (
        .aclk(clk),
        .s_axis_cartesian_tvalid(in_valid),
        .s_axis_cartesian_tdata({q_in, i_in}),
        .m_axis_dout_tvalid(out_valid),
        .m_axis_dout_tdata(dout)
    );

    task drive;
        input valid;
        input signed [15:0] i_word;
        input signed [15:0] q_word;
        begin
            @(negedge clk);
            in_valid = valid;
            i_in = i_word;
            q_in = q_word;
        end
    endtask

    always @(posedge clk) begin
        #1;
        $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                  cycle, in_valid, i_in, q_in, out_valid, phase, magnitude);
        if (out_valid) begin
            valid_outputs = valid_outputs + 1;
        end
        cycle = cycle + 1;
    end

    initial begin
        fd = $fopen("angle_cordic_ip_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open angle_cordic_ip_trace.csv");
            $finish;
        end
        $fdisplay(fd, "cycle,in_valid,i_in,q_in,out_valid,phase,magnitude");

        repeat (4) @(posedge clk);
        drive(1'b1, 16'sd16384, 16'sd0);
        drive(1'b1, 16'sd0, 16'sd16384);
        drive(1'b1, -16'sd16384, 16'sd0);
        drive(1'b1, 16'sd0, -16'sd16384);
        drive(1'b1, 16'sd11585, 16'sd11585);
        drive(1'b1, 16'sd11585, -16'sd11585);
        drive(1'b0, 16'sd0, 16'sd0);

        repeat (40) @(negedge clk);
        in_valid = 1'b0;
        i_in = 16'sd0;
        q_in = 16'sd0;
        repeat (4) @(posedge clk);

        $fclose(fd);
        if (valid_outputs < 6) begin
            $display("FAIL: angle_CORDIC valid_outputs=%0d", valid_outputs);
            $finish;
        end
        $display("PASS: angle_cordic_ip_trace_tb valid_outputs=%0d", valid_outputs);
        $finish;
    end
endmodule
