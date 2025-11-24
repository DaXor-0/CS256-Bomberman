`timescale 1ns/1ps

/**
* Module: place_bomb
* Description: contains all the logic that lets player place bomb, time for bomb, writing to map_mem, triggering explosion
*
**/

module explode_logic
#(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW     = 11,
    parameter int NUM_COL     = 19,
    parameter int TILE_PX     = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W  = 32,
    parameter int SPRITE_H  = 64,
    // ---- Bomb Parameters ----
    parameter int EXPLODE_TIME = 1,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

)(
    input logic clk, rst, tick,
    input logic trigger_explosion,
    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_x,  // map_player_x
    input logic [9:0] player_y,   // map_player_y
    input logic [ADDR_WIDTH-1:0] explosion_addr,

    output logic [ADDR_WIDTH-1:0] check_addr,
    input logic [MAP_MEM_WIDTH-1:0] map_mem_in,

    output logic [MAP_MEM_WIDTH-1:0] write_data,
    output logic [3:0] surroundings_status, // [UP, DOWN, LEFT, RIGHT]. if 1 --> explosion, else if 0 --> empty
    output logic explosion_active,          // To be used by drawcon to draw the explosion
    output logic game_over,
    output logic write_en
);

  // Direction indices
  localparam int UP    = 0;
  localparam int DOWN  = 1;
  localparam int LEFT  = 2;
  localparam int RIGHT = 3;

  // Internal state
  logic [ADDR_WIDTH-1:0] saved_explosion_addr;
  logic [1:0] dir_cnt; // for UP, DOWN, LEFT, RIGHT
  logic [5:0] second_cnt; // for EXPLODE state

  // -----------------------------------------------------------------
  // -- FSM for the explosion logic, explosion_state --
  // -----------------------------------------------------------------
  typedef enum logic [1:0] { IDLE, CHECK, EXPLODE, FREE_BLKS } bomb_state;

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
      IDLE: if (trigger_explosion) nst = CHECK;
      CHECK: if (check_done) nst = EXPLODE;
      EXPLODE: if (second_cnt <= 6'd59) nst = FREE_BLKS;
      FREE_BLKS: if (write_done) nst = IDLE;
      default: nst = IDLE;
    endcase
  end

  // -----------------------------------------------------------------
  // -- Sequential elements (counters, registers) control per state
  // -----------------------------------------------------------------
  always_ff @( posedge clk ) 
    if (rst)
    begin
      surroundings_status <= 0;
      saved_explosion_addr <= 0;
    end



endmodule