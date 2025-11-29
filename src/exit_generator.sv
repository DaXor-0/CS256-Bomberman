`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: exit_generator 
* Description: contains the logic that operates the explosion of the bombs.
*
**/

module exit_generator #(
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
    input logic free_blk_signal, // on free_blk, generate the exit with a 5% probability
    input logic last_blk,
    input logic [ADDR_WIDTH-1:0] explosion_addr,

    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_x,  // map_player_x
    input logic [ 9:0] player_y,  // map_player_y

    output logic [ADDR_WIDTH-1:0] exit_addr,
    output logic exit_present,  // To be used by drawcon to draw the explosion
    output logic game_win
);
    
    // state defined in bomberman_dir header
    exit_state_t st, nst;
    
    // -- exit generation signal --
    logic generate_exit;
    logic [ADDR_WIDTH - 1:0] saved_addr;
    logic [ADDR_WIDTH - 1:0] player_addr;


    // p-bit instance for random exit generation
    pbit exit_pbit (
        .Dout(generate_exit),
        .Din(32'h0CCCCCCD), // 5% probability
        .clk(clk)
    );
    
    // ------------------------------
    // -- state register --
    // ------------------------------
    always_ff @(posedge clk) begin
        if (rst)
        st <= EXIT_STATE_IDLE;
        else
        st <= nst;
    end
    
    // ------------------------------
    // -- next state logic --
    // ------------------------------
    always_comb begin
        nst = st;
        case (st)
        EXIT_STATE_IDLE: begin
            if ((generate_exit && free_blk_signal) || last_blk) begin
            nst = EXIT_STATE_PRESENT;
            end
        end
    
        EXIT_STATE_PRESENT: begin
            nst = EXIT_STATE_PRESENT;
        end
    
        endcase
    end
    
    
    // ------------------------------
    // -- state-dependent logic --
    // ------------------------------
    always_ff @(posedge clk)
    if (rst)
      saved_addr <= 0;
    else
    case (st)
      EXIT_STATE_IDLE:
      begin
        if ((generate_exit && free_blk_signal) || last_blk) saved_addr <= explosion_addr;
      end
    endcase
    // ------------------------------
    // -- output logic --
    // ------------------------------
    assign exit_present = (st == EXIT_STATE_PRESENT);

    // Player_x and Player_y in block (col, row)
    logic [$clog2(NUM_ROW)-1:0] blockpos_row;
    logic [$clog2(NUM_COL)-1:0] blockpos_col;
    assign blockpos_row = (player_y >> TILE_SHIFT);  // truncates to ROW_W
    assign blockpos_col = (player_x >> TILE_SHIFT);  // truncates to COL_W
    
    assign player_addr = (blockpos_row * NUM_COL) + blockpos_col;

    // ------------------------------
    // -- win condition --
    // ------------------------------
    assign game_win = (exit_present && 
                       (player_addr == exit_addr)); // Player wins when exit is present
    
    // Exit address is the same as explosion address
    assign exit_addr = saved_addr;

endmodule