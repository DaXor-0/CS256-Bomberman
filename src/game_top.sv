`timescale 1ns/1ps

module game_top (
    input  logic        CLK100MHZ,
    input  logic        CPU_RESETN,
    input  logic        up, down, left, right,      // movement control
    output logic [3:0]  o_pix_r, o_pix_g, o_pix_b,
    output logic        o_hsync, o_vsync
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
  vga_out_cp vga_out_u (
    .i_clk    (pixclk),   .i_rst    (rst),
    .i_r      (r),        .i_g      (g),        .i_b  (b),          // white background
    .o_pix_r  (o_pix_r),  .o_pix_g  (o_pix_g),  .o_pix_b (o_pix_b), // VGA color output
    .o_hsync  (o_hsync),  .o_vsync  (o_vsync),                      // horizontal and vertical sync
    .o_curr_x (curr_x),   .o_curr_y (curr_y)                        // what pixel are we on
  );

  localparam logic [11:0] 
      C_BLACK  = 12'h000,
      C_WHITE  = 12'hFFF,
      C_RED    = 12'hF00,
      C_GREEN  = 12'h0F0,
      C_BLUE   = 12'h00F;

  localparam int SCREEN_W = 1280;
  localparam int SCREEN_H = 800;

//  always_ff @(posedge pixclk) begin
//    if (rst)                              { r, g, b } <= C_BLACK;
//    else begin
//      if (curr_x < (SCREEN_W/3))          { r, g, b } <= C_GREEN;
//      else if (curr_x < (2*(SCREEN_W/3))) { r, g, b } <= C_WHITE;
//      else if (curr_x < (SCREEN_W))       { r, g, b } <= C_RED;
//      else                                { r, g, b } <= C_BLACK;
//    end
//  end

  // TODO: TO be tested later
   logic [10:0] blkpos_x = 11'd200;
   logic [9:0]  blkpos_y = 10'd120;
  
   drawcon drawcon_i (
     .blkpos_x(blkpos_x), .blkpos_y(blkpos_y),
     .draw_x(curr_x),     .draw_y(curr_y),
     .r(r), .g(g), .b(b)
   );

endmodule
