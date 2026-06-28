`timescale 1ns / 1ps

module dc_blocker_valid_stage_a_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg in_valid = 1'b0;
    reg signed [15:0] sample_in = 16'sd0;
    wire out_valid;
    wire signed [15:0] sample_out;

    integer fd;
    integer cycle = 0;
    integer idx;

    always #4 clk = ~clk;

    dc_blocker_valid_stage_a #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(48),
        .LEAK_SHIFT(7)
    ) dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .in_valid(in_valid),
        .sample_in(sample_in),
        .out_valid(out_valid),
        .sample_out(sample_out)
    );

    task drive;
        input signed [15:0] value;
        input valid;
        begin
            @(negedge clk);
            sample_in = value;
            in_valid = valid;
            @(posedge clk);
            #1;
            $fdisplay(fd, "%0d,%0d,%0d,%0d", cycle, valid, value, $signed(sample_out));
            if (out_valid !== valid) begin
                $display("FAIL: out_valid mismatch at cycle %0d expected %0d got %0d", cycle, valid, out_valid);
                $finish;
            end
            cycle = cycle + 1;
        end
    endtask

    initial begin
        fd = $fopen("dc_blocker_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open dc_blocker_trace.csv");
            $finish;
        end
        $fdisplay(fd, "cycle,in_valid,sample_in,sample_out");

        repeat (3) @(posedge clk);
        rst = 1'b0;

        drive(16'sd0, 1'b0);
        drive(16'sd1000, 1'b1);
        drive(16'sd1000, 1'b1);
        drive(16'sd1000, 1'b1);
        drive(16'sd0, 1'b0);
        drive(-16'sd2000, 1'b1);
        drive(16'sd3000, 1'b1);
        drive(16'sd0, 1'b1);
        drive(16'sd0, 1'b0);

        for (idx = 0; idx < 24; idx = idx + 1) begin
            drive(16'sd12000, 1'b1);
        end
        for (idx = 0; idx < 24; idx = idx + 1) begin
            drive(16'sd0, 1'b1);
        end
        for (idx = 0; idx < 8; idx = idx + 1) begin
            drive((idx[0] == 1'b0) ? 16'sd32767 : -16'sd32768, 1'b1);
        end

        $fclose(fd);
        $display("PASS: dc_blocker_valid_stage_a_tb");
        $finish;
    end
endmodule
