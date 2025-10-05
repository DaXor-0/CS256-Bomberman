`timescale 1ns / 1ps

module vga_timing_tb();
  logic         clk, rst;
  logic         hsync, vsync;
  logic [10:0]  pix_x;
  logic [9:0]   pix_y;
  logic         sof, eol, in_screen;

  vga_timing uut (
    .clk84mhz      (clk),     .rst       (rst),
    .VGA_HS        (hsync),   .VGA_VS    (vsync),
    .pix_x_out     (pix_x),   .pix_y_out (pix_y),
    .sof_out       (sof),     .eol_out   (eol),
    .in_screen_out (in_screen)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    #15 rst = 0;
    #200000 $finish;
  end

endmodule

