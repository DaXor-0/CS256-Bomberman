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

  clk_wiz_0 pixclk_i ( // Set pixclk to 83.456MHz
    .clk_in1  (CLK100MHZ),
    .clk_out1 (pixclk)
  );
  

  // Get the VGA timing signals
  logic [10:0] curr_x;
  logic [9:0]  curr_y;
  logic [3:0]  drawcon_i_r, drawcon_i_g, drawcon_i_b;
  logic [3:0]  drawcon_o_r, drawcon_o_g, drawcon_o_b;
  vga_out vga_out_u (
    .i_clk (pixclk), .i_rst    (rst),
    .i_r     (drawcon_o_r),      .i_g   (drawcon_o_g),      .i_b  (drawcon_o_b),
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
//  en
   // Logic for positioning rectangle control.
   logic obstacle_right, obstacle_left, obstacle_down, obstacle_up;
   logic [10:0] blkpos_x;
   logic [9:0]  blkpos_y;
   
  logic clk_strb;
  always_ff @(posedge pixclk)
    clk_strb <= (curr_x == 0) && (curr_y == 0);

   // Single Sprite mem for Bomberman_walking
   logic [11:0] addr_down_1, dout_down_1;
   bomberman_down_1 down_1 (.clka(pixclk), .addra(addr_down_1), .douta(dout_down_1));

   // Should be put in its own module (positioning logic / game logic)
   always_ff @(posedge pixclk) begin
     if (rst) begin blkpos_x <= 800; blkpos_y <= 400; end
     else begin
     if (clk_strb)
     begin
      if (up & ~obstacle_up) blkpos_y <= blkpos_y - 4;
      else if (down & ~obstacle_down) blkpos_y <= blkpos_y + 4;
      if (left & ~obstacle_left) blkpos_x <= blkpos_x - 4;
      else if (right & ~obstacle_right) blkpos_x <= blkpos_x + 4;
     end
     end
   end
   
   assign {drawcon_i_r, drawcon_i_g, drawcon_i_b} = dout_down_1;
     
   
   assign addr_down_1 = ((curr_y-blkpos_y)<<5)+(curr_x-blkpos_x) + 2; // adding 2 for read latency.
   
   parameter BLK_W = 32, BLK_H = 64;
   drawcon #(.BLK_W(BLK_W), .BLK_H(BLK_H)) drawcon_i ( // drawcon is fully combinational (for now) -- conditions that determine what needs to be drawn
     .blkpos_x(blkpos_x), .blkpos_y(blkpos_y),
     .draw_x(curr_x),     .draw_y(curr_y),
     .i_r(drawcon_i_r), .i_g(drawcon_i_g), .i_b(drawcon_i_b),
     .o_r(drawcon_o_r), .o_g(drawcon_o_g), .o_b(drawcon_o_b),
     .obstacle_right(obstacle_right), .obstacle_left(obstacle_left), .obstacle_up(obstacle_up),.obstacle_down(obstacle_down)
   );

endmodule
