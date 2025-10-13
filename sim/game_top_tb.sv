`timescale 1ns / 1ps

module game_top_tb();
  logic clk, rst;
  logic hsync, vsync;
  logic [3:0] pix_r, pix_g, pix_b;
  
  game_top uut (
    .CLK100MHZ(clk),
    .CPU_RESETN(rst),
    .o_pix_r(pix_r),
    .o_pix_g(pix_g),
    .o_pix_b(pix_b),
    .o_hsync(hsync),
    .o_vsync(vsync)
  );
  
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 0;
    #15 rst = 1;
    #200000 $finish;
  end
 
endmodule