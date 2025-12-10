`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: explode_logic 
* Description: contains the logic that operates the explosion of the bombs.
*
**/

module explode_logic #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = 11,
    parameter int NUM_COL       = 19,
    parameter int TILE_PX       = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W      = 32,
    parameter int SPRITE_H      = 48,
    // ---- Bomb Parameters ----
    parameter int EXPLODE_TIME  = 1,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

) (
    input logic clk,
    input logic rst,
    input logic tick,
    input logic game_over,
    input logic trigger_explosion,
    input logic [ADDR_WIDTH-1:0] explosion_addr,

    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_x,  // map_player_x
    input logic [ 9:0] player_y,  // map_player_y

    output logic [ADDR_WIDTH-1:0] saved_explosion_addr,
    output logic explode_signal,  // To be used by drawcon to draw the explosion
    output logic game_over_fake,
    output logic free_blks_signal
);
  // Internal state
  logic [5:0] second_cnt;  // for EXPLODE state

  // ---------------------------------------------------------------------------
  // -- FSM for the explosion logic, explosion_state --
  // ---------------------------------------------------------------------------
  bomb_explosion_state_t st, nst;

  // next state ff block
  always_ff @(posedge clk)
    if (rst || game_over) st <= EXP_STATE_IDLE;
    else st <= nst;

  // Next state logic
  always_comb begin
    nst = st;  // State remains unchanged if no condition triggered.
    case (st)
      EXP_STATE_IDLE: if (trigger_explosion) nst = EXP_STATE_ACTIVE;
      EXP_STATE_ACTIVE: if (second_cnt == 6'd59) nst = EXP_STATE_FREE_BLOCKS;
      EXP_STATE_FREE_BLOCKS: nst = EXP_STATE_IDLE;
      default: nst = EXP_STATE_IDLE;
    endcase
  end

  // ---------------------------------------------------------------------------
  // -- Sequential elements (counters, registers) control per state
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst || game_over) begin
      saved_explosion_addr <= 0;
      second_cnt <= 0;
    end else begin
      case (st)
        EXP_STATE_IDLE: begin
          second_cnt <= 0;
          if (trigger_explosion) saved_explosion_addr <= explosion_addr;
        end
        EXP_STATE_ACTIVE: begin
          if (tick) second_cnt <= second_cnt + 1;
        end
      endcase
    end
  end

  assign explode_signal   = (st == EXP_STATE_ACTIVE);
  assign free_blks_signal = (st == EXP_STATE_FREE_BLOCKS);

  // ---------------------------------------------------------------------------
  // Game Over condition: a player comes in contact with an explosion
  // ---------------------------------------------------------------------------
  logic [TILE_SHIFT:0] tile_offset_x;
  logic [TILE_SHIFT:0] tile_offset_y;
  logic [TILE_SHIFT:0] right_edge_offset;
  logic [TILE_SHIFT:0] bottom_edge_offset;
  assign tile_offset_x = {1'b0, player_x[TILE_SHIFT-1:0]};
  assign tile_offset_y = {1'b0, player_y[TILE_SHIFT-1:0]};
  assign right_edge_offset = tile_offset_x + (TILE_SHIFT + 1)'(SPRITE_W);
  assign bottom_edge_offset = tile_offset_y + (TILE_SHIFT + 1)'(SPRITE_H);

  // Player_x and Player_y in block (col, row)
  logic [$clog2(NUM_ROW)-1:0] blockpos_row, blockpos_row_2;
  logic [$clog2(NUM_COL)-1:0] blockpos_col, blockpos_col_2;
  assign blockpos_row = (player_y >> TILE_SHIFT);  // truncates to ROW_W
  assign blockpos_col = (player_x >> TILE_SHIFT);  // truncates to COL_W
  assign blockpos_row_2 = (bottom_edge_offset > TILE_PX) ? blockpos_row + 1 : 0;  // Player between two blocks
  assign blockpos_col_2 = (right_edge_offset > TILE_PX) ? blockpos_col + 1 : 0;         // Player between two blocks

  // player blocks addresses
  logic [ADDR_WIDTH-1:0] blk1_addr, blk2_addr;
  assign blk1_addr = blockpos_row * NUM_COL + blockpos_col;
  assign blk2_addr = blockpos_row_2 * NUM_COL + blockpos_col_2;

  // Function to check if the player's block is exploding
  function logic is_exploding(input logic [ADDR_WIDTH-1:0] blk_addr,
                              input logic [ADDR_WIDTH-1:0] exp);
    return ((blk_addr == exp) ||
            (blk_addr == exp - NUM_COL)   ||
            (blk_addr == exp + NUM_COL) ||
            (blk_addr == exp - 1) ||
            (blk_addr == exp + 1));
  endfunction

  // Game Over condition
  assign game_over_fake = (is_exploding(
      blk1_addr, saved_explosion_addr
  ) || is_exploding(
      blk2_addr, saved_explosion_addr
  ));

endmodule
