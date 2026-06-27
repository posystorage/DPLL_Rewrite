//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/09/10 16:12:58
// Design Name: 
// Module Name: PLL_VCO_MUL_DIV
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module PLL_VCO_MUL_DIV(
    input wire clk,
    input wire sample_valid,
    input wire [47:0] data_in,
    output reg [47:0] data_out,
    input wire [15:0] PLL_Mul_factor,
    input wire [15:0] PLL_Div_factor
    );
    reg [48-1:0]clk_data_in = 0;
    reg [48-1:0]clk_data_in_reg = 0;
    reg clk_data_ready = 0;
    reg clk_data_ready_reg = 0;
    reg clk_data_ready_reg_d1 = 0;
    wire [48+16-1:0]PLL_Mul_Data; 
    wire [48+16-1:0]PLL_Div_Data ;
    wire m_axis_data_tvalid;  
    reg [48-1:0]PLL_Div_Data_reg;
    // Capture the lower-rate DPLL word with a one-cycle valid pulse in clk domain.
always @(posedge clk) begin
    if (sample_valid)
    begin
        clk_data_ready <= 1;
        clk_data_in <= data_in;
    end    
    else begin
        clk_data_ready <= 0;
    end
    clk_data_in_reg <= clk_data_in;
    clk_data_ready_reg <= clk_data_ready;//ÑÓÊ±1clk
    clk_data_ready_reg_d1 <= clk_data_ready_reg;//ÑÓÊ±2clk
end  
    
    
    mult_gen_pll VCO0_Multiplier(
    .CLK(clk),
    .A(clk_data_in_reg),   
    .B(PLL_Mul_factor),
    .P(PLL_Mul_Data)
    );   
    
div_gen_pll VCO0_Divider(
     .aclk                    (clk),
     .s_axis_divisor_tvalid   (1),
     .s_axis_divisor_tdata    (PLL_Div_factor),
     .s_axis_dividend_tvalid  (clk_data_ready_reg_d1),
     .s_axis_dividend_tdata   (PLL_Mul_Data),
     .m_axis_dout_tvalid      (m_axis_data_tvalid),
     .m_axis_dout_tdata       (PLL_Div_Data)
    ); 
    //assign    
always @(posedge clk) begin
    if(m_axis_data_tvalid)
    begin
        PLL_Div_Data_reg <= PLL_Div_Data[63:16]; 
    end
    data_out <= PLL_Div_Data_reg;
end    
          
endmodule
