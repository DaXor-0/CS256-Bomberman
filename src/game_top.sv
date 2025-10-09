`timescale 1ns/1ps

module game_top (
    input  logic        CLK100MHZ,
    input  logic        CPU_RESETN,
    input  logic        up, down, left, right,      // movement control
    output logic [3:0]  o_pix_r, o_pix_g, o_pix_b,
    output logic        o_hsync, o_vsync
);

  wire pixclk, rst, clk6Mhz, clk60hz;
  assign rst = ~CPU_RESETN; // the reset button is reversed (lost too much time on that :( )

  clk_wiz_0 pixclk_i ( // Set pixclk to 84MHz
    .clk_in1  (CLK100MHZ),
    .clk_out1 (pixclk),
    .clk_out2 (clk6Mhz) // clk_out2 outputs a 6Mhz clock, which will be divided to 60Hz using a counter
  );

  // Get the VGA timing signals
  logic [10:0] curr_x;
  logic [9:0]  curr_y;
  logic [3:0]  r, g, b;
  vga_out vga_out_u (
    .i_clk (pixclk), .i_rst    (rst),
    .i_r     (r),      .i_g   (g),      .i_b  (b),  // white background
    .o_pix_r    (o_pix_r),  .o_pix_g  (o_pix_g),  .o_pix_b (o_pix_b), // VGA color output
    .o_hsync   (o_hsync), .o_vsync (o_vsync),                  // horizontal and vertical sync
    .o_curr_x   (curr_x), .o_curr_y (curr_y)                   // what pixel are we on
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
   logic obstacle;
   logic [10:0] blkpos_x;
   logic [9:0]  blkpos_y;
   
   // clk divider 6Mhz -> 60hz
  clk_divider #(
   .INPUT_FREQ_HZ(6_000_000),
   .OUTPUT_FREQ_HZ(60)
   ) clk_div_6Mhz_60hz (
   .clk_in(clk_6Mhz),
   .clk_out(clk_60hz)
   );

   
   always_ff @(posedge clk60hz) begin
     if (rst) begin blkpos_x <= 800; blkpos_y <= 400; end
     else begin 
      if (up) blkpos_y <= blkpos_y - 4;
      else if (down) blkpos_y <= blkpos_y + 4;
      if (left) blkpos_x <= blkpos_x - 4;
      else if (right) blkpos_x <= blkpos_x + 4;
     end
   end
   
   parameter BLK_W = 32, BLK_H = 32;
   drawcon #(.BLK_W(BLK_W), .BLK_H(BLK_H)) drawcon_i (
     .blkpos_x(blkpos_x), .blkpos_y(blkpos_y),
     .draw_x(curr_x),     .draw_y(curr_y),
     .r(r), .g(g), .b(b),
     .obstacle(obstacle)
   );

endmodule
