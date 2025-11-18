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
* - player_x: X position of the block (top-left corner).
* - player_y: Y position of the block (top-left corner).
* - draw_x: Current X position being drawn.
* - draw_y: Current Y position being drawn.
*
* Outputs:
* - r, g, b: Color values for the current pixel (4-bit each).
*/
module drawcon #(
    parameter MAP_MEM_WIDTH   = 2, // this is $clog2(number of map states).
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
    localparam DEPTH = NUM_COL*NUM_ROW, // 
    localparam ADDR_WIDTH = $clog2(DEPTH) // bit-width of map_addr output
)(
    // Map Memory block state input
    input logic [MAP_MEM_WIDTH-1:0] map_tile_state, 
    
    // Game logic conditions for drawing control
    input logic is_player,

    // curr_x, curr_y    
    input  logic [10:0] draw_x,
    input  logic [9:0]  draw_y,

    // input pixels, coming from various sprite ROMs (which will be multiplexed)
    input logic [3:0] i_r, i_g, i_b,

    // output pixels, to be fed directly to vga_out
    output logic [3:0]  o_r, o_g, o_b,
    output logic [ADDR_WIDTH-1:0] map_addr
  );

  logic out_of_map;
  always_comb begin
    out_of_map = (draw_x < BRD_H) || (draw_x >= SCREEN_W - BRD_H) ||
                 (draw_y < BRD_TOP) || (draw_y >= SCREEN_H - BRD_BOT);
  end

  // Map state-machine (0,1,2,...), with next-state obtained from the map_memory
  typedef enum logic [1:0] {
    no_blk          = 2'd0,
    perm_blk        = 2'd1,
    destroyable_blk = 2'd2,
    bomb            = 2'd3
} map_state;

  map_state st;
  assign st = map_state'(map_tile_state);

  // change drawing inputs based on the map_mem_in.
  // initially: will multiplex different colors.
  // when adding sprites: bring counter and control logic out, multiplexing at the memory and simply receiving pix_rgb as input .. ?
  always_comb begin
    if (out_of_map)
      {o_r, o_g, o_b} = {BRD_R, BRD_G, BRD_B};
    else if (is_player)
      {o_r, o_g, o_b} = {i_r, i_g, i_b};
    else
      unique case (st)
        no_blk:          { o_r, o_g, o_b } = { BG_R, BG_G, BG_B };
        perm_blk:        { o_r, o_g, o_b } = 12'h0F0;
        destroyable_blk: { o_r, o_g, o_b } = 12'h00F;
        bomb:            { o_r, o_g, o_b } = 12'h333;
//      power_up:        { o_r, o_g, o_b } = 12'h0F0;
        default:         { o_r, o_g, o_b } = 12'hFF0; // bug state; if a block is yellow then there is something wrong.
      endcase
  end

// map_addr_drawcon addressing control
// Indexing the block address
localparam BLK_H_LOG2 = $clog2(BLK_H);
localparam BLK_W_LOG2 = $clog2(BLK_W);
logic [10:0] map_x;
logic [9:0] map_y;

// accounting for the border offset so that indexing is done correctly.
assign map_x = draw_x - BRD_H;
assign map_y = draw_y - BRD_TOP;

logic [4:0] row, col;
logic [ADDR_WIDTH-1:0] addr_next;
always_comb begin
  col = map_x >> BLK_W_LOG2;
  row = map_y >> BLK_H_LOG2;
  addr_next = row * NUM_COL + col;
  map_addr = out_of_map ? '0 : addr_next;
end


endmodule
