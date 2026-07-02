`timescale 1ns / 1ps

module angle_cordic_ip_trace_tb;
    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg in_valid = 1'b0;
    reg signed [19:0] i_in = 20'sd0;
    reg signed [19:0] q_in = 20'sd0;

    wire in_ready;
    wire out_valid;
    wire [47:0] dout;
    wire signed [17:0] phase = dout[41:24];
    wire [19:0] magnitude = dout[19:0];
    wire [47:0] cartesian_tdata = {
        {4{q_in[19]}}, q_in,
        {4{i_in[19]}}, i_in
    };

    integer fd;
    integer cycle = 0;
    integer valid_outputs = 0;
    integer accepted_inputs = 0;

    always #4 clk = ~clk;

    dpll_angle_CORDIC dut (
        .aclk(clk),
        .aresetn(rstn),
        .s_axis_cartesian_tvalid(in_valid),
        .s_axis_cartesian_tready(in_ready),
        .s_axis_cartesian_tdata(cartesian_tdata),
        .m_axis_dout_tvalid(out_valid),
        .m_axis_dout_tdata(dout)
    );

    task drive;
        input valid;
        input signed [19:0] i_word;
        input signed [19:0] q_word;
        begin
            @(negedge clk);
            in_valid = valid;
            i_in = i_word;
            q_in = q_word;
            if (valid) begin
                begin : wait_for_accept
                    forever begin
                        @(posedge clk);
                        if (in_ready) begin
                            disable wait_for_accept;
                        end
                    end
                end
                @(negedge clk);
                in_valid = 1'b0;
            end
        end
    endtask

    always @(posedge clk) begin
        #1;
        $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                  cycle, in_valid, in_ready, i_in, q_in, out_valid, phase, magnitude);
        if (in_valid && in_ready) begin
            accepted_inputs = accepted_inputs + 1;
        end
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
        $fdisplay(fd, "cycle,in_valid,in_ready,i_in,q_in,out_valid,phase,magnitude");

        repeat (4) @(posedge clk);
        rstn = 1'b1;
        repeat (4) @(posedge clk);
        drive(1'b1, 20'sd131072, 20'sd0);
        drive(1'b1, 20'sd0, 20'sd131072);
        drive(1'b1, -20'sd131072, 20'sd0);
        drive(1'b1, 20'sd0, -20'sd131072);
        drive(1'b1, 20'sd92782, 20'sd92782);
        drive(1'b1, 20'sd92782, -20'sd92782);
        drive(1'b0, 20'sd0, 20'sd0);

        repeat (160) @(negedge clk);
        in_valid = 1'b0;
        i_in = 20'sd0;
        q_in = 20'sd0;
        repeat (4) @(posedge clk);

        $fclose(fd);
        if (accepted_inputs != 6) begin
            $display("FAIL: dpll_angle_CORDIC accepted_inputs=%0d", accepted_inputs);
            $finish;
        end
        if (valid_outputs < 6) begin
            $display("FAIL: dpll_angle_CORDIC valid_outputs=%0d", valid_outputs);
            $finish;
        end
        $display("PASS: angle_cordic_ip_trace_tb valid_outputs=%0d", valid_outputs);
        $finish;
    end
endmodule
