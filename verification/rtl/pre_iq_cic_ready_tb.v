`timescale 1ns / 1ps

module pre_iq_cic_ready_tb;
    reg clk = 1'b0;
    reg signed [15:0] sample = 16'sd0;
    reg in_valid = 1'b0;
    wire in_ready;
    wire [15:0] out_data;
    wire out_valid;

    integer fd;
    integer cycle = 0;
    integer idx;
    integer ready_low_count = 0;
    integer out_valid_count = 0;

    always #4 clk = ~clk;

    pre_iq_cic_40_125m_v1 dut (
        .aclk(clk),
        .s_axis_data_tdata(sample),
        .s_axis_data_tvalid(in_valid),
        .s_axis_data_tready(in_ready),
        .m_axis_data_tdata(out_data),
        .m_axis_data_tvalid(out_valid)
    );

    initial begin
        fd = $fopen("pre_iq_cic_ready_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open pre_iq_cic_ready_trace.csv");
            $finish;
        end
        $fdisplay(fd, "cycle,in_valid,in_ready,out_valid,out_data");

        repeat (8) @(posedge clk);
        in_valid = 1'b1;
        for (idx = 0; idx < 512; idx = idx + 1) begin
            @(negedge clk);
            sample = idx[15:0];
            @(posedge clk);
            #1;
            $fdisplay(fd, "%0d,%0d,%0d,%0d,%0d", cycle, in_valid, in_ready, out_valid, $signed(out_data));
            if (in_valid && !in_ready) begin
                ready_low_count = ready_low_count + 1;
            end
            if (out_valid) begin
                out_valid_count = out_valid_count + 1;
            end
            cycle = cycle + 1;
        end

        if (ready_low_count != 0) begin
            $display("FAIL: pre-IQ CIC deasserted input ready %0d times", ready_low_count);
            $finish;
        end
        if (out_valid_count < 8) begin
            $display("FAIL: expected decimated outputs, got %0d", out_valid_count);
            $finish;
        end

        $fclose(fd);
        $display("PASS: pre_iq_cic_ready_tb ready_low=%0d out_valid=%0d", ready_low_count, out_valid_count);
        $finish;
    end
endmodule
