`timescale 1ns / 1ps

module vga_out_tb();
  logic clk, rst;
  logic [3:0] r_in, g_in, b_in;
  logic [3:0] pix_r, pix_g, pix_b;
  logic hsync, vsync;
  logic [10:0] curr_x;
  logic [9:0]  curr_y;

  vga_out uut (
    .i_clk(clk),   .i_rst(rst),
    .i_r(r_in),      .i_g(g_in),    .i_b(b_in),
    .o_pix_r(pix_r),    .o_pix_g(pix_g),  .o_pix_b(pix_b),
    .o_hsync(hsync),   .o_vsync(vsync),
    .o_curr_x(curr_x),  .o_curr_y(curr_y)
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
