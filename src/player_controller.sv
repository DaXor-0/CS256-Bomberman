`timescale 1ns / 1ps

`include "bomberman_dir.svh"

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
*   - Sprite = 32x48 pixels (W×H).
*   - tick: movement update enable.
*/
module player_controller #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = 11,
    parameter int NUM_COL       = 19,
    parameter int TILE_PX       = 64,
    parameter int MAP_MEM_WIDTH = 2,
    // ---- Player sprite ----
    parameter int SPRITE_W      = 32,
    parameter int SPRITE_H      = 48,
    // ---- Screen + HUD ----
    parameter int SCREEN_W      = 1280,
    parameter int SCREEN_H      = 800,
    // ---- Initial player position ----
    parameter int INIT_X        = 64,
    parameter int INIT_Y        = 64,


    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     tick,
    input  dir_t                     move_dir,
    input logic [5:0]                 player_speed,
    input  logic [MAP_MEM_WIDTH-1:0] map_mem_in,
    input logic read_granted,

    output logic read_req,
    output logic [             10:0] player_x,      // screen-space
    output logic [              9:0] player_y,      // screen-space
    output logic [             10:0] map_player_x,
    output logic [              9:0] map_player_y,
    output logic [   ADDR_WIDTH-1:0] map_addr
);
  // ---- Derived geometry ----
  localparam int MAP_W_PX = NUM_COL * TILE_PX;  // 19 * 64 = 1216
  localparam int MAP_H_PX = NUM_ROW * TILE_PX;  // 11 * 64 = 704
  localparam int MAX_MAP_X = MAP_W_PX - SPRITE_W;
  localparam int MAX_MAP_Y = MAP_H_PX - SPRITE_H;
  localparam int TILE_SHIFT = $clog2(TILE_PX);
  localparam int DIST_WIDTH = TILE_SHIFT + 1;
  localparam int MAX_STEP = (1 << TILE_SHIFT);

  // ---- HUD layout (derived) ----
  // horizontally centered map; full HUD bar at top
  localparam int HUD_SIDE_PX = (SCREEN_W - MAP_W_PX) / 2;  // 32 px
  localparam int HUD_TOP_PX = (SCREEN_H - MAP_H_PX);  // 96 px

  // ---- Convert player position to map-space (remove HUD offsets) ----
  always_comb begin
    map_player_x = (player_x > HUD_SIDE_PX) ? (player_x - HUD_SIDE_PX) : 11'd64; // (64,64) is pos of first free block, (0,0) is perm_block
    map_player_y = (player_y > HUD_TOP_PX) ? (player_y - HUD_TOP_PX) : 10'd64;
  end

  // ---- Obstacle detection in map-space ----
  logic [3:0] obstacles;
  logic [DIST_WIDTH-1:0] obstacle_dist[3:0];
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
      .obstacles_valid(obstacles_valid),
      .read_granted   (read_granted),
      .read_req       (read_req)
  );

  // ---- Register obstacles for stable use ----
  logic [3:0] obstacles_r;
  logic [DIST_WIDTH-1:0] obstacle_dist_r[3:0];
  always_ff @(posedge clk) begin
    if (rst) begin
      obstacles_r <= '0;
      obstacle_dist_r[UP]    <= '1;
      obstacle_dist_r[DOWN]  <= '1;
      obstacle_dist_r[LEFT]  <= '1;
      obstacle_dist_r[RIGHT] <= '1;
    end else if (obstacles_valid) begin
      obstacles_r            <= obstacles;
      obstacle_dist_r[UP]    <= obstacle_dist[UP];
      obstacle_dist_r[DOWN]  <= obstacle_dist[DOWN];
      obstacle_dist_r[LEFT]  <= obstacle_dist[LEFT];
      obstacle_dist_r[RIGHT] <= obstacle_dist[RIGHT];
    end
  end

  // ---- Max movement per direction ---
  logic [DIST_WIDTH-1:0] step[3:0];
  logic [DIST_WIDTH-1:0] step_req;
  assign step_req = (player_speed > MAX_STEP) ? DIST_WIDTH'(MAX_STEP) : DIST_WIDTH'(player_speed);

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
        DIR_UP:    player_y <= (player_y - step[UP]);    // UP with saturation
        DIR_DOWN:  player_y <= (player_y + step[DOWN]);  // DOWN with saturation
        DIR_LEFT:  player_x <= (player_x - step[LEFT]);  // LEFT with saturation
        DIR_RIGHT: player_x <= (player_x + step[RIGHT]); // RIGHT with saturation
      endcase
    end
  end
endmodule
