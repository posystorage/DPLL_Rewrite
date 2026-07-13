`timescale 1ns / 1ps

module post_iir_stage_a_tb;
    reg clk_125m = 1'b0;
    reg rst_125m = 1'b1;
    reg clear = 1'b0;
    reg in_valid = 1'b0;
    reg signed [19:0] i_in = 20'sd0;
    reg signed [19:0] q_in = 20'sd0;
    reg [1:0] mode = 2'd0;
    reg state_use_track = 1'b0;
    wire out_valid;
    wire signed [19:0] i_out;
    wire signed [19:0] q_out;
    wire active_bypass;
    wire active_use_track;

    integer n;
    integer hf_peak;
    integer step_final;
    integer observed_i;
    integer observed_q;
    reg observed_valid;
    integer observed_latency;
    integer max_filtered_latency;

    always #4 clk_125m = ~clk_125m;

    post_iir_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .clear(clear),
        .in_valid(in_valid),
        .i_in(i_in),
        .q_in(q_in),
        .mode(mode),
        .state_use_track(state_use_track),
        .acq_b0(32'sd138975519),
        .acq_b1(32'sd277951039),
        .acq_b2(32'sd138975519),
        .acq_a1(-32'sd812870960),
        .acq_a2(32'sd295031213),
        .track_b0(32'sd48851600),
        .track_b1(32'sd97703199),
        .track_b2(32'sd48851600),
        .track_a1(-32'sd1409400772),
        .track_a2(32'sd531065347),
        .out_valid(out_valid),
        .i_out(i_out),
        .q_out(q_out),
        .active_bypass(active_bypass),
        .active_use_track(active_use_track)
    );

    function integer abs20;
        input signed [19:0] value;
        begin
            abs20 = value[19] ? -value : value;
        end
    endfunction

    task push_bypass_sample;
        input signed [19:0] sample_i;
        input signed [19:0] sample_q;
        begin
            @(negedge clk_125m);
            i_in = sample_i;
            q_in = sample_q;
            in_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            in_valid = 1'b0;
            if (!out_valid || i_out !== sample_i || q_out !== sample_q ||
                active_bypass !== 1'b1) begin
                $display("FAIL: bypass path mismatch valid=%b i=%0d q=%0d bypass=%b",
                         out_valid, i_out, q_out, active_bypass);
                $finish;
            end
        end
    endtask

    task push_flush_sample;
        input signed [19:0] sample_i;
        input signed [19:0] sample_q;
        begin
            @(negedge clk_125m);
            i_in = sample_i;
            q_in = sample_q;
            in_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            in_valid = 1'b0;
            if (out_valid !== 1'b0) begin
                $display("FAIL: flush/selection change produced stale output");
                $finish;
            end
        end
    endtask

    task push_filtered_sample;
        input signed [19:0] sample_i;
        input signed [19:0] sample_q;
        integer wait_cycles;
        begin
            observed_valid = 1'b0;
            observed_latency = 0;
            @(negedge clk_125m);
            i_in = sample_i;
            q_in = sample_q;
            in_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            in_valid = 1'b0;
            for (wait_cycles = 0; wait_cycles < 24; wait_cycles = wait_cycles + 1) begin
                @(posedge clk_125m);
                #1;
                observed_latency = wait_cycles + 1;
                if (out_valid) begin
                    observed_valid = 1'b1;
                    observed_i = i_out;
                    observed_q = q_out;
                    if (observed_latency > max_filtered_latency) begin
                        max_filtered_latency = observed_latency;
                    end
                end
            end
            if (!observed_valid) begin
                $display("FAIL: filtered transaction did not retire");
                $finish;
            end
        end
    endtask

    initial begin
        max_filtered_latency = 0;
        repeat (4) @(posedge clk_125m);
        rst_125m = 1'b0;

        push_bypass_sample(20'sd12345, -20'sd23456);

        mode = 2'd1;
        push_flush_sample(20'sd1000, -20'sd1000);
        if (out_valid !== 1'b0 || active_bypass !== 1'b0 || active_use_track !== 1'b0) begin
            $display("FAIL: acquire mode switch did not flush one cycle");
            $finish;
        end

        mode = 2'd3;
        state_use_track = 1'b1;
        push_flush_sample(20'sd1000, 20'sd1000);
        if (active_use_track !== 1'b1) begin
            $display("FAIL: auto mode did not select track coefficients");
            $finish;
        end

        clear = 1'b1;
        push_flush_sample(20'sd0, 20'sd0);
        clear = 1'b0;

        hf_peak = 0;
        for (n = 0; n < 96; n = n + 1) begin
            push_filtered_sample(n[0] ? -20'sd100000 : 20'sd100000,
                                 n[0] ? 20'sd50000 : -20'sd50000);
            if (observed_valid && n > 24 && abs20(observed_i) > hf_peak) begin
                hf_peak = abs20(observed_i);
            end
            if (observed_valid && (observed_i === 20'sh7ffff || observed_i === 20'sh80000)) begin
                $display("FAIL: high-frequency response saturated");
                $finish;
            end
        end
        if (hf_peak > 20000) begin
            $display("FAIL: high-frequency alternating input not attenuated enough peak=%0d", hf_peak);
            $finish;
        end

        clear = 1'b1;
        push_flush_sample(20'sd0, 20'sd0);
        clear = 1'b0;
        step_final = 0;
        for (n = 0; n < 160; n = n + 1) begin
            push_filtered_sample(20'sd10000, -20'sd10000);
            if (observed_valid) begin
                step_final = observed_i;
            end
        end
        if (step_final < 20'sd8000 || step_final > 20'sd12000) begin
            $display("FAIL: step response final value out of range %0d", step_final);
            $finish;
        end
        if (max_filtered_latency > 20) begin
            $display("FAIL: filtered latency exceeded 20 clocks, max=%0d", max_filtered_latency);
            $finish;
        end

        $display("PASS: post_iir_stage_a_tb max_filtered_latency=%0d", max_filtered_latency);
        $finish;
    end
endmodule
