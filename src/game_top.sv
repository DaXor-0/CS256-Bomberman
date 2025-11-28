`timescale 1ns / 1ps

`include "bomberman_dir.svh"

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
    o_vsync,
    output logic CA, CB, CC, CD, CE, CF, CG,
    output logic [7:0] AN
);



  wire pixclk, rst;
  assign rst = ~CPU_RESETN;  // the reset button is reversed (lost too much time on that :( )

  clk_wiz_0 pixclk_i (  // Set pixclk to 83.456MHz
      .clk_in1 (CLK100MHZ),
      .clk_out1(pixclk)
  );

// -------------------------------------------------------- //
// -------------------- 7-SEG DISPLAY -------------------- //
// -------------------------------------------------------- //
  logic [3:0] dig0;
  multidigit multidigit_i (
      .clk   (CLK100MHZ),
      .rst   (~CPU_RESETN),
      .dig0  (dig0),
      .dig1  (4'd0),
      .dig2  (4'd0),
      .dig3  (4'd0),
      .dig4  (4'd0),
      .dig5  (4'd0),
      .dig6  (4'd0),
      .dig7  (4'd0),
      .a     (CA),
      .b     (CB),
      .c     (CC),
      .d     (CD),
      .e     (CE),
      .f     (CF),
      .g     (CG),
      .an    (AN)
  );

  assign dig0 = countdown; // display the bomb countdown on the 7-seg

// -------------------------------------------------------- //
// ----------------------- VGA MODULE --------------------- //
// -------------------------------------------------------- //
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
  localparam int BOMB_TIME = 3;

  // Logic for positioning rectangle control.
  logic [10:0] player_x, map_player_x;
  logic [9:0] player_y, map_player_y;
  logic [MAP_ADDR_WIDTH-1:0] map_addr_obst, map_addr_drawcon, read_addr;
  logic [MAP_ADDR_WIDTH-1:0] read_addr_req[0:1];
  logic [1:0] read_req, read_granted;
  logic [MAP_MEM_WIDTH-1:0] map_tile_state_obst, map_tile_state_drawcon;

  // one-cycle pulse, synchronous to pixclk
  logic tick;
  always_ff @(posedge pixclk) tick <= (curr_x == 0 && curr_y == 0);

  dir_t move_dir;
  always_comb begin
    move_dir = DIR_NONE;
    case ({
      up, down, left, right
    })
      4'b1000: move_dir = DIR_UP;
      4'b0100: move_dir = DIR_DOWN;
      4'b0010: move_dir = DIR_LEFT;
      4'b0001: move_dir = DIR_RIGHT;
      default: move_dir = DIR_NONE;
    endcase
  end

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
      .map_player_y(map_player_y),
      .read_granted(read_granted[0]),
      .read_req(read_req[0])
  );

  // -------------------------------------------------------- //
  // ----------------- BOMBS AND EXPLOSIONS ----------------- //
  // -------------------------------------------------------- // 
  logic [MAP_ADDR_WIDTH-1:0] wr_addr, wr_addr_bomb, wr_addr_free, saved_explosion_addr;
  logic [MAP_MEM_WIDTH-1:0] write_data, write_data_bomb, write_data_free;
  logic we, we_bomb, we_free;

  logic trigger_explosion, explode_signal, game_over, free_blks_signal;
  logic [$clog2(BOMB_TIME)-1:0] countdown;

  // Write enable mux (very basic, with more bombs this needs to be an arbiter)
  assign we = (we_bomb || we_free);
  assign wr_addr = we_bomb ? wr_addr_bomb : wr_addr_free;
  assign write_data = we_bomb ? write_data_bomb : write_data_free;


  bomb_logic bomb_logic_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .player_x(map_player_x),
      .player_y(map_player_y),
      .place_bomb(place_bomb),
      .write_addr(wr_addr_bomb),
      .write_data(write_data_bomb),
      .write_en(we_bomb),
      .trigger_explosion(trigger_explosion),
      .countdown(countdown),
      .countdown_signal(countdown_signal)
  );

  // Explosion Logic
  explode_logic explode_logic_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .trigger_explosion(trigger_explosion),
      .explosion_addr(wr_addr_bomb),
      .player_x(map_player_x),
      .player_y(map_player_y),
      .saved_explosion_addr(saved_explosion_addr),
      .explode_signal(explode_signal),
      .game_over(game_over),
      .free_blks_signal(free_blks_signal)
  );

  // Free Blocks
  free_blocks free_blocks_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .free_blks_signal(free_blks_signal),
      .explosion_addr(saved_explosion_addr),
      .map_mem_in(map_tile_state_obst),
      .read_granted(read_granted[1]),
      .read_req(read_req[1]),
      .read_addr(read_addr_req[1]),
      .write_addr(wr_addr_free),
      .write_data(write_data_free),
      .write_en(we_free)
  );

  // Map memory read controller (arbiter)
  mem_read_controller r_arbiter (
      .clk(pixclk),
      .rst(rst),
      .read_req(read_req),
      .read_addr_req(read_addr_req),
      .read_addr(read_addr),
      .read_granted(read_granted)
  );

  assign read_addr_req[0] = map_addr_obst;

  // Map memory write controller (arbiter)

  // Map memory
  map_mem #(
      .NUM_ROW(MAP_NUM_ROW),
      .NUM_COL(MAP_NUM_COL),
      .DATA_WIDTH(2),
      .MEM_INIT_FILE("basic_map.mem")
  ) mem_i (
      .clk(pixclk),
      .rst(rst),
      .rd_addr_1(read_addr),
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
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .map_tile_state(map_tile_state_drawcon),
      .draw_x(curr_x_d),
      .draw_y(curr_y_d),
      .player_x(player_x),
      .player_y(player_y),
      .player_dir(move_dir),
      .explode_signal(explode_signal),
      .explosion_addr(saved_explosion_addr),
      .o_r(drawcon_o_r),
      .o_g(drawcon_o_g),
      .o_b(drawcon_o_b),
      .map_addr(map_addr_drawcon)
  );

endmodule
