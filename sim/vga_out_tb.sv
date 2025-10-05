`timescale 1ns / 1ps

module vga_out_tb();
  logic clk, rst;
  logic [3:0] r_in, g_in, b_in;
  logic [3:0] pix_r, pix_g, pix_b;
  logic hsync, vsync;
  logic [10:0] curr_x;
  logic [9:0]  curr_y;

  vga_out uut (
    .clk84mhz(clk),   .rst(rst),
    .r_in(r_in),      .g_in(g_in),    .b_in(b_in),
    .VGA_R(pix_r),    .VGA_G(pix_g),  .VGA_B(pix_b),
    .VGA_HS(hsync),   .VGA_VS(vsync),
    .curr_x(curr_x),  .curr_y(curr_y)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    {r_in, g_in, b_in} = 12'hF00;
    #15 rst = 0;
    #200000 $finish;
  end

endmodule
