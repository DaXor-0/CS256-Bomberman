`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
 * Module: drawcon_hud
 * Description: Generates HUD hit flags and RGB samples for player icons, power-up icons and
 *              upgrade track pips using the current draw coordinate and power-up levels.
 *
 * Responsibilities:
 *  - Assert *_q when draw_x/draw_y falls inside a HUD element bounding box.
 *  - Drive sprite_rom addresses for each element and mux player 1/2 reads for shared icons.
 *  - Render up to three track pips per upgrade; inputs above 3 are saturated.
 *
 * Parameters (geometry/layout):
 *  - SCREEN_W/H           : Screen size and HUD strip dimensions.
 *  - HUD_*                : HUD thickness/offsets; icon origins are absolute screen coordinates.
 *  - *_ICON_*             : Sprite dimensions for player icons, power-up icons and track pips.
 *  - HUD_TRACK_TYPES      : Frames per track sprite (owned/unowned frame offset).
 *
 * Ports:
 *  - draw_x/draw_y        : Current pixel from the draw pipeline.
 *  - p?_bomb/range/speed_level : Upgrade counts 0..3 per player (clamped internally).
 *  - *_q / track_hit_q    : High when the previous cycle's draw_x/draw_y was inside the region.
 *  - *_rgb_q              : 12-bit RGB from sprite ROM for the last asserted element.
 *
 * Notes:
 *  - Layout mirrors P1 icons to the right for P2; track pips sit to the right of each item row.
 *  - sprite_rom is synchronous, so outputs are registered to align with the drawcon pipeline.
 */
module drawcon_hud #(
    parameter int SCREEN_W = 1280,
    parameter int SCREEN_H = 800,
    parameter int HUD_H = 32,
    parameter int HUD_TOP = 96,
    parameter int HUD_BOT = 0,
    // HUD icon layout (positions are absolute screen coordinates)
    parameter int HUD_PLAYER_ICON_W = 64,
    parameter int HUD_PLAYER_ICON_H = 64,
    parameter int HUD_SMALL_ICON_W = 16,
    parameter int HUD_SMALL_ICON_H = 16,
    parameter int HUD_TRACK_ICON_W = 8,
    parameter int HUD_TRACK_ICON_H = 8,
    localparam int HUD_PLAYER_ICON_W_LOG2 = $clog2(HUD_PLAYER_ICON_W),
    localparam int HUD_PLAYER_ICON_H_LOG2 = $clog2(HUD_PLAYER_ICON_H),
    localparam int HUD_SMALL_ICON_W_LOG2 = $clog2(HUD_SMALL_ICON_W),
    localparam int HUD_SMALL_ICON_H_LOG2 = $clog2(HUD_SMALL_ICON_H),
    localparam int HUD_TRACK_ICON_W_LOG2 = $clog2(HUD_TRACK_ICON_W),
    localparam int HUD_TRACK_ICON_H_LOG2 = $clog2(HUD_TRACK_ICON_H),
    localparam int HUD_PLAYER_ICON_ADDR_WIDTH = $clog2(HUD_PLAYER_ICON_W * HUD_PLAYER_ICON_H),
    localparam int HUD_SMALL_ICON_ADDR_WIDTH = $clog2(HUD_SMALL_ICON_W * HUD_SMALL_ICON_H),
    localparam int HUD_TRACK_TYPES = 2,  // owned / not owned
    localparam int HUD_TRACK_ICON_ADDR_WIDTH = $clog2(
        HUD_TRACK_TYPES * HUD_TRACK_ICON_W * HUD_TRACK_ICON_H
    ),
    localparam int HUD_TRACK_FRAME_OFFSET = HUD_TRACK_ICON_W * HUD_TRACK_ICON_H,
    localparam int HUD_P1_ICON_X = HUD_H,
    localparam int HUD_P1_ICON_Y = 14,
    localparam int HUD_BOMB_P1_ICON_X = HUD_P1_ICON_X + HUD_PLAYER_ICON_W + 8,
    localparam int HUD_BOMB_P1_ICON_Y = HUD_P1_ICON_Y,
    localparam int HUD_RANGE_P1_ICON_X = HUD_BOMB_P1_ICON_X,
    localparam int HUD_RANGE_P1_ICON_Y = HUD_BOMB_P1_ICON_Y + HUD_SMALL_ICON_H + 8,
    localparam int HUD_SPEED_P1_ICON_X = HUD_BOMB_P1_ICON_X,
    localparam int HUD_SPEED_P1_ICON_Y = HUD_RANGE_P1_ICON_Y + HUD_SMALL_ICON_H + 8,
    localparam int HUD_P1_TRACK_X_START = HUD_BOMB_P1_ICON_X + HUD_SMALL_ICON_W + 8,
    localparam int HUD_P1_TRACK_X_STEP = HUD_TRACK_ICON_W,
    localparam int HUD_P2_X_OFFSET = 1088,
    localparam int HUD_P2_ICON_X = HUD_P1_ICON_X + HUD_P2_X_OFFSET,
    localparam int HUD_P2_ICON_Y = HUD_P1_ICON_Y,
    localparam int HUD_BOMB_P2_ICON_X = HUD_BOMB_P1_ICON_X + HUD_P2_X_OFFSET,
    localparam int HUD_BOMB_P2_ICON_Y = HUD_BOMB_P1_ICON_Y,
    localparam int HUD_RANGE_P2_ICON_X = HUD_RANGE_P1_ICON_X + HUD_P2_X_OFFSET,
    localparam int HUD_RANGE_P2_ICON_Y = HUD_RANGE_P1_ICON_Y,
    localparam int HUD_SPEED_P2_ICON_X = HUD_SPEED_P1_ICON_X + HUD_P2_X_OFFSET,
    localparam int HUD_SPEED_P2_ICON_Y = HUD_SPEED_P1_ICON_Y,
    localparam int HUD_P2_TRACK_X_START = HUD_P1_TRACK_X_START + HUD_P2_X_OFFSET,
    localparam int HUD_P2_TRACK_X_STEP = HUD_P1_TRACK_X_STEP,
    localparam int HUD_P1_TRACK_Y_OFFSET = 4
) (
    input  logic        clk,
    input  logic [10:0] draw_x,
    input  logic [ 9:0] draw_y,
    input  logic [ 1:0] p1_bomb_level,
    input  logic [ 1:0] p1_range_level,
    input  logic [ 1:0] p1_speed_level,
    input  logic [ 1:0] p2_bomb_level,
    input  logic [ 1:0] p2_range_level,
    input  logic [ 1:0] p2_speed_level,
    output logic        hud_p1_icon_q,
    output logic        hud_p2_icon_q,
    output logic        hud_bomb_p1_q,
    output logic        hud_bomb_p2_q,
    output logic        hud_range_p1_q,
    output logic        hud_range_p2_q,
    output logic        hud_speed_p1_q,
    output logic        hud_speed_p2_q,
    output logic        hud_p1_track_hit_q,
    output logic        hud_p2_track_hit_q,
    output logic [11:0] hud_p1_icon_rgb_q,
    output logic [11:0] hud_p2_icon_rgb_q,
    output logic [11:0] hud_bomb_rgb_q,
    output logic [11:0] hud_range_rgb_q,
    output logic [11:0] hud_speed_rgb_q,
    output logic [11:0] hud_track_rgb_q
);

  localparam int HUD_P1_TRACK_X[0:2] = '{
      HUD_P1_TRACK_X_START,
      HUD_P1_TRACK_X_START + HUD_P1_TRACK_X_STEP,
      HUD_P1_TRACK_X_START + 2 * HUD_P1_TRACK_X_STEP
  };
  localparam int HUD_P1_TRACK_Y[0:2] = '{
      HUD_BOMB_P1_ICON_Y + HUD_P1_TRACK_Y_OFFSET,
      HUD_RANGE_P1_ICON_Y + HUD_P1_TRACK_Y_OFFSET,
      HUD_SPEED_P1_ICON_Y + HUD_P1_TRACK_Y_OFFSET
  };
  localparam int HUD_P2_TRACK_X[0:2] = '{
      HUD_P2_TRACK_X_START,
      HUD_P2_TRACK_X_START + HUD_P2_TRACK_X_STEP,
      HUD_P2_TRACK_X_START + 2 * HUD_P2_TRACK_X_STEP
  };
  localparam int HUD_P2_TRACK_Y[0:2] = '{
      HUD_BOMB_P2_ICON_Y + HUD_P1_TRACK_Y_OFFSET,
      HUD_RANGE_P2_ICON_Y + HUD_P1_TRACK_Y_OFFSET,
      HUD_SPEED_P2_ICON_Y + HUD_P1_TRACK_Y_OFFSET
  };

`ifdef SYNTHESIS
  localparam string HUD_P1_ICON_MEM_FILE = "player_1_icon.mem";
  localparam string HUD_P2_ICON_MEM_FILE = "player_2_icon.mem";
  localparam string HUD_BOMB_ICON_MEM_FILE = "bomb_icon.mem";
  localparam string HUD_RANGE_ICON_MEM_FILE = "range_icon.mem";
  localparam string HUD_SPEED_ICON_MEM_FILE = "speed_icon.mem";
  localparam string HUD_TRACK_MEM_FILE = "track.mem";
