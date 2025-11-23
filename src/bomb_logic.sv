`timescale 1ns/1ps

/**
* Module: place_bomb
* Description: contains all the logic that lets player place bomb, time for bomb, writing to map_mem, triggering explosion
*
**/

module bomb_logic
#(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW     = 11,
    parameter int NUM_COL     = 19,
    parameter int TILE_PX     = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W  = 32,
    parameter int SPRITE_H  = 64,
    // ---- Bomb Parameters ----
    parameter int BOMB_TIME = 3,


    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

)(
    input logic clk, rst, tick,
    input logic [10:0] player_x,  // map_player_x
    input logic [9:0] player_y,   // map_player_y
    input logic place_bomb,
    output logic [ADDR_WIDTH-1:0] bomb_addr,
    output logic [MAP_MEM_WIDTH-1:0] write_data,
    output logic write_en, trigger_explosion,
    output logic [$clog2(BOMB_TIME)-1:0] countdown
);
  
  logic [1:0] max_bombs;
  logic place_bomb_r;
  logic place_bomb_success;

  logic [5:0] second_cnt;

  always_ff @(posedge clk)
    if (rst) begin
      max_bombs <= 1;
      countdown <= BOMB_TIME;
      place_bomb_r <= 0;
      second_cnt <= 0;
      trigger_explosion <= 0;
    end else begin
    if (tick) begin
      if (place_bomb_success) begin
        max_bombs <= max_bombs - 1;
        place_bomb_r <= place_bomb;
      end
      if (place_bomb_r)
        if (second_cnt == 59)
        begin
          second_cnt <= 0;
          if (countdown == 0) begin countdown <= BOMB_TIME; place_bomb_r <= 0; max_bombs <= max_bombs + 1; end        
          else countdown <= countdown - 1;
        end
        else second_cnt <= second_cnt + 1;
    end
    if (countdown == 0 & second_cnt == 59) trigger_explosion <= 1'b1; else trigger_explosion <= 1'b0;
    end

  assign place_bomb_success = place_bomb & (max_bombs > 0);
  assign write_en = (place_bomb_success | trigger_explosion);
  assign write_data = (trigger_explosion) ? 2'd0 : 2'd3;

  // Determining Bomb placement address
  // ==========================================================================
  // Tile coordinates (64 px per tile -> shift by 6)
  // ==========================================================================
  // player_x/y are the sprite's TOP-LEFT corner
  logic [$clog2(NUM_ROW)-1:0] blockpos_row;
  logic [$clog2(NUM_COL)-1:0] blockpos_col;
  assign blockpos_row = (player_y >> TILE_SHIFT); // truncates to ROW_W
  assign blockpos_col = (player_x >> TILE_SHIFT); // truncates to COL_W

  // ==========================================================================
  // Distance to the next tile boundary for each direction (in pixels)
  // ==========================================================================
  logic [TILE_SHIFT-1:0] tile_offset_x;
  logic [TILE_SHIFT-1:0] tile_offset_y;
  assign tile_offset_x = player_x[TILE_SHIFT-1:0];
  assign tile_offset_y = player_y[TILE_SHIFT-1:0];
  
  always_comb
    begin
      bomb_addr = blockpos_row * NUM_COL + blockpos_col;
      if (tile_offset_y > (TILE_PX >> 2))
        bomb_addr = (blockpos_row + 1) * NUM_COL + blockpos_col;
      else if (tile_offset_x > (TILE_PX >> 2) + (SPRITE_W >> 2))
        bomb_addr = blockpos_row * NUM_COL + (blockpos_col + 1);
    end

endmodule