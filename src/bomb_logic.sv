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
    // input logic add_bomb :: to be integrated with implementation of power-up
    input logic place_bomb,
    output logic [ADDR_WIDTH-1:0] write_addr,
    output logic [MAP_MEM_WIDTH-1:0] write_data,
    output logic write_en, trigger_explosion,
    output logic [$clog2(BOMB_TIME)-1:0] countdown
);
  
  // NOTE: This implementation can do 1 bomb only. For more bombs, each bomb should have its state-machine, and there should be an indexing between currently placed bombs.
  // -- internal state --
  logic [1:0] max_bombs;
  logic place_bomb_r, place_bomb_prev;
  logic [5:0] second_cnt;
  logic [ADDR_WIDTH-1:0] saved_addr, computed_addr;

  // pulses
  logic place_pulse;

  // -----------------------------------------------------------------
  // -- edge detection for bomb placement + success condition --
  // -----------------------------------------------------------------
  always_ff @(posedge clk)
  if (rst)
    begin
    place_bomb_r <= 0;
    place_bomb_prev <= 0;
    end
  else
    begin
    place_bomb_r <= place_bomb;
    place_bomb_prev <= place_bomb_r;
    end
  // place_pulse -- makes sure that the bomb placement is only triggered once.
  assign place_pulse = (~place_bomb_prev & place_bomb_r) & (max_bombs > 0);


  // -----------------------------------------------------------------
  // -- FSM for the bomb logic, bomb_state --
  // -----------------------------------------------------------------
  typedef enum logic [1:0] { IDLE, PLACE, CNTDWN, EXPLODE } bomb_state;

  bomb_state st, nst;

  // next state ff block
  always_ff @(posedge clk)
    if (rst) st <= IDLE;
    else st <= nst;

  // Next state logic
  always_comb
  begin
    nst = st; // State remains unchanged if no condition triggered.
    case (st)
      IDLE: if (place_pulse) nst = PLACE;
      PLACE: nst = CNTDWN;
      CNTDWN: if ((countdown == 1) && (second_cnt == 6'd59)) nst = EXPLODE;
      EXPLODE: nst = IDLE;
      default: nst = IDLE;
    endcase
  end
  
  // -----------------------------------------------------------------
  // -- Sequential elements (counters, registers) control per state
  // -----------------------------------------------------------------
  always_ff @(posedge clk)
    if (rst) begin
      max_bombs <= 1;
      countdown <= BOMB_TIME;
      second_cnt <= 0;
      saved_addr <= 0;
    end else 
    begin
      case (st)
        IDLE:
        begin
          max_bombs <= 1;
          countdown <= BOMB_TIME;
          second_cnt <= 0;
        end
        PLACE:
        begin
          saved_addr <= computed_addr; // save the bomb address to be freed later.
          max_bombs <= 0;
          countdown <= BOMB_TIME;
          second_cnt <= 0;
        end
        CNTDWN: // Countdown state, such that
        begin
          if (tick)
          begin
            if (second_cnt == 59) begin 
              second_cnt <= 0; 
              countdown <= countdown - 1; // no need for if (countdown == 0), as it is handled in the next_state logic
            end 
            else second_cnt <= second_cnt + 1;
          end
        end
        default: // {IDLE, PLACE, EXPLODE} states, do nothing
        begin
          max_bombs <= 1;
          countdown <= BOMB_TIME;
          second_cnt <= 0;
        end
      endcase
    end

  assign trigger_explosion = (st == EXPLODE);
  assign write_en = ((st == PLACE) | (st == EXPLODE));
  assign write_data = (trigger_explosion) ? 2'd0 : 2'd3;
  assign write_addr = (trigger_explosion) ? saved_addr : computed_addr; // free the same block that was placed to.

  // ------------------------------
  // Determining Bomb placement address
  // Addressing: compute tile from sprite CENTER (safer than top-left heuristics)
  // center_x = player_x + SPRITE_W/2  (integer arithmetic)
  // ------------------------------
  // player_x/y are the sprite's TOP-LEFT corner
  // center coordinates (combinational)
  logic [10:0] center_x;
  logic [9:0] center_y;
  assign center_x = player_x + (SPRITE_W >> 1);
  assign center_y = player_y + (SPRITE_H >> 1); 
 
  logic [$clog2(NUM_ROW)-1:0] blockpos_row;
  logic [$clog2(NUM_COL)-1:0] blockpos_col;
  assign blockpos_row = (center_y >> TILE_SHIFT); // truncates to ROW_W
  assign blockpos_col = (center_x >> TILE_SHIFT); // truncates to COL_W

  // ==========================================================================
  // Distance to the next tile boundary for each direction (in pixels)
  // ==========================================================================
  logic [TILE_SHIFT-1:0] tile_offset_x;
  logic [TILE_SHIFT-1:0] tile_offset_y;
  assign tile_offset_x = player_x[TILE_SHIFT-1:0];
  assign tile_offset_y = player_y[TILE_SHIFT-1:0];
  assign computed_addr = blockpos_row * NUM_COL + blockpos_col;
  

endmodule