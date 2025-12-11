`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: item_generator
* Description: module that generates an item with a given probability.
* Takes as input a write_addr from free_blks, and generates randomly the item in the freed block
**/

module item_generator #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = MAP_NUM_ROW_DEF,
    parameter int NUM_COL       = MAP_NUM_COL_DEF,
    parameter int TILE_PX       = MAP_TILE_PX_DEF,
    parameter int MAP_MEM_WIDTH = MAP_MEM_WIDTH_DEF,
    parameter int SPRITE_W      = SPRITE_W_PX_DEF,
    parameter int SPRITE_H      = SPRITE_H_PX_DEF,
    // ---- Bomb Parameters ----
    parameter int ITEM_TIME     = 8,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

) (
    input logic clk,
    input logic rst,
    input logic tick,
    input logic game_over,
    input logic we_in,  // on free_blk, generate the exit with a 5% probability
    input logic [ADDR_WIDTH-1:0] write_addr_in,
    input logic [MAP_MEM_WIDTH-1:0] write_data_in,

    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_1_x,  // map_player_x
    input logic [ 9:0] player_1_y,  // map_player_y
    input logic [10:0] player_2_x,  // map_player_x
    input logic [ 9:0] player_2_y,  // map_player_y
    input logic [31:0] probability,

    output logic [ADDR_WIDTH-1:0] item_addr,
    output logic item_active,  // To be used by drawcon to draw the explosion
    output logic player_1_on_item,
    output logic player_2_on_item
);

  // state defined in bomberman_dir header
  item_state_t st, nst;

  // -- item generation signal --
  logic generate_item;
  // -- saved_addr and player_addr
  logic [ADDR_WIDTH - 1:0] saved_addr;
  logic [ADDR_WIDTH - 1:0] player_1_addr;
  logic [ADDR_WIDTH - 1:0] player_2_addr;

  logic [5:0] second_cnt;
  logic [$clog2(ITEM_TIME)-1:0] countdown;


  // p-bit instance for random item generation
  pbit item_pbit (
      .Dout(generate_item),
      .Din (probability),    // 5% probability
      .clk (clk),
      .rst (rst)
  );

  // ------------------------------
  // -- state register --
  // ------------------------------
  always_ff @(posedge clk) begin
    if (rst || game_over) st <= ITEM_STATE_IDLE;
    else st <= nst;
  end

  logic player_on_item;
  assign player_on_item = player_1_on_item | player_2_on_item;

  // ------------------------------
  // -- next state logic --
  // ------------------------------
  always_comb begin
    nst = st;
    case (st)
      ITEM_STATE_IDLE: begin
        if (we_in && (write_data_in == 2'd0) && generate_item) begin
          nst = ITEM_STATE_ACTIVE;
        end
      end

      ITEM_STATE_ACTIVE: begin
        if (((countdown == 1) && (second_cnt == 6'd59)) || player_on_item) nst = ITEM_STATE_IDLE;
      end

    endcase
  end


  // ------------------------------
  // -- state-dependent logic --
  // ------------------------------

  always_ff @(posedge clk)
    if (rst || game_over) begin
      saved_addr <= 0;
      countdown  <= ITEM_TIME;
      second_cnt <= 0;
    end else
      case (st)
        ITEM_STATE_IDLE: begin
          second_cnt <= 0;
          countdown  <= ITEM_TIME;
          if (we_in && (write_data_in == 2'd0) && generate_item) begin
            saved_addr <= write_addr_in;
            second_cnt <= 0;
          end else saved_addr <= 0;
        end
        ITEM_STATE_ACTIVE: begin
          if (tick) begin
            if (second_cnt == 59) begin
              second_cnt <= 0;
              countdown <= countdown - 1; // no need for if (countdown == 0), as it is handled in the next_state logic
            end else second_cnt <= second_cnt + 1;
          end
        end
      endcase
  // ------------------------------
  // -- output logic --
  // ------------------------------
  assign item_active = (st == ITEM_STATE_ACTIVE);

  // ------------------------------
  // -- player blk computation logic --
  // ------------------------------
  // Player_x and Player_y in block (col, row)
  // player blocks addresses
  logic [ADDR_WIDTH-1:0] p1_blk1_addr, p1_blk2_addr, p2_blk1_addr, p2_blk2_addr;
  compute_player_blocks cpb_i (
      player_1_x,
      player_1_y,
      p1_blk1_addr,
      p1_blk2_addr
  );
  compute_player_blocks cpb_2 (
      player_2_x,
      player_2_y,
      p2_blk1_addr,
      p2_blk2_addr
  );

  // ------------------------------
  // -- win condition --
  // ------------------------------
  assign player_1_on_item = (item_active && 
                       ((p1_blk1_addr == item_addr) ||
                        (p1_blk2_addr == item_addr))); // Player wins when exit is present
  assign player_2_on_item = (item_active && 
                       ((p2_blk1_addr == item_addr) ||
                        (p2_blk2_addr == item_addr))); // Player wins when exit is present

  // Exit address is the same as explosion address
  assign item_addr = saved_addr;

endmodule
