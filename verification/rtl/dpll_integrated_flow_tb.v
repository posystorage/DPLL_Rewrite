`timescale 1ns / 1ps
`default_nettype none

module dpll_integrated_flow_tb;
    localparam [47:0] ADC_DDS_WORD    = 48'h000b_45ae_5ffa; // 21.5 kHz at 125 MHz
    localparam [31:0] CENTER_WORD_HI  = 32'h000b_88ca;      // 22 kHz, high 32 bits
    localparam [31:0] PHASE_LOCK_THRESHOLD_LSB = 32'd5825;  // 8 deg, 2^18 LSB/turn
    localparam [31:0] FREQ_LOCK_THRESHOLD_LSB  = 32'd2147;  // 100 Hz, ~0.046566 Hz/LSB
    localparam integer RESET_DELAY_CYCLES = 4096;
    localparam integer INIT_SETTLE_CYCLES = 4096;
    localparam integer RUN_CYCLES_0   = 2500000;
    localparam integer RUN_CYCLES_1   = 3750000;

    reg clk1 = 1'b0;
    reg sys_clk = 1'b0;
    reg rst = 1'b0;
    reg sys_rstn = 1'b0;

    reg [31:0] sys_addr = 32'd0;
    reg [31:0] sys_wdata = 32'd0;
    reg [3:0]  sys_sel = 4'hf;
    reg        sys_wen = 1'b0;
    reg        sys_ren = 1'b0;

    wire [31:0] sys_rdata;
    wire        sys_err;
    wire        sys_ack;
    wire signed [15:0] dac0_out;
    wire signed [15:0] dac1_debug_out;
    wire [6:0] led;

    wire adc_dds_valid;
    wire [15:0] adc_dds_sample_raw;
    wire signed [31:0] adc_dds_scaled_wide;
    wire signed [15:0] adc_dds_scaled_16;
    wire signed [13:0] adc_dds_adc14;
    reg signed [15:0] adc_sample = 16'sd0;
    reg [31:0] adc_sample_count = 32'd0;

    integer n;
    reg [31:0] read_data;

    always #4 clk1 = ~clk1;      // 125 MHz DPLL/data clock
    always #5 sys_clk = ~sys_clk; // 100 MHz register bus clock

    DAC_DDS0 adc_stimulus_dds (
        .aclk(clk1),
        .s_axis_phase_tvalid(1'b1),
        .s_axis_phase_tdata(ADC_DDS_WORD),
        .m_axis_data_tvalid(adc_dds_valid),
        .m_axis_data_tdata(adc_dds_sample_raw)
    );

//    assign adc_dds_scaled_wide = ($signed(adc_dds_sample_raw) * 32'sd4) / 32'sd5;
//    assign adc_dds_scaled_16 = adc_dds_scaled_wide[15:0];
    assign adc_dds_scaled_16 = adc_dds_sample_raw;
    assign adc_dds_adc14 = adc_dds_scaled_16[15:2];

    always @(posedge clk1) begin
        if (!rst) begin
            adc_sample <= 16'sd0;
            adc_sample_count <= 32'd0;
        end else if (adc_dds_valid) begin
            adc_sample <= {adc_dds_adc14, 2'b0};
            adc_sample_count <= adc_sample_count + 32'd1;
        end
    end

    dpll_wrapper dut (
        .clk1(clk1),
        .rst(rst),
        .sys_clk(sys_clk),
        .sys_rstn(sys_rstn),
        .ADCraw0(adc_sample),
        .DACout0(dac0_out),
        .DACout1(dac1_debug_out),
        .sys_addr(sys_addr),
        .sys_wdata(sys_wdata),
        .sys_sel(sys_sel),
        .sys_wen(sys_wen),
        .sys_ren(sys_ren),
        .sys_rdata(sys_rdata),
        .sys_err(sys_err),
        .sys_ack(sys_ack),
        .led(led)
    );

    task bus_write;
        input [15:0] index;
        input [31:0] value;
        begin
            @(negedge sys_clk);
            sys_addr = {14'd0, index, 2'b00};
            sys_wdata = value;
            sys_sel = 4'hf;
            sys_wen = 1'b1;
            sys_ren = 1'b0;
            @(posedge sys_clk);
            #1;
            if (!sys_ack) begin
                $display("FAIL: write timeout index=0x%04h value=0x%08h", index, value);
                $finish;
            end
            if (sys_err) begin
                $display("FAIL: write returned sys_err index=0x%04h value=0x%08h", index, value);
                $finish;
            end
            @(negedge sys_clk);
            sys_wen = 1'b0;
            sys_wdata = 32'd0;
        end
    endtask

    task bus_read;
        input [15:0] index;
        output [31:0] value;
        integer wait_count;
        begin
            @(negedge sys_clk);
            sys_addr = {14'd0, index, 2'b00};
            sys_wen = 1'b0;
            sys_ren = 1'b1;
            @(posedge sys_clk);
            #1;
            wait_count = 0;
            while (!sys_ack && wait_count < 64) begin
                @(posedge sys_clk);
                #1;
                wait_count = wait_count + 1;
            end
            if (!sys_ack) begin
                $display("FAIL: read timeout index=0x%04h", index);
                $finish;
            end
            value = sys_rdata;
            @(negedge sys_clk);
            sys_ren = 1'b0;
        end
    endtask

    task wait_apply_done;
        integer wait_count;
        reg [31:0] apply_status;
        begin
            wait_count = 0;
            apply_status = 32'h0000_0001;
            while (((apply_status[0] == 1'b1) || (apply_status[15:8] == 8'd0)) && wait_count < 128) begin
                bus_read(16'h006f, apply_status);
                wait_count = wait_count + 1;
            end
            if (apply_status[0]) begin
                $display("FAIL: CONFIG_APPLY busy stuck status=0x%08h", apply_status);
                $finish;
            end
            if (apply_status[1]) begin
                bus_read(16'h0070, apply_status);
                $display("FAIL: CONFIG_APPLY rejected mask=0x%08h", apply_status);
                $finish;
            end
        end
    endtask

    task log_read;
        input [15:0] index;
        input [8*32-1:0] name;
        begin
            bus_read(index, read_data);
            $display("READ %-32s index=0x%04h data=0x%08h time=%0t", name, index, read_data, $time);
        end
    endtask

    task run_clocks;
        input integer count;
        begin
            for (n = 0; n < count; n = n + 1) begin
                @(posedge clk1);
            end
        end
    endtask

    initial begin
        $timeformat(-9, 3, " ns", 12);
        $display("DPLL integrated flow TB started");

        run_clocks(16);
        rst = 1'b1;
        sys_rstn = 1'b1;
        run_clocks(16);

        log_read(16'h010e, "ABI_VERSION");
        log_read(16'h010f, "FPGA_BUILD_ID");

        $display("ARM-style startup: reset DPLL, keep lock disabled, then wait");
        bus_write(16'h0000, 32'h0000_0001);
        bus_write(16'h0020, 32'h0000_0000);
        run_clocks(RESET_DELAY_CYCLES);

        $display("Programming DPLL register shadow set for 22 kHz center, 21.5 kHz ADC DDS input");
        bus_write(16'h0010, CENTER_WORD_HI);
        bus_write(16'h0011, 32'h0000_0000);
        bus_write(16'h0021, 32'd40000);
        bus_write(16'h0022, 32'd117200);
        bus_write(16'h0023, 32'd8000000);
        bus_write(16'h0024, 32'd4000000);
        bus_write(16'h0025, 32'd0);
        bus_write(16'h0026, 32'd40000);
        bus_write(16'h0027, 32'd117200);
        bus_write(16'h0028, 32'h7fff_fffe);
        bus_write(16'h0029, 32'h8000_0001);
        bus_write(16'h002a, 32'h0000_0000);
        bus_write(16'h0030, 32'h0000_0000);
        bus_write(16'h0031, 32'h0000_7fff);
        bus_write(16'h0032, 32'h0000_0001);
        bus_write(16'h0033, 32'h0000_0001);
        bus_write(16'h0040, 32'h0000_0000);
        bus_write(16'h0041, 32'h0000_7fff);
        bus_write(16'h0042, 32'h0000_0007);
        bus_write(16'h0043, 32'h0000_0106);
        bus_write(16'h0050, PHASE_LOCK_THRESHOLD_LSB);
        bus_write(16'h0051, 32'h0000_0000);
        bus_write(16'h0052, FREQ_LOCK_THRESHOLD_LSB);
        bus_write(16'h0053, 32'd16384);
        bus_write(16'h0054, 32'd8192);
        bus_write(16'h0055, 32'd16);
        bus_write(16'h0056, 32'd128);
        bus_write(16'h0057, 32'd64);
        bus_write(16'h0058, 32'd1250000);
        bus_write(16'h0059, 32'd65535);
        bus_write(16'h0060, 32'h0000_000c);
        bus_write(16'h0061, 32'h0000_0006);
        bus_write(16'h0062, 32'h0000_0003);
        bus_write(16'h0063, 32'd16);
        bus_write(16'h0064, 32'h0000_0003);
        bus_write(16'h0065, 32'h0848_991f);
        bus_write(16'h0066, 32'h1091_323f);
        bus_write(16'h0067, 32'h0848_991f);
        bus_write(16'h0068, 32'hcf8c_92d0);
        bus_write(16'h0069, 32'h1195_d1ad);
        bus_write(16'h006a, 32'h02e9_6a90);
        bus_write(16'h006b, 32'h05d2_d51f);
        bus_write(16'h006c, 32'h02e9_6a90);
        bus_write(16'h006d, 32'habfe_403c);
        bus_write(16'h006e, 32'h1fa7_6a03);
        run_clocks(INIT_SETTLE_CYCLES);
        bus_write(16'h006f, 32'h0000_0001);
        wait_apply_done();
        run_clocks(INIT_SETTLE_CYCLES);
        bus_write(16'h0020, 32'h0000_0001);

        log_read(16'h0110, "ACTIVE_CENTER_WORD_HI");
        log_read(16'h0111, "ACTIVE_CIC_CONFIG");
        log_read(16'h0112, "ACTIVE_OUTPUT_MUL_DIV");
        log_read(16'h011e, "ACTIVE_CONFIG_CRC");
        log_read(16'h011f, "ACTIVE_POST_IIR_CONFIG");
        log_read(16'h0120, "ACTIVE_POST_IIR_ACQ_B0");
        log_read(16'h0123, "ACTIVE_POST_IIR_ACQ_A1");
        log_read(16'h0125, "ACTIVE_POST_IIR_TRACK_B0");
        log_read(16'h0128, "ACTIVE_POST_IIR_TRACK_A1");

        $display("Running DDS-driven ADC stimulus, debug DAC source = CORDIC phase");
        run_clocks(RUN_CYCLES_0);

        log_read(16'h0100, "DPLL_STATUS");
        log_read(16'h0101, "MAGNITUDE");
        log_read(16'h0102, "CORDIC_PHASE");
        log_read(16'h0103, "FLL_ERROR");
        log_read(16'h0104, "FREQ_CORRECTION");
        log_read(16'h0105, "TRACKING_WORD_LO");
        log_read(16'h0108, "LOOP_STATE_FLAGS");
        log_read(16'h010b, "OUTPUT_WORD_LO");
        log_read(16'h010c, "OUTPUT_WORD_HI");

        $display("Switching DACout1 debug source to magnitude");
        bus_write(16'h0042, 32'h0000_0008);
        bus_write(16'h0043, 32'h0000_0104);
        run_clocks(RUN_CYCLES_1);

        log_read(16'h0042, "DEBUG_DAC_SOURCE");
        log_read(16'h0100, "DPLL_STATUS_FINAL");
        log_read(16'h0108, "LOOP_STATE_FLAGS_FINAL");

        if (adc_sample_count == 32'd0) begin
            $display("FAIL: ADC DDS never produced a valid sample");
            $finish;
        end

        $display("PASS: dpll_integrated_flow_tb adc_samples=%0d dac0=%0d dac1=%0d led=0b%b",
                 adc_sample_count, dac0_out, dac1_debug_out, led);
        $finish;
    end
endmodule

`default_nettype wire
