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
    input logic game_over,
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

  logic [1:0] walk_frame_1;  // ranges 0,1,2
  logic [1:0] walk_frame_2;  // ranges 0,1,2
  logic [2:0] dest_frame;  // ranges 0..5
  logic [2:0] bomb_frame;
  logic       p_up_frame;

  drawcon_anim #(
      .WALK_ANIM_TIME           (WALK_ANIM_TIME),
      .WALK_FRAMES_PER_DIR      (WALK_FRAMES_PER_DIR),
      .DEST_FRAME_TIME          (DEST_FRAME_TIME),
      .DEST_FRAMES              (DEST_FRAMES),
      .BOMB_TOTAL_ANIMATION_TIME(BOMB_TOTAL_ANIMATION_TIME),
      .BOMB_ANIM_TIME           (BOMB_ANIM_TIME),
      .P_UP_FRAME_TIME          (P_UP_FRAME_TIME)
  ) drawcon_anim_i (
      .clk          (clk),
      .rst          (rst),
      .tick         (tick),
      .game_over    (game_over),
      .player_1_dir (player_1_dir),
      .player_2_dir (player_2_dir),
      .explode_signal(explode_signal),
      .explode_signal_2(explode_signal_2),
      .walk_frame_1 (walk_frame_1),
      .walk_frame_2 (walk_frame_2),
      .dest_frame   (dest_frame),
      .bomb_frame   (bomb_frame),
      .p_up_frame   (p_up_frame)
  );

  // ---------------------------------------------------------------------------
  // Player sprite addressing
  // ---------------------------------------------------------------------------
  logic player_1_sprite_q, player_2_sprite_q;
  logic [11:0] player_1_sprite_rgb_q, player_2_sprite_rgb_q;
  logic [           MAP_ADDR_WIDTH-1:0] addr_next;

  drawcon_player_sprite #(
      .SPRITE_W           (SPRITE_W),
      .SPRITE_H           (SPRITE_H),
      .WALK_FRAMES_PER_DIR(WALK_FRAMES_PER_DIR),
      .WALK_FRAMES_TOTAL  (WALK_FRAMES_TOTAL),
      .MEM_INIT_FILE      ("player_1.mem")
  ) player_1_sprite_i (
      .clk      (clk),
      .draw_x   (draw_x),
      .draw_y   (draw_y),
      .sprite_x (player_1_x),
      .sprite_y (player_1_y),
      .dir      (player_1_dir),
      .walk_frame(walk_frame_1),
      .active_q (player_1_sprite_q),
      .rgb_q    (player_1_sprite_rgb_q)
  );

  drawcon_player_sprite #(
      .SPRITE_W           (SPRITE_W),
      .SPRITE_H           (SPRITE_H),
      .WALK_FRAMES_PER_DIR(WALK_FRAMES_PER_DIR),
      .WALK_FRAMES_TOTAL  (WALK_FRAMES_TOTAL),
      .MEM_INIT_FILE      ("player_2.mem")
  ) player_2_sprite_i (
      .clk      (clk),
      .draw_x   (draw_x),
      .draw_y   (draw_y),
      .sprite_x (player_2_x),
      .sprite_y (player_2_y),
      .dir      (player_2_dir),
      .walk_frame(walk_frame_2),
      .active_q (player_2_sprite_q),
      .rgb_q    (player_2_sprite_rgb_q)
  );

  // ---------------------------------------------------------------------------
  // Static blocks, block destruction, explosion and power ups sprite addressing
  // ---------------------------------------------------------------------------
  logic [BLK_W_LOG2-1:0] perm_blk_local_x, perm_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] perm_blk_local_y, perm_blk_local_y_q;
  logic [BLK_W_LOG2-1:0] dest_blk_local_x, dest_blk_local_x_q;
  logic [BLK_H_LOG2-1:0] dest_blk_local_y, dest_blk_local_y_q;
  logic [BLK_W_LOG2-1:0] explode_local_x_q;
  logic [BLK_H_LOG2-1:0] explode_local_y_q;
  logic [BLK_W_LOG2-1:0] bomb_local_x, bomb_local_x_q;
  logic [BLK_H_LOG2-1:0] bomb_local_y, bomb_local_y_q;
  logic [BLK_W_LOG2-1:0] p_up_speed_local_x, p_up_speed_local_x_q;
  logic [BLK_H_LOG2-1:0] p_up_speed_local_y, p_up_speed_local_y_q;
  logic [BLK_W_LOG2-1:0] p_up_bomb_local_x, p_up_bomb_local_x_q;
  logic [BLK_H_LOG2-1:0] p_up_bomb_local_y, p_up_bomb_local_y_q;
  logic [BLK_W_LOG2-1:0] p_up_range_local_x, p_up_range_local_x_q;
  logic [BLK_H_LOG2-1:0] p_up_range_local_y, p_up_range_local_y_q;
  // HUD outputs (pipelined)
  logic hud_p1_icon_q, hud_p2_icon_q, hud_bomb_p1_q, hud_bomb_p2_q;
  logic hud_range_p1_q, hud_range_p2_q, hud_speed_p1_q, hud_speed_p2_q;
  logic hud_p1_track_hit_q, hud_p2_track_hit_q;
  logic [11:0] hud_p1_icon_rgb_q, hud_p2_icon_rgb_q;
  logic [11:0] hud_bomb_rgb_q, hud_range_rgb_q, hud_speed_rgb_q;
  logic [11:0] hud_track_rgb_q;

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

  drawcon_hud #(
      .SCREEN_W(SCREEN_W),
      .SCREEN_H(SCREEN_H),
      .HUD_H   (HUD_H),
      .HUD_TOP (HUD_TOP),
      .HUD_BOT (HUD_BOT)
  ) drawcon_hud_i (
      .clk             (clk),
      .draw_x          (draw_x),
      .draw_y          (draw_y),
      .p1_bomb_level   (p1_bomb_level),
      .p1_range_level  (p1_range_level),
      .p1_speed_level  (p1_speed_level),
      .p2_bomb_level   (p2_bomb_level),
      .p2_range_level  (p2_range_level),
      .p2_speed_level  (p2_speed_level),
      .hud_p1_icon_q   (hud_p1_icon_q),
      .hud_p2_icon_q   (hud_p2_icon_q),
      .hud_bomb_p1_q   (hud_bomb_p1_q),
      .hud_bomb_p2_q   (hud_bomb_p2_q),
      .hud_range_p1_q  (hud_range_p1_q),
      .hud_range_p2_q  (hud_range_p2_q),
      .hud_speed_p1_q  (hud_speed_p1_q),
      .hud_speed_p2_q  (hud_speed_p2_q),
      .hud_p1_track_hit_q(hud_p1_track_hit_q),
      .hud_p2_track_hit_q(hud_p2_track_hit_q),
      .hud_p1_icon_rgb_q(hud_p1_icon_rgb_q),
      .hud_p2_icon_rgb_q(hud_p2_icon_rgb_q),
      .hud_bomb_rgb_q  (hud_bomb_rgb_q),
      .hud_range_rgb_q (hud_range_rgb_q),
      .hud_speed_rgb_q (hud_speed_rgb_q),
      .hud_track_rgb_q (hud_track_rgb_q)
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
