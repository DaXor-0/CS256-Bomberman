`timescale 1ns / 1ps

/**
 * Draws the centered game-over overlay (960x512) using 64x64 border tiles.
 * Game-over art is 288x224 (matches the halved game_over.mem asset).
 * Produces a 1-cycle-latent color/active signal aligned to sprite_rom latency.
 */
module drawcon_gameover #(
    parameter  int    SCREEN_W      = 1280,
    parameter  int    SCREEN_H      = 800,
    parameter  int    GO_W          = 960,
    parameter  int    GO_H          = 512,
    parameter  int    GO_TILE       = 64,
    parameter  int    SPRITE_W      = 288,
    parameter  int    SPRITE_H      = 224,
    parameter  string MEM_INIT_FILE = "border_tiles.mem",
    parameter  string SPRITE_MEM    = "game_over.mem",
    localparam int    GO_TILES_X    = GO_W / GO_TILE,                 // 15
    localparam int    GO_TILES_Y    = GO_H / GO_TILE,                 // 8
    localparam int    GO_X          = (SCREEN_W - GO_W) / 2,
    localparam int    GO_Y          = (SCREEN_H - GO_H) / 2,
    localparam int    GO_ADDR_WIDTH = $clog2(GO_TILE * GO_TILE * 2),
    localparam int    GO_TILE_MAX   = GO_TILE - 1,
    localparam int    SPRITE_X      = GO_X + (GO_W - SPRITE_W) / 2,
    localparam int    SPRITE_Y      = GO_Y + (GO_H - SPRITE_H) / 2,
    localparam int    SPRITE_ADDR_W = $clog2(SPRITE_W * SPRITE_H),
    localparam int    TRANSPARENCY  = 12'hF0F
) (
    input  logic        clk,
    input  logic        game_over_screen,
    input  logic [10:0] draw_x,
    input  logic [ 9:0] draw_y,
    output logic        go_active_q,
    output logic [11:0] go_rgb_q
);

  logic go_region;
  logic go_use_border;
  logic [GO_ADDR_WIDTH-1:0] go_border_addr;
  logic [11:0] go_border_rgb, go_border_rgb_q;
  logic [10:0] go_local_x;
  logic [ 9:0] go_local_y;
  logic [5:0] go_tile_px_x, go_tile_px_y, go_rom_x, go_rom_y;
  logic [3:0] go_tile_x;
  logic [2:0] go_tile_y;
  logic go_is_corner_tl, go_is_corner_tr;
  logic go_is_corner_bl, go_is_corner_br;
  logic go_is_top_edge, go_is_bot_edge;
  logic go_is_left_edge, go_is_right_edge;
  logic go_region_q, go_use_border_q;
  logic sprite_region, sprite_region_q;
  logic [10:0] sprite_local_x;
  logic [9:0] sprite_local_y;
  logic [SPRITE_ADDR_W-1:0] sprite_addr;
  logic [11:0] sprite_rgb, sprite_rgb_q;

  // Border tile ROM: frame 0 = corner, frame 1 = horizontal pipe
  sprite_rom #(
      .SPRITE_W     (GO_TILE),
      .SPRITE_H     (GO_TILE),
      .NUM_FRAMES   (2),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(MEM_INIT_FILE)
  ) game_over_border_i (
      .clk (clk),
      .addr(go_border_addr),
      .data(go_border_rgb)
  );

  sprite_rom #(
      .SPRITE_W     (SPRITE_W),
      .SPRITE_H     (SPRITE_H),
      .NUM_FRAMES   (1),
      .DATA_WIDTH   (12),
      .MEM_INIT_FILE(SPRITE_MEM)
  ) game_over_sprite_i (
      .clk (clk),
      .addr(sprite_addr),
      .data(sprite_rgb)
  );

  // Combinational address + orientation selection
  always_comb begin
    go_region        = 1'b0;
    go_use_border    = 1'b0;
    go_local_x       = '0;
    go_local_y       = '0;
    go_tile_x        = '0;
    go_tile_y        = '0;
    go_tile_px_x     = '0;
    go_tile_px_y     = '0;
    go_rom_x         = '0;
    go_rom_y         = '0;
    go_border_addr   = '0;
    go_is_corner_tl  = 1'b0;
    go_is_corner_tr  = 1'b0;
    go_is_corner_bl  = 1'b0;
    go_is_corner_br  = 1'b0;
    go_is_top_edge   = 1'b0;
    go_is_bot_edge   = 1'b0;
    go_is_left_edge  = 1'b0;
    go_is_right_edge = 1'b0;
    sprite_region    = 1'b0;
    sprite_local_x   = '0;
    sprite_local_y   = '0;
    sprite_addr      = '0;

    if (game_over_screen) begin
      go_region = (draw_x >= GO_X) && (draw_x < GO_X + GO_W) && (draw_y >= GO_Y) &&
                  (draw_y < GO_Y + GO_H);
      if (go_region) begin
        go_local_x   = draw_x - GO_X;
        go_local_y   = draw_y - GO_Y;
        go_tile_x    = go_local_x[10:6];  // divide by 64
        go_tile_y    = go_local_y[9:6];   // divide by 64
        go_tile_px_x = go_local_x[5:0];
        go_tile_px_y = go_local_y[5:0];

        go_is_corner_tl = (go_tile_x == 0) && (go_tile_y == 0);
        go_is_corner_tr = (go_tile_x == GO_TILES_X - 1) && (go_tile_y == 0);
        go_is_corner_bl = (go_tile_x == 0) && (go_tile_y == GO_TILES_Y - 1);
        go_is_corner_br = (go_tile_x == GO_TILES_X - 1) && (go_tile_y == GO_TILES_Y - 1);

        go_is_top_edge   = (go_tile_y == 0);
        go_is_bot_edge   = (go_tile_y == GO_TILES_Y - 1);
        go_is_left_edge  = (go_tile_x == 0);
        go_is_right_edge = (go_tile_x == GO_TILES_X - 1);

        if (go_is_corner_tl || go_is_corner_tr || go_is_corner_bl || go_is_corner_br ||
            go_is_top_edge || go_is_bot_edge || go_is_left_edge || go_is_right_edge) begin
          go_use_border = 1'b1;

          if (go_is_corner_tl) begin
            go_rom_x = go_tile_px_x;
            go_rom_y = go_tile_px_y;
          end else if (go_is_corner_tr) begin
            go_rom_x = GO_TILE_MAX - go_tile_px_x;
            go_rom_y = go_tile_px_y;
          end else if (go_is_corner_bl) begin
            go_rom_x = go_tile_px_x;
            go_rom_y = GO_TILE_MAX - go_tile_px_y;
          end else if (go_is_corner_br) begin
            go_rom_x = GO_TILE_MAX - go_tile_px_x;
            go_rom_y = GO_TILE_MAX - go_tile_px_y;
          end else if (go_is_top_edge || go_is_bot_edge) begin
            // Horizontal pipe
            go_rom_x = go_tile_px_x;
            go_rom_y = go_tile_px_y;
          end else if (go_is_left_edge) begin
            // Rotate pipe 90° counter-clockwise for left edge
            go_rom_x = GO_TILE_MAX - go_tile_px_y;
            go_rom_y = go_tile_px_x;
          end else if (go_is_right_edge) begin
            // Rotate pipe 90° clockwise for right edge
            go_rom_x = go_tile_px_y;
            go_rom_y = GO_TILE_MAX - go_tile_px_x;
          end

          go_border_addr = {
            (go_is_corner_tl || go_is_corner_tr || go_is_corner_bl || go_is_corner_br) ? 1'b0 : 1'b1,
            go_rom_y,
            go_rom_x
          };
        end
      end
    end

    // Center sprite region inside the overlay
    if (game_over_screen &&
        (draw_x >= SPRITE_X) && (draw_x < SPRITE_X + SPRITE_W) &&
        (draw_y >= SPRITE_Y) && (draw_y < SPRITE_Y + SPRITE_H)) begin
      sprite_region  = 1'b1;
      sprite_local_x = draw_x - SPRITE_X;
      sprite_local_y = draw_y - SPRITE_Y;
      sprite_addr    = sprite_local_y * SPRITE_W + sprite_local_x;
    end
  end

  // 1-cycle pipeline to align ROM latency with active flag
  always_ff @(posedge clk) begin
    go_region_q     <= go_region;
    go_use_border_q <= go_use_border;
    go_border_rgb_q <= go_border_rgb;
    sprite_region_q <= sprite_region;
    sprite_rgb_q    <= sprite_rgb;
  end

  assign go_active_q = go_region_q;
  always_comb begin
    if (sprite_region_q && sprite_rgb_q != TRANSPARENCY) go_rgb_q = sprite_rgb_q;
    else if (go_use_border_q) go_rgb_q = go_border_rgb_q;
    else go_rgb_q = 12'h000;
  end

endmodule
