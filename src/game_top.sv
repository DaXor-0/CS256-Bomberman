`timescale 1ns/1ps

module game_top (
    input  logic        CLK100MHZ,
    input  logic        CPU_RESETN,
    input  logic        up, down, left, right,      // movement control
    output logic [3:0]  o_pix_r, o_pix_g, o_pix_b,
    output logic        o_hsync, o_vsync
);

  wire pixclk, rst;
  assign rst = ~CPU_RESETN; // the reset button is reversed (lost too much time on that :( )

  clk_wiz_0 pixclk_i ( // Set pixclk to 83.456MHz
    .clk_in1  (CLK100MHZ),
    .clk_out1 (pixclk)
  );

  // Get the VGA timing signals
  logic [10:0] curr_x;
  logic [9:0]  curr_y;
  logic [3:0]  drawcon_i_r, drawcon_i_g, drawcon_i_b;
  logic [3:0]  drawcon_o_r, drawcon_o_g, drawcon_o_b;
  vga_out vga_out_u (
    .i_clk    (pixclk),      .i_rst    (rst),
    .i_r      (drawcon_o_r), .i_g      (drawcon_o_g), .i_b  (drawcon_o_b),
    .o_pix_r  (o_pix_r),     .o_pix_g  (o_pix_g),     .o_pix_b (o_pix_b), // VGA color output
    .o_hsync  (o_hsync),     .o_vsync  (o_vsync),                         // horizontal and vertical sync
    .o_curr_x (curr_x),      .o_curr_y (curr_y)                           // what pixel are we on
  );

  localparam logic [11:0] 
      C_BLACK  = 12'h000,
      C_WHITE  = 12'hFFF,
      C_RED    = 12'hF00,
      C_GREEN  = 12'h0F0,
      C_BLUE   = 12'h00F;

  localparam int SCREEN_W = 1280;
  localparam int SCREEN_H = 800;
  localparam int MAP_NUM_ROW = 11;
  localparam int MAP_NUM_COL = 19;
  localparam int MAP_DEPTH = MAP_NUM_ROW * MAP_NUM_COL;
  localparam int MAP_ADDR_WIDTH = $clog2(MAP_DEPTH);
  localparam int MAP_MEM_WIDTH = 2;

  // Logic for positioning rectangle control.
  logic [10:0] player_x;
  logic [9:0]  player_y;
  logic [MAP_ADDR_WIDTH-1:0] map_addr_obst, map_addr_drawcon;
  logic [MAP_MEM_WIDTH-1:0] map_tile_state_obst, map_tile_state_drawcon;

  // one-cycle pulse, synchronous to pixclk
  logic tick;
  always_ff @(posedge pixclk)
    tick <= (curr_x == 0 && curr_y == 0);

  // Single Sprite mem for Bomberman_walking
  localparam int SPRITE_W = 32;
  localparam int SPRITE_H = 64;
  localparam int SPRITE_ADDR_WIDTH = $clog2(SPRITE_W * SPRITE_H);
  logic [SPRITE_ADDR_WIDTH-1:0] sprite_addr;
  logic [11:0] sprite_rgb_raw;
  logic player_sprite;
  logic [$clog2(SPRITE_W)-1:0] sprite_local_x;
  logic [$clog2(SPRITE_H)-1:0] sprite_local_y;

  always_comb begin
    player_sprite = 1'b0;
    sprite_local_x = '0;
    sprite_local_y = '0;
    sprite_addr    = '0;

    if ((curr_x >= player_x) && (curr_x < player_x + SPRITE_W) &&
        (curr_y >= player_y) && (curr_y < player_y + SPRITE_H)) begin
      player_sprite = 1'b1;
      sprite_local_x = curr_x - player_x;
      sprite_local_y = curr_y - player_y;
      sprite_addr = {sprite_local_y, sprite_local_x};
    end
  end

  // Simply loads the down walking sprite for now.
  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .DATA_WIDTH(12),
      .MEM_INIT_FILE("sprites/walk/mem/down_1.mem") // for now just use the down sprite
  ) bomberman_sprite_i (
      .addr(sprite_addr),
      .data(sprite_rgb_raw)
  );

  logic[3:0] move_dir;
  assign move_dir = {up, down, left, right};
  player_controller #(
      .INIT_X(64),
      .INIT_Y(64),
      .STEP_SIZE(4)
  ) player_ctrl_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .move_dir(move_dir),
      .map_mem_in(map_tile_state_obst),
      .map_addr(map_addr_obst),
      .player_x(player_x),
      .player_y(player_y)
  );


  map_mem #(
      .NUM_ROW(MAP_NUM_ROW),
      .NUM_COL(MAP_NUM_COL),
      .DATA_WIDTH(2),
      .MEM_INIT_FILE("maps/basic_map.mem")
  ) mem_i (
      .clk(pixclk),
      .rst(rst),
      .rd_addr_1(map_addr_obst),
      .rd_data_1(map_tile_state_obst),
      .rd_addr_2(map_addr_drawcon),
      .rd_data_2(map_tile_state_drawcon),
      .we(1'b0),
      .wr_addr('0),
      .wr_data('0)
  );

  logic [10:0] curr_x_d;
  logic [9:0]  curr_y_d;

always_ff @(posedge pixclk) begin
    curr_x_d <= curr_x;
    curr_y_d <= curr_y;
end

  // drawcon now contains sequential due to map FSM.
  assign {drawcon_i_r, drawcon_i_g, drawcon_i_b} = sprite_rgb_raw;
  drawcon drawcon_i (
    // Map State to determine draw current tile
    .map_tile_state(map_tile_state_drawcon), 
    // Game conditions
    .is_player(player_sprite),
    // curr_x and curr_y
    .draw_x(curr_x_d),     .draw_y(curr_y_d),
    // input output colors
    .i_r(drawcon_i_r), .i_g(drawcon_i_g), .i_b(drawcon_i_b),
    .o_r(drawcon_o_r), .o_g(drawcon_o_g), .o_b(drawcon_o_b),
    // Map addressing
    .map_addr(map_addr_drawcon)
  );

endmodule
