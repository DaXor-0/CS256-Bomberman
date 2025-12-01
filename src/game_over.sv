`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: game_over 
* Description: contains the logic that operates the explosion of the bombs.
*
**/

module game_over #(
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
    rst,
    input logic [2:0] explode_signal_1, explode_signal_2,
    input logic [ADDR_WIDTH-1:0] explosion_addr_1 [0:2], explosion_addr_2 [0:2],
    input logic [1:0] exp_range_1, exp_range_2,

    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_1_x,  // map_player_x
    input logic [ 9:0] player_1_y,  // map_player_y
    input logic [10:0] player_2_x,  // map_player_x
    input logic [ 9:0] player_2_y,  // map_player_y

    input logic start_over_button,

    output logic game_over
);

    logic game_over_condition, start_over;
    // FSM for game over state (GAME_ACTIVE, GAME_OVER)
    game_over_state_t st, nst;
    // next state ff block
    always_ff @(posedge clk)
      if (rst) st <= GAME_ACTIVE;
      else st <= nst;

    // Next state logic
    always_comb begin
      nst = st;  // State remains unchanged if no condition triggered.
      case (st)
        GAME_ACTIVE: if (game_over_condition) nst = GAME_OVER;
        GAME_OVER: if (start_over) nst = GAME_ACTIVE;
        default: nst = GAME_ACTIVE;
      endcase 
    end
    // Output logic
    assign start_over = (st == GAME_OVER) && start_over_button;
    assign game_over = (st == GAME_OVER);

    // --- Compute player blocks ---
    logic [ADDR_WIDTH-1:0] player_1_blk1_addr, player_1_blk2_addr;
    logic [ADDR_WIDTH-1:0] player_2_blk1_addr, player_2_blk2_addr;
    compute_player_blocks #(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .TILE_PX(TILE_PX),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_SHIFT(TILE_SHIFT)
    ) compute_player_blocks_1 (
        .player_x(player_1_x),
        .player_y(player_1_y),
        .blk1_addr(player_1_blk1_addr),
        .blk2_addr(player_1_blk2_addr)
    );

    compute_player_blocks #(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .TILE_PX(TILE_PX),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TILE_SHIFT(TILE_SHIFT)
    ) compute_player_blocks_2 (
        .player_x(player_2_x),
        .player_y(player_2_y),
        .blk1_addr(player_2_blk1_addr),
        .blk2_addr(player_2_blk2_addr)
    );

    // Function to check if the player's block is exploding
    function automatic logic is_exploding(input logic [ADDR_WIDTH-1:0] blk_addr,
                                input logic [ADDR_WIDTH-1:0] exp [0:2],
                                input logic [2:0] exp_signal
                                // input logic [1:0] exp_range TBD: After exp_range power_up implementation
                                );
        for (int i = 0; i < 3; i++) begin
            if (exp_signal[i]) begin
                if ((blk_addr == exp[i]) ||
                    (blk_addr == exp[i] - NUM_COL)   ||
                    (blk_addr == exp[i] + NUM_COL) ||
                    (blk_addr == exp[i] - 1) ||
                    (blk_addr == exp[i] + 1)) begin
                    return 1'b1;
                end
            end
        end
        return 1'b0;
    endfunction

    // Game Over condition
    assign game_over_condition = 
        is_exploding(
            player_1_blk1_addr, explosion_addr_1, explode_signal_1
        ) || is_exploding(
            player_1_blk2_addr, explosion_addr_1, explode_signal_1
        ) || is_exploding(
            player_1_blk1_addr, explosion_addr_2, explode_signal_2
        ) || is_exploding(
            player_1_blk2_addr, explosion_addr_2, explode_signal_2
        ) || is_exploding(
            player_2_blk1_addr, explosion_addr_2, explode_signal_2
        ) || is_exploding(
            player_2_blk2_addr, explosion_addr_2, explode_signal_2
        ) || is_exploding(
            player_2_blk1_addr, explosion_addr_1, explode_signal_1
        ) || is_exploding(
            player_2_blk2_addr, explosion_addr_1, explode_signal_1
        );

endmodule 