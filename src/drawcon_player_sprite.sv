`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
 * Module: drawcon_player_sprite
 * Description: Draw controller module for player sprite rendering.
 * Parameters:
 * - SPRITE_W / SPRITE_H: Dimensions of the sprite in pixels.
 * - WALK_FRAMES_PER_DIR: Number of walking frames per direction.
 * - WALK_FRAMES_TOTAL: Total number of walking frames.
 * - MEM_INIT_FILE: Memory initialization file for sprite ROM.
 */
module drawcon_player_sprite #(
    parameter  int    SPRITE_W            = 32,
    parameter  int    SPRITE_H            = 48,
    parameter  int    WALK_FRAMES_PER_DIR = 3,
    parameter  int    WALK_FRAMES_TOTAL   = 9,
    parameter  string MEM_INIT_FILE       = "player_1.mem",
    localparam int    WALK_SPRITE_SIZE    = SPRITE_W * SPRITE_H,
    localparam int    ADDR_WIDTH          = $clog2(WALK_SPRITE_SIZE * WALK_FRAMES_TOTAL)
) (
    input  logic        clk,
    input  logic [10:0] draw_x,
    input  logic [ 9:0] draw_y,
    input  logic [10:0] sprite_x,
    input  logic [ 9:0] sprite_y,
    input  dir_t        dir,
    input  logic [ 1:0] walk_frame,
    output logic        active_q,
    output logic [11:0] rgb_q
);

  logic [      ADDR_WIDTH-1:0] sprite_addr;
  logic [      ADDR_WIDTH-1:0] sprite_offset;
  logic [      ADDR_WIDTH-1:0] sprite_x_in_rom;
  logic [                11:0] rgb_raw;
  logic                        active;

  logic [$clog2(SPRITE_W)-1:0] local_x;
  logic [$clog2(SPRITE_H)-1:0] local_y;

  always_comb begin
    active   = (draw_x >= sprite_x) && (draw_x < sprite_x + SPRITE_W) &&
               (draw_y >= sprite_y) && (draw_y < sprite_y + SPRITE_H);
    local_x = draw_x - sprite_x;
    local_y = draw_y - sprite_y;
    sprite_offset = '0;

    case (dir_t'(dir))
      DIR_DOWN:  sprite_offset = 0*WALK_FRAMES_PER_DIR + walk_frame; // 0..2
      DIR_LEFT:  sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame; // 3..5
      DIR_RIGHT: sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame; // 3..5
      DIR_UP:    sprite_offset = 2*WALK_FRAMES_PER_DIR + walk_frame; // 6..8
      default:   sprite_offset = '0;
    endcase
  end

  assign sprite_x_in_rom = (dir == DIR_LEFT) ? (SPRITE_W - 1 - local_x) : local_x;

  assign sprite_addr = active ?
      (sprite_offset * WALK_SPRITE_SIZE + local_y * SPRITE_W + sprite_x_in_rom) : '0;

  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .NUM_FRAMES   (WALK_FRAMES_TOTAL),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(MEM_INIT_FILE)
  ) sprite_rom_i (
      .clk (clk),
      .addr(sprite_addr),
      .data(rgb_raw)
  );

  always_ff @(posedge clk) begin
    active_q <= active;
    rgb_q    <= rgb_raw;
  end

endmodule
