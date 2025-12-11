`timescale 1ns/1ps

`include "bomberman_dir.svh"

module power_up_tb;

    // ------------------------------------------------------------
    // Parameters (match DUT)
    // ------------------------------------------------------------
    localparam NUM_ROW       = 11;
    localparam NUM_COL       = 19;
    localparam TILE_PX       = 64;
    localparam MAP_MEM_WIDTH = 2;
    localparam SPRITE_W      = 32;
    localparam SPRITE_H      = 48;
    localparam ITEM_TIME     = 2;

    localparam DEPTH         = NUM_ROW * NUM_COL;
    localparam ADDR_WIDTH    = $clog2(DEPTH);

    // ------------------------------------------------------------
    // DUT I/O
    // ------------------------------------------------------------
    logic clk, rst, tick, game_over;
    logic we_in;
    logic [ADDR_WIDTH-1:0] write_addr_in;
    logic [MAP_MEM_WIDTH-1:0] write_data_in;

    logic [10:0] player_1_x, player_2_x;
    logic [9:0]  player_1_y, player_2_y;

    logic [ADDR_WIDTH-1:0] item_addr [0:2];
    logic [2:0] item_active;
    logic [1:0] max_bombs_p1, max_bombs_p2;
    logic [5:0] player_speed_p1, player_speed_p2;
    logic [1:0] bomb_range_p1, bomb_range_p2;
    logic [1:0] p1_bomb_level, p1_speed_level, p1_range_level;
    logic [1:0] p2_bomb_level, p2_speed_level, p2_range_level;

    // ------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------
    power_up #(
        .NUM_ROW(NUM_ROW), .NUM_COL(NUM_COL),
        .TILE_PX(TILE_PX),
        .MAP_MEM_WIDTH(MAP_MEM_WIDTH),
        .SPRITE_W(SPRITE_W), .SPRITE_H(SPRITE_H),
        .ITEM_TIME(ITEM_TIME)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .game_over(game_over),
        .we_in(we_in),
        .write_addr_in(write_addr_in),
        .write_data_in(write_data_in),

        .player_1_x(player_1_x),
        .player_1_y(player_1_y),
        .player_2_x(player_2_x),
        .player_2_y(player_2_y),
        .probability(32'hFFFFFFFF), // Always generate for testing

        .item_addr(item_addr),
        .item_active(item_active),
        .max_bombs_p1(max_bombs_p1),
        .player_speed_p1(player_speed_p1),
        .bomb_range_p1(bomb_range_p1),
        .max_bombs_p2(max_bombs_p2),
        .player_speed_p2(player_speed_p2),
        .bomb_range_p2(bomb_range_p2),
        .p1_bomb_level(p1_bomb_level),
        .p2_bomb_level(p2_bomb_level),
        .p1_speed_level(p1_speed_level),
        .p2_speed_level(p2_speed_level),
        .p1_range_level(p1_range_level),
        .p2_range_level(p2_range_level)
    );

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;    // 100 MHz

    // Tick generation
    initial begin
        tick = 0;
        forever begin
            #100 tick = 1;
            #10  tick = 0;
        end
    end

    // ------------------------------------------------------------
    // Testbench procedure with scenarios
    // ------------------------------------------------------------
    initial begin
        // ------------------------------
        // Reset
        // ------------------------------
        rst = 1;
        game_over = 0;
        we_in = 0;
        write_addr_in = 0;
        write_data_in = 0;
        player_1_x = 64;
        player_1_y = 64;
        player_2_x = 0;
        player_2_y = 0;
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst = 0;

        // ------------------------------
        // Scenario 1: Generate first power-up (speed)
        // ------------------------------
        $display("Scenario 1: Generate speed power-up");
        we_in = 1;
        write_addr_in = 20;
        write_data_in = 0; // Free block
        @(negedge clk);
        we_in = 0;

        // Move player to pick up the item
        player_1_x = 64;
        player_1_y = 64;
        repeat(5) @(posedge clk);

        if (p1_speed_level > 0)
            $display("PASS: Player picked up speed power-up (level=%0d, speed=%0d)", p1_speed_level, player_speed_p1);
        else
            $display("FAIL: Player did not pick up speed power-up");

        // ------------------------------
        // Scenario 2: Generate extra bomb
        // ------------------------------
        $display("Scenario 2: Generate extra bomb power-up");
        we_in = 1;
        write_addr_in = 21;
        write_data_in = 0;
        repeat (2) @(negedge clk);
        we_in = 0;

        player_1_x = 128; // Move player to new block
        player_1_y = 64;
        repeat(5) @(posedge clk);

        if (p1_bomb_level > 0)
            $display("PASS: Player picked up extra bomb, max_bombs_p1 = %0d", max_bombs_p1);
        else
            $display("FAIL: Player did not pick up extra bomb");

        // ------------------------------
        // Scenario 3: Generate bomb range
        // ------------------------------
        $display("Scenario 3: Generate bomb range power-up");
        we_in = 1;
        write_addr_in = 39;
        write_data_in = 0;
        repeat (2) @(negedge clk);
        we_in = 0;

        player_1_x = 64;
        player_1_y = 128;
        repeat(5) @(posedge clk);

        if (p1_range_level > 0)
            $display("PASS: Player picked up bomb range power-up, bomb_range_p1 = %0d", bomb_range_p1);
        else
            $display("FAIL: Player did not pick up bomb range");

        // ------------------------------
        // Scenario 4: Multiple pickups
        // ------------------------------
        $display("Scenario 4: Multiple pickups sequentially");
        write_addr_in = 40; write_data_in = 0; we_in = 1; @(negedge clk); we_in = 0;
        player_1_x = 64; player_1_y = 64; repeat(5) @(posedge clk);
        player_1_x = 128; player_1_y = 64; repeat(5) @(posedge clk);
        player_1_x = 64; player_1_y = 128; repeat(5) @(posedge clk);

        $display("Player_speed_p1 = %0d, max_bombs_p1 = %0d, bomb_range_p1 = %0d", player_speed_p1, max_bombs_p1, bomb_range_p1);

        $display("All scenarios done");
        $stop;
    end
endmodule
