`timescale 1ns/1ps

module game_top (
    input  logic        CLK100MHZ,
    input  logic        CPU_RESETN,
    output logic [3:0]  VGA_R, VGA_G, VGA_B,
    output logic        VGA_HS, VGA_VS
);

  wire pixclk, rst;
  assign rst = ~CPU_RESETN; // the reset button is reversed (lost too much time on that :( )

  clk_wiz_0 pixclk_i ( // Set pixclk to 84MHz
    .clk_in1  (CLK100MHZ),
    .clk_out1 (pixclk)
  );

  // Get the VGA timing signals
  logic [10:0] curr_x;
  logic [9:0]  curr_y;
  logic [3:0]  r, g, b;
  vga_out vga_out_u (
    .clk84mhz (pixclk), .rst    (rst),
    .r_in     (r),      .g_in   (g),      .b_in  (b),  // white background
    .VGA_R    (VGA_R),  .VGA_G  (VGA_G),  .VGA_B (VGA_B), // VGA color output
    .VGA_HS   (VGA_HS), .VGA_VS (VGA_VS),                  // horizontal and vertical sync
    .curr_x   (curr_x), .curr_y (curr_y)                   // what pixel are we on
  );

  localparam logic [11:0] 
      C_BLACK  = 12'h000,
      C_WHITE  = 12'hFFF,
      C_RED    = 12'hF00,
      C_GREEN  = 12'h0F0,
      C_BLUE   = 12'h00F;

  localparam int SCREEN_W = 1280;
  localparam int SCREEN_H = 800;

  always_ff @(posedge pixclk) begin
    if (rst)                              { r, g, b } <= C_BLACK;
    else begin
      if (curr_x < (SCREEN_W/3))          { r, g, b } <= C_GREEN;
      else if (curr_x < (2*(SCREEN_W/3))) { r, g, b } <= C_WHITE;
      else                                { r, g, b } <= C_RED;
    end
  end

  // TODO: TO be tested later
  // logic [10:0] blkpos_x = 11'd200;
  // logic [9:0]  blkpos_y = 10'd120;
  //
  // drawcon drawcon_i (
  //   .blkpos_x(blkpos_x), .blkpos_y(blkpos_y),
  //   .draw_x(curr_x),     .draw_y(curr_y),
  //   .r(r), .g(g), .b(b)
  // );

endmodule
