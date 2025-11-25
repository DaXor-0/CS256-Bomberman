`timescale 1ns/1ps

/**
* Module: free_blocks
* Description: receives an input signal from explode_logic, and an input address,
* then checks the blocks around the given address and writes over destroyable_blks to make them no_blk
**/

module explode_logic
#(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW     = 11,
    parameter int NUM_COL     = 19,
    parameter int TILE_PX     = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W  = 32,
    parameter int SPRITE_H  = 48,
    // ---- Bomb Parameters ----
    parameter int EXPLODE_TIME = 1,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

)(
    input logic clk, rst, tick,
    input logic free_blks_signal,
    input logic [ADDR_WIDTH-1:0] explosion_addr,
    input logic [MAP_MEM_WIDTH-1:0] map_mem_in,
    input logic read_ready,
    
    output logic [ADDR_WIDTH-1:0] read_addr,
    output logic [ADDR_WIDTH-1:0] write_addr,
    output logic [MAP_MEM_WIDTH-1:0] write_data,
    output logic write_en          
);

  // Direction indices
  localparam int UP    = 0;
  localparam int DOWN  = 1;
  localparam int LEFT  = 2;
  localparam int RIGHT = 3;

  

endmodule