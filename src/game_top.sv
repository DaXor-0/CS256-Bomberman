`timescale 1ns / 1ps

module game_top (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input  logic       up,
    down,
    left,
    right,  // movement control
    input  logic       place_bomb,
    output logic [3:0] o_pix_r,
    o_pix_g,
    o_pix_b,
    output logic       o_hsync,
    o_vsync
);

  wire pixclk, rst;
  assign rst = ~CPU_RESETN;  // the reset button is reversed (lost too much time on that :( )

  clk_wiz_0 pixclk_i (  // Set pixclk to 83.456MHz
      .clk_in1 (CLK100MHZ),
      .clk_out1(pixclk)
  );

  // Get the VGA timing signals
  logic [10:0] curr_x;
  logic [ 9:0] curr_y;
  logic [3:0] drawcon_o_r, drawcon_o_g, drawcon_o_b;
  vga_out vga_out_u (
      .i_clk   (pixclk),
      .i_rst   (rst),
      .i_r     (drawcon_o_r),
      .i_g     (drawcon_o_g),
      .i_b     (drawcon_o_b),
      .o_pix_r (o_pix_r),
      .o_pix_g (o_pix_g),
      .o_pix_b (o_pix_b),      // VGA color output
      .o_hsync (o_hsync),
      .o_vsync (o_vsync),      // horizontal and vertical sync
      .o_curr_x(curr_x),
      .o_curr_y(curr_y)        // what pixel are we on
  );

  localparam int SCREEN_W = 1280;
  localparam int SCREEN_H = 800;
  localparam int MAP_NUM_ROW = 11;
  localparam int MAP_NUM_COL = 19;
  localparam int MAP_DEPTH = MAP_NUM_ROW * MAP_NUM_COL;
  localparam int MAP_ADDR_WIDTH = $clog2(MAP_DEPTH);
  localparam int MAP_MEM_WIDTH = 2;

  // Logic for positioning rectangle control.
  logic [10:0] player_x, map_player_x;
  logic [9:0] player_y, map_player_y;
  logic [MAP_ADDR_WIDTH-1:0] map_addr_obst, map_addr_drawcon;
  logic [MAP_MEM_WIDTH-1:0] map_tile_state_obst, map_tile_state_drawcon;

  // one-cycle pulse, synchronous to pixclk
  logic tick;
  always_ff @(posedge pixclk) tick <= (curr_x == 0 && curr_y == 0);


  logic [3:0] move_dir;
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
      .player_y(player_y),
      .map_player_x(map_player_x),
      .map_player_y(map_player_y)
  );


  // Bomb Logic
  logic [MAP_ADDR_WIDTH-1:0] wr_addr;
  logic [MAP_MEM_WIDTH-1:0] write_data;
  logic we;
  bomb_logic bomb_logic_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .player_x(map_player_x),
      .player_y(map_player_y),
      .place_bomb(place_bomb),
      .write_addr(wr_addr),
      .write_data(write_data),
      .write_en(we),
      .trigger_explosion(trigger_explosion),
      .countdown(countdown)
  );

  // Explosion Logic
  map_mem #(
      .NUM_ROW(MAP_NUM_ROW),
      .NUM_COL(MAP_NUM_COL),
      .DATA_WIDTH(2),
      .MEM_INIT_FILE("basic_map.mem")
  ) mem_i (
      .clk(pixclk),
      .rst(rst),
      .rd_addr_1(map_addr_obst),
      .rd_data_1(map_tile_state_obst),
      .rd_addr_2(map_addr_drawcon),
      .rd_data_2(map_tile_state_drawcon),
      .we(we),
      .wr_addr(wr_addr),
      .wr_data(write_data)
  );

  logic [10:0] curr_x_d;
  logic [ 9:0] curr_y_d;

  always_ff @(posedge pixclk) begin
    curr_x_d <= curr_x;
    curr_y_d <= curr_y;
  end

  // drawcon now contains sequential due to map FSM.
  drawcon drawcon_i (
      .map_tile_state(map_tile_state_drawcon),
      .draw_x(curr_x_d),
      .draw_y(curr_y_d),
      .player_x(player_x),
      .player_y(player_y),
      .o_r(drawcon_o_r),
      .o_g(drawcon_o_g),
      .o_b(drawcon_o_b),
      .map_addr(map_addr_drawcon)
  );

endmodule