`else
  localparam string HUD_P1_ICON_MEM_FILE = "sprites/hud/mem/player_1_icon.mem";
  localparam string HUD_P2_ICON_MEM_FILE = "sprites/hud/mem/player_2_icon.mem";
  localparam string HUD_BOMB_ICON_MEM_FILE = "sprites/hud/mem/bomb_icon.mem";
  localparam string HUD_RANGE_ICON_MEM_FILE = "sprites/hud/mem/range_icon.mem";
  localparam string HUD_SPEED_ICON_MEM_FILE = "sprites/hud/mem/speed_icon.mem";
  localparam string HUD_TRACK_MEM_FILE = "sprites/hud/mem/track.mem";
`endif

  logic hud_p1_icon, hud_p2_icon, hud_bomb_p1, hud_bomb_p2, hud_range_p1, hud_range_p2;
  logic hud_speed_p1, hud_speed_p2;
  logic hud_p1_icon_q_int, hud_p2_icon_q_int, hud_bomb_p1_q_int, hud_bomb_p2_q_int;
  logic hud_range_p1_q_int, hud_range_p2_q_int, hud_speed_p1_q_int, hud_speed_p2_q_int;

  logic [HUD_PLAYER_ICON_W_LOG2-1:0] hud_p1_icon_local_x, hud_p2_icon_local_x;
  logic [HUD_PLAYER_ICON_H_LOG2-1:0] hud_p1_icon_local_y, hud_p2_icon_local_y;
  logic [HUD_SMALL_ICON_W_LOG2-1:0] hud_bomb_p1_local_x, hud_range_p1_local_x, hud_speed_p1_local_x;
  logic [HUD_SMALL_ICON_W_LOG2-1:0] hud_bomb_p2_local_x, hud_range_p2_local_x, hud_speed_p2_local_x;
  logic [HUD_SMALL_ICON_H_LOG2-1:0] hud_bomb_p1_local_y, hud_range_p1_local_y, hud_speed_p1_local_y;
  logic [HUD_SMALL_ICON_H_LOG2-1:0] hud_bomb_p2_local_y, hud_range_p2_local_y, hud_speed_p2_local_y;
  logic [HUD_PLAYER_ICON_ADDR_WIDTH-1:0] hud_p1_icon_addr, hud_p2_icon_addr;
  logic [HUD_SMALL_ICON_ADDR_WIDTH-1:0] hud_bomb_p1_addr, hud_range_p1_addr, hud_speed_p1_addr;
  logic [HUD_SMALL_ICON_ADDR_WIDTH-1:0] hud_bomb_p2_addr, hud_range_p2_addr, hud_speed_p2_addr;
  logic [HUD_SMALL_ICON_ADDR_WIDTH-1:0] hud_bomb_addr_mux, hud_range_addr_mux, hud_speed_addr_mux;
  logic [11:0] hud_p1_icon_rgb, hud_p2_icon_rgb;
  logic [11:0] hud_bomb_rgb, hud_range_rgb, hud_speed_rgb;

  logic hud_p1_track_active[0:2][0:2], hud_p2_track_active[0:2][0:2];
  logic [HUD_TRACK_ICON_W_LOG2-1:0] hud_p1_track_local_x[0:2][0:2];
  logic [HUD_TRACK_ICON_W_LOG2-1:0] hud_p2_track_local_x[0:2][0:2];
  logic [HUD_TRACK_ICON_H_LOG2-1:0] hud_p1_track_local_y[0:2][0:2];
  logic [HUD_TRACK_ICON_H_LOG2-1:0] hud_p2_track_local_y[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p1_track_addr[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p2_track_addr[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p1_track_offset[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p2_track_offset[0:2][0:2];
  logic hud_p1_track_hit, hud_p2_track_hit, hud_p1_track_hit_q_int, hud_p2_track_hit_q_int;
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p1_track_addr_mux, hud_p2_track_addr_mux;
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_track_addr_mux;
  logic [11:0] hud_track_rgb;

  // HUD hit helpers
  // Calculates whether draw_x/draw_y is inside a HUD element; also emits local coords for ROM addr.
  `define HUD_HIT(name, X0, Y0, W, H)                    \
  name = (draw_x >= (X0)) && (draw_x < (X0) + (W)) &&  \
         (draw_y >= (Y0)) && (draw_y < (Y0) + (H));    \
  name``_local_x = draw_x - (X0);                      \
  name``_local_y = draw_y - (Y0);

  always_comb begin
    `HUD_HIT(hud_p1_icon, HUD_P1_ICON_X, HUD_P1_ICON_Y, HUD_PLAYER_ICON_W, HUD_PLAYER_ICON_H)
    `HUD_HIT(hud_p2_icon, HUD_P2_ICON_X, HUD_P2_ICON_Y, HUD_PLAYER_ICON_W, HUD_PLAYER_ICON_H)
    `HUD_HIT(hud_bomb_p1, HUD_BOMB_P1_ICON_X, HUD_BOMB_P1_ICON_Y, HUD_SMALL_ICON_W,
             HUD_SMALL_ICON_H)
    `HUD_HIT(hud_bomb_p2, HUD_BOMB_P2_ICON_X, HUD_BOMB_P2_ICON_Y, HUD_SMALL_ICON_W,
             HUD_SMALL_ICON_H)
    `HUD_HIT(hud_range_p1, HUD_RANGE_P1_ICON_X, HUD_RANGE_P1_ICON_Y, HUD_SMALL_ICON_W,
             HUD_SMALL_ICON_H)
    `HUD_HIT(hud_range_p2, HUD_RANGE_P2_ICON_X, HUD_RANGE_P2_ICON_Y, HUD_SMALL_ICON_W,
             HUD_SMALL_ICON_H)
    `HUD_HIT(hud_speed_p1, HUD_SPEED_P1_ICON_X, HUD_SPEED_P1_ICON_Y, HUD_SMALL_ICON_W,
             HUD_SMALL_ICON_H)
    `HUD_HIT(hud_speed_p2, HUD_SPEED_P2_ICON_X, HUD_SPEED_P2_ICON_Y, HUD_SMALL_ICON_W,
             HUD_SMALL_ICON_H)

    for (int item = HUD_ITEM_BOMB; item <= HUD_ITEM_SPEED; item++) begin
      int level_p1;
      int level_p2;

      unique case (item)
        HUD_ITEM_BOMB: begin
          level_p1 = p1_bomb_level;
          level_p2 = p2_bomb_level;
        end
        HUD_ITEM_RANGE: begin
          level_p1 = p1_range_level;
          level_p2 = p2_range_level;
        end
        HUD_ITEM_SPEED: begin
          level_p1 = p1_speed_level;
          level_p2 = p2_speed_level;
        end
        default: begin
          level_p1 = 0;
          level_p2 = 0;
        end
      endcase

      if (level_p1 > 3) level_p1 = 3;
      if (level_p2 > 3) level_p2 = 3;

      for (int slot = 0; slot < 3; slot++) begin
        // slot < level_* selects the "owned" frame (offset into sprite_rom)
        hud_p1_track_offset[item][slot] = (slot < level_p1) ? HUD_TRACK_FRAME_OFFSET : '0;
        hud_p2_track_offset[item][slot] = (slot < level_p2) ? HUD_TRACK_FRAME_OFFSET : '0;
      end
    end

    hud_p1_track_hit      = 1'b0;
    hud_p1_track_addr_mux = '0;
    hud_p2_track_hit      = 1'b0;
    hud_p2_track_addr_mux = '0;

    for (int item = HUD_ITEM_BOMB; item <= HUD_ITEM_SPEED; item++) begin
      for (int slot = 0; slot < 3; slot++) begin
        hud_p1_track_active[item][slot] =
            (draw_x >= HUD_P1_TRACK_X[slot]) &&
            (draw_x < HUD_P1_TRACK_X[slot] + HUD_TRACK_ICON_W) &&
            (draw_y >= HUD_P1_TRACK_Y[item]) &&
            (draw_y < HUD_P1_TRACK_Y[item] + HUD_TRACK_ICON_H);
        hud_p1_track_local_x[item][slot] = draw_x - HUD_P1_TRACK_X[slot];
        hud_p1_track_local_y[item][slot] = draw_y - HUD_P1_TRACK_Y[item];
        hud_p1_track_addr[item][slot]    = { hud_p1_track_local_y[item][slot],
                                             hud_p1_track_local_x[item][slot]} +
                                             hud_p1_track_offset[item][slot];

        if (hud_p1_track_active[item][slot]) begin
          hud_p1_track_hit      = 1'b1;
          // Only one icon can be active per pixel; last match wins but is deterministic.
          hud_p1_track_addr_mux = hud_p1_track_addr[item][slot];
        end
      end
    end

    for (int item = HUD_ITEM_BOMB; item <= HUD_ITEM_SPEED; item++) begin
      for (int slot = 0; slot < 3; slot++) begin
        hud_p2_track_active[item][slot] =
            (draw_x >= HUD_P2_TRACK_X[slot]) &&
            (draw_x < HUD_P2_TRACK_X[slot] + HUD_TRACK_ICON_W) &&
            (draw_y >= HUD_P2_TRACK_Y[item]) &&
            (draw_y < HUD_P2_TRACK_Y[item] + HUD_TRACK_ICON_H);
        hud_p2_track_local_x[item][slot] = draw_x - HUD_P2_TRACK_X[slot];
        hud_p2_track_local_y[item][slot] = draw_y - HUD_P2_TRACK_Y[item];
        hud_p2_track_addr[item][slot]    = { hud_p2_track_local_y[item][slot],
                                             hud_p2_track_local_x[item][slot]} +
                                             hud_p2_track_offset[item][slot];

        if (hud_p2_track_active[item][slot]) begin
          hud_p2_track_hit      = 1'b1;
          // Mirrors P1 logic for right-side HUD.
          hud_p2_track_addr_mux = hud_p2_track_addr[item][slot];
        end
      end
    end

    hud_bomb_addr_mux  = hud_bomb_p1_addr;
    hud_range_addr_mux = hud_range_p1_addr;
    hud_speed_addr_mux = hud_speed_p1_addr;
    hud_track_addr_mux = hud_p1_track_addr_mux;

    if (hud_bomb_p2) hud_bomb_addr_mux = hud_bomb_p2_addr;
    if (hud_range_p2) hud_range_addr_mux = hud_range_p2_addr;
    if (hud_speed_p2) hud_speed_addr_mux = hud_speed_p2_addr;
    if (hud_p2_track_hit) hud_track_addr_mux = hud_p2_track_addr_mux;
  end

  assign hud_p1_icon_addr  = {hud_p1_icon_local_y, hud_p1_icon_local_x};
  assign hud_p2_icon_addr  = {hud_p2_icon_local_y, hud_p2_icon_local_x};
  assign hud_bomb_p1_addr  = {hud_bomb_p1_local_y, hud_bomb_p1_local_x};
  assign hud_bomb_p2_addr  = {hud_bomb_p2_local_y, hud_bomb_p2_local_x};
  assign hud_range_p1_addr = {hud_range_p1_local_y, hud_range_p1_local_x};
  assign hud_range_p2_addr = {hud_range_p2_local_y, hud_range_p2_local_x};
  assign hud_speed_p1_addr = {hud_speed_p1_local_y, hud_speed_p1_local_x};
  assign hud_speed_p2_addr = {hud_speed_p2_local_y, hud_speed_p2_local_x};

  sprite_rom #(
      .SPRITE_W     (HUD_PLAYER_ICON_W),
      .SPRITE_H     (HUD_PLAYER_ICON_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(HUD_P1_ICON_MEM_FILE)
  ) hud_p1_icon_i (
      .clk (clk),
      .addr(hud_p1_icon_addr),
      .data(hud_p1_icon_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (HUD_PLAYER_ICON_W),
      .SPRITE_H     (HUD_PLAYER_ICON_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(HUD_P2_ICON_MEM_FILE)
  ) hud_p2_icon_i (
      .clk (clk),
      .addr(hud_p2_icon_addr),
      .data(hud_p2_icon_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (HUD_SMALL_ICON_W),
      .SPRITE_H     (HUD_SMALL_ICON_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(HUD_BOMB_ICON_MEM_FILE)
  ) hud_bomb_icon_i (
      .clk (clk),
      .addr(hud_bomb_addr_mux),
      .data(hud_bomb_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (HUD_SMALL_ICON_W),
      .SPRITE_H     (HUD_SMALL_ICON_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(HUD_RANGE_ICON_MEM_FILE)
  ) hud_range_icon_i (
      .clk (clk),
      .addr(hud_range_addr_mux),
      .data(hud_range_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (HUD_SMALL_ICON_W),
      .SPRITE_H     (HUD_SMALL_ICON_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(HUD_SPEED_ICON_MEM_FILE)
  ) hud_speed_icon_i (
      .clk (clk),
      .addr(hud_speed_addr_mux),
      .data(hud_speed_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (HUD_TRACK_ICON_W),
      .SPRITE_H     (HUD_TRACK_ICON_H),
      .NUM_FRAMES   (HUD_TRACK_TYPES),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(HUD_TRACK_MEM_FILE)
  ) hud_track_i (
      .clk (clk),
      .addr(hud_track_addr_mux),
      .data(hud_track_rgb)
  );

  always_ff @(posedge clk) begin
    // Register hit flags and sampled RGB to align with synchronous sprite_rom outputs.
    hud_p1_icon_q_int      <= hud_p1_icon;
    hud_p2_icon_q_int      <= hud_p2_icon;
    hud_bomb_p1_q_int      <= hud_bomb_p1;
    hud_bomb_p2_q_int      <= hud_bomb_p2;
    hud_range_p1_q_int     <= hud_range_p1;
    hud_range_p2_q_int     <= hud_range_p2;
    hud_speed_p1_q_int     <= hud_speed_p1;
    hud_speed_p2_q_int     <= hud_speed_p2;
    hud_p1_track_hit_q_int <= hud_p1_track_hit;
    hud_p2_track_hit_q_int <= hud_p2_track_hit;
    hud_p1_icon_rgb_q      <= hud_p1_icon_rgb;
    hud_p2_icon_rgb_q      <= hud_p2_icon_rgb;
    hud_bomb_rgb_q         <= hud_bomb_rgb;
    hud_range_rgb_q        <= hud_range_rgb;
    hud_speed_rgb_q        <= hud_speed_rgb;
    hud_track_rgb_q        <= hud_track_rgb;
  end

  assign hud_p1_icon_q      = hud_p1_icon_q_int;
  assign hud_p2_icon_q      = hud_p2_icon_q_int;
  assign hud_bomb_p1_q      = hud_bomb_p1_q_int;
  assign hud_bomb_p2_q      = hud_bomb_p2_q_int;
  assign hud_range_p1_q     = hud_range_p1_q_int;
  assign hud_range_p2_q     = hud_range_p2_q_int;
  assign hud_speed_p1_q     = hud_speed_p1_q_int;
  assign hud_speed_p2_q     = hud_speed_p2_q_int;
  assign hud_p1_track_hit_q = hud_p1_track_hit_q_int;
  assign hud_p2_track_hit_q = hud_p2_track_hit_q_int;

endmodule
