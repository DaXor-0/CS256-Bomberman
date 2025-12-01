`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: power_up 
* Description: module that generates an item with a given probability. 
* Takes as input a write_addr from free_blks, and generates randomly the item in the freed block
**/

module power_up #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = 11,
    parameter int NUM_COL       = 19,
    parameter int TILE_PX       = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W      = 32,
    parameter int SPRITE_H      = 48,
    // ---- Bomb Parameters ----
    parameter int ITEM_TIME  = 6,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

) (
    input logic clk,
    rst,
    tick,
    game_over,
    input logic we_in, // on free_blk, generate the exit with a 5% probability
    input logic [ADDR_WIDTH-1:0] write_addr_in,
    input logic [MAP_MEM_WIDTH-1:0] write_data_in,

    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_x,  // map_player_x
    input logic [ 9:0] player_y,  // map_player_y
    input logic [31:0] probability,

    output logic [ADDR_WIDTH-1:0] item_addr [0:2], // Max 3 power-ups at a time
    output logic item_active [0:2],  // To be used by drawcon to draw the explosion
    output logic player_on_item [0:2],
    output logic [1:0] max_bombs,
    output logic [5:0] player_speed,
    output logic [1:0] bomb_range 
);

    // ------------------------------
    // -- shuffle over power-up types --
    // ------------------------------
    logic [1:0] idx;
    logic [2:0] we_in_internal;
    always_ff @(posedge clk) begin
        if (rst || game_over) begin
            idx <= 2'd0;
        end else if (we_in) begin
            if (idx == 2'd2) idx <= 0; 
            else 
            begin 
              idx <= idx + 2'd1;
            end
        end
    end

    assign we_in_internal = we_in ? (3'b001 << idx) : 3'b000;

    // ------------------------------
    // -- power-up conditions --
    // ------------------------------
    always_ff @(posedge clk) begin
        if (rst || game_over) begin
            max_bombs   <= 2'd1; // Initial max bombs
            player_speed <= 6'd4; // Initial speed
            bomb_range  <= 2'd1; // Initial bomb range
        end else begin
            // Speed up power-up
            if (player_on_item[0]) begin
                if (player_speed < 6'd25) // Cap speed increase
                    player_speed <= player_speed + 6'd4;
            end
            // Extra bomb power-up
            if (player_on_item[1]) begin
                if (max_bombs < 4'd9) // Cap max bombs
                    max_bombs <= max_bombs + 4'd1;
            end
            // Bomb range power-up
            if (player_on_item[2]) begin
                if (bomb_range < 4'd9) // Cap bomb range
                    bomb_range <= bomb_range + 4'd1;
            end
        end
    end

    // ------------------------------
    // -- item generator instances --
    // -- 0: speed up
    // -- 1: extra bomb
    // -- 2: bomb range
    // ------------------------------
    item_generator item_gen_speed_up (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .game_over(game_over),
        .we_in(we_in),
        .write_addr_in(write_addr_in),
        .write_data_in(write_data_in),
        .player_x(player_x),
        .player_y(player_y),
        .probability(probability),
        .item_addr(item_addr[0]),
        .item_active(item_active[0]),
        .player_on_item(player_on_item[0])
    );

    item_generator item_gen_extra_bomb (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .game_over(game_over),
        .we_in(1'b0),
        .write_addr_in(write_addr_in),
        .write_data_in(write_data_in),
        .player_x(player_x),
        .player_y(player_y),
        .probability(probability),
        .item_addr(item_addr[1]),
        .item_active(item_active[1]),
        .player_on_item(player_on_item[1])
    );

    item_generator item_gen_bomb_range (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .game_over(game_over),
        .we_in(1'b0),
        .write_addr_in(write_addr_in),
        .write_data_in(write_data_in),
        .player_x(player_x),
        .player_y(player_y),
        .probability(probability),
        .item_addr(item_addr[2]),
        .item_active(item_active[2]),
        .player_on_item(player_on_item[2])
    );

endmodule