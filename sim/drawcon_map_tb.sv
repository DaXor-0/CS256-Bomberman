`timescale 1ns / 1ps

`include "bomberman_dir.svh"

module drawcon_map_tb;
  localparam CLK_PERIOD = 10;
  localparam int NUM_ROW = MAP_NUM_ROW_DEF;
  localparam int NUM_COL = MAP_NUM_COL_DEF;
  localparam int DEPTH   = NUM_ROW * NUM_COL;
  localparam int ADDR_WIDTH = $clog2(DEPTH);

  logic clk = 0;
  logic rst = 1;
  logic tick;
  logic game_over = 0;
  logic game_over_screen = 0;
  logic [MAP_MEM_WIDTH_DEF-1:0] map_tile_state;
  logic [10:0] draw_x;
  logic [9:0]  draw_y;
  logic [3:0] o_r, o_g, o_b;
  logic [10:0] player_1_x = 11'd64, player_2_x = 11'd1088;
  logic [9:0]  player_1_y = 10'd64, player_2_y = 10'd576;
  dir_t player_1_dir = DIR_DOWN, player_2_dir = DIR_UP;
  logic explode_signal = 0, explode_signal_2 = 0;
  logic [ADDR_WIDTH-1:0] explosion_addr = '0, explosion_addr_2 = '0;
  logic [ADDR_WIDTH-1:0] item_addr[0:2];
  logic [2:0] item_active = '0;
  logic [1:0] p1_bomb_level = '0, p1_range_level = '0, p1_speed_level = '0;
  logic [1:0] p2_bomb_level = '0, p2_range_level = '0, p2_speed_level = '0;
  logic [ADDR_WIDTH-1:0] map_addr;
  logic [MAP_MEM_WIDTH_DEF-1:0] map_mem [0:DEPTH-1];

  // DUT
  drawcon dut (
      .clk(clk),
      .rst(rst),
      .tick(tick),
      .game_over(game_over),
      .map_tile_state(map_tile_state),
      .draw_x(draw_x),
      .draw_y(draw_y),
      .game_over_screen(game_over_screen),
      .player_1_x(player_1_x),
      .player_1_y(player_1_y),
      .player_2_x(player_2_x),
      .player_2_y(player_2_y),
      .player_1_dir(player_1_dir),
      .player_2_dir(player_2_dir),
      .explode_signal(explode_signal),
      .explode_signal_2(explode_signal_2),
      .explosion_addr(explosion_addr),
      .explosion_addr_2(explosion_addr_2),
      .p1_bomb_level(p1_bomb_level),
      .p1_range_level(p1_range_level),
      .p1_speed_level(p1_speed_level),
      .p2_bomb_level(p2_bomb_level),
      .p2_range_level(p2_range_level),
      .p2_speed_level(p2_speed_level),
      .item_active(item_active),
      .item_addr(item_addr),
      .o_r(o_r),
      .o_g(o_g),
      .o_b(o_b),
      .map_addr(map_addr)
  );

  // Simple tick pulse (once per 1280*800 pixels)
  always_ff @(posedge clk) begin
    if (rst) begin
      draw_x <= 0;
      draw_y <= 0;
    end else begin
      if (draw_x == 1279) begin
        draw_x <= 0;
        if (draw_y == 799) draw_y <= 0;
        else draw_y <= draw_y + 1;
      end else draw_x <= draw_x + 1;
    end
  end

  assign tick = (draw_x == 0 && draw_y == 0);

  // Map BRAM model: synchronous 1-cycle
  always_ff @(posedge clk) begin
    map_tile_state <= map_mem[map_addr];
  end

  initial begin
    $dumpfile("drawcon_map_tb.vcd");
    $dumpvars(0, drawcon_map_tb);
    $readmemh("maps/basic_map.mem", map_mem);
    item_addr[0] = '0;
    item_addr[1] = '0;
    item_addr[2] = '0;

    repeat (5) @(posedge clk);
    rst = 0;

    // run enough cycles for a handful of frames
    repeat (200000) @(posedge clk);
    $finish;
  end

  always #(CLK_PERIOD/2) clk = ~clk;

endmodule
