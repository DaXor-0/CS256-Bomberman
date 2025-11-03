`timescale 1ns/1ps

module player_controller_tb;
  localparam int CLK_PERIOD = 10;
  localparam int NUM_ROW    = 11;
  localparam int NUM_COL    = 19;
  localparam int TILE_PX    = 64;
  localparam int SPRITE_W   = 32;
  localparam int SPRITE_H   = 64;
  localparam int STEP_SIZE  = 32;
  localparam int SCREEN_W   = 1280;
  localparam int SCREEN_H   = 800;
  localparam int INIT_X     = 64;
  localparam int INIT_Y     = 64;
  localparam string MAP_FILE = "maps/basic_map.mem";

  localparam int MAP_W_PX   = NUM_COL * TILE_PX;
  localparam int MAP_H_PX   = NUM_ROW * TILE_PX;
  localparam int HUD_SIDE_PX = (SCREEN_W - MAP_W_PX) / 2;
  localparam int HUD_TOP_PX  = (SCREEN_H - MAP_H_PX);
  localparam int DEPTH       = NUM_ROW * NUM_COL;
  localparam int ADDR_WIDTH  = $clog2(DEPTH);

  localparam logic [3:0] DIR_UP    = 4'b1000;
  localparam logic [3:0] DIR_DOWN  = 4'b0100;
  localparam logic [3:0] DIR_LEFT  = 4'b0010;
  localparam logic [3:0] DIR_RIGHT = 4'b0001;

  logic clk  = 0;
  logic rst  = 1;
  logic tick = 0;
  logic [3:0] move_dir = 4'b0;
  logic [1:0] map_mem_in = '0;

  logic [10:0] player_x;
  logic [9:0]  player_y;
  logic [ADDR_WIDTH-1:0] map_addr;

  logic [1:0] map_mem [0:DEPTH-1];
  logic [ADDR_WIDTH-1:0] map_addr_d;

  player_controller #(
      .NUM_ROW (NUM_ROW),
      .NUM_COL (NUM_COL),
      .TILE_PX (TILE_PX),
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .STEP_SIZE(STEP_SIZE),
      .SCREEN_W(SCREEN_W),
      .SCREEN_H(SCREEN_H),
      .INIT_X  (INIT_X),
      .INIT_Y  (INIT_Y)
  ) dut (
      .clk(clk),
      .rst(rst),
      .tick(tick),
      .move_dir(move_dir),
      .map_mem_in(map_mem_in),
      .player_x(player_x),
      .player_y(player_y),
      .map_addr(map_addr)
  );

  always #(CLK_PERIOD / 2) clk = ~clk;

  always_ff @(posedge clk) begin
    if (rst) begin
      map_addr_d <= '0;
      map_mem_in <= '0;
    end else begin
      map_addr_d <= map_addr;
      map_mem_in <= map_mem[map_addr_d];
    end
  end

  function automatic int idx(input int row, input int col);
    return row * NUM_COL + col;
  endfunction

  task automatic log_position(input string label);
    int px;
    int py;
    int map_x;
    int map_y;
    int tile_row;
    int tile_col;
    px = player_x;
    py = player_y;
    map_x = (px > HUD_SIDE_PX) ? (px - HUD_SIDE_PX) : 0;
    map_y = (py > HUD_TOP_PX)  ? (py - HUD_TOP_PX)  : 0;

    tile_col = (map_x >= 0) ? (map_x / TILE_PX) : 0;
    tile_row = (map_y >= 0) ? (map_y / TILE_PX) : 0;

    $display("[%0t] %s -> screen=(%0d,%0d) map=(%0d,%0d) tile=%0d",
             $time, label, px, py, tile_row, tile_col,
             map_mem[idx(tile_row, tile_col)]);
  endtask

  task automatic pulse_tick(input logic [3:0] dir);
    move_dir = dir;
    tick = 1'b1;
    @(posedge clk);
    tick = 1'b0;
    move_dir = 4'b0;
    repeat (4) @(posedge clk);
  endtask

  task automatic drive_moves(
      input logic [3:0] dir,
      input int num_ticks,
      input string label
  );
    $display("[%0t] >>> %s (%0d ticks)", $time, label, num_ticks);
    for (int i = 0; i < num_ticks; i++) begin
      pulse_tick(dir);
    end
    log_position({"after ", label});
  endtask

  initial begin
    $dumpfile("player_controller_tb.vcd");
    $dumpvars(0, player_controller_tb);

    $readmemh(MAP_FILE, map_mem);

    repeat (6) @(posedge clk);
    rst = 0;

    repeat (12) @(posedge clk);
    log_position("reset released");

    drive_moves(DIR_UP, 1, "attempt move up into perimeter");
    drive_moves(DIR_RIGHT, 2, "step right into column 2");
    drive_moves(DIR_DOWN, 2, "attempt move down into pillar");
    drive_moves(DIR_LEFT, 2, "return left to column 1");
    drive_moves(DIR_DOWN, 4, "descend two rows along corridor");
    drive_moves(DIR_RIGHT, 6, "move east through open hall");
    drive_moves(DIR_RIGHT, 26, "long stride towards east wall");
    drive_moves(DIR_RIGHT, 2, "attempt to breach east wall");

    repeat (16) @(posedge clk);
    $finish;
  end

endmodule
