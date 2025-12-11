`timescale 1ns/1ps

`include "bomberman_dir.svh"

module compute_player_blocks #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = MAP_NUM_ROW_DEF,
    parameter int NUM_COL       = MAP_NUM_COL_DEF,
    parameter int TILE_PX       = MAP_TILE_PX_DEF,
    parameter int MAP_MEM_WIDTH = MAP_MEM_WIDTH_DEF,
    parameter int SPRITE_W      = SPRITE_W_PX_DEF,
    parameter int SPRITE_H      = SPRITE_H_PX_DEF,


    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

) (
    input  logic [10:0] player_x,
    input  logic [ 9:0] player_y,

    output logic [ADDR_WIDTH-1:0] blk1_addr,
    output logic [ADDR_WIDTH-1:0] blk2_addr
);

    // --- Local intermediate signals ---
    logic [TILE_SHIFT:0] tile_offset_x;
    logic [TILE_SHIFT:0] tile_offset_y;
    logic [TILE_SHIFT:0] right_edge_offset;
    logic [TILE_SHIFT:0] bottom_edge_offset;

    logic [$clog2(NUM_ROW)-1:0] blockpos_row;
    logic [$clog2(NUM_COL)-1:0] blockpos_col;
    logic [$clog2(NUM_ROW)-1:0] blockpos_row2;
    logic [$clog2(NUM_COL)-1:0] blockpos_col2;

    // --- Offsets inside current tile ---
    always_comb
    begin
    tile_offset_x = {1'b0, player_x[TILE_SHIFT-1:0]};
    tile_offset_y = {1'b0, player_y[TILE_SHIFT-1:0]};
    right_edge_offset  = tile_offset_x + SPRITE_W;
    bottom_edge_offset = tile_offset_y + SPRITE_H;

    // --- Base tile positions ---
    blockpos_row = player_y >> TILE_SHIFT;
    blockpos_col = player_x >> TILE_SHIFT;

    // --- Check if sprite spans into a second block ---
    blockpos_row2 = (bottom_edge_offset > TILE_PX) ? blockpos_row + 1 : blockpos_row;
    blockpos_col2 = (right_edge_offset  > TILE_PX) ? blockpos_col + 1 : blockpos_col;

    // --- Block addresses ---
    blk1_addr = blockpos_row * NUM_COL + blockpos_col;
    blk2_addr = blockpos_row2 * NUM_COL + blockpos_col2;
    end
endmodule
