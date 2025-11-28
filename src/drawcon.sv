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
    parameter logic [3:0] BRD_R         = 4'h1,
                          BRD_G         = 4'h7,
                          BRD_B         = 4'h3,
    parameter logic [3:0] BG_R          = 4'hF,
                          BG_G          = 4'hF,
                          BG_B          = 4'hF,

    // Derived parameters (not overridable)
    localparam DEPTH      = NUM_COL * NUM_ROW,
    localparam ADDR_WIDTH = $clog2(DEPTH)       // bit-width of map_addr output
) (
    // Map Memory block state input
    input logic clk,
    input logic [MAP_MEM_WIDTH-1:0] map_tile_state,
    input logic [10:0] draw_x,
    input logic [9:0] draw_y,
    input logic [10:0] player_x,
    input logic [9:0] player_y,
    input logic [1:0] anim_frame,
    input dir_t player_dir,
    input logic explode_signal,
    input logic [ADDR_WIDTH-1:0] explosion_addr,
    output logic [3:0] o_r,
    o_g,
    o_b,
    output logic [ADDR_WIDTH-1:0] map_addr
);

  localparam int BLK_W_LOG2 = $clog2(BLK_W);
  localparam int BLK_H_LOG2 = $clog2(BLK_H);

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
  logic [                        11:0] sprite_rgb_q;
  logic                                player_sprite;
  logic                                player_sprite_q;

  logic [        $clog2(SPRITE_W)-1:0] sprite_local_x;
  logic [        $clog2(SPRITE_H)-1:0] sprite_local_y;
  logic [        $clog2(SPRITE_W)-1:0] sprite_x_in_rom;
  logic [$clog2(NUM_FRAMES_TOTAL)-1:0] sprite_offset;

  // Determine if current pixel is within player sprite bounds
  always_comb begin
    player_sprite  = 1'b0;
    sprite_local_x = draw_x - player_x;
    sprite_local_y = draw_y - player_y;


    if ((draw_x >= player_x) && (draw_x < player_x + SPRITE_W) &&
        (draw_y >= player_y) && (draw_y < player_y + SPRITE_H)) begin
      player_sprite = 1'b1;
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
      .MEM_INIT_FILE("player_1.mem")  // 9-frame sheet: DOWN,LR,UP cropped to 32x48
  ) bomberman_sprite_i (
      .clk (clk),
      .addr(sprite_addr),
      .data(sprite_rgb_raw)
  );

  // Align sprite presence with synchronous ROM output (1-cycle latency)
  always_ff @(posedge clk) begin
    player_sprite_q <= player_sprite;
    sprite_rgb_q    <= sprite_rgb_raw;
  end

  // ----------------------------------------------------------------------------
  // Explosion detection: determine if current block is an explosion
  // ----------------------------------------------------------------------------
  // Function to check if the draw block is exploding
  function logic is_exploding(input logic [ADDR_WIDTH-1:0] blk_addr, 
                              input logic [ADDR_WIDTH-1:0] exp);
  return   ((blk_addr == exp) ||
            (blk_addr == exp - NUM_COL) ||
            (blk_addr == exp + NUM_COL) ||
            (blk_addr == exp - 1) ||
            (blk_addr == exp - 1));
  endfunction


  // ---------------------------------------------------------------------------
  // Border / map region detection
  // ---------------------------------------------------------------------------
  logic out_of_map;
  logic out_of_map_q;

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
  map_state st_q;

  // ---------------------------------------------------------------------------
  // Permanent block sprite (64x64)
  // ---------------------------------------------------------------------------
  localparam int PERM_BLK_ADDR_WIDTH = $clog2(BLK_W * BLK_H);
  logic [BLK_W_LOG2-1:0] perm_blk_local_x, perm_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] perm_blk_local_y, perm_blk_local_y_q;
  logic [PERM_BLK_ADDR_WIDTH-1:0] perm_blk_addr;
  logic [                   11:0] perm_blk_rgb;

  // ---------------------------------------------------------------------------
  // Color output muxing
  // ---------------------------------------------------------------------------
  // Everything is pipelined by 1 cycle to line up with the synchronous sprite ROM.
  always_ff @(posedge clk) begin
    out_of_map_q       <= out_of_map;
    st_q               <= st;
    perm_blk_local_x_q <= perm_blk_local_x;
    perm_blk_local_y_q <= perm_blk_local_y;
  end

  always_comb begin
    if (out_of_map_q) begin
      {o_r, o_g, o_b} = {BRD_R, BRD_G, BRD_B};

      // Player sprites have a color key (12'hF0F) for transparency
    end else if (player_sprite_q && (sprite_rgb_q != 12'hF0F)) begin
      {o_r, o_g, o_b} = sprite_rgb_q;

    end else begin
      unique case (st_q)
        no_blk:
        begin
          if (is_exploding(addr_next) && explode_signal)
            {o_r, o_g, o_b} = 12'hF17;
          else
            {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
        end
        perm_blk:        {o_r, o_g, o_b} = perm_blk_rgb;
        destroyable_blk: 
        begin
          if (is_exploding(addr_next) && explode_signal)
            {o_r, o_g, o_b} = 12'hF00; // Here, it should be changed with the reading from explosion ROM
          else 
            {o_r, o_g, o_b} = 12'h00F;
        end
        bomb:            {o_r, o_g, o_b} = 12'h333;
        default:         {o_r, o_g, o_b} = 12'hF0F;  // Magenta as error color
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Map address generation
  // ---------------------------------------------------------------------------
  logic [10:0] map_x;
  logic [ 9:0] map_y;
  logic [4:0] row, col;
  logic [ADDR_WIDTH-1:0] addr_next;

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

  always_comb begin
    col       = map_x >> BLK_W_LOG2;
    row       = map_y >> BLK_H_LOG2;
    addr_next = row * NUM_COL + col;
    map_addr  = (out_of_map) ? '0 : addr_next;
  end

endmodule
