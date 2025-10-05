`timescale 1ns/1ps

module vga_top (
    input  logic        CLK100MHZ,
    input  logic        CPU_RESETN,
    output logic [3:0]  VGA_R, VGA_G, VGA_B,
    output logic        VGA_HS, VGA_VS
);

  logic pixclk, rst;
  assign rst = ~CPU_RESETN; // the reset button is reversed (lost too much time on that :( )

  clk_wiz_0 pixclk_i ( // Set pixclk to 84MHz
    .clk_in1  (CLK100MHZ),
    .clk_out1 (pixclk)
  );

  logic [10:0] pix_x;
  logic [9:0]  pix_y;
  logic        in_screen, sof, eol; // boolean for in active screen, start of frame, end of line

  // Get the VGA timing signals
  vga_timing timing_i (
    .clk84mhz      (pixclk),    .rst       (rst),
    .VGA_HS        (VGA_HS),    .VGA_VS    (VGA_VS),  // horizontal and vertical sync
    .pix_x_out     (pix_x),     .pix_y_out (pix_y),   // what pixel are we on
    .sof_out       (sof),       .eol_out   (eol),     // start of frame, end of line
    .in_screen_out (in_screen)                        // in active screen
  );


  // Colors
  localparam logic [11:0] 
      C_BLACK  = 12'h000,
      C_WHITE  = 12'hFFF,
      C_RED    = 12'hF00,
      C_GREEN  = 12'h0F0,
      C_BLUE   = 12'h00F;

  localparam int FLAG_W = 1280 / 3;
  localparam int FLAG_H = 800;

  // Render italian flag
  logic [3:0] R_green, G_green, B_green;
  logic [3:0] R_white, G_white, B_white;
  logic [3:0] R_red,   G_red,   B_red;
  logic write_green, write_white, write_red;
  vga_render_box_rgb12 #(
    .BG (C_BLACK)
  ) flag_green_i (
    .pix_x_in   (pix_x),     .pix_y_in   (pix_y),
    .in_screen  (in_screen),
    .x_in       (0),         .width_in   (FLAG_W),
    .y_in       (0),         .height_in  (FLAG_H),
    .rgb_in     (C_GREEN),
    .VGA_R      (R_green),   .VGA_G      (G_green),  .VGA_B      (B_green),
    .write_out  (write_green)
  );

  vga_render_box_rgb12 #(
    .BG (C_BLACK)
  ) flag_white_i (
    .pix_x_in   (pix_x),     .pix_y_in   (pix_y),
    .in_screen  (in_screen),
    .x_in       (FLAG_W),    .width_in   (FLAG_W),
    .y_in       (0),         .height_in  (FLAG_H),
    .rgb_in     (C_WHITE),
    .VGA_R      (R_white),    .VGA_G      (G_white), .VGA_B      (B_white),
    .write_out  (write_white)
  );

  vga_render_box_rgb12 #(
    .BG (C_BLACK)
  ) flag_red_i (
    .pix_x_in   (pix_x),     .pix_y_in   (pix_y),
    .in_screen  (in_screen),
    .x_in       (2*FLAG_W),  .width_in   (FLAG_W),
    .y_in       (0),         .height_in  (FLAG_H),
    .rgb_in     (C_RED),
    .VGA_R      (R_red),     .VGA_G      (G_red),    .VGA_B      (B_red),
    .write_out  (write_red)
  );

  // to avoid multiple input mapped to same port
  always_comb begin
    {VGA_R, VGA_G, VGA_B} = C_BLACK;
    if      (write_red)   {VGA_R, VGA_G, VGA_B} = {R_red, G_red, B_red};
    else if (write_white) {VGA_R, VGA_G, VGA_B} = {R_white, G_white, B_white};
    else if (write_green) {VGA_R, VGA_G, VGA_B} = {R_green, G_green, B_green};
  end

endmodule
