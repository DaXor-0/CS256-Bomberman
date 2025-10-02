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
    .VGA_R(pix_r),
    .VGA_G(pix_g),
    .VGA_B(pix_b),
    .VGA_HS(hsync),
    .VGA_VS(vsync)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    {in_r, in_g, in_b} = 12'hF00;
    #15 rst = 0;
    #200000 $finish;
  end

endmodule
