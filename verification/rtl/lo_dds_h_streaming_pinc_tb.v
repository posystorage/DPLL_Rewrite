`timescale 1ns / 1ps

module lo_dds_h_streaming_pinc_tb;
    localparam [47:0] PINC_WORD = 48'h4000_0000_0000;

    reg clk = 1'b0;
    reg in_valid = 1'b0;
    reg [47:0] phase_inc = 48'd0;

    wire data_valid;
    wire [31:0] data_out;
    wire phase_valid;
    wire [47:0] phase_out;
    wire signed [15:0] cos_out = data_out[15:0];
    wire signed [15:0] sin_out = data_out[31:16];

    integer fd;
    integer cycle = 0;
    integer out_count = 0;

    always #4 clk = ~clk;

    LO_DDS_H dut (
        .aclk(clk),
        .s_axis_phase_tvalid(in_valid),
        .s_axis_phase_tdata(phase_inc),
        .m_axis_data_tvalid(data_valid),
        .m_axis_data_tdata(data_out),
        .m_axis_phase_tvalid(phase_valid),
        .m_axis_phase_tdata(phase_out)
    );

    always @(posedge clk) begin
        #1;
        $fdisplay(fd, "%0d,%0d,%012h,%0d,%0d,%012h,%0d,%0d",
                  cycle, in_valid, phase_inc, data_valid, phase_valid,
                  phase_out, cos_out, sin_out);
        if (data_valid && phase_valid) begin
            out_count = out_count + 1;
        end
        cycle = cycle + 1;
    end

    initial begin
        fd = $fopen("lo_dds_h_streaming_pinc_trace.csv", "w");
        if (fd == 0) begin
            $display("FAIL: could not open lo_dds_h_streaming_pinc_trace.csv");
            $finish;
        end
        $fdisplay(fd, "cycle,in_valid,pinc,data_valid,phase_valid,phase,cos,sin");

        repeat (4) @(negedge clk);
        in_valid = 1'b1;
        phase_inc = PINC_WORD;
        repeat (32) @(negedge clk);
        in_valid = 1'b0;
        phase_inc = 48'd0;
        repeat (12) @(posedge clk);

        $fclose(fd);
        if (out_count < 12) begin
            $display("FAIL: LO_DDS_H output count=%0d", out_count);
            $finish;
        end
        $display("PASS: lo_dds_h_streaming_pinc_tb out_count=%0d", out_count);
        $finish;
    end
endmodule
