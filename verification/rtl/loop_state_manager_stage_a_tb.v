`timescale 1ns / 1ps

module loop_state_manager_stage_a_tb;
    localparam [3:0] ST_DISABLED      = 4'd1;
    localparam [3:0] ST_WARMUP        = 4'd3;
    localparam [3:0] ST_FLL_ACQUIRE   = 4'd4;
    localparam [3:0] ST_FLL_PLL_BLEND = 4'd5;
    localparam [3:0] ST_PLL_TRACK     = 4'd6;
    localparam [3:0] ST_HOLDOVER      = 4'd7;
    localparam [3:0] ST_REACQUIRE     = 4'd8;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg loop_enable = 1'b0;
    reg config_apply = 1'b0;
    reg measurement_valid = 1'b0;
    reg [17:0] phase_abs = 18'd0;
    reg [21:0] freq_abs = 22'd0;
    reg [15:0] magnitude = 16'd0;
    reg cic_fault = 1'b0;
    reg correction_saturated = 1'b0;

    wire enable_fll;
    wire enable_pll_i;
    wire enable_pll_p;
    wire signed [23:0] active_kf;
    wire signed [23:0] active_ki;
    wire signed [23:0] active_kp;
    wire [3:0] loop_state;
    wire [3:0] loss_reason;
    wire signal_present;
    wire phase_locked;
    wire frequency_locked;
    wire locked;

    always #4 clk = ~clk;

    loop_state_manager_stage_a dut (
        .clk_125m(clk),
        .rst_125m(rst),
        .loop_enable(loop_enable),
        .config_apply(config_apply),
        .measurement_valid(measurement_valid),
        .measurement_timeout(24'd8),
        .phase_abs(phase_abs),
        .freq_abs(freq_abs),
        .magnitude(magnitude),
        .cic_fault(cic_fault),
        .correction_saturated(correction_saturated),
        .phase_lock_threshold(18'd100),
        .freq_lock_threshold(22'd200),
        .mag_enter_threshold(16'd10),
        .mag_exit_threshold(16'd4),
        .acquire_dwell(16'd2),
        .blend_dwell(16'd2),
        .loss_dwell(16'd2),
        .holdover_timeout(24'd8),
        .warmup_samples(16'd1),
        .kf_acquire(24'sd11),
        .kf_blend(24'sd7),
        .kf_track(24'sd3),
        .kp_blend(24'sd5),
        .ki_blend(24'sd6),
        .kp_track(24'sd2),
        .ki_track(24'sd1),
        .enable_fll(enable_fll),
        .enable_pll_i(enable_pll_i),
        .enable_pll_p(enable_pll_p),
        .active_kf(active_kf),
        .active_ki(active_ki),
        .active_kp(active_kp),
        .loop_state(loop_state),
        .loss_reason(loss_reason),
        .signal_present(signal_present),
        .phase_locked(phase_locked),
        .frequency_locked(frequency_locked),
        .locked(locked)
    );

    task push_measurement;
        input [17:0] phase_value;
        input [21:0] freq_value;
        input [15:0] mag_value;
        begin
            @(negedge clk);
            phase_abs = phase_value;
            freq_abs = freq_value;
            magnitude = mag_value;
            measurement_valid = 1'b1;
            @(posedge clk);
            #1;
            measurement_valid = 1'b0;
        end
    endtask

    task expect_state;
        input [3:0] expected;
        begin
            if (loop_state !== expected) begin
                $display("FAIL: expected state %0d got %0d", expected, loop_state);
                $finish;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
        expect_state(ST_DISABLED);

        @(negedge clk);
        loop_enable = 1'b1;
        config_apply = 1'b1;
        @(posedge clk);
        #1;
        config_apply = 1'b0;
        repeat (2) @(posedge clk);
        expect_state(ST_WARMUP);

        push_measurement(18'd20, 22'd30, 16'd20);
        repeat (1) @(posedge clk);
        expect_state(ST_FLL_ACQUIRE);
        if (enable_fll !== 1'b1 || enable_pll_i !== 1'b0 || active_kf !== 24'sd11) begin
            $display("FAIL: acquire enables/kf incorrect");
            $finish;
        end

        push_measurement(18'd20, 22'd30, 16'd20);
        push_measurement(18'd20, 22'd30, 16'd20);
        expect_state(ST_FLL_PLL_BLEND);
        if (enable_fll !== 1'b1 || enable_pll_i !== 1'b1 || active_kf !== 24'sd7 ||
            active_kp !== 24'sd5 || active_ki !== 24'sd6) begin
            $display("FAIL: blend enables/coefficients incorrect");
            $finish;
        end

        push_measurement(18'd20, 22'd30, 16'd20);
        push_measurement(18'd20, 22'd30, 16'd20);
        expect_state(ST_PLL_TRACK);
        @(posedge clk);
        #1;
        if (locked !== 1'b1 || active_kf !== 24'sd3 ||
            active_kp !== 24'sd2 || active_ki !== 24'sd1) begin
            $display("FAIL: track lock/coefficients incorrect");
            $finish;
        end

        push_measurement(18'd20, 22'd30, 16'd1);
        push_measurement(18'd20, 22'd30, 16'd1);
        push_measurement(18'd20, 22'd30, 16'd1);
        expect_state(ST_HOLDOVER);
        if (loss_reason !== 4'd1) begin
            $display("FAIL: expected signal loss reason got %0d", loss_reason);
            $finish;
        end

        push_measurement(18'd20, 22'd30, 16'd20);
        push_measurement(18'd20, 22'd30, 16'd20);
        repeat (1) @(posedge clk);
        expect_state(ST_REACQUIRE);

        push_measurement(18'd20, 22'd30, 16'd20);
        push_measurement(18'd20, 22'd30, 16'd20);
        expect_state(ST_FLL_PLL_BLEND);
        push_measurement(18'd20, 22'd30, 16'd20);
        push_measurement(18'd20, 22'd30, 16'd20);
        expect_state(ST_PLL_TRACK);
        repeat (10) @(posedge clk);
        expect_state(ST_HOLDOVER);
        if (loss_reason !== 4'd6) begin
            $display("FAIL: expected timeout loss reason got %0d", loss_reason);
            $finish;
        end

        $display("PASS: loop_state_manager_stage_a_tb");
        $finish;
    end
endmodule
