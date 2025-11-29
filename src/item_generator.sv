`timescale 1ns / 1ps

`include "bomberman_dir.svh"
`include "func_player_addr.svh"

/**
* Module: item_generator 
* Description: module that generates an item with a given probability. 
* Takes as input a write_addr from free_blks, and generates randomly the item in the freed block
**/

module item_generator #(
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
    input logic we_in, // on free_blk, generate the exit with a 5% probability
    input logic [ADDR_WIDTH-1:0] write_addr_in,
    input logic [MAP_MEM_WIDTH-1:0] write_data_in,

    // input logic increase_explode_length :: to be integrated with implementation of power-up
    input logic [10:0] player_x,  // map_player_x
    input logic [ 9:0] player_y,  // map_player_y
    input logic [31:0] probability,

    output logic [ADDR_WIDTH-1:0] item_addr,
    output logic item_active,  // To be used by drawcon to draw the explosion
    output logic player_on_item
);
    
    // state defined in bomberman_dir header
    item_state_t st, nst;
    
    // -- item generation signal --
    logic generate_item;
    // -- saved_addr and player_addr
    logic [ADDR_WIDTH - 1:0] saved_addr;
    logic [ADDR_WIDTH - 1:0] player_addr;
    
    logic [5:0] second_cnt;
    logic [$clog2(ITEM_TIME)-1:0] countdown;


    // p-bit instance for random item generation
    pbit item_pbit (
        .Dout(generate_item),
        .Din(probability), // 5% probability
        .clk(clk),
        .rst(rst)
    );
    
    // ------------------------------
    // -- state register --
    // ------------------------------
    always_ff @(posedge clk) begin
        if (rst)
        st <= ITEM_STATE_IDLE;
        else
        st <= nst;
    end
    
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
            if ((countdown == 1) && (second_cnt == 6'd59)) nst = ITEM_STATE_IDLE;
        end
    
        endcase
    end
    
    
    // ------------------------------
    // -- state-dependent logic --
    // ------------------------------
    
    always_ff @(posedge clk)
    if (rst)
    begin
      saved_addr <= 0;
      countdown  <= ITEM_TIME;
      second_cnt <= 0;
    end
    else
    case (st)
      ITEM_STATE_IDLE:
      begin
        second_cnt <= 0;
        countdown  <= ITEM_TIME;
        if (we_in && (write_data_in == 2'd0) && generate_item) 
        begin
            saved_addr <= write_addr_in;
            second_cnt <= 0;
        end else saved_addr <= 0;
      end
      ITEM_STATE_ACTIVE:
      begin
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
//    logic [TILE_SHIFT:0] tile_offset_x;
//    logic [TILE_SHIFT:0] tile_offset_y;
//    logic [TILE_SHIFT:0] right_edge_offset;
//    logic [TILE_SHIFT:0] bottom_edge_offset;
//    assign tile_offset_x = {1'b0, player_x[TILE_SHIFT-1:0]};
//    assign tile_offset_y = {1'b0, player_y[TILE_SHIFT-1:0]};
//    assign right_edge_offset = tile_offset_x + (TILE_SHIFT + 1)'(SPRITE_W);
//    assign bottom_edge_offset = tile_offset_y + (TILE_SHIFT + 1)'(SPRITE_H);
//
//    // Player_x and Player_y in block (col, row)
//    logic [$clog2(NUM_ROW)-1:0] blockpos_row;
//    logic [$clog2(NUM_COL)-1:0] blockpos_col;
//    logic [$clog2(NUM_ROW)-1:0] blockpos_row2;
//    logic [$clog2(NUM_COL)-1:0] blockpos_col2;
//    assign blockpos_row = (player_y >> TILE_SHIFT);  // truncates to ROW_W
//    assign blockpos_col = (player_x >> TILE_SHIFT);  // truncates to COL_W
//    assign blockpos_row2 = (bottom_edge_offset > TILE_PX) ? blockpos_row + 1 : 0;  // Player between two blocks
//    assign blockpos_col2 = (right_edge_offset > TILE_PX) ? blockpos_col + 1 : 0;         // Player between two blocks

    // player blocks addresses
    logic [ADDR_WIDTH-1:0] blk1_addr, blk2_addr;
//    assign blk1_addr = blockpos_row * NUM_COL + blockpos_col;
//    assign blk2_addr = blockpos_row2 * NUM_COL + blockpos_col2;
    compute_player_blocks cpb_i (player_x, player_y, blk1_addr, blk2_addr);

    // ------------------------------
    // -- win condition --
    // ------------------------------
    assign player_on_item = (item_active && 
                       ((blk1_addr == item_addr) ||
                        (blk2_addr == item_addr))); // Player wins when exit is present
    
    // Exit address is the same as explosion address
    assign item_addr = saved_addr;

endmodule