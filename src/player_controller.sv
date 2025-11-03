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
    // ---- Player sprite ----
    parameter int SPRITE_W    = 32,
    parameter int SPRITE_H    = 64,
    parameter int STEP_SIZE   = 4,
    // ---- Screen + HUD ----
    parameter int SCREEN_W    = 1280,
    parameter int SCREEN_H    = 800,
    // ---- Initial player position ----
    parameter int INIT_X      = 0,
    parameter int INIT_Y      = 0,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  tick,
    input  logic [3:0]            move_dir,      // [UP,DOWN,LEFT,RIGHT]
    input  logic [1:0]            map_mem_in,
    output logic [10:0]           player_x,      // screen-space
    output logic [9:0]            player_y,      // screen-space
    output logic [ADDR_WIDTH-1:0] map_addr
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
  localparam int MOVE_WIDTH   = 16;
  localparam int MAX_SCREEN_X = MAX_MAP_X + HUD_LEFT_PX;
  localparam int MAX_SCREEN_Y = MAX_MAP_Y + HUD_TOP_PX;

  // ---- HUD layout (derived) ----
  // horizontally centered map; full HUD bar at top
  localparam int HUD_LEFT_PX  = (SCREEN_W - MAP_W_PX) / 2; // 32 px
  localparam int HUD_RIGHT_PX = (SCREEN_W - MAP_W_PX) / 2; // 32 px
  localparam int HUD_TOP_PX   = (SCREEN_H - MAP_H_PX);     // 96 px

  // ---- Convert player position to map-space (remove HUD offsets) ----
  logic [10:0] map_player_x;
  logic [9:0]  map_player_y;

  always_comb begin
    map_player_x = (player_x > HUD_LEFT_PX) ? (player_x - HUD_LEFT_PX) : 11'd0;
    map_player_y = (player_y > HUD_TOP_PX)  ? (player_y - HUD_TOP_PX)  : 10'd0;
  end

  // ---- Obstacle detection in map-space ----
  logic [3:0] obstacles;
  logic [DIST_WIDTH-1:0] obstacle_dist [3:0];
  check_obst #(
    .NUM_ROW (NUM_ROW),
    .NUM_COL (NUM_COL),
    .SPRITE_W(SPRITE_W),
    .SPRITE_H(SPRITE_H)
  ) check_obst_i (
    .clk        (clk),
    .rst        (rst),
    .player_x   (map_player_x),
    .player_y   (map_player_y),
    .map_mem_in (map_mem_in),
    .obstacles  (obstacles),
    .map_addr   (map_addr),
    .obstacle_dist(obstacle_dist)
  );


  // ---- Player movement logic ----
  
  logic [MOVE_WIDTH-1:0] next_x;
  logic [MOVE_WIDTH-1:0] next_y;
  logic [MOVE_WIDTH-1:0] step_amt;
  always_ff @(posedge clk) begin
    if (rst) begin
      player_x <= INIT_X + HUD_LEFT_PX;
      player_y <= INIT_Y + HUD_TOP_PX;
    end else if (tick) begin
      next_x   = player_x;
      next_y   = player_y;
      step_amt = '0;

      case (move_dir)
        4'b1000: if (!obstacles[UP]) begin
                   step_amt[DIST_WIDTH-1:0] = obstacle_dist[UP];
                   if (step_amt > STEP_SIZE) step_amt = STEP_SIZE;
                   next_y -= step_amt;
                 end
        4'b0100: if (!obstacles[DOWN]) begin
                   step_amt[DIST_WIDTH-1:0] = obstacle_dist[DOWN];
                   if (step_amt > STEP_SIZE) step_amt = STEP_SIZE;
                   next_y += step_amt;
                 end
        4'b0010: if (!obstacles[LEFT]) begin
                   step_amt[DIST_WIDTH-1:0] = obstacle_dist[LEFT];
                   if (step_amt > STEP_SIZE) step_amt = STEP_SIZE;
                   next_x -= step_amt;
                 end
        4'b0001: if (!obstacles[RIGHT]) begin
                   step_amt[DIST_WIDTH-1:0] = obstacle_dist[RIGHT];
                   if (step_amt > STEP_SIZE) step_amt = STEP_SIZE;
                   next_x += step_amt;
                 end
        default:; // No movement or conflicting inputs
      endcase

      if (next_x < HUD_LEFT_PX)       next_x = HUD_LEFT_PX;
      else if (next_x > MAX_SCREEN_X) next_x = MAX_SCREEN_X;

      if (next_y < HUD_TOP_PX)        next_y = HUD_TOP_PX;
      else if (next_y > MAX_SCREEN_Y) next_y = MAX_SCREEN_Y;

      player_x <= next_x[10:0];
      player_y <= next_y[9:0];
    end
  end
endmodule
