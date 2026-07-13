`timescale 1ns / 1ps

module dpll_angle_CORDIC (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        s_axis_cartesian_tvalid,
    output wire        s_axis_cartesian_tready,
    input  wire [47:0] s_axis_cartesian_tdata,
    output wire        m_axis_dout_tvalid,
    input  wire        m_axis_dout_tready,
    output wire [47:0] m_axis_dout_tdata
);
    assign s_axis_cartesian_tready = aresetn;
    assign m_axis_dout_tvalid = 1'b0;
    assign m_axis_dout_tdata = 48'd0;

    wire unused = aclk | s_axis_cartesian_tvalid | |s_axis_cartesian_tdata |
                  m_axis_dout_tready;
endmodule

module cordic_word_serial_adapter_status_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg clear = 1'b0;
    reg status_clear = 1'b0;
    reg in_valid = 1'b0;
    reg signed [19:0] i_in = 20'sd0;
    reg signed [19:0] q_in = 20'sd0;

    wire input_overrun_seen;
    wire input_out_of_range_seen;
    wire output_format_error_seen;

    always #4 clk = ~clk;

    cordic_word_serial_adapter dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .clear(clear),
        .status_clear(status_clear),
        .in_valid(in_valid),
        .i_in(i_in),
        .q_in(q_in),
        .out_valid(),
        .phase_out(),
        .magnitude_out(),
        .busy(),
        .input_overrun_seen(input_overrun_seen),
        .input_out_of_range_seen(input_out_of_range_seen),
        .output_format_error_seen(output_format_error_seen)
    );

    initial begin
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (6) @(posedge clk);

        @(negedge clk);
        i_in = 20'sd300000;
        in_valid = 1'b1;
        @(posedge clk);
        #1;
        in_valid = 1'b0;
        if (!input_out_of_range_seen) begin
            $display("FAIL: out-of-range sticky did not set");
            $finish;
        end

        @(negedge clk);
        clear = 1'b1;
        @(posedge clk);
        #1;
        clear = 1'b0;
        if (!input_out_of_range_seen) begin
            $display("FAIL: datapath clear unexpectedly cleared sticky status");
            $finish;
        end

        @(negedge clk);
        status_clear = 1'b1;
        @(posedge clk);
        #1;
        status_clear = 1'b0;
        if (input_overrun_seen || input_out_of_range_seen ||
            output_format_error_seen) begin
            $display("FAIL: status_clear did not clear CORDIC sticky status");
            $finish;
        end

        $display("PASS: cordic_word_serial_adapter_status_tb");
        $finish;
    end
endmodule
