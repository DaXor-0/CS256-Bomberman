`timescale 1ns / 1ps

module clk_divider_tb();
  logic clk;
  
  clk_divider uut (clk, clk_out);
  
  initial begin clk = 0; forever begin #5 clk = ~clk; end end
  
endmodule
