`timescale 1ns / 1ps

module vga_out_tb();
  logic clk, rst;
  logic [3:0] in_r, in_g, in_b;
  logic [3:0] pix_r, pix_g, pix_b;
  logic hsync, vsync;

  vga_out uut (
    .clk(clk),
    .rst(rst),
    .in_r(in_r),
    .in_g(in_g),
    .in_b(in_b),
    .pix_r(pix_r),
    .pix_g(pix_g),
    .pix_b(pix_b),
    .hsync(hsync),
    .vsync(vsync)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    in_r = 4'hF;
    in_g = 4'hF;
    in_b = 4'hF;
    #15 rst = 0;
    #200000 $finish;
  end

endmodule
