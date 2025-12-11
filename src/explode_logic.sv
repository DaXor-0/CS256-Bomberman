`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: explode_logic 
* Description: contains the logic that operates the explosion of the bombs.
*
**/

module explode_logic #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = MAP_NUM_ROW_DEF,
    parameter int NUM_COL       = MAP_NUM_COL_DEF,
    parameter int TILE_PX       = MAP_TILE_PX_DEF,
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

    output logic [ADDR_WIDTH-1:0] saved_explosion_addr,
    output logic explode_signal,  // To be used by drawcon to draw the explosion
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

endmodule
