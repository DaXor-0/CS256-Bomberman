`timescale 1ns/1ps

module tb_bomb_logic;

  // PARAMETERS (match DUT)
  parameter int NUM_ROW = 11;
  parameter int NUM_COL = 19;
  parameter int TILE_PX = 64;
  parameter int MAP_MEM_WIDTH = 2;
  parameter int SPRITE_W = 32;
  parameter int SPRITE_H = 64;
  parameter int BOMB_TIME_CYCLES = 3;

  localparam int DEPTH = NUM_ROW * NUM_COL;
  localparam int ADDR_WIDTH = $clog2(DEPTH);
  localparam int TILE_SHIFT = $clog2(TILE_PX);

  // SIGNALS
  logic clk;
  logic rst;
  logic tick;
  logic [10:0] player_x;
  logic [9:0] player_y;
  logic place_bomb;

  wire [1:0] state_probe;
  wire [ADDR_WIDTH-1:0] write_addr, saved_addr_probe;
  wire [MAP_MEM_WIDTH-1:0] write_data;
  wire write_en;
  wire trigger_explosion;
  wire [$clog2(BOMB_TIME_CYCLES)-1:0] countdown;

  // CLOCK GENERATION
  initial clk = 0;
  always #5 clk = ~clk;     // 100 MHz clock

  // TICK PULSE GENERATOR (1-cycle pulse every 60 clocks)
  logic [8:0] tick_count;
  always_ff @(posedge clk) begin
    if (rst) begin
      tick_count <= 0;
    end else begin
      if (tick_count == (20)) tick_count <= 0;
      else tick_count <= tick_count + 1;
    end
  end
  
  assign tick = (tick_count == 20);

  // DUT INSTANCE
  bomb_logic #(
    .NUM_ROW(NUM_ROW),
    .NUM_COL(NUM_COL),
    .TILE_PX(TILE_PX),
    .MAP_MEM_WIDTH(MAP_MEM_WIDTH),
    .SPRITE_W(SPRITE_W),
    .SPRITE_H(SPRITE_H),
    .BOMB_TIME_CYCLES(BOMB_TIME_CYCLES)
  ) dut (
    .clk(clk),
    .rst(rst),
    .tick(tick),
    .player_x(player_x),
    .player_y(player_y),
    .place_bomb(place_bomb),
    .write_addr(write_addr),
    .write_data(write_data),
    .write_en(write_en),
    .trigger_explosion(trigger_explosion),
    .countdown(countdown)
  );

  // WAVEFORM DUMPING
  initial begin
    $dumpfile("bomb_logic.vcd");
    $dumpvars(0, tb_bomb_logic);
  end

  // MAIN TEST SEQUENCE
  initial begin
    // Initialization
    rst        = 1;
    place_bomb = 0;
    player_x   = 96;   // inside tile (0,0)
    player_y   = 70;

    repeat (5) @(posedge clk);
    rst = 0;

    $display("\n--- RESET RELEASED ---");

    @(posedge clk);

    // Place bomb
    $display("[%0t] Placing bomb...", $time);
    place_bomb = 1;
    @(posedge clk);
    place_bomb = 0;

    // Check placement result
    @(posedge clk);
    player_x = 128; player_y = 64;
    $display("[%0t] write_en=%0b write_addr=%0d, saved_addr=%0d, write_data=%0d, current_state=%0d, should be == 1",
             $time, write_en, write_addr, saved_addr_probe, write_data, state_probe); // next state, should be in PLACE



    // Wait for explosion
    @(posedge clk); // wait to enter cntdown state
    // wait(tick == 1)
    repeat (1200) @(posedge clk);
    //wait(trigger_explosion == 1);
    $display("[%0t] EXPLOSION! write_en=%0b free_addr=%0d, saved_addr=%0d, current_state=%0d, should be == 3",
             $time, write_en, write_addr, saved_addr_probe, state_probe);

    // Finish a few cycles later
    repeat (10) @(posedge clk);
    
    repeat(2000) @(posedge clk);
    place_bomb = 1;
    @(posedge clk); place_bomb = 0;
    player_x = 192; player_y = 192;
    @(posedge clk); player_x = 64; player_y = 64;
    $finish;
  end

endmodule
