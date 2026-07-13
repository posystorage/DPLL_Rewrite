`timescale 1ns / 1ps
`default_nettype none

module fll_cross_dot_stage_a_tb;

    reg clk_125m;
    reg rst_125m;
    reg clear;
    reg sample_valid;
    reg signed [19:0] i_in;
    reg signed [19:0] q_in;
    reg [1:0] delay_sel;
    reg [8:0] rate_r;

    wire freq_error_valid;
    wire freq_error_block_valid;
    wire signed [21:0] freq_error;
    wire ambiguous;

    integer failures;
    integer accepted_count;
    integer observed_valid_count;
    integer observed_block_count;
    integer max_sample_busy;
    integer min_sample_interval;
    integer last_accept_cycle;
    integer cycle_count;
    integer n;

    // Scalar reference state. Test vectors are deliberately small, so every
    // intermediate product and the final scaled quotient fit in signed 64b.
    reg signed [63:0] ref_i_delay [0:7];
    reg signed [63:0] ref_q_delay [0:7];
    integer ref_valid_count;
    integer ref_block_count;
    reg signed [63:0] ref_dot_acc;
    reg signed [63:0] ref_cross_acc;
    integer ref_replay_count;
    reg signed [63:0] ref_replay_value;
    reg ref_replay_ambiguous;

    reg [70:0] expected_serial_numerator;
    reg [59:0] expected_serial_denominator;
    reg expected_serial_pending;

    always #4 clk_125m = ~clk_125m;

    fll_cross_dot_stage_a dut (
        .clk_125m(clk_125m),
        .rst_125m(rst_125m),
        .clear(clear),
        .sample_valid(sample_valid),
        .i_in(i_in),
        .q_in(q_in),
        .delay_sel(delay_sel),
        .rate_r(rate_r),
        .freq_error_valid(freq_error_valid),
        .freq_error_block_valid(freq_error_block_valid),
        .freq_error(freq_error),
        .ambiguous(ambiguous)
    );

    task fail_now;
        input [8*96-1:0] message;
        begin
            failures = failures + 1;
            $display("FAIL: %0s", message);
            $finish;
        end
    endtask

    task reset_reference;
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1) begin
                ref_i_delay[k] = 64'sd0;
                ref_q_delay[k] = 64'sd0;
            end
            ref_valid_count = 0;
            ref_block_count = 0;
            ref_dot_acc = 64'sd0;
            ref_cross_acc = 64'sd0;
            ref_replay_count = 0;
            ref_replay_value = 64'sd0;
            ref_replay_ambiguous = 1'b0;
            expected_serial_numerator = 71'd0;
            expected_serial_denominator = 60'd0;
            expected_serial_pending = 1'b0;
            accepted_count = 0;
            observed_valid_count = 0;
            observed_block_count = 0;
            max_sample_busy = 0;
            last_accept_cycle = -1000000;
            min_sample_interval = 1000000;
        end
    endtask

    task reset_dut;
        begin
            reset_reference;
            @(negedge clk_125m);
            rst_125m = 1'b1;
            clear = 1'b1;
            sample_valid = 1'b0;
            i_in = 20'sd0;
            q_in = 20'sd0;
            repeat (4) @(posedge clk_125m);
            #1;
            rst_125m = 1'b0;
            clear = 1'b0;
            repeat (2) @(posedge clk_125m);
        end
    endtask

    task compare_outputs;
        input integer expected_valid;
        input integer expected_block;
        input signed [63:0] expected_value;
        input integer expected_ambiguous;
        reg signed [21:0] expected_value_22;
        begin
            expected_value_22 = expected_value[21:0];
            if (expected_valid != 0) begin
                if (!freq_error_valid || freq_error !== expected_value_22 ||
                    ambiguous !== expected_ambiguous[0] ||
                    freq_error_block_valid !== (expected_block != 0)) begin
                    $display("FAIL: replay mismatch valid=%b block=%b err=%0d amb=%b expected err=%0d amb=%0d block=%0d",
                             freq_error_valid, freq_error_block_valid, freq_error,
                             ambiguous, expected_value_22, expected_ambiguous,
                             expected_block);
                    $finish;
                end
                observed_valid_count = observed_valid_count + 1;
                if (expected_block != 0) begin
                    observed_block_count = observed_block_count + 1;
                end
            end else if (freq_error_valid || freq_error_block_valid) begin
                $display("FAIL: unexpected replay valid=%b block=%b err=%0d amb=%b",
                         freq_error_valid, freq_error_block_valid, freq_error, ambiguous);
                $finish;
            end
        end
    endtask

    task update_reference;
        input integer sample_i_arg;
        input integer sample_q_arg;
        integer k;
        integer selected_delay_int;
        integer enough_int;
        integer normalization_int;
        reg signed [63:0] current_i;
        reg signed [63:0] current_q;
        reg signed [63:0] delayed_i_ref;
        reg signed [63:0] delayed_q_ref;
        reg signed [63:0] dot_sample_ref;
        reg signed [63:0] cross_sample_ref;
        reg signed [63:0] dot_next_ref;
        reg signed [63:0] cross_next_ref;
        reg [63:0] dot_abs_ref;
        reg [63:0] cross_abs_ref;
        reg [63:0] numerator_ref;
        reg [63:0] denominator_ref;
        reg signed [63:0] quotient_ref;
        reg signed [63:0] signed_result_ref;
        begin
            case (delay_sel)
                2'd0: selected_delay_int = 1;
                2'd1: selected_delay_int = 2;
                2'd2: selected_delay_int = 4;
                default: selected_delay_int = 8;
            endcase
            normalization_int = rate_r * selected_delay_int;

            case (delay_sel)
                2'd0: begin
                    delayed_i_ref = ref_i_delay[0];
                    delayed_q_ref = ref_q_delay[0];
                end
                2'd1: begin
                    delayed_i_ref = ref_i_delay[1];
                    delayed_q_ref = ref_q_delay[1];
                end
                2'd2: begin
                    delayed_i_ref = ref_i_delay[3];
                    delayed_q_ref = ref_q_delay[3];
                end
                default: begin
                    delayed_i_ref = ref_i_delay[7];
                    delayed_q_ref = ref_q_delay[7];
                end
            endcase

            enough_int = (ref_valid_count >= selected_delay_int);
            current_i = sample_i_arg;
            current_q = sample_q_arg;

            if (enough_int != 0) begin
                dot_sample_ref = current_i * delayed_i_ref +
                                 current_q * delayed_q_ref;
                cross_sample_ref = current_q * delayed_i_ref -
                                   current_i * delayed_q_ref;
                dot_next_ref = ref_dot_acc + dot_sample_ref;
                cross_next_ref = ref_cross_acc + cross_sample_ref;

                if (ref_block_count >= 15) begin
                    ref_dot_acc = 64'sd0;
                    ref_cross_acc = 64'sd0;
                    ref_block_count = 0;

                    dot_abs_ref = (dot_next_ref < 0) ? -dot_next_ref : dot_next_ref;
                    cross_abs_ref = (cross_next_ref < 0) ? -cross_next_ref : cross_next_ref;
                    if ((dot_next_ref > 0) && (normalization_int != 0)) begin
                        numerator_ref = cross_abs_ref * 64'd10680836;
                        denominator_ref = dot_abs_ref * normalization_int;
                        expected_serial_numerator = numerator_ref;
                        expected_serial_denominator = denominator_ref;
                        expected_serial_pending = 1'b1;
                        quotient_ref = numerator_ref / denominator_ref;
                        if (cross_next_ref < 0) begin
                            signed_result_ref = -quotient_ref;
                        end else begin
                            signed_result_ref = quotient_ref;
                        end
                        if (signed_result_ref > 64'sd2097151) begin
                            ref_replay_value = 64'sd2097151;
                        end else if (signed_result_ref < -64'sd2097152) begin
                            ref_replay_value = -64'sd2097152;
                        end else begin
                            ref_replay_value = signed_result_ref;
                        end
                        ref_replay_ambiguous = 1'b0;
                    end else begin
                        expected_serial_pending = 1'b0;
                        ref_replay_value = 64'sd0;
                        ref_replay_ambiguous = 1'b1;
                    end
                    ref_replay_count = 16;
                end else begin
                    ref_dot_acc = dot_next_ref;
                    ref_cross_acc = cross_next_ref;
                    ref_block_count = ref_block_count + 1;
                end
            end

            // Match the DUT's nonblocking shift: every stage reads the old
            // lower stage, so the reference must move from high to low.
            for (k = 7; k > 0; k = k - 1) begin
                ref_i_delay[k] = ref_i_delay[k-1];
                ref_q_delay[k] = ref_q_delay[k-1];
            end
            ref_i_delay[0] = current_i;
            ref_q_delay[0] = current_q;
            if (ref_valid_count != 15) begin
                ref_valid_count = ref_valid_count + 1;
            end
        end
    endtask

    task push_sample;
        input integer sample_i_arg;
        input integer sample_q_arg;
        integer expected_valid;
        integer expected_block;
        integer expected_ambiguous;
        reg signed [63:0] expected_value;
        integer busy_cycles;
        integer pad_cycles;
        begin
            expected_valid = (ref_replay_count != 0);
            expected_block = (ref_replay_count == 16);
            expected_ambiguous = ref_replay_ambiguous;
            expected_value = ref_replay_value;

            @(negedge clk_125m);
            i_in = sample_i_arg;
            q_in = sample_q_arg;
            sample_valid = 1'b1;
            @(posedge clk_125m);
            #1;
            sample_valid = 1'b0;
            accepted_count = accepted_count + 1;
            if ((cycle_count - last_accept_cycle) < min_sample_interval) begin
                min_sample_interval = cycle_count - last_accept_cycle;
            end
            last_accept_cycle = cycle_count;

            compare_outputs(expected_valid, expected_block, expected_value,
                            expected_ambiguous);
            if (ref_replay_count != 0) begin
                ref_replay_count = ref_replay_count - 1;
            end
            update_reference(sample_i_arg, sample_q_arg);

            busy_cycles = 0;
            while (dut.sample_math_busy) begin
                @(posedge clk_125m);
                #1;
                busy_cycles = busy_cycles + 1;
                if (busy_cycles > 6) begin
                    fail_now("sample arithmetic busy exceeded six clocks");
                end
            end
            if (busy_cycles > max_sample_busy) begin
                max_sample_busy = busy_cycles;
            end

            // Keep the sample cadence safely above the R=8 worst-case budget.
            for (pad_cycles = 0; pad_cycles < 300; pad_cycles = pad_cycles + 1) begin
                @(posedge clk_125m);
                #1;
            end
        end
    endtask

    task run_static_case;
        input [1:0] delay_arg;
        input integer rate_arg;
        begin
            delay_sel = delay_arg;
            rate_r = rate_arg;
            reset_dut;
            for (n = 0; n < 42; n = n + 1) begin
                push_sample(1000, 0);
            end
            if (observed_valid_count == 0 || observed_block_count == 0) begin
                fail_now("static case produced no replay result");
            end
        end
    endtask

    task run_ramp_case;
        input [1:0] delay_arg;
        input integer rate_arg;
        input integer direction;
        integer ramp_i;
        integer ramp_q;
        begin
            delay_sel = delay_arg;
            rate_r = rate_arg;
            reset_dut;
            for (n = 0; n < 58; n = n + 1) begin
                ramp_i = 1000 - (10 * n);
                ramp_q = direction * (100 * n);
                push_sample(ramp_i, ramp_q);
            end
            if (observed_valid_count == 0 || observed_block_count == 0) begin
                fail_now("ramp case produced no replay result");
            end
        end
    endtask

    task run_zero_case;
        begin
            delay_sel = 2'd0;
            rate_r = 12;
            reset_dut;
            for (n = 0; n < 38; n = n + 1) begin
                push_sample(0, 0);
            end
            if (!ref_replay_ambiguous) begin
                fail_now("zero case did not reach ambiguous reference result");
            end
        end
    endtask

    always @(posedge clk_125m) begin
        cycle_count = cycle_count + 1;
        #1;
        if (dut.divide_busy && expected_serial_pending) begin
            if (dut.serial_numerator !== expected_serial_numerator ||
                dut.serial_denominator !== expected_serial_denominator) begin
                $display("FAIL: serial scaling mismatch delay=%0d rate=%0d accepted=%0d num=%0d expected=%0d den=%0d expected=%0d cross_abs=%0d dot_abs=%0d norm=%0d",
                         delay_sel, rate_r, accepted_count,
                         dut.serial_numerator, expected_serial_numerator,
                         dut.serial_denominator, expected_serial_denominator,
                         dut.serial_cross_abs, dut.serial_dot_abs,
                         dut.serial_normalization);
                $finish;
            end
            expected_serial_pending = 1'b0;
        end
    end

    initial begin
        clk_125m = 1'b0;
        rst_125m = 1'b1;
        clear = 1'b1;
        sample_valid = 1'b0;
        i_in = 20'sd0;
        q_in = 20'sd0;
        delay_sel = 2'd0;
        rate_r = 9'd12;
        failures = 0;
        cycle_count = 0;
        reset_reference;

        repeat (4) @(posedge clk_125m);
        rst_125m = 1'b0;
        clear = 1'b0;

        run_static_case(2'd0, 8);
        run_static_case(2'd1, 12);
        run_static_case(2'd2, 16);
        run_static_case(2'd3, 312);
        run_ramp_case(2'd0, 12, 1);
        run_ramp_case(2'd1, 16, 1);
        run_ramp_case(2'd2, 8, -1);
        run_ramp_case(2'd3, 312, -1);
        run_zero_case;

        if (max_sample_busy > 6) begin
            fail_now("sample busy metric exceeded limit");
        end
        if (min_sample_interval < 300) begin
            fail_now("test cadence unexpectedly collapsed");
        end
        if (expected_serial_pending) begin
            fail_now("serial scaling result was never observed");
        end
        $display("PASS: fll_cross_dot_stage_a_tb accepted=%0d valid=%0d blocks=%0d max_sample_busy=%0d min_interval=%0d",
                 accepted_count, observed_valid_count, observed_block_count,
                 max_sample_busy, min_sample_interval);
        $finish;
    end

endmodule

`default_nettype wire
