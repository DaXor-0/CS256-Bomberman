`timescale 1ns/1ps
/**
* Module: player_controller
* Description:
*   - Translates player screen coordinates (1280x800) into map coordinates
*     for a 19x11 tile map (each tile 64x64).
*   - Accounts for HUD margins (top, left, right).
*   - Updates player position in pixels based on move_dir and obstacle flags.
*
* Assumptions:
*   - player_x, player_y = top-left corner of sprite in screen pixels.
*   - Sprite = 32x64 pixels (W×H).
*   - tick: movement update enable.
*/
module player_controller #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW     = 11,
    parameter int NUM_COL     = 19,
    parameter int TILE_PX     = 64,
    parameter int MAP_MEM_WIDTH = 2,
    // ---- Player sprite ----
    parameter int SPRITE_W    = 32,
    parameter int SPRITE_H    = 64,
    parameter int STEP_SIZE   = 4,
    // ---- Screen + HUD ----
    parameter int SCREEN_W    = 1280,
    parameter int SCREEN_H    = 800,
    // ---- Initial player position ----
    parameter int INIT_X      = 64,
    parameter int INIT_Y      = 64,


    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     tick,
    input  logic [3:0]               move_dir,      // [UP,DOWN,LEFT,RIGHT]
    input  logic [MAP_MEM_WIDTH-1:0] map_mem_in,
    output logic [10:0]              player_x,      // screen-space
    output logic [9:0]               player_y,      // screen-space
    output logic [ADDR_WIDTH-1:0]    map_addr
);
  // Direction indices
  localparam int UP    = 0;
  localparam int DOWN  = 1;
  localparam int LEFT  = 2;
  localparam int RIGHT = 3;

  // ---- Derived geometry ----
  localparam int MAP_W_PX     = NUM_COL * TILE_PX;   // 19 * 64 = 1216
  localparam int MAP_H_PX     = NUM_ROW * TILE_PX;   // 11 * 64 = 704
  localparam int MAX_MAP_X    = MAP_W_PX - SPRITE_W;
  localparam int MAX_MAP_Y    = MAP_H_PX - SPRITE_H;
  localparam int TILE_SHIFT   = $clog2(TILE_PX);
  localparam int DIST_WIDTH   = TILE_SHIFT + 1;
  localparam int MAX_STEP     = (1 << TILE_SHIFT);

  // ---- HUD layout (derived) ----
  // horizontally centered map; full HUD bar at top
  localparam int HUD_SIDE_PX  = (SCREEN_W - MAP_W_PX) / 2; // 32 px
  localparam int HUD_TOP_PX   = (SCREEN_H - MAP_H_PX);     // 96 px

  // ---- Convert player position to map-space (remove HUD offsets) ----
  logic [10:0] map_player_x;
  logic [9:0]  map_player_y;
  always_comb begin
    map_player_x = (player_x > HUD_SIDE_PX) ? (player_x - HUD_SIDE_PX) : 11'd64; // (64,64) is pos of first free block, (0,0) is perm_block
    map_player_y = (player_y > HUD_TOP_PX)  ? (player_y - HUD_TOP_PX)  : 10'd64;
  end

  // ---- Obstacle detection in map-space ----
  logic [3:0] obstacles;
  logic [DIST_WIDTH-1:0] obstacle_dist [3:0];
  logic obstacles_valid;

  check_obst #(
    .NUM_ROW (NUM_ROW),
    .NUM_COL (NUM_COL),
    .TILE_PX (TILE_PX),
    .SPRITE_W(SPRITE_W),
    .SPRITE_H(SPRITE_H)
  ) check_obst_i (
    .clk            (clk),
    .rst            (rst),
    .player_x       (map_player_x),
    .player_y       (map_player_y),
    .map_mem_in     (map_mem_in),
    .obstacles      (obstacles),
    .map_addr       (map_addr),
    .obstacle_dist  (obstacle_dist),
    .obstacles_valid(obstacles_valid)
  );

  // ---- Register obstacles for stable use ----
  logic [3:0] obstacles_r;
  logic [DIST_WIDTH-1:0] obstacle_dist_r [3:0];
  always_ff @(posedge clk) begin
    if (rst) begin
      obstacles_r <= '0;
      obstacle_dist_r[UP]    <= '1;
      obstacle_dist_r[DOWN]  <= '1;
      obstacle_dist_r[LEFT]  <= '1;
      obstacle_dist_r[RIGHT] <= '1;
    end else if (obstacles_valid) begin
      obstacles_r     <= obstacles;
      obstacle_dist_r[UP]    <= obstacle_dist[UP];
      obstacle_dist_r[DOWN]  <= obstacle_dist[DOWN];
      obstacle_dist_r[LEFT]  <= obstacle_dist[LEFT];
      obstacle_dist_r[RIGHT] <= obstacle_dist[RIGHT];
    end
  end

  // ---- Max movement per direction ---
  logic [DIST_WIDTH-1:0] step [3:0];
  logic [DIST_WIDTH-1:0] step_req;
  assign step_req = (STEP_SIZE > MAX_STEP) ? DIST_WIDTH'(MAX_STEP) : DIST_WIDTH'(STEP_SIZE);

  assign step[UP]    = obstacles_r[UP]    ? '0 : ((obstacle_dist_r[UP]    < step_req) ? obstacle_dist_r[UP]    : step_req);
  assign step[DOWN]  = obstacles_r[DOWN]  ? '0 : ((obstacle_dist_r[DOWN]  < step_req) ? obstacle_dist_r[DOWN]  : step_req);
  assign step[LEFT]  = obstacles_r[LEFT]  ? '0 : ((obstacle_dist_r[LEFT]  < step_req) ? obstacle_dist_r[LEFT]  : step_req);
  assign step[RIGHT] = obstacles_r[RIGHT] ? '0 : ((obstacle_dist_r[RIGHT] < step_req) ? obstacle_dist_r[RIGHT] : step_req);

  // ---- Player position update (only when obstacles are valid) ----
  always_ff @(posedge clk) begin
    if (rst) begin
      player_x <= 11'(INIT_X + HUD_SIDE_PX);
      player_y <= 10'(INIT_Y + HUD_TOP_PX);
    end else if (tick) begin
      case (move_dir)
        4'b1000: player_y <= (player_y >= step[UP])   ? (player_y - step[UP])   : player_y; // UP with saturation
        4'b0100: player_y <= (player_y <= MAX_MAP_Y)  ? (player_y + step[DOWN]) : player_y; // DOWN with saturation
        4'b0010: player_x <= (player_x >= step[LEFT]) ? (player_x - step[LEFT]) : player_x; // LEFT with saturation
        4'b0001: player_x <= (player_x <= MAX_MAP_X)  ? (player_x + step[RIGHT]): player_x; // RIGHT with saturation
      endcase
    end
  end
endmodule
