`timescale 1ns/1ps

module game_top_tb();
  logic clk, rst;
  logic [3:0] map_mem_in;
  logic [10:0] blkpos_x;
  logic [9:0]  blkpos_y;
  logic [10:0] draw_x;
  logic [9:0]  draw_y;
  logic [3:0] i_r, i_g, i_b;
  logic [3:0]  o_r, o_g, o_b;
  logic obstacle_right, obstacle_left, obstacle_down, obstacle_up;
  logic [7:0] blk_addr;
  
  drawcon uut (
    .clk(clk),
    .rst(rst),
    .map_mem_in(map_mem_in),
    .blkpos_x(blkpos_x),
    .blkpos_y(blkpos_y),
    .draw_x(draw_x),
    .draw_y(draw_y),
    .i_r(i_r), .i_g(i_g), .i_b(i_b),
    .o_r(o_r), .o_g(o_g), .o_b(o_b),
    .obstacle_left(obstacle_left),
    .obstacle_right(obstacle_right),
    .obstacle_up(obstacle_up),
    .obstacle_down(obstacle_down)
    .blk_addr(blk_addr)
  );
  
  assign {i_r, i_g, i_b} = 12'hF2F;

  // counters for draw_x and draw_y
  always_ff @(posedge clk)
    if (rst) begin draw_x <= 0; draw_y <= 0; end
    else
      if (draw_x == 1280) 
      begin
        draw_x <= 0;
        if (draw_y == 800) draw_y <= 0; 
        else
        draw_y <= draw_y + 1;
      end

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    #15 rst = 0;
    // ends at end of screen
    #10240000 $finish;
  end

  // Test memory with random states
  logic [3:0] map [0:208];
  initial
    $readmemh("mem.txt", map); 
  
  assign map_mem_in = map[blk_addr];

//   // test counter
//   logic [7:0] test_cnt;
//   always_ff @(posedge clk)
//   if (rst) test_cnt <= 0;
//   else if (draw_x > 32 && draw_y > 96)
//   begin 
    
//   end


  
 
endmodule