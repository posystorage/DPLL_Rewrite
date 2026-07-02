`timescale 1ns / 1ps
`default_nettype none

module cordic_word_serial_adapter #(
    parameter integer IQ_WIDTH    = 20,
    parameter integer PHASE_WIDTH = 18,
    parameter integer MAG_WIDTH   = 20
) (
    input  wire                         clk_125m,
    input  wire                         rst_125m,
    input  wire                         clear,

    input  wire                         in_valid,
    input  wire signed [IQ_WIDTH-1:0]   i_in,
    input  wire signed [IQ_WIDTH-1:0]   q_in,

    output wire                         out_valid,
    output wire signed [PHASE_WIDTH-1:0] phase_out,
    output wire        [MAG_WIDTH-1:0]   magnitude_out,

    output wire                         busy,
    output reg                          input_overrun_seen,
    output reg                          input_out_of_range_seen,
    output reg                          output_format_error_seen
);

    localparam signed [IQ_WIDTH-1:0] IQ_LIMIT_POS = 20'sd262144;
    localparam signed [IQ_WIDTH-1:0] IQ_LIMIT_NEG = -20'sd262144;

    reg [2:0] reset_count;
    reg guard_count;
    wire reset_active = rst_125m || (reset_count != 3'd0) || guard_count;
    wire cordic_aresetn = !reset_active;

    reg signed [IQ_WIDTH-1:0] fifo_i [0:1];
    reg signed [IQ_WIDTH-1:0] fifo_q [0:1];
    reg [1:0] fifo_count;
    reg [7:0] outstanding_count;

    wire [23:0] cordic_x_lane = {{4{fifo_i[0][IQ_WIDTH-1]}}, fifo_i[0]};
    wire [23:0] cordic_y_lane = {{4{fifo_q[0][IQ_WIDTH-1]}}, fifo_q[0]};
    wire [47:0] cordic_s_tdata = {cordic_y_lane, cordic_x_lane};
    wire        cordic_s_tvalid = (fifo_count != 2'd0) && !reset_active;
    wire        cordic_s_tready;
    wire        input_fire = cordic_s_tvalid && cordic_s_tready;

    wire        cordic_m_tvalid;
    wire [47:0] cordic_m_tdata;
    wire        output_fire = cordic_m_tvalid && !reset_active && (outstanding_count != 8'd0);
    wire        fifo_pop = input_fire;
    wire        fifo_can_push = (fifo_count != 2'd2) || fifo_pop;
    wire        fifo_push = in_valid && !reset_active && fifo_can_push;
    wire        fifo_overrun = in_valid && !reset_active && !fifo_can_push;
    wire        input_out_of_range =
        (i_in > IQ_LIMIT_POS) || (i_in < IQ_LIMIT_NEG) ||
        (q_in > IQ_LIMIT_POS) || (q_in < IQ_LIMIT_NEG);
    wire        output_format_error =
        (cordic_m_tdata[23:20] != {4{cordic_m_tdata[19]}}) ||
        (cordic_m_tdata[47:44] != {4{cordic_m_tdata[43]}});

    dpll_angle_CORDIC cordic_inst (
        .aclk(clk_125m),
        .aresetn(cordic_aresetn),
        .s_axis_cartesian_tvalid(cordic_s_tvalid),
        .s_axis_cartesian_tready(cordic_s_tready),
        .s_axis_cartesian_tdata(cordic_s_tdata),
        .m_axis_dout_tvalid(cordic_m_tvalid),
        .m_axis_dout_tdata(cordic_m_tdata)
    );

    always @(posedge clk_125m) begin
        if (rst_125m || clear) begin
            reset_count <= 3'd3;
            guard_count <= 1'b0;
        end else if (reset_count != 3'd0) begin
            reset_count <= reset_count - 1'b1;
            guard_count <= (reset_count == 3'd1);
        end else begin
            guard_count <= 1'b0;
        end
    end

    always @(posedge clk_125m) begin
        if (rst_125m || clear) begin
            fifo_i[0] <= {IQ_WIDTH{1'b0}};
            fifo_i[1] <= {IQ_WIDTH{1'b0}};
            fifo_q[0] <= {IQ_WIDTH{1'b0}};
            fifo_q[1] <= {IQ_WIDTH{1'b0}};
            fifo_count <= 2'd0;
            outstanding_count <= 8'd0;
        end else if (reset_active) begin
            fifo_count <= 2'd0;
            outstanding_count <= 8'd0;
        end else begin
            case ({fifo_push, fifo_pop})
                2'b10: begin
                    if (fifo_count == 2'd0) begin
                        fifo_i[0] <= i_in;
                        fifo_q[0] <= q_in;
                    end else begin
                        fifo_i[1] <= i_in;
                        fifo_q[1] <= q_in;
                    end
                    fifo_count <= fifo_count + 1'b1;
                end
                2'b01: begin
                    fifo_i[0] <= fifo_i[1];
                    fifo_q[0] <= fifo_q[1];
                    fifo_count <= fifo_count - 1'b1;
                end
                2'b11: begin
                    if (fifo_count == 2'd1) begin
                        fifo_i[0] <= i_in;
                        fifo_q[0] <= q_in;
                    end else begin
                        fifo_i[0] <= fifo_i[1];
                        fifo_q[0] <= fifo_q[1];
                        fifo_i[1] <= i_in;
                        fifo_q[1] <= q_in;
                    end
                end
                default: begin
                    fifo_count <= fifo_count;
                end
            endcase

            if (input_fire && !output_fire) begin
                outstanding_count <= outstanding_count + 1'b1;
            end else if (!input_fire && output_fire) begin
                outstanding_count <= outstanding_count - 1'b1;
            end
        end
    end

    always @(posedge clk_125m) begin
        if (rst_125m) begin
            input_overrun_seen <= 1'b0;
            input_out_of_range_seen <= 1'b0;
            output_format_error_seen <= 1'b0;
        end else begin
            if (fifo_overrun) begin
                input_overrun_seen <= 1'b1;
            end
            if (in_valid && !reset_active && input_out_of_range) begin
                input_out_of_range_seen <= 1'b1;
            end
            if (output_fire && output_format_error) begin
                output_format_error_seen <= 1'b1;
            end
        end
    end

    assign out_valid = output_fire;
    assign magnitude_out = cordic_m_tdata[19:0];
    assign phase_out = cordic_m_tdata[24+:PHASE_WIDTH];
    assign busy = reset_active || (fifo_count != 2'd0) || (outstanding_count != 8'd0);

endmodule

`default_nettype wire
