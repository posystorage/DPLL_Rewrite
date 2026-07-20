`timescale 1ns / 1ps

module post_iq_cic_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg in_valid = 1'b0;
    reg signed [17:0] i_in = 18'sd0;
    reg signed [17:0] q_in = 18'sd0;
    reg config_apply = 1'b0;
    reg status_clear = 1'b0;
    reg [8:0] shadow_rate_r = 9'd8;
    reg [5:0] shadow_output_shift = 6'd0;
    reg flush = 1'b0;
    wire out_valid;
    wire signed [19:0] i_out;
    wire signed [19:0] q_out;
    wire [8:0] active_rate_r;
    wire [5:0] active_output_shift;
    wire overflow_seen;
    wire illegal_config_seen;

    integer valid_count = 0;
    integer valid_count_before;
    integer sample_index = 0;
    integer trace_fd;
    reg saw_rounding_value = 1'b0;

    post_iq_cic_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .in_valid(in_valid),
        .i_in(i_in),
        .q_in(q_in),
        .config_apply(config_apply),
        .status_clear(status_clear),
        .shadow_rate_r(shadow_rate_r),
        .shadow_output_shift(shadow_output_shift),
        .flush(flush),
        .out_valid(out_valid),
        .i_out(i_out),
        .q_out(q_out),
        .active_rate_r(active_rate_r),
        .active_output_shift(active_output_shift),
        .overflow_seen(overflow_seen),
        .illegal_config_seen(illegal_config_seen)
    );

    always #4 clk_125m = ~clk_125m;

    task tick_sample;
        input signed [17:0] sample_i;
        input signed [17:0] sample_q;
        begin
            @(negedge clk_125m);
            i_in = sample_i;
            q_in = sample_q;
            in_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            sample_index = sample_index + 1;
            if (out_valid) begin
                valid_count = valid_count + 1;
                $fdisplay(trace_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                          sample_index, valid_count, active_rate_r,
                          active_output_shift, sample_i, sample_q,
                          i_out, q_out, overflow_seen);
                if (i_out === 20'sd1 && q_out === -20'sd1) begin
                    saw_rounding_value = 1'b1;
                end
            end
        end
    endtask

    initial begin
        trace_fd = $fopen("post_iq_cic_trace.csv", "w");
        if (trace_fd == 0) begin
            $display("FAIL: could not open post_iq_cic_trace.csv");
            $finish;
        end
        $fdisplay(trace_fd, "sample_index,output_index,active_rate_r,active_output_shift,i_in,q_in,i_out,q_out,overflow_seen");

        repeat (3) @(posedge clk_125m);
        @(negedge clk_125m);
        rst_125m = 1'b0;

        config_apply = 1'b1;
        shadow_rate_r = 9'd8;
        shadow_output_shift = 6'd10;
        @(posedge clk_125m);
        #1;
        config_apply = 1'b0;
        if (active_rate_r !== 9'd8) begin
            $display("FAIL: active_rate_r expected 8 got %0d", active_rate_r);
            $finish;
        end
        if (active_output_shift !== 6'd10) begin
            $display("FAIL: active_output_shift expected 10 got %0d", active_output_shift);
            $finish;
        end

        repeat (32) tick_sample(18'sd1, -18'sd1);
        if (valid_count !== 0) begin
            $display("FAIL: warmup suppression expected 0 output valids got %0d", valid_count);
            $finish;
        end

        repeat (32) tick_sample(18'sd1, -18'sd1);
        if (valid_count < 2) begin
            $display("FAIL: expected output valids after warmup got %0d", valid_count);
            $finish;
        end
        if (saw_rounding_value !== 1'b1) begin
            $display("FAIL: expected symmetric rounded steady value +/-1");
            $finish;
        end

        valid_count_before = valid_count;
        shadow_rate_r = 9'd7;
        config_apply = 1'b1;
        @(posedge clk_125m);
        #1;
        config_apply = 1'b0;
        if (active_rate_r !== 9'd8 || illegal_config_seen !== 1'b1) begin
            $display("FAIL: illegal config did not preserve active_rate_r or flag error");
            $finish;
        end

        repeat (16) tick_sample(18'sd1, -18'sd1);
        if (valid_count != valid_count_before + 2) begin
            $display("FAIL: illegal config flushed CIC state, valid_count=%0d", valid_count);
            $finish;
        end

        status_clear = 1'b1;
        @(posedge clk_125m);
        #1;
        status_clear = 1'b0;
        if (illegal_config_seen !== 1'b0 || active_rate_r !== 9'd8) begin
            $display("FAIL: status clear changed active CIC config or left sticky error set");
            $finish;
        end

        shadow_rate_r = 9'd8;
        shadow_output_shift = 6'd10;
        config_apply = 1'b1;
        @(posedge clk_125m);
        #1;
        config_apply = 1'b0;
        if (illegal_config_seen !== 1'b0) begin
            $display("FAIL: legal config did not clear illegal_config_seen");
            $finish;
        end

        repeat (24) tick_sample(18'sd0, 18'sd0);
        tick_sample(18'sd2048, -18'sd1024);
        repeat (48) tick_sample(18'sd0, 18'sd0);

        shadow_rate_r = 9'd12;
        shadow_output_shift = 6'd11;
        config_apply = 1'b1;
        @(posedge clk_125m);
        #1;
        config_apply = 1'b0;
        if (active_rate_r !== 9'd12 || active_output_shift !== 6'd11) begin
            $display("FAIL: legal R=12 apply failed, active_rate=%0d shift=%0d",
                     active_rate_r, active_output_shift);
            $finish;
        end
        repeat (96) tick_sample(18'sd3, -18'sd2);

        flush = 1'b1;
        @(posedge clk_125m);
        #1;
        flush = 1'b0;
        repeat (48) tick_sample(-18'sd5, 18'sd7);

        $display("PASS: post_iq_cic_stage_a_tb");
        $fclose(trace_fd);
        $finish;
    end
endmodule
