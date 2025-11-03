`timescale 1ns/1ps

module check_obst_tb;
  localparam int CLK_PERIOD = 10;
  localparam int NUM_ROW = 3;
  localparam int NUM_COL = 3;
  localparam int TILE_PX = 64;
  localparam int TILE_SHIFT = $clog2(TILE_PX);
  localparam logic [1:0] TILE_FREE = 2'b00;
  localparam logic [1:0] TILE_WALL = 2'b01;

  localparam int UP = 0;
  localparam int DOWN = 1;
  localparam int LEFT = 2;
  localparam int RIGHT = 3;

  logic clk = 0;
  logic rst = 1;
  logic [10:0] player_x = 0;
  logic [9:0]  player_y = 0;
  logic [1:0]  map_mem_in;
  logic [3:0]  obstacles;
  logic [TILE_SHIFT:0] obstacle_dist [3:0];
  logic [$clog2(NUM_ROW * NUM_COL)-1:0] map_addr;

  logic [1:0] map_mem [0:NUM_ROW * NUM_COL - 1];

  // DUT ----------------------------------------------------------------------
  check_obst #(
      .NUM_ROW (NUM_ROW),
      .NUM_COL (NUM_COL),
      .SPRITE_W(32),
      .SPRITE_H(64)
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

  always_comb begin
    map_mem_in = map_mem[map_addr];
  end

  function automatic int idx(input int row, input int col);
    idx = row * NUM_COL + col;
  endfunction

  task automatic expect_obstacles(
      input int px,
      input int py,
      input logic [3:0] expected,
      input string label
  );
    player_x = px;
    player_y = py;

    repeat (8) @(posedge clk); // sweep all directions twice

    if (obstacles !== expected) begin
      $error("[%0t] %s FAILED -> got %b expected %b",
             $time, label, obstacles, expected);
    end else begin
      $display("[%0t] %s -> obstacles %b",
               $time, label, obstacles);
    end
  endtask

  initial begin
    $dumpfile("check_obst_tb.vcd");
    $dumpvars(0, check_obst_tb);

    foreach (map_mem[i]) map_mem[i] = TILE_FREE;
    map_mem[idx(0, 1)] = TILE_WALL; // above the centre tile
    map_mem[idx(1, 2)] = TILE_WALL; // to the right of the centre tile

    repeat (2) @(posedge clk);
    rst = 0;

    repeat (6) @(posedge clk);

    expect_obstacles(
        32, 32,
        4'b0001, // up blocked, others clear
        "centre tile"
    );

    expect_obstacles(
        63, 32,
        4'b1001, // right blocked (at tile boundary), up still blocked
        "approaching right neighbour"
    );

    expect_obstacles(
        0, 32,
        4'b0100, // left boundary blocks, others free
        "left edge boundary"
    );

    expect_obstacles(
        32, 0,
        4'b0001, // top boundary blocks upward movement
        "top edge boundary"
    );

    repeat (6) @(posedge clk);
    $finish;
  end

endmodule
