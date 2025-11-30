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
 *  - HUD_H         : Horizontal border thickness (left/right)
 *  - HUD_TOP/BOT   : Top / bottom hud offsets
 *  - BLK_W/H       : Block width / height in pixels (power of 2)
 *  - SPRITE_W/H    : Sprite width / height
 *  - HUD_*         : HUD color (4-bit each)
 *  - BG_*          : Background color (4-bit each)
 */
module drawcon #(
    parameter             MAP_MEM_WIDTH = 2,     // this is $clog2(number of map states).
    parameter             NUM_ROW       = 11,
    parameter             NUM_COL       = 19,
    parameter             SCREEN_W      = 1280,
    parameter             SCREEN_H      = 800,
    parameter             HUD_H         = 32,    // border thickness (left/right)
    parameter             HUD_TOP       = 96,
    parameter             HUD_BOT       = 0,
    parameter             BLK_W         = 64,    // should be power of 2
    parameter             BLK_H         = 64,    // should be power of 2
    parameter             SPRITE_W      = 32,
    parameter             SPRITE_H      = 48,
    parameter logic [3:0] HUD_R         = 4'h0,
                          HUD_G         = 4'h0,
                          HUD_B         = 4'h0,
    parameter logic [3:0] BG_R          = 4'h1,
                          BG_G          = 4'h7,
                          BG_B          = 4'h3,

    // Derived parameters (not overridable)
    localparam DEPTH           = NUM_COL * NUM_ROW,
    localparam MAP_ADDR_WIDTH  = $clog2(DEPTH),          // bit-width of map_addr output
    localparam BLK_W_LOG2      = $clog2(BLK_W),
    localparam BLK_H_LOG2      = $clog2(BLK_H),
    localparam BLK_ADDR_WIDTH  = $clog2(BLK_W * BLK_H),
    localparam TRANSPARENCY    = 12'hF0F,
    localparam P_UP_ANIM_COLOR = 12'h0E0

) (
    // Map Memory block state input
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      tick,
    input  logic [ MAP_MEM_WIDTH-1:0] map_tile_state,
    input  logic [              10:0] draw_x,
    input  logic [               9:0] draw_y,
    input  logic [              10:0] player_1_x,
    input  logic [               9:0] player_1_y,
    input  dir_t                      player_1_dir,
    input  logic [              10:0] player_2_x,
    input  logic [               9:0] player_2_y,
    input  dir_t                      player_2_dir,
    input  logic                      explode_signal,
    explode_signal_2,
    input  logic [MAP_ADDR_WIDTH-1:0] explosion_addr,
    explosion_addr_2,
    input  logic [MAP_ADDR_WIDTH-1:0] item_addr     [0:2],
    input  logic                      item_active   [0:2],
    // Upgrade levels: 0..3 for each item type
    input  logic [               1:0] p1_bomb_level,
    input  logic [               1:0] p1_range_level,
    input  logic [               1:0] p1_speed_level,
    input  logic [               1:0] p2_bomb_level,
    input  logic [               1:0] p2_range_level,
    input  logic [               1:0] p2_speed_level,
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
  localparam int BOMB_ANIM_TIME = 20;  // hold each frame for 20 ticks

  localparam int DEST_FRAMES = 6;
  localparam int DEST_SPRITE_SIZE = BLK_W * BLK_H;
  localparam int DEST_SPRITE_ROM_DEPTH = DEST_FRAMES * DEST_SPRITE_SIZE;
  localparam int DEST_SPRITE_ADDR_WIDTH = $clog2(DEST_SPRITE_ROM_DEPTH);
  localparam int DEST_TOTAL_ANIMATION_TIME = 60;  // 1 second at 60 fps
  localparam int DEST_FRAME_TIME = DEST_TOTAL_ANIMATION_TIME / DEST_FRAMES;

  localparam int EXPL_FRAMES = 6;
  localparam int EXPL_SPRITE_SIZE = BLK_W * BLK_H;
  localparam int EXPL_SPRITE_ROM_DEPTH = EXPL_FRAMES * EXPL_SPRITE_SIZE;
  localparam int EXPL_SPRITE_ADDR_WIDTH = $clog2(EXPL_SPRITE_ROM_DEPTH);
  localparam int EXPL_TOTAL_ANIMATION_TIME = 60;  // 1 second at 60 fps
  localparam int EXPL_FRAME_TIME = EXPL_TOTAL_ANIMATION_TIME / EXPL_FRAMES;

  localparam int P_UP_FRAMES = 2;
  localparam int P_UP_SPRITE_SIZE = BLK_W * BLK_H;
  localparam int P_UP_SPRITE_ADDR_WIDTH = $clog2(P_UP_SPRITE_SIZE);
  localparam int P_UP_FRAME_TIME = 30;  // switch frame every 30 ticks
  localparam int P_UP_BORDER_SIZE = 4;  // pixels

  // HUD icon layout (positions are absolute screen coordinates)
  localparam int HUD_PLAYER_ICON_W = 64;
  localparam int HUD_PLAYER_ICON_H = 64;
  localparam int HUD_SMALL_ICON_W = 16;
  localparam int HUD_SMALL_ICON_H = 16;
  localparam int HUD_TRACK_ICON_W = 8;
  localparam int HUD_TRACK_ICON_H = 8;
  localparam int HUD_PLAYER_ICON_W_LOG2 = $clog2(HUD_PLAYER_ICON_W);
  localparam int HUD_PLAYER_ICON_H_LOG2 = $clog2(HUD_PLAYER_ICON_H);
  localparam int HUD_SMALL_ICON_W_LOG2 = $clog2(HUD_SMALL_ICON_W);
  localparam int HUD_SMALL_ICON_H_LOG2 = $clog2(HUD_SMALL_ICON_H);
  localparam int HUD_TRACK_ICON_W_LOG2 = $clog2(HUD_TRACK_ICON_W);
  localparam int HUD_TRACK_ICON_H_LOG2 = $clog2(HUD_TRACK_ICON_H);
  localparam int HUD_PLAYER_ICON_ADDR_WIDTH = $clog2(HUD_PLAYER_ICON_W * HUD_PLAYER_ICON_H);
  localparam int HUD_SMALL_ICON_ADDR_WIDTH = $clog2(HUD_SMALL_ICON_W * HUD_SMALL_ICON_H);
  localparam int HUD_TRACK_TYPES = 2;  // owned / not owned
  localparam int HUD_TRACK_ICON_ADDR_WIDTH = $clog2(
      HUD_TRACK_TYPES * HUD_TRACK_ICON_W * HUD_TRACK_ICON_H
  );
  localparam int HUD_TRACK_FRAME_OFFSET = HUD_TRACK_ICON_W * HUD_TRACK_ICON_H;  // 64 entries per frame

  localparam int HUD_P1_ICON_X = HUD_H;
  localparam int HUD_P1_ICON_Y = 14;
  localparam int HUD_BOMB_P1_ICON_X = HUD_P1_ICON_X + HUD_PLAYER_ICON_W + 8;
  localparam int HUD_BOMB_P1_ICON_Y = HUD_P1_ICON_Y;
  localparam int HUD_RANGE_P1_ICON_X = HUD_BOMB_P1_ICON_X;
  localparam int HUD_RANGE_P1_ICON_Y = HUD_BOMB_P1_ICON_Y + HUD_SMALL_ICON_H + 8;
  localparam int HUD_SPEED_P1_ICON_X = HUD_BOMB_P1_ICON_X;
  localparam int HUD_SPEED_P1_ICON_Y = HUD_RANGE_P1_ICON_Y + HUD_SMALL_ICON_H + 8;
  // Track icons: three 8x8 slots per upgrade. Each track sprite has two frames:
  // frame 0 = not owned, frame 1 = owned.
  localparam int HUD_P1_TRACK_X_START = HUD_BOMB_P1_ICON_X + HUD_SMALL_ICON_W + 8;
  localparam int HUD_P1_TRACK_X_STEP = HUD_TRACK_ICON_W;
  localparam int HUD_P1_TRACK_X[0:2] = '{
      HUD_P1_TRACK_X_START,
      HUD_P1_TRACK_X_START + HUD_P1_TRACK_X_STEP,
      HUD_P1_TRACK_X_START + 2 * HUD_P1_TRACK_X_STEP
  };
  localparam int HUD_P1_TRACK_Y_OFFSET = 4;
  localparam int HUD_P1_TRACK_Y[0:2] = '{
      HUD_BOMB_P1_ICON_Y + HUD_P1_TRACK_Y_OFFSET,
      HUD_RANGE_P1_ICON_Y + HUD_P1_TRACK_Y_OFFSET,
      HUD_SPEED_P1_ICON_Y + HUD_P1_TRACK_Y_OFFSET
  };
  typedef enum int {
    HUD_ITEM_BOMB  = 0,
    HUD_ITEM_RANGE = 1,
    HUD_ITEM_SPEED = 2
  } hud_item_t;

  // Player 2 HUD uses the same layout shifted to the right.
  localparam int HUD_P2_X_OFFSET = 1088;
  localparam int HUD_P2_ICON_X = HUD_P1_ICON_X + HUD_P2_X_OFFSET;
  localparam int HUD_P2_ICON_Y = HUD_P1_ICON_Y;
  localparam int HUD_BOMB_P2_ICON_X = HUD_BOMB_P1_ICON_X + HUD_P2_X_OFFSET;
  localparam int HUD_BOMB_P2_ICON_Y = HUD_BOMB_P1_ICON_Y;
  localparam int HUD_RANGE_P2_ICON_X = HUD_RANGE_P1_ICON_X + HUD_P2_X_OFFSET;
  localparam int HUD_RANGE_P2_ICON_Y = HUD_RANGE_P1_ICON_Y;
  localparam int HUD_SPEED_P2_ICON_X = HUD_SPEED_P1_ICON_X + HUD_P2_X_OFFSET;
  localparam int HUD_SPEED_P2_ICON_Y = HUD_SPEED_P1_ICON_Y;
  localparam int HUD_P2_TRACK_X_START = HUD_P1_TRACK_X_START + HUD_P2_X_OFFSET;
  localparam int HUD_P2_TRACK_X_STEP = HUD_P1_TRACK_X_STEP;
  localparam int HUD_P2_TRACK_X[0:2] = '{
      HUD_P2_TRACK_X_START,
      HUD_P2_TRACK_X_START + HUD_P2_TRACK_X_STEP,
      HUD_P2_TRACK_X_START + 2 * HUD_P2_TRACK_X_STEP
  };
  localparam int HUD_P2_TRACK_Y_OFFSET = HUD_P1_TRACK_Y_OFFSET;
  localparam int HUD_P2_TRACK_Y[0:2] = '{
      HUD_BOMB_P2_ICON_Y + HUD_P2_TRACK_Y_OFFSET,
      HUD_RANGE_P2_ICON_Y + HUD_P2_TRACK_Y_OFFSET,
      HUD_SPEED_P2_ICON_Y + HUD_P2_TRACK_Y_OFFSET
  };

  // ---------------------------------------------------------------------------
  // Animation driver (runs a counter to select animation frame)
  // ---------------------------------------------------------------------------
  logic [5:0] frame_cnt;  // fame counter to 60 fps
  logic [1:0] walk_frame_1;  // ranges 0,1,2
  logic [1:0] walk_frame_2;  // ranges 0,1,2
  logic [5:0] dest_frame_cnt;
  logic [2:0] dest_frame;  // ranges 0..5
  logic [7:0] bomb_frame_cnt;
  logic [2:0] bomb_frame;
  logic       p_up_frame;
  always_ff @(posedge clk) begin
    if (rst) begin
      frame_cnt <= 6'd0;
      walk_frame_1 <= 2'd0;
      walk_frame_2 <= 2'd0;
      dest_frame_cnt <= 6'd0;
      dest_frame <= 3'd0;
      bomb_frame_cnt <= 8'd0;
      bomb_frame <= 3'd0;
      p_up_frame <= 1'b0;
    end else if (tick) begin
      frame_cnt <= frame_cnt + 1;
      if (frame_cnt == 6'd59) frame_cnt <= 0;

      if (player_1_dir != DIR_NONE) begin
        if ((frame_cnt + 1) % WALK_ANIM_TIME == 0) begin
          walk_frame_1 <= walk_frame_1 + 1;
          if (walk_frame_1 == WALK_FRAMES_PER_DIR - 1) walk_frame_1 <= 0;
        end
      end

      if (player_2_dir != DIR_NONE) begin
        if ((frame_cnt + 1) % WALK_ANIM_TIME == 0) begin
          walk_frame_2 <= walk_frame_2 + 1;
          if (walk_frame_2 == WALK_FRAMES_PER_DIR - 1) walk_frame_2 <= 0;
        end
      end

      if (explode_signal || explode_signal_2) begin
        dest_frame_cnt <= dest_frame_cnt + 1;
        if ((dest_frame_cnt + 1) % DEST_FRAME_TIME == 0) dest_frame <= dest_frame + 1;
        if (dest_frame_cnt == 6'd59) begin
          dest_frame_cnt <= 6'd0;
          dest_frame <= 3'd0;
        end
      end else begin
        dest_frame_cnt <= 6'd0;
        dest_frame <= 3'd0;
      end

      p_up_frame <= (frame_cnt < P_UP_FRAME_TIME) ? 1'b0 : 1'b1;

      bomb_frame_cnt <= (bomb_frame_cnt == BOMB_TOTAL_ANIMATION_TIME - 1) ?
                        8'd0 : bomb_frame_cnt + 1;

      // Bomb animation: frames 0-2 repeat every 20 ticks for the first 120 ticks,
      // then frames 3-5 for the last 60 ticks (one every 20).
      unique case (bomb_frame_cnt / BOMB_ANIM_TIME)
        4'd0, 4'd3: bomb_frame <= 3'd0;
        4'd1, 4'd4: bomb_frame <= 3'd1;
        4'd2, 4'd5: bomb_frame <= 3'd2;
        4'd6:       bomb_frame <= 3'd3;
        4'd7:       bomb_frame <= 3'd4;
        4'd8:       bomb_frame <= 3'd5;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Player sprite addressing
  // ---------------------------------------------------------------------------
  // Sprite ROM interface signals
  logic [WALK_SPRITE_ADDR_WIDTH-1:0] player_1_sprite_addr;
  logic [WALK_SPRITE_ADDR_WIDTH-1:0] player_2_sprite_addr;
  logic [                      11:0] player_1_sprite_rgb_raw;
  logic [                      11:0] player_2_sprite_rgb_raw;
  logic [                      11:0] player_1_sprite_rgb_q;
  logic [                      11:0] player_2_sprite_rgb_q;
  // Sprite position and bounds checking
  logic player_1_sprite, player_2_sprite;
  logic player_1_sprite_q, player_2_sprite_q;
  logic [         $clog2(SPRITE_W)-1:0] player_1_sprite_local_x;
  logic [         $clog2(SPRITE_H)-1:0] player_1_sprite_local_y;
  logic [         $clog2(SPRITE_W)-1:0] player_2_sprite_local_x;
  logic [         $clog2(SPRITE_H)-1:0] player_2_sprite_local_y;
  // Sprite frame selection
  logic [         $clog2(SPRITE_W)-1:0] player_1_sprite_x_in_rom;
  logic [         $clog2(SPRITE_W)-1:0] player_2_sprite_x_in_rom;
  logic [$clog2(WALK_FRAMES_TOTAL)-1:0] player_1_sprite_offset;
  logic [$clog2(WALK_FRAMES_TOTAL)-1:0] player_2_sprite_offset;

  logic [           MAP_ADDR_WIDTH-1:0] addr_next;

  // Determine if current pixel is within player sprite bounds and
  // which sprite frame to use based on player direction and animation frame
  always_comb begin
    player_1_sprite_offset = '0;
    player_2_sprite_offset = '0;
    player_1_sprite_local_x = draw_x - player_1_x;
    player_1_sprite_local_y = draw_y - player_1_y;
    player_2_sprite_local_x = draw_x - player_2_x;
    player_2_sprite_local_y = draw_y - player_2_y;
    player_1_sprite = (draw_x >= player_1_x) && (draw_x < player_1_x + SPRITE_W) &&
                      (draw_y >= player_1_y) && (draw_y < player_1_y + SPRITE_H);
    player_2_sprite = (draw_x >= player_2_x) && (draw_x < player_2_x + SPRITE_W) &&
                      (draw_y >= player_2_y) && (draw_y < player_2_y + SPRITE_H);

    case (dir_t'(player_1_dir))
      DIR_DOWN:  player_1_sprite_offset = 0*WALK_FRAMES_PER_DIR + walk_frame_1; // 0..2
      DIR_LEFT:  player_1_sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame_1; // 3..5
      DIR_RIGHT: player_1_sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame_1; // 3..5
      DIR_UP:    player_1_sprite_offset = 2*WALK_FRAMES_PER_DIR + walk_frame_1; // 6..8
    endcase

    case (dir_t'(player_2_dir))
      DIR_DOWN:  player_2_sprite_offset = 0*WALK_FRAMES_PER_DIR + walk_frame_2; // 0..2
      DIR_LEFT:  player_2_sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame_2; // 3..5
      DIR_RIGHT: player_2_sprite_offset = 1*WALK_FRAMES_PER_DIR + walk_frame_2; // 3..5
      DIR_UP:    player_2_sprite_offset = 2*WALK_FRAMES_PER_DIR + walk_frame_2; // 6..8
    endcase
  end

  // If facing left, flip the right sprite horizontaly
  assign player_1_sprite_x_in_rom = (player_1_dir == DIR_LEFT) ?
                                    (SPRITE_W - 1 - player_1_sprite_local_x) :
                                    player_1_sprite_local_x;
  assign player_2_sprite_x_in_rom = (player_2_dir == DIR_LEFT) ?
                                    (SPRITE_W - 1 - player_2_sprite_local_x) :
                                    player_2_sprite_local_x;
  // Calculate final sprite ROM address also in correlation to frame offset
  assign player_1_sprite_addr = player_1_sprite ?
                                (player_1_sprite_offset * WALK_SPRITE_SIZE +
                                player_1_sprite_local_y * SPRITE_W + player_1_sprite_x_in_rom) :
                                '0;
  assign player_2_sprite_addr = player_2_sprite ?
                                (player_2_sprite_offset * WALK_SPRITE_SIZE +
                                player_2_sprite_local_y * SPRITE_W + player_2_sprite_x_in_rom) :
                                '0;

  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .NUM_FRAMES   (WALK_FRAMES_TOTAL),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("player_1.mem")      // 9-frame sheet: DOWN,LR,UP cropped to 32x48
  ) bomberman_1_sprite_i (
      .clk (clk),
      .addr(player_1_sprite_addr),
      .data(player_1_sprite_rgb_raw)
  );

  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .NUM_FRAMES   (WALK_FRAMES_TOTAL),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("player_2.mem")      // mirrored structure for player 2
  ) bomberman_2_sprite_i (
      .clk (clk),
      .addr(player_2_sprite_addr),
      .data(player_2_sprite_rgb_raw)
  );

  // ---------------------------------------------------------------------------
  // Static blocks, block destruction, explosion and power ups sprite addressing
  // ---------------------------------------------------------------------------
  logic [BLK_W_LOG2-1:0] perm_blk_local_x, perm_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] perm_blk_local_y, perm_blk_local_y_q;
  logic [BLK_W_LOG2-1:0] dest_blk_local_x, dest_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] dest_blk_local_y, dest_blk_local_y_q;
  logic [BLK_W_LOG2-1:0] explode_local_x, explode_local_x_q;
  logic [BLK_H_LOG2-1:0] explode_local_y, explode_local_y_q;
  logic [BLK_W_LOG2-1:0] bomb_local_x, bomb_local_x_q;
  logic [BLK_H_LOG2-1:0] bomb_local_y, bomb_local_y_q;
  logic [BLK_W_LOG2-1:0] p_up_speed_local_x, p_up_speed_local_x_q;
  logic [BLK_H_LOG2-1:0] p_up_speed_local_y, p_up_speed_local_y_q;
  logic [BLK_W_LOG2-1:0] p_up_bomb_local_x, p_up_bomb_local_x_q;
  logic [BLK_H_LOG2-1:0] p_up_bomb_local_y, p_up_bomb_local_y_q;
  logic [BLK_W_LOG2-1:0] p_up_range_local_x, p_up_range_local_x_q;
  logic [BLK_H_LOG2-1:0] p_up_range_local_y, p_up_range_local_y_q;

  // HUD icon addressing helpers
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
  logic [11:0] hud_p1_icon_rgb_q, hud_p2_icon_rgb_q;
  logic [11:0] hud_bomb_rgb_q, hud_range_rgb_q, hud_speed_rgb_q;
  logic hud_p1_icon, hud_bomb_p1, hud_range_p1, hud_speed_p1;
  logic hud_p2_icon, hud_bomb_p2, hud_range_p2, hud_speed_p2;
  logic hud_p1_icon_q, hud_bomb_p1_q, hud_range_p1_q, hud_speed_p1_q;
  logic hud_p2_icon_q, hud_bomb_p2_q, hud_range_p2_q, hud_speed_p2_q;
  logic hud_p1_track_active[0:2][0:2], hud_p2_track_active[0:2][0:2];
  logic [HUD_TRACK_ICON_W_LOG2-1:0] hud_p1_track_local_x[0:2][0:2];
  logic [HUD_TRACK_ICON_W_LOG2-1:0] hud_p2_track_local_x[0:2][0:2];
  logic [HUD_TRACK_ICON_H_LOG2-1:0] hud_p1_track_local_y[0:2][0:2];
  logic [HUD_TRACK_ICON_H_LOG2-1:0] hud_p2_track_local_y[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p1_track_addr[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p2_track_addr[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p1_track_offset[0:2][0:2];
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p2_track_offset[0:2][0:2];
  logic hud_p1_track_hit, hud_p2_track_hit, hud_p1_track_hit_q, hud_p2_track_hit_q;
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_p1_track_addr_mux, hud_p2_track_addr_mux;
  logic [HUD_TRACK_ICON_ADDR_WIDTH-1:0] hud_track_addr_mux;
  logic [11:0] hud_track_rgb, hud_track_rgb_q;

  // Animation outputs also have a "_q" version to line up with the pipelined logic
  // that selects the correct block based on map state. Powerups are exceptions since
  // the animation change is driven by a change in border color while the
  // sprite ROM is static
  logic [        BLK_ADDR_WIDTH-1:0] perm_blk_addr;
  logic [                      11:0] perm_blk_rgb;
  logic [        BLK_ADDR_WIDTH-1:0] dest_blk_addr;
  logic [                      11:0] dest_blk_rgb;
  logic [P_UP_SPRITE_ADDR_WIDTH-1:0] p_up_speed_sprite_addr;
  logic [                      11:0] p_up_speed_sprite_rgb;
  logic [P_UP_SPRITE_ADDR_WIDTH-1:0] p_up_bomb_sprite_addr;
  logic [                      11:0] p_up_bomb_sprite_rgb;
  logic [P_UP_SPRITE_ADDR_WIDTH-1:0] p_up_range_sprite_addr;
  logic [                      11:0] p_up_range_sprite_rgb;
  logic [EXPL_SPRITE_ADDR_WIDTH-1:0] explode_sprite_addr;
  logic [                      11:0] explode_sprite_rgb;
  logic [                      11:0] explode_sprite_rgb_q;
  logic [BOMB_SPRITE_ADDR_WIDTH-1:0] bomb_sprite_addr;
  logic [                      11:0] bomb_sprite_rgb;
  logic [                      11:0] bomb_sprite_rgb_q;
  logic [DEST_SPRITE_ADDR_WIDTH-1:0] dest_blk_anim_addr;
  logic [                      11:0] dest_blk_anim_rgb;
  logic [                      11:0] dest_blk_anim_rgb_q;

  // Select animation frame + local pixel within the 64x64 block
  assign dest_blk_anim_addr  = {dest_frame, dest_blk_local_y_q, dest_blk_local_x_q};
  assign explode_sprite_addr = {dest_frame, explode_local_y_q, explode_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (DEST_FRAMES),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("dest_blk_anim.mem")
  ) dest_blk_anim_i (
      .clk (clk),
      .addr(dest_blk_anim_addr),
      .data(dest_blk_anim_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (EXPL_FRAMES),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("explosion.mem")
  ) explosion_sprite_i (
      .clk (clk),
      .addr(explode_sprite_addr),
      .data(explode_sprite_rgb)
  );

  // ---------------------------------------------------------------------------
  // HUD icons
  // ---------------------------------------------------------------------------
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

    // Drive track offsets from upgrade levels (0..3).
    // Slots below the current level show the owned frame, the rest stay on frame 0.
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
        hud_p1_track_offset[item][slot] = (slot < level_p1) ? HUD_TRACK_FRAME_OFFSET : '0;
        hud_p2_track_offset[item][slot] = (slot < level_p2) ? HUD_TRACK_FRAME_OFFSET : '0;
      end
    end

    hud_p1_track_hit = 1'b0;
    hud_p1_track_addr_mux = '0;
    hud_p2_track_hit = 1'b0;
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
        hud_p1_track_addr[item][slot] = { hud_p1_track_local_y[item][slot],
                                          hud_p1_track_local_x[item][slot]} +
                                          hud_p1_track_offset[item][slot];

        if (hud_p1_track_active[item][slot]) begin
          hud_p1_track_hit = 1'b1;
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
        hud_p2_track_addr[item][slot] = { hud_p2_track_local_y[item][slot],
                                          hud_p2_track_local_x[item][slot]} +
                                          hud_p2_track_offset[item][slot];

        if (hud_p2_track_active[item][slot]) begin
          hud_p2_track_hit = 1'b1;
          hud_p2_track_addr_mux = hud_p2_track_addr[item][slot];
        end
      end
    end

    // Select the HUD sprite address to feed the shared ROMs
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
      .MEM_INIT_FILE("player_1_icon.mem")
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
      .MEM_INIT_FILE("player_2_icon.mem")
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
      .MEM_INIT_FILE("bomb_icon.mem")
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
      .MEM_INIT_FILE("range_icon.mem")
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
      .MEM_INIT_FILE("speed_icon.mem")
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
      .MEM_INIT_FILE("track.mem")
  ) hud_track_i (
      .clk (clk),
      .addr(hud_track_addr_mux),
      .data(hud_track_rgb)
  );

  // ---------------------------------------------------------------------------
  // Map region detection
  // ---------------------------------------------------------------------------
  logic out_of_map;
  logic out_of_map_q;
  always_comb begin
    out_of_map = (draw_x < HUD_H)               ||
                 (draw_x >= SCREEN_W - HUD_H)   ||
                 (draw_y < HUD_TOP)             ||
                 (draw_y >= SCREEN_H - HUD_BOT);
  end

  map_state_t st;
  map_state_t st_q;
  assign st = map_state_t'(map_tile_state);

  // Function to check if the draw block is exploding
  function logic is_exploding(input logic [MAP_ADDR_WIDTH-1:0] blk_addr,
                              input logic [MAP_ADDR_WIDTH-1:0] exp);
    return ((blk_addr == exp)          ||
           (blk_addr == exp - NUM_COL) ||
           (blk_addr == exp + NUM_COL) ||
           (blk_addr == exp - 1)       ||
           (blk_addr == exp + 1));
  endfunction

  // Function to check if the draw block is within the power-up border
  function logic is_p_up_border(input logic [BLK_W_LOG2-1:0] local_x,
                                input logic [BLK_H_LOG2-1:0] local_y);
    return (local_x < P_UP_BORDER_SIZE)          ||
           (local_x >= BLK_W - P_UP_BORDER_SIZE) ||
           (local_y < P_UP_BORDER_SIZE)          ||
           (local_y >= BLK_H - P_UP_BORDER_SIZE);
  endfunction

  logic is_speed_power_up, is_bomb_power_up, is_range_power_up;
  assign is_speed_power_up = (addr_next == item_addr[0]) && item_active[0];
  assign is_bomb_power_up  = (addr_next == item_addr[1]) && item_active[1];
  assign is_range_power_up = (addr_next == item_addr[2]) && item_active[2];

  // ---------------------------------------------------------------------------
  // Color output muxing
  // ---------------------------------------------------------------------------
  // Everything is pipelined by 1 cycle to line up with the synchronous sprite ROM.
  always_ff @(posedge clk) begin
    out_of_map_q          <= out_of_map;
    st_q                  <= st;
    player_1_sprite_q     <= player_1_sprite;
    player_2_sprite_q     <= player_2_sprite;
    player_1_sprite_rgb_q <= player_1_sprite_rgb_raw;
    player_2_sprite_rgb_q <= player_2_sprite_rgb_raw;
    hud_p1_icon_q         <= hud_p1_icon;
    hud_p2_icon_q         <= hud_p2_icon;
    hud_bomb_p1_q         <= hud_bomb_p1;
    hud_bomb_p2_q         <= hud_bomb_p2;
    hud_range_p1_q        <= hud_range_p1;
    hud_range_p2_q        <= hud_range_p2;
    hud_speed_p1_q        <= hud_speed_p1;
    hud_speed_p2_q        <= hud_speed_p2;
    hud_p1_icon_rgb_q     <= hud_p1_icon_rgb;
    hud_p2_icon_rgb_q     <= hud_p2_icon_rgb;
    hud_bomb_rgb_q        <= hud_bomb_rgb;
    hud_range_rgb_q       <= hud_range_rgb;
    hud_speed_rgb_q       <= hud_speed_rgb;
    hud_p1_track_hit_q    <= hud_p1_track_hit;
    hud_p2_track_hit_q    <= hud_p2_track_hit;
    hud_track_rgb_q       <= hud_track_rgb;
    perm_blk_local_x_q    <= perm_blk_local_x;
    perm_blk_local_y_q    <= perm_blk_local_y;
    dest_blk_local_x_q    <= dest_blk_local_x;
    dest_blk_local_y_q    <= dest_blk_local_y;
    p_up_bomb_local_y_q   <= p_up_bomb_local_y;
    p_up_bomb_local_x_q   <= p_up_bomb_local_x;
    p_up_range_local_x_q  <= p_up_range_local_x;
    p_up_range_local_y_q  <= p_up_range_local_y;
    p_up_speed_local_x_q  <= p_up_speed_local_x;
    p_up_speed_local_y_q  <= p_up_speed_local_y;
    dest_blk_anim_rgb_q   <= dest_blk_anim_rgb;
    bomb_local_x_q        <= bomb_local_x;
    bomb_local_y_q        <= bomb_local_y;
    bomb_sprite_rgb_q     <= bomb_sprite_rgb;
    explode_local_x_q     <= dest_blk_local_x;
    explode_local_y_q     <= dest_blk_local_y;
    explode_sprite_rgb_q  <= explode_sprite_rgb;
  end

  always_comb begin
    if (out_of_map_q) begin
      {o_r, o_g, o_b} = {HUD_R, HUD_G, HUD_B};

      if (hud_p1_icon_q) begin
        {o_r, o_g, o_b} = hud_p1_icon_rgb_q;
      end else if (hud_p2_icon_q) begin
        {o_r, o_g, o_b} = hud_p2_icon_rgb_q;
      end else if (hud_bomb_p1_q) begin
        {o_r, o_g, o_b} = hud_bomb_rgb_q;
      end else if (hud_bomb_p2_q) begin
        {o_r, o_g, o_b} = hud_bomb_rgb_q;
      end else if (hud_range_p1_q) begin
        {o_r, o_g, o_b} = hud_range_rgb_q;
      end else if (hud_range_p2_q) begin
        {o_r, o_g, o_b} = hud_range_rgb_q;
      end else if (hud_speed_p1_q) begin
        {o_r, o_g, o_b} = hud_speed_rgb_q;
      end else if (hud_speed_p2_q) begin
        {o_r, o_g, o_b} = hud_speed_rgb_q;
      end else if (hud_p1_track_hit_q) begin
        {o_r, o_g, o_b} = hud_track_rgb_q;
      end else if (hud_p2_track_hit_q) begin
        {o_r, o_g, o_b} = hud_track_rgb_q;
      end

      // Player sprites have a color key (12'hF0F) for transparency
    end else if (player_1_sprite_q && (player_1_sprite_rgb_q != TRANSPARENCY)) begin
      {o_r, o_g, o_b} = player_1_sprite_rgb_q;
    end else if (player_2_sprite_q && (player_2_sprite_rgb_q != TRANSPARENCY)) begin
      {o_r, o_g, o_b} = player_2_sprite_rgb_q;
    end else begin
      unique case (st_q)
        // a map tile NO_BLK may contain:
        // - nothing (empty background)
        // - explosion
        // - power-up (speed, bomb, range)
        NO_BLK: begin
          {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};

          if ((is_exploding(
                  addr_next, explosion_addr
              ) && explode_signal) || (is_exploding(
                  addr_next, explosion_addr_2
              ) && explode_signal_2)) begin
            if (explode_sprite_rgb_q != TRANSPARENCY) {o_r, o_g, o_b} = explode_sprite_rgb_q;

          end else if (is_speed_power_up) begin
            if (p_up_frame && is_p_up_border(p_up_speed_local_x_q, p_up_speed_local_y_q))
              {o_r, o_g, o_b} = P_UP_ANIM_COLOR;
            else {o_r, o_g, o_b} = p_up_speed_sprite_rgb;

          end else if (is_bomb_power_up) begin
            if (p_up_frame && is_p_up_border(p_up_bomb_local_x_q, p_up_bomb_local_y_q))
              {o_r, o_g, o_b} = P_UP_ANIM_COLOR;
            else {o_r, o_g, o_b} = p_up_bomb_sprite_rgb;

          end else if (is_range_power_up) begin
            if (p_up_frame && is_p_up_border(p_up_range_local_x_q, p_up_range_local_y_q))
              {o_r, o_g, o_b} = P_UP_ANIM_COLOR;
            else {o_r, o_g, o_b} = p_up_range_sprite_rgb;
          end
        end

        PERM_BLK: begin
          {o_r, o_g, o_b} = perm_blk_rgb;
        end

        DESTROYABLE_BLK: begin
          if ((is_exploding(
                  addr_next, explosion_addr
              ) && explode_signal) || (is_exploding(
                  addr_next, explosion_addr_2
              ) && explode_signal_2)) begin
            if (dest_blk_anim_rgb_q != TRANSPARENCY) {o_r, o_g, o_b} = dest_blk_anim_rgb_q;
            else {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
          end else begin
            if (dest_blk_rgb != TRANSPARENCY) {o_r, o_g, o_b} = dest_blk_rgb;
            else {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
          end
        end

        BOMB: begin
          if (bomb_sprite_rgb_q != TRANSPARENCY) {o_r, o_g, o_b} = bomb_sprite_rgb_q;
          else {o_r, o_g, o_b} = {BG_R, BG_G, BG_B};
        end

        default: {o_r, o_g, o_b} = TRANSPARENCY;  // Magenta as error color
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
  assign map_x = draw_x - HUD_H;
  assign map_y = draw_y - HUD_TOP;

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

  assign bomb_local_x = map_x[BLK_W_LOG2-1:0];
  assign bomb_local_y = map_y[BLK_H_LOG2-1:0];
  assign bomb_sprite_addr = {bomb_frame, bomb_local_y_q, bomb_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (BOMB_SPRITE_TOTAL),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("bomb.mem")
  ) bomb_sprite_i (
      .clk (clk),
      .addr(bomb_sprite_addr),
      .data(bomb_sprite_rgb)
  );


  assign p_up_speed_local_x = map_x[BLK_W_LOG2-1:0];
  assign p_up_speed_local_y = map_y[BLK_H_LOG2-1:0];
  assign p_up_speed_sprite_addr = {p_up_speed_local_y_q, p_up_speed_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("p_up_speed.mem")
  ) p_up_speed_sprite_i (
      .clk (clk),
      .addr(p_up_speed_sprite_addr),
      .data(p_up_speed_sprite_rgb)
  );

  assign p_up_bomb_local_x = map_x[BLK_W_LOG2-1:0];
  assign p_up_bomb_local_y = map_y[BLK_H_LOG2-1:0];
  assign p_up_bomb_sprite_addr = {p_up_bomb_local_y_q, p_up_bomb_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("p_up_bomb.mem")
  ) p_up_bomb_sprite_i (
      .clk (clk),
      .addr(p_up_bomb_sprite_addr),
      .data(p_up_bomb_sprite_rgb)
  );

  assign p_up_range_local_x = map_x[BLK_W_LOG2-1:0];
  assign p_up_range_local_y = map_y[BLK_H_LOG2-1:0];
  assign p_up_range_sprite_addr = {p_up_range_local_y_q, p_up_range_local_x_q};

  sprite_rom #(
      .SPRITE_W     (BLK_W),
      .SPRITE_H     (BLK_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE("p_up_range.mem")
  ) p_up_range_sprite_i (
      .clk (clk),
      .addr(p_up_range_sprite_addr),
      .data(p_up_range_sprite_rgb)
  );

  always_comb begin
    col       = map_x >> BLK_W_LOG2;
    row       = map_y >> BLK_H_LOG2;
    addr_next = row * NUM_COL + col;
    map_addr  = (out_of_map) ? '0 : addr_next;
  end

endmodule
