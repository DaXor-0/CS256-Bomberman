`timescale 1ns/1ps

module check_obst_tb;
  localparam int CLK_PERIOD = 10;
  localparam int NUM_ROW    = 11;
  localparam int NUM_COL    = 19;
  localparam int TILE_PX    = 64;
  localparam int SPRITE_W   = 32;
  localparam int SPRITE_H   = 64;
  localparam string MAP_FILE = "maps/basic_map.mem";

  localparam int TILE_SHIFT = $clog2(TILE_PX);
  localparam int DEPTH      = NUM_ROW * NUM_COL;
  localparam int ADDR_WIDTH = $clog2(DEPTH);

  localparam int UP    = 0;
  localparam int DOWN  = 1;
  localparam int LEFT  = 2;
  localparam int RIGHT = 3;

  logic clk = 0;
  logic rst = 1;
  logic [10:0] player_x = '0;
  logic [9:0]  player_y = '0;
  logic [1:0]  map_mem_in = '0;
  logic [3:0]  obstacles;
  logic [ADDR_WIDTH-1:0] map_addr;
  logic [TILE_SHIFT:0] obstacle_dist [3:0];
  logic [TILE_SHIFT:0] dist_up, dist_down, dist_left, dist_right;
  logic [1:0] map_mem [0:DEPTH-1];
  logic [ADDR_WIDTH-1:0] map_addr_d;

  check_obst #(
      .NUM_ROW (NUM_ROW),
      .NUM_COL (NUM_COL),
      .TILE_PX (TILE_PX),
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H)
  ) dut (
      .clk(clk),
      .rst(rst),
      .player_x(player_x),
      .player_y(player_y),
      .map_mem_in(map_mem_in),
      .obstacles(obstacles),
      .map_addr(map_addr),
      .obstacle_dist(obstacle_dist)
  );

  always #(CLK_PERIOD / 2) clk = ~clk;

  always_ff @(posedge clk) begin
    if (rst) begin
      map_mem_in <= '0;
    end else begin
      map_mem_in <= map_mem[map_addr];
    end
  end

  task automatic place_sprite(
      input int tile_row,
      input int tile_col,
      input int x_offset = 0,
      input int y_offset = 0,
      input string label = ""
  );
    int px;
    int py;
    px = tile_col * TILE_PX + x_offset;
    py = tile_row * TILE_PX + y_offset;

    player_x = px;
    player_y = py;

    repeat (8) @(posedge clk);

    $display("[%0t] %s -> col,row (%0d,%0d) pos (%0d,%0d) obstacles=%b dist={U:%0d D:%0d L:%0d R:%0d}",
             $time, label, tile_col, tile_row, player_x, player_y, obstacles,
             obstacle_dist[UP], obstacle_dist[DOWN], obstacle_dist[LEFT], obstacle_dist[RIGHT]);
  endtask

  initial begin
    $dumpfile("check_obst_tb.vcd");
    $dumpvars(0, check_obst_tb);

    $readmemh(MAP_FILE, map_mem);

    repeat (4) @(posedge clk);
    rst = 0;

    repeat (8) @(posedge clk);

    place_sprite(1, 1, 0, 0,  "inner corner near border");
    place_sprite(1, 1, 32, 0, "sliding right along open corridor");
    place_sprite(2, 1, 32, 0, "corridor facing pillar on the right");
    place_sprite(5, 9, 0, 0,  "centre corridor with open neighbours");
    place_sprite(5, 9, 20, 24,"within tile to observe distances");
    place_sprite(9, 17, 32, 0,"adjacent to outer wall on the right");

    repeat (8) @(posedge clk);
    $finish;
  end

endmodule
