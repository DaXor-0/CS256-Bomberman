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
    input  wire uart_rx,
    output logic [4:0] LED, // debug LEDs
    output logic [3:0] o_pix_r,
    o_pix_g,
    o_pix_b,
    output logic       o_hsync,
    o_vsync,
    output logic CA, CB, CC, CD, CE, CF, CG,
    output logic [7:0] AN
);



  // -------------------------------------------------------- //
  // --------------------- UART_RX -------------------- //
  // -------------------------------------------------------- //
  wire [7:0] rx_byte;
  wire       rx_done;

  // UART receiver at 115200 baud, 100 MHz clock
    uart_rx #(
        .CLKS_PER_BIT(868)   // 100_000_000 / 115200 ≈ 868
    ) uart_rx_inst (
        .clk   (CLK100MHZ),
        .rx    (uart_rx),
        .rx_dv (rx_done),
        .rx_byte(rx_byte)
    );

    // Latch last received byte
    logic [7:0] buttons = 8'd0;

    always_ff @(posedge CLK100MHZ) begin
        if (rx_done) begin
            buttons <= rx_byte;
        end
    end

    // Map bits to LEDs: UP, DOWN, LEFT, RIGHT, ACTION
    assign LED[0] = buttons[0];   // UP
    assign LED[1] = buttons[1];   // DOWN
    assign LED[2] = buttons[2];   // LEFT
    assign LED[3] = buttons[3];   // RIGHT
    assign LED[4] = buttons[4];   // ACTION (B button)

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
      .rst   (rst),
      .dig0  (dig0),
      .dig1  (4'd0),
      .dig2  (4'd0),
      .dig3  (4'd0),
      .dig4  (dig4),
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

  logic [$clog2(BOMB_TIME)-1:0] countdown, countdown_2;
  assign dig0 = countdown && countdown_signal; // display the bomb countdown on the 7-seg
  assign dig4 = countdown_2 && countdown_signal_2; // display the bomb countdown on the 7-seg
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

  // Logic for positioning rectangle control.
  logic [10:0] player_x, map_player_x, player_2_x, map_player_2_x;
  logic [9:0] player_y, map_player_y, player_2_y, map_player_2_y;
  logic [MAP_ADDR_WIDTH-1:0] map_addr_obst, map_addr_obst_2, map_addr_drawcon, read_addr;
  // Player 1: idx 0, Player 2: idx 1, free_blks: idx 2-7
  logic [MAP_ADDR_WIDTH-1:0] read_addr_req[0:7];
  logic [7:0] read_req, read_granted;
  logic [MAP_MEM_WIDTH-1:0] map_tile_state_obst, map_tile_state_drawcon;
  logic [5:0] player_speed, player_2_speed;

  // one-cycle pulse, synchronous to pixclk
  logic tick;
  always_ff @(posedge pixclk) tick <= (curr_x == 0 && curr_y == 0);

  // Player 1 Movement
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

  // Player 2 Movement
  dir_t move_dir2;
  always_comb begin
    move_dir2 = DIR_NONE;
    case ({
      buttons[0], buttons[1], buttons[2], buttons[3]
    })
      4'b1000: move_dir2 = DIR_UP;
      4'b0100: move_dir2 = DIR_DOWN;
      4'b0010: move_dir2 = DIR_LEFT;
      4'b0001: move_dir2 = DIR_RIGHT;
      default: move_dir2 = DIR_NONE;
    endcase
  end

  // Player 1 Controller
  player_controller #(
      .INIT_X(64),
      .INIT_Y(64)
  ) player_ctrl_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .move_dir(move_dir),
      .player_speed(player_speed),
      .map_mem_in(map_tile_state_obst),
      .map_addr(map_addr_obst),
      .player_x(player_x),
      .player_y(player_y),
      .map_player_x(map_player_x),
      .map_player_y(map_player_y),
      .read_granted(read_granted[0]),
      .read_req(read_req[0])
  );

  player_controller #(
      .INIT_X(1088),
      .INIT_Y(576)
  ) player_ctrl_2 (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .move_dir(move_dir2),
      .player_speed(player_2_speed),
      .map_mem_in(map_tile_state_obst),
      .map_addr(map_addr_obst_2),
      .player_x(player_2_x),
      .player_y(player_2_y),
      .map_player_x(map_player_2_x),
      .map_player_y(map_player_2_y),
      .read_granted(read_granted[1]),
      .read_req(read_req[1])
  );

  // TBD Functionalities
  assign player_2_speed = 4;

  // -------------------------------------------------------- //
  // ----------------- BOMBS AND EXPLOSIONS ----------------- //
  // -------------------------------------------------------- // 
  logic [MAP_ADDR_WIDTH-1:0] wr_addr, wr_addr_bomb, wr_addr_free, saved_explosion_addr;
  logic [MAP_ADDR_WIDTH-1:0] wr_addr_bomb_2, saved_explosion_addr_2;
  logic [MAP_MEM_WIDTH-1:0] write_data, write_data_bomb, write_data_free;
  logic [MAP_MEM_WIDTH-1:0] write_data_bomb_2;
  logic we, we_bomb, we_bomb_2, we_free;

  logic trigger_explosion, explode_signal, game_over, free_blks_signal;
  logic trigger_explosion_2, explode_signal_2, game_over_2, free_blks_signal_2;

  // Write enable mux (very basic, with more bombs this needs to be an arbiter)
  assign we = (we_bomb || we_bomb_2 || we_free);
  assign wr_addr = we_bomb ? wr_addr_bomb : ((we_bomb_2) ? we_bomb_2 : wr_addr_free);
  assign write_data = we_bomb ? write_data_bomb : ((we_bomb_2) ? write_data_bomb_2 : write_data_free);


  bomb_logic bomb_logic_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .player_x(map_player_x),
      .player_y(map_player_y),
      .place_bomb(place_bomb), // ACTION button
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
      .read_granted(read_granted[2]),
      .read_req(read_req[2]),
      .read_addr(read_addr_req[2]),
      .write_addr(wr_addr_free),
      .write_data(write_data_free),
      .write_en(we_free)
  );

  // ------------------------------------------------- //
  // ----------- Player 2 Bomb Logic ----------- //
  // ------------------------------------------------- //

  bomb_logic bomb_logic_2 (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .player_x(map_player_2_x),
      .player_y(map_player_2_y),
      .place_bomb(buttons[4]), // ACTION button
      .write_addr(wr_addr_bomb_2),
      .write_data(write_data_bomb_2),
      .write_en(we_bomb_2),
      .trigger_explosion(trigger_explosion_2),
      .countdown(countdown_2),
      .countdown_signal(countdown_signal_2)
  );

  // Explosion Logic
  explode_logic explode_logic_2 (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .trigger_explosion(trigger_explosion_2),
      .explosion_addr(wr_addr_bomb_2),
      .player_x(map_player_2_x),
      .player_y(map_player_2_y),
      .saved_explosion_addr(saved_explosion_addr_2),
      .explode_signal(explode_signal_2),
      .game_over(game_over_2),
      .free_blks_signal(free_blks_signal_2)
  );


  // ---- Exit / Win condition -- WIP
