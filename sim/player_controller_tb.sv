`timescale 1ns/1ps

module player_controller_tb;
  localparam int CLK_PERIOD = 10;
  localparam int NUM_ROW = 6;
  localparam int NUM_COL = 6;
  localparam int STEP_SIZE = 32;
  localparam int INIT_TILE_ROW = 2;
  localparam int INIT_TILE_COL = 2;
  localparam int INIT_X = INIT_TILE_COL * 32;
  localparam int INIT_Y = INIT_TILE_ROW * 32;
  localparam logic [1:0] TILE_FREE = 2'b00;
  localparam logic [1:0] TILE_WALL = 2'b01;

  localparam logic [3:0] DIR_UP    = 4'b1000;
  localparam logic [3:0] DIR_DOWN  = 4'b0100;
  localparam logic [3:0] DIR_LEFT  = 4'b0010;
  localparam logic [3:0] DIR_RIGHT = 4'b0001;

  logic clk = 0;
  logic rst = 1;
  logic tick = 0;
  logic [3:0] move_dir = 4'b0;
  logic [1:0] map_mem_in;

  logic [10:0] player_x;
  logic [9:0]  player_y;
  logic [$clog2(NUM_ROW * NUM_COL)-1:0] map_addr;

  logic [1:0] map_mem [0:NUM_ROW * NUM_COL - 1];

  // DUT ----------------------------------------------------------------------
  player_controller #(
      .INIT_X(INIT_X),
      .INIT_Y(INIT_Y),
      .STEP_SIZE(STEP_SIZE),
      .NUM_ROW(NUM_ROW),
      .NUM_COL(NUM_COL)
  ) dut (
      .clk(clk),
      .rst(rst),
      .tick(tick),
      .move_dir(move_dir),
      .map_mem_in(map_mem_in),
      .player_x(player_x),
      .player_y(player_y),
      .map_addr(map_addr)
  );

  // Clock generation
  always #(CLK_PERIOD / 2) clk = ~clk;

  // Combinational map read
  always_comb begin
    map_mem_in = map_mem[map_addr];
  end

  // Helpers ------------------------------------------------------------------
  function automatic int idx(input int row, input int col);
    idx = row * NUM_COL + col;
  endfunction

  task automatic drive_move(
      input logic [3:0] dir,
      input string label,
      input int exp_x,
      input int exp_y
  );
    move_dir = dir;
    repeat (4) @(posedge clk); // allow obstacle sampler to sweep directions

    tick = 1'b1;
    @(posedge clk);
    #1; // allow DUT to observe the tick pulse before it is deasserted
    tick = 1'b0;
    move_dir = 4'b0;

    @(posedge clk);
    if (player_x !== exp_x || player_y !== exp_y) begin
      $error("[%0t] %s FAILED -> got (%0d,%0d) expected (%0d,%0d)",
             $time, label, player_x, player_y, exp_x, exp_y);
    end else begin
      $display("[%0t] %s -> pos=(%0d,%0d)",
               $time, label, player_x, player_y);
    end
  endtask

  // Stimulus -----------------------------------------------------------------
  initial begin
    int curr_x;
    int curr_y;

    $dumpfile("player_controller_tb.vcd");
    $dumpvars(0, player_controller_tb);

    foreach (map_mem[i]) map_mem[i] = TILE_FREE;

    for (int col = 0; col < NUM_COL; col++) begin
      map_mem[idx(0, col)] = TILE_WALL;
      map_mem[idx(NUM_ROW - 1, col)] = TILE_WALL;
    end

    for (int row = 0; row < NUM_ROW; row++) begin
      map_mem[idx(row, 0)] = TILE_WALL;
      map_mem[idx(row, NUM_COL - 1)] = TILE_WALL;
    end

    // Hard obstacle above the starting tile.
    map_mem[idx(INIT_TILE_ROW - 1, INIT_TILE_COL)] = TILE_WALL;

    repeat (3) @(posedge clk);
    rst = 0;

    // allow obstacle sampler to flush initial pipeline
    repeat (6) @(posedge clk);

    curr_x = INIT_X;
    curr_y = INIT_Y;

    drive_move(DIR_UP, "blocked moving up into wall", curr_x, curr_y);

    drive_move(DIR_LEFT, "move left into open space", curr_x - STEP_SIZE, curr_y);
    curr_x -= STEP_SIZE;

    drive_move(DIR_LEFT, "blocked by left boundary", curr_x, curr_y);

    drive_move(DIR_DOWN, "move down into open space", curr_x, curr_y + STEP_SIZE);
    curr_y += STEP_SIZE;

    repeat (6) @(posedge clk);
    $finish;
  end

endmodule
