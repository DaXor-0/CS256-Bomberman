`timescale 1ns / 1ps

`include "bomberman_dir.svh"

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
    localparam DEPTH      = NUM_COL * NUM_ROW,
    localparam ADDR_WIDTH = $clog2(DEPTH)       // bit-width of map_addr output
) (
    // Map Memory block state input
    input logic [MAP_MEM_WIDTH-1:0] map_tile_state,
    input logic [10:0] draw_x,
    input logic [9:0] draw_y,
    input logic [10:0] player_x,
    input logic [9:0] player_y,
    input logic [1:0] anim_frame,
    input dir_t player_dir,
    output logic [3:0] o_r,
    o_g,
    o_b,
    output logic [ADDR_WIDTH-1:0] map_addr
);

  // ---------------------------------------------------------------------------
  // Sprite sheet layout parameters
  // ---------------------------------------------------------------------------
  localparam int FRAMES_PER_DIR = 3;  // left/right share these 3 frames
  localparam int NUM_DIRS_STORED = 3;  // LEFT/RIGHT, UP, DOWN
  localparam int NUM_FRAMES_TOTAL = FRAMES_PER_DIR * NUM_DIRS_STORED;  // 9
  localparam int SPR_PIXELS_PER_FRM = SPRITE_W * SPRITE_H;
  localparam int SPRITE_ROM_DEPTH = NUM_FRAMES_TOTAL * SPR_PIXELS_PER_FRM;
  localparam int SPRITE_ADDR_WIDTH = $clog2(SPRITE_ROM_DEPTH);

  // ---------------------------------------------------------------------------
  // Sprite addressing
  // ---------------------------------------------------------------------------
  logic [       SPRITE_ADDR_WIDTH-1:0] sprite_addr;
  logic [                        11:0] sprite_rgb_raw;
  logic                                player_sprite;

  logic [        $clog2(SPRITE_W)-1:0] sprite_local_x;
  logic [        $clog2(SPRITE_H)-1:0] sprite_local_y;
  logic [        $clog2(SPRITE_W)-1:0] sprite_x_in_rom;
  logic [$clog2(NUM_FRAMES_TOTAL)-1:0] sprite_offset;

  // Determine if current pixel is within player sprite bounds
  always_comb begin
    player_sprite  = 1'b0;
    sprite_local_x = draw_x - player_x;
    sprite_local_y = draw_y - player_y;
    sprite_addr    = '0;

    if ((draw_x >= player_x) && (draw_x < player_x + SPRITE_W) &&
        (draw_y >= player_y) && (draw_y < player_y + SPRITE_H)) begin
      player_sprite  = 1'b1;
    end
  end

  // Determine which sprite frame to use based on player direction and animation frame
  always_comb begin
    sprite_offset = '0;
    case (dir_t'(player_dir))
      DIR_DOWN:  sprite_offset = 0*FRAMES_PER_DIR + anim_frame; // 0..2
      DIR_LEFT:  sprite_offset = 1*FRAMES_PER_DIR + anim_frame; // 3..5
      DIR_RIGHT: sprite_offset = 1*FRAMES_PER_DIR + anim_frame; // 3..5
      DIR_UP:    sprite_offset = 2*FRAMES_PER_DIR + anim_frame; // 6..8
    endcase
  end

  // If facing left, flip the right sprite horizontaly
  always_comb begin
    sprite_x_in_rom = sprite_local_x;
    if (player_dir == DIR_LEFT) sprite_x_in_rom = SPRITE_W - 1 - sprite_local_x;
  end

  // Calculate final sprite ROM address also in correlation to frame offset
  always_comb begin
    if (player_sprite) begin
      sprite_addr = sprite_offset * SPR_PIXELS_PER_FRM + sprite_local_y * SPRITE_W + sprite_x_in_rom;
    end else begin
      sprite_addr = '0;
    end
  end

  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .NUM_FRAMES   (9),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("player_1.mem")  // 9-frame sheet: LR,UP,DOWN cropped to 32x48
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
        (draw_x < BRD_H)              ||
        (draw_x >= SCREEN_W - BRD_H)  ||
        (draw_y < BRD_TOP)            ||
        (draw_y >= SCREEN_H - BRD_BOT);
  end

  // ---------------------------------------------------------------------------
  // Map state decoding
  // ---------------------------------------------------------------------------
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
  always_comb begin
    if (out_of_map) begin
      {o_r, o_g, o_b} = {BRD_R, BRD_G, BRD_B};
    end else if (player_sprite) begin
      {o_r, o_g, o_b} = sprite_rgb_raw;
    end else begin
      unique case (st)
        no_blk:          {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
        perm_blk:        {o_r, o_g, o_b} = 12'h0F0;
        destroyable_blk: {o_r, o_g, o_b} = 12'h00F;
        bomb:            {o_r, o_g, o_b} = 12'h333;
        default:         {o_r, o_g, o_b} = 12'hFF0;  // bug state; yellow = error
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Map address generation
  // ---------------------------------------------------------------------------
  localparam int BLK_H_LOG2 = $clog2(BLK_H);
  localparam int BLK_W_LOG2 = $clog2(BLK_W);

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
