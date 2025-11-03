`timescale 1ns/1ps

/**
* Module: drawcon
* Description: Draws a border and a block on the screen.
*
* THIS NEEDS TO BE UPDATED. TO BE DONE ONCE MODULE IS TESTED AND FUNCTIONS CORRECTLY.
* Parameters:
* - SCREEN_W: Width of the screen in pixels.
* - SCREEN_H: Height of the screen in pixels.
* - BRD_SIZE: Thickness of the border in pixels.
* - BLK_W: Width of the block in pixels.
* - BLK_H: Height of the block in pixels.
* - BRD_R, BRD_G, BRD_B: Color of the border (4-bit each).
* - BLK_R, BLK_G, BLK_B: Color of the block (4-bit each).
* - BG_R, BG_G, BG_B: Background color (4-bit each).
*
* Inputs:
* - blkpos_x: X position of the block (top-left corner).
* - blkpos_y: Y position of the block (top-left corner).
* - draw_x: Current X position being drawn.
* - draw_y: Current Y position being drawn.
*
* Outputs:
* - r, g, b: Color values for the current pixel (4-bit each).
*/
module drawcon #(
    parameter MAP_MEM_WIDTH   = 4, // this is $clog2(number of map states).
    parameter NUM_ROW     = 11,
    parameter NUM_COL     = 19,
    parameter SCREEN_W       = 1280,
    parameter SCREEN_H       = 800,
    parameter BRD_H       = 32, // BRD_SIZE_H
    parameter BRD_TOP     = 96,
    parameter BRD_BOT     = 0,
    parameter BLK_W          = 64, // should be power of 2
    parameter BLK_H          = 64, // should be power of 2
    parameter logic[3:0] BRD_R =4'hF, BRD_G=4'hF, BRD_B = 4'hF, // White border
    parameter logic[3:0] BG_R = 4'h0, BG_G = 4'h0,  BG_B  = 4'h0,  // Black background
    // localparams should not be modified in module instantiation
    localparam NUM_BLKS = NUM_COL*NUM_ROW, // 
    localparam BLK_IND_WIDTH = $clog2(NUM_BLKS) // bit-width of blk_addr output
)(
    input logic clk, rst,
    input logic [MAP_MEM_WIDTH-1:0] map_mem_in, // Map Memory block state input
    input  logic [10:0] blkpos_x,
    input  logic [9:0]  blkpos_y,
    input  logic [10:0] draw_x,
    input  logic [9:0]  draw_y,
    input logic [3:0] i_r, i_g, i_b,
    output logic [3:0]  o_r, o_g, o_b,
    output logic obstacle_right, obstacle_left, obstacle_down, obstacle_up, // Variable names are very verbose..
    output logic [BLK_IND_WIDTH-1:0] blk_addr
);

  logic out_of_map;
  always_comb begin
    out_of_map = (draw_x < BRD_H) || (draw_x >= SCREEN_W - BRD_H) ||
                 (draw_y < BRD_TOP) || (draw_y >= SCREEN_H - BRD_BOT);
    obstacle_right = (blkpos_x + BLK_W >= SCREEN_W - BRD_H);
    obstacle_left = (blkpos_x <= BRD_H);
    obstacle_down = (blkpos_y + BLK_H >= SCREEN_H - BRD_BOT);
    obstacle_up = (blkpos_y <= BRD_TOP);
  end

  // Map state-machine (0,1,2,...), with next-state obtained from the map_memory
  typedef enum { no_blk, perm_blk, destroyable_blk } map_state;

  map_state st;

  always_ff @(posedge clk) begin
    if (rst || out_of_map) st <= border;
    else st <= map_state'(map_mem_in);
  end

  // change drawing inputs based on the map_mem_in.
  // initially: will multiplex different colors.
  // when adding sprites: bring counter and control logic out, multiplexing at the memory and simply receiving pix_rgb as input .. ?
  always_comb begin
    case (st)
      border:          { o_r, o_g, o_b } = { BRD_R, BRD_G, BRD_B };
      no_blk:          { o_r, o_g, o_b } = { BG_R, BG_G, BG_B };
      perm_blk:        { o_r, o_g, o_b } = 12'hFFF;
      destroyable_blk: { o_r, o_g, o_b } = 12'h00F;
      player:          { o_r, o_g, o_b } = { i_r, i_g, i_b };
      enemy:           { o_r, o_g, o_b } = 12'hF33;
      bomb:            { o_r, o_g, o_b } = 12'h333;
      explosion:       { o_r, o_g, o_b } = 12'hF00;
      power_up:        { o_r, o_g, o_b } = 12'h0F0;
      default:         { o_r, o_g, o_b } = 12'hFF0; // bug state; if a block is yellow then there is something wrong.
    endcase
  end

  // Indexing the block address
  localparam BLK_H_LOG2 = $clog2(BLK_H);
  localparam BLK_W_LOG2 = $clog2(BLK_W);
  logic [10:0] map_x;
  logic [9:0] map_y;

  // accounting for the border offset so that indexing is done correctly.
  assign map_x = draw_x - BRD_H;
  assign map_y = draw_y - BRD_TOP;

  logic [4:0] row, col;
  logic [BLK_IND_WIDTH-1:0] addr_next;
  always_comb begin
    col = map_x >> BLK_W_LOG2;
    row = map_y >> BLK_H_LOG2;
    addr_next = (row << 4) + (row << 1) + row + col; // (row << 4) + (row << 1) + row == row*16+row*2+row == row*19 --> hard-coded for 19 blocks. It's okay, since we will not change number of blocks.
    blk_addr = out_of_map ? '0 : addr_next;
  end


endmodule