//  logic last_blk, exit_present, game_win;
//  logic [ADDR_WIDTH-1:0] exit_addr;
//  exit_generator exit_generator_i (
//      .clk(pixclk),
//      .rst(rst),
//      .free_blk_signal(free_blk_signal),
//      .last_blk(last_blk),
//      .explosion_addr(saved_explosion_addr),
//      .player_x(player_x),
//      .player_y(player_y),
//      .exit_addr(exit_addr),
//      .exit_present(exit_present),
//      .game_win(game_win)
//  );

  // --------------------------------- //
  // -------- Power-up Logic --------- //
  // --------------------------------- //
  logic [MAP_ADDR_WIDTH-1:0] item_addr [0:2];
  logic item_active [0:2];
  logic player_on_item [0:2];
  logic [3:0] max_bombs;
  logic [3:0] bomb_range; 
  power_up power_up_i (
      .clk(pixclk),
      .rst(rst),
      .tick(tick),
      .we_in(we_free), // on free_blk, generate the exit with a 5% probability
      .write_addr_in(wr_addr_free),
      .write_data_in(write_data_free),
      .player_x(map_player_x),  // map_player_x
      .player_y(map_player_y),
      .probability(32'h33333333), // ~20% probability
      .item_addr(item_addr),
      .item_active(item_active),
      .player_on_item(player_on_item),
      .max_bombs(max_bombs),
      .player_speed(player_speed),
      .bomb_range(bomb_range)
  );

//  assign last_blk = 1'b0; // until implemented, disable

  // Map memory read controller (arbiter)
  // TBD: implement N readers.
  mem_multi_read_controller r_arbiter (
      .clk(pixclk),
      .rst(rst),
      .read_req(read_req),
      .read_addr_req(read_addr_req),
      .read_addr(read_addr),
      .read_granted(read_granted)
  );

  assign read_addr_req[0] = map_addr_obst;
  assign read_addr_req[1] = map_addr_obst_2;

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
      .player_1_x(player_x),
      .player_1_y(player_y),
      .player_2_x(player_2_x),
      .player_2_y(player_2_y),
      .player_1_dir(move_dir),
      .player_2_dir(move_dir2),
      .explode_signal(explode_signal),
      .explode_signal_2(explode_signal_2),
      .explosion_addr(saved_explosion_addr),
      .explosion_addr_2(saved_explosion_addr_2),
      .exit_present(1'b0),
      .exit_addr(1'b0),
      .item_active(item_active),
      .item_addr(item_addr),
      .o_r(drawcon_o_r),
      .o_g(drawcon_o_g),
      .o_b(drawcon_o_b),
      .map_addr(map_addr_drawcon)
  );

endmodule
