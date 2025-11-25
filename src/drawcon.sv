`timescale 1ns / 1ps

/**
 * Module: drawcon
 * Description: Draws borders / map blocks and multiplexes colors based on map state.
 *
 * Parameters:
 *  - MAP_MEM_WIDTH : $clog2(number of map states)
 *  - NUM_ROW       : Number of rows in the map
 *  - NUM_COL       : Number of columns in the map
 *  - SCREEN_W/H    : Screen width / height in pixels
 *  - BRD_H         : Horizontal border thickness (left/right)
 *  - BRD_TOP/BOT   : Top / bottom border offsets
 *  - BLK_W/H       : Block width / height in pixels (power of 2)
 *  - SPRITE_W/H    : Sprite width / height
 *  - BRD_*         : Border color (4-bit each)
 *  - BG_*          : Background color (4-bit each)
 */
module drawcon #(
    parameter             MAP_MEM_WIDTH = 2,     // this is $clog2(number of map states).
    parameter             NUM_ROW       = 11,
    parameter             NUM_COL       = 19,
    parameter             SCREEN_W      = 1280,
    parameter             SCREEN_H      = 800,
    parameter             BRD_H         = 32,    // border thickness (left/right)
    parameter             BRD_TOP       = 96,
    parameter             BRD_BOT       = 0,
    parameter             BLK_W         = 64,    // should be power of 2
    parameter             BLK_H         = 64,    // should be power of 2
    parameter             SPRITE_W      = 32,
    parameter             SPRITE_H      = 48,
    parameter logic [3:0] BRD_R         = 4'hF,
                          BRD_G         = 4'hF,
                          BRD_B         = 4'hF,
    parameter logic [3:0] BG_R          = 4'h0,
                          BG_G          = 4'h0,
                          BG_B          = 4'h0,

    // Derived parameters (not overridable)
    localparam DEPTH             = NUM_COL * NUM_ROW,
    localparam ADDR_WIDTH        = $clog2(DEPTH),               // bit-width of map_addr output
    localparam SPRITE_ADDR_WIDTH = $clog2(SPRITE_W * SPRITE_H)
) (
    // Map Memory block state input
    input logic [MAP_MEM_WIDTH-1:0] map_tile_state,
    input logic [10:0] draw_x,
    input logic [9:0] draw_y,
    input logic [3:0] i_r,
    i_g,
    i_b,
    output logic [3:0] o_r,
    o_g,
    o_b,
    output logic [ADDR_WIDTH-1:0] map_addr
);

  // ---------------------------------------------------------------------------
  // Sprite addressing
  // ---------------------------------------------------------------------------
  // Single sprite memory for Bomberman_walking
  logic [SPRITE_ADDR_WIDTH-1:0] sprite_addr;
  logic [                 11:0] sprite_rgb_raw;
  logic                         player_sprite;
  logic [ $clog2(SPRITE_W)-1:0] sprite_local_x;
  logic [ $clog2(SPRITE_H)-1:0] sprite_local_y;

  always_comb begin
    player_sprite  = 1'b0;
    sprite_local_x = '0;
    sprite_local_y = '0;
    sprite_addr    = '0;

    if ((curr_x >= player_x) && (curr_x < player_x + SPRITE_W) &&
        (curr_y >= player_y) && (curr_y < player_y + SPRITE_H)) begin
      player_sprite  = 1'b1;
      sprite_local_x = curr_x - player_x;
      sprite_local_y = curr_y - player_y;
      sprite_addr    = {sprite_local_y, sprite_local_x};
    end
  end

  // Simply loads the down walking sprite for now.
  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("down_1.mem")  // for now just use the down sprite
  ) bomberman_sprite_i (
      .addr(sprite_addr),
      .data(sprite_rgb_raw)
  );

  // ---------------------------------------------------------------------------
  // Border / map region detection
  // ---------------------------------------------------------------------------
  logic out_of_map;
  always_comb begin
    out_of_map =
        (draw_x < BRD_H)   || (draw_x >= SCREEN_W - BRD_H)  ||
        (draw_y < BRD_TOP) || (draw_y >= SCREEN_H - BRD_BOT);
  end

  // ---------------------------------------------------------------------------
  // Map state decoding
  // ---------------------------------------------------------------------------
  // Map state-machine (0,1,2,...), with next-state obtained from the map_memory
  typedef enum logic [1:0] {
    no_blk          = 2'd0,
    perm_blk        = 2'd1,
    destroyable_blk = 2'd2,
    bomb            = 2'd3
  } map_state;

  map_state st;
  assign st = map_state'(map_tile_state);

  // ---------------------------------------------------------------------------
  // Color output muxing
  // ---------------------------------------------------------------------------
  // Initially: multiplex different colors.
  // When adding sprites: bring counter and control logic out, multiplexing at
  // the memory and simply receiving pix_rgb as input.
  always_comb begin
    if (out_of_map) begin
      {o_r, o_g, o_b} = {BRD_R, BRD_G, BRD_B};
    end else if (is_player) begin
      {o_r, o_g, o_b} = {i_r, i_g, i_b};
    end else begin
      unique case (st)
        no_blk:          {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
        perm_blk:        {o_r, o_g, o_b} = 12'h0F0;
        destroyable_blk: {o_r, o_g, o_b} = 12'h00F;
        bomb:            {o_r, o_g, o_b} = 12'h333;
        // power_up:     {o_r, o_g, o_b} = 12'h0F0;
        default:         {o_r, o_g, o_b} = 12'hFF0;  // bug state; yellow = error
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Map address generation
  // ---------------------------------------------------------------------------
  // map_addr_drawcon addressing control
  // Indexing the block address
  localparam BLK_H_LOG2 = $clog2(BLK_H);
  localparam BLK_W_LOG2 = $clog2(BLK_W);

  logic [10:0] map_x;
  logic [ 9:0] map_y;
  logic [4:0] row, col;
  logic [ADDR_WIDTH-1:0] addr_next;

  // Accounting for the border offset so that indexing is done correctly.
  assign map_x = draw_x - BRD_H;
  assign map_y = draw_y - BRD_TOP;

  always_comb begin
    col       = map_x >> BLK_W_LOG2;
    row       = map_y >> BLK_H_LOG2;
    addr_next = row * NUM_COL + col;
    map_addr  = (out_of_map) ? '0 : addr_next;
  end

endmodule
