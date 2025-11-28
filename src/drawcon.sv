`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
 * Module: drawcon
 * Description: Draws borders / map blocks and multiplexes colors based on map state.
 *              Player sprite comes from a synchronous ROM; related gating is pipelined by 1 cycle.
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
    parameter logic [3:0] BG_R          = 4'h1,
                          BG_G          = 4'h7,
                          BG_B          = 4'h3,

    // Derived parameters (not overridable)
    localparam DEPTH          = NUM_COL * NUM_ROW,
    localparam MAP_ADDR_WIDTH = $clog2(DEPTH),         // bit-width of map_addr output
    localparam BLK_W_LOG2     = $clog2(BLK_W),
    localparam BLK_H_LOG2     = $clog2(BLK_H),
    localparam BLK_ADDR_WIDTH = $clog2(BLK_W * BLK_H)

) (
    // Map Memory block state input
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      tick,
    input  logic [ MAP_MEM_WIDTH-1:0] map_tile_state,
    input  logic [              10:0] draw_x,
    input  logic [               9:0] draw_y,
    input  logic [              10:0] player_x,
    input  logic [               9:0] player_y,
    input  dir_t                      player_dir,
    input  logic                      explode_signal,
    input  logic [MAP_ADDR_WIDTH-1:0] explosion_addr,
    output logic [               3:0] o_r,
    o_g,
    o_b,
    output logic [MAP_ADDR_WIDTH-1:0] map_addr
);

  // ---------------------------------------------------------------------------
  // Sprite sheet layout parameters
  // ---------------------------------------------------------------------------
  localparam int WALK_DIRS_STORED = 3;  // down, left/right (shared), up
  localparam int WALK_FRAMES_PER_DIR = 3;  // left/right share these 3 frames
  localparam int WALK_FRAMES_TOTAL = WALK_FRAMES_PER_DIR * WALK_DIRS_STORED;  // 9
  localparam int WALK_SPRITE_SIZE = SPRITE_W * SPRITE_H;
  localparam int WALK_SPRITE_ROM_DEPTH = WALK_FRAMES_TOTAL * WALK_SPRITE_SIZE;
  localparam int WALK_SPRITE_ADDR_WIDTH = $clog2(WALK_SPRITE_ROM_DEPTH);
  localparam int WALK_ANIM_TIME = 10;  // hold each frame for 5 ticks

  localparam int BOMB_STATUS_TYPES = 2;  // normal, red (about to explode)
  localparam int BOMB_SPRITE_PER_TYPE = 3;
  localparam int BOMB_SPRITE_TOTAL = BOMB_STATUS_TYPES * BOMB_SPRITE_PER_TYPE;  // 6
  localparam int BOMB_SPRITE_SIZE = BLK_W * BLK_H;
  localparam int BOMB_SPRITE_ROM_DEPTH = BOMB_SPRITE_TOTAL * BOMB_SPRITE_SIZE;
  localparam int BOMB_SPRITE_ADDR_WIDTH = $clog2(BOMB_SPRITE_ROM_DEPTH);
  localparam int BOMB_TOTAL_ANIMATION_TIME = 180;  // 3 seconds at 60 fps
  localparam int BOMB_SPRITE_BLACK_TIME = 120;
  localparam int BOMB_SPRITE_RED_RIME = 60;
  localparam int BOMB_ANIM_TIME = 15;  // hold each frame for 15 ticks

  // ---------------------------------------------------------------------------
  // Animation driver (runs a counter to select animation frame)
  // ---------------------------------------------------------------------------
  logic [5:0] frame_cnt;  // fame counter to 60 fps
  logic [1:0] walk_frame;  // ranges 0,1,2
  always_ff @(posedge clk) begin
    if (rst) begin
      frame_cnt  <= 6'd0;
      walk_frame <= 2'd0;
    end else if (tick) begin
      frame_cnt <= frame_cnt + 1;
      if (frame_cnt == 6'd59) frame_cnt <= 0;

      if (player_dir != DIR_NONE) begin
        if ((frame_cnt + 1) % WALK_ANIM_TIME == 0) begin
          walk_frame <= walk_frame + 1;
          if (walk_frame == WALK_FRAMES_PER_DIR - 1) walk_frame <= 0;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Player sprite addressing
  // ---------------------------------------------------------------------------
  // Sprite ROM interface signals
  logic [   WALK_SPRITE_ADDR_WIDTH-1:0] sprite_addr;
  logic [                         11:0] sprite_rgb_raw;
  logic [                         11:0] sprite_rgb_q;
  // Sprite position and bounds checking
  logic                                 player_sprite;
  logic                                 player_sprite_q;
  logic [         $clog2(SPRITE_W)-1:0] sprite_local_x;
  logic [         $clog2(SPRITE_H)-1:0] sprite_local_y;
  // Sprite frame selection
  logic [         $clog2(SPRITE_W)-1:0] sprite_x_in_rom;
  logic [$clog2(WALK_FRAMES_TOTAL)-1:0] sprite_offset;

  logic [           MAP_ADDR_WIDTH-1:0] addr_next;

  // Determine if current pixel is within player sprite bounds and
  // which sprite frame to use based on player direction and animation frame
  always_comb begin
    sprite_offset = '0;
    sprite_local_x = draw_x - player_x;
    sprite_local_y = draw_y - player_y;
    player_sprite = (draw_x >= player_x) && (draw_x < player_x + SPRITE_W) &&
                    (draw_y >= player_y) && (draw_y < player_y + SPRITE_H);

    case (dir_t'(player_dir))
      DIR_DOWN:  sprite_offset = 0*WALK_FRAMES_PER_DIR + walk_frame; // 0..2
      DIR_LEFT:  sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame; // 3..5
      DIR_RIGHT: sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame; // 3..5
      DIR_UP:    sprite_offset = 2*WALK_FRAMES_PER_DIR + walk_frame; // 6..8
    endcase
  end

  // If facing left, flip the right sprite horizontaly
  assign sprite_x_in_rom = (player_dir == DIR_LEFT) ?
                           (SPRITE_W - 1 - sprite_local_x) :
                            sprite_local_x;
  // Calculate final sprite ROM address also in correlation to frame offset
  assign sprite_addr = player_sprite ?
                       (sprite_offset * WALK_SPRITE_SIZE +
                        sprite_local_y * SPRITE_W + sprite_x_in_rom) :
                       '0;

  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .NUM_FRAMES   (WALK_FRAMES_TOTAL),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("player_1.mem")      // 9-frame sheet: DOWN,LR,UP cropped to 32x48
  ) bomberman_sprite_i (
      .clk (clk),
      .addr(sprite_addr),
      .data(sprite_rgb_raw)
  );

  // ---------------------------------------------------------------------------
  // Border / map region detection
  // ---------------------------------------------------------------------------
  logic out_of_map;
  logic out_of_map_q;
  always_comb begin
    out_of_map = (draw_x < BRD_H)               ||
                 (draw_x >= SCREEN_W - BRD_H)   ||
                 (draw_y < BRD_TOP)             ||
                 (draw_y >= SCREEN_H - BRD_BOT);
  end

  map_state_t st;
  map_state_t st_q;
  assign st = map_state_t'(map_tile_state);

  // ---------------------------------------------------------------------------
  // Static block sprite (64x64)
  // ---------------------------------------------------------------------------
  logic [BLK_W_LOG2-1:0] perm_blk_local_x, perm_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] perm_blk_local_y, perm_blk_local_y_q;
  logic [BLK_W_LOG2-1:0] dest_blk_local_x, dest_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] dest_blk_local_y, dest_blk_local_y_q;
  logic [BLK_ADDR_WIDTH-1:0] perm_blk_addr;
  logic [              11:0] perm_blk_rgb;
  logic [BLK_ADDR_WIDTH-1:0] dest_blk_addr;
  logic [              11:0] dest_blk_rgb;

  // ----------------------------------------------------------------------------
  // Explosion detection: determine if current block is an explosion
  // ----------------------------------------------------------------------------
  // Function to check if the draw block is exploding
  function logic is_exploding(input logic [MAP_ADDR_WIDTH-1:0] blk_addr,
                              input logic [MAP_ADDR_WIDTH-1:0] exp);
    return ((blk_addr == exp)          ||
           (blk_addr == exp - NUM_COL) ||
           (blk_addr == exp + NUM_COL) ||
           (blk_addr == exp - 1)       ||
           (blk_addr == exp + 1));
  endfunction

  // ---------------------------------------------------------------------------
  // Color output muxing
  // ---------------------------------------------------------------------------
  // Everything is pipelined by 1 cycle to line up with the synchronous sprite ROM.
  always_ff @(posedge clk) begin
    out_of_map_q       <= out_of_map;
    st_q               <= st;
    player_sprite_q    <= player_sprite;
    sprite_rgb_q       <= sprite_rgb_raw;
    perm_blk_local_x_q <= perm_blk_local_x;
    perm_blk_local_y_q <= perm_blk_local_y;
    dest_blk_local_x_q <= dest_blk_local_x;
    dest_blk_local_y_q <= dest_blk_local_y;
  end

  always_comb begin
    if (out_of_map_q) begin
      {o_r, o_g, o_b} = {BRD_R, BRD_G, BRD_B};

      // Player sprites have a color key (12'hF0F) for transparency
    end else if (player_sprite_q && (sprite_rgb_q != 12'hF0F)) begin
      {o_r, o_g, o_b} = sprite_rgb_q;

    end else begin
      unique case (st_q)
        NO_BLK: begin
          if (is_exploding(addr_next, explosion_addr) && explode_signal) {o_r, o_g, o_b} = 12'hF17;
          else {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
        end

        PERM_BLK: {o_r, o_g, o_b} = perm_blk_rgb;

        DESTROYABLE_BLK: begin
          if (is_exploding(addr_next, explosion_addr) && explode_signal)
            {o_r, o_g, o_b} = 12'hF00; // Here, it should be changed with the reading from explosion ROM
          else {o_r, o_g, o_b} = dest_blk_rgb;
        end

        BOMB: {o_r, o_g, o_b} = 12'h333;

        default: {o_r, o_g, o_b} = 12'hF0F;  // Magenta as error color
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Map address generation
  // ---------------------------------------------------------------------------
  logic [10:0] map_x;
  logic [ 9:0] map_y;
  logic [4:0] row, col;

  // Accounting for the border offset so that indexing is done correctly.
  assign map_x = draw_x - BRD_H;
  assign map_y = draw_y - BRD_TOP;

  assign perm_blk_local_x = map_x[BLK_W_LOG2-1:0];
  assign perm_blk_local_y = map_y[BLK_H_LOG2-1:0];
  assign perm_blk_addr = {perm_blk_local_y_q, perm_blk_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("perm_blk.mem")
  ) perm_blk_sprite_i (
      .clk (clk),
      .addr(perm_blk_addr),
      .data(perm_blk_rgb)
  );

  assign dest_blk_local_x = map_x[BLK_W_LOG2-1:0];
  assign dest_blk_local_y = map_y[BLK_H_LOG2-1:0];
  assign dest_blk_addr = {dest_blk_local_y_q, dest_blk_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("dest_blk.mem")
  ) dest_blk_sprite_i (
      .clk (clk),
      .addr(dest_blk_addr),
      .data(dest_blk_rgb)
  );

  always_comb begin
    col       = map_x >> BLK_W_LOG2;
    row       = map_y >> BLK_H_LOG2;
    addr_next = row * NUM_COL + col;
    map_addr  = (out_of_map) ? '0 : addr_next;
  end

endmodule
