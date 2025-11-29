`timescale 1ns / 1ps

`include "bomberman_dir.svh"

/**
* Module: free_blocks
* Description: receives an input signal from free_blocks, and an input address,
* then checks the blocks around the given address and writes over destroyable_blks to make them no_blk
**/

module free_blocks #(
    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = 11,
    parameter int NUM_COL       = 19,
    parameter int TILE_PX       = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W      = 32,
    parameter int SPRITE_H      = 48,
    // ---- Bomb Parameters ----
    parameter int EXPLODE_TIME  = 1,

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

) (
    input logic clk,
    rst,
    tick,
    input logic free_blks_signal,
    input logic [ADDR_WIDTH-1:0] explosion_addr,
    input logic [MAP_MEM_WIDTH-1:0] map_mem_in,
    input logic read_granted,

    output logic read_req,
    output logic [ADDR_WIDTH-1:0] read_addr,
    output logic [ADDR_WIDTH-1:0] write_addr,
    output logic [MAP_MEM_WIDTH-1:0] write_data,
    output logic write_en
);

  // -----------------------------------------------------------------
  // -- FSM for the explosion logic, explosion_state --
  // -----------------------------------------------------------------
  free_blocks_state_t st, nst;

  // next state ff block
  always_ff @(posedge clk)
    if (rst) st <= IDLE;
    else st <= nst;

  // Next state logic
  always_comb begin
    nst = st;  // State remains unchanged if no condition triggered.
    case (st)
      IDLE: if (free_blks_signal) nst = REQ_READ;
      REQ_READ: if (read_granted) nst = CHECK_BLOCKS;
      CHECK_BLOCKS: if (check_done) nst = CLEAR_BLOCKS;
      CLEAR_BLOCKS: if (free_done) nst = IDLE;
      default: nst = IDLE;
    endcase
  end

  // -----------------------------------------------------------------
  // -- Sequential elements (counters, registers) control per state
  // -----------------------------------------------------------------
  logic [ADDR_WIDTH-1:0] saved_explosion_addr;
  logic [3:0] blk_status;
  logic [1:0] dir_cnt, dir_a;


  always_ff @(posedge clk)
    if (rst) begin
      saved_explosion_addr <= 0;
      dir_cnt <= 0;
      dir_a <= 0;
      blk_status <= 0;
    end else begin
      case (st)
        IDLE: begin
          if (free_blks_signal) begin
            saved_explosion_addr <= explosion_addr;
          end else dir_cnt <= 0;
          blk_status <= 0;
        end
        REQ_READ: begin
          // Waiting for read to be granted
          if (read_granted) begin
            dir_cnt <= dir_cnt + 1;
            dir_a   <= dir_cnt;
          end
        end
        CHECK_BLOCKS: begin
          if (dir_cnt != 2'b0) dir_cnt <= dir_cnt + 1;
          dir_a <= dir_cnt;
          if (map_mem_in == 2'd2) blk_status[dir_a] <= 1'b1;  // Mark as needs to be free
        end
        CLEAR_BLOCKS: begin
          dir_cnt <= dir_cnt + 1;
        end
      endcase
    end

  // Addresses
  assign read_addr = (dir_cnt == UP) ? explosion_addr - NUM_COL :  // UP
      (dir_cnt == DOWN) ? saved_explosion_addr + NUM_COL :  // DOWN
      (dir_cnt == LEFT) ? saved_explosion_addr - 1 :  // LEFT
      saved_explosion_addr + 1;  // RIGHT
  assign write_addr = (dir_cnt == UP) ? saved_explosion_addr - NUM_COL :  // UP
      (dir_cnt == DOWN) ? saved_explosion_addr + NUM_COL :  // DOWN
      (dir_cnt == LEFT) ? saved_explosion_addr - 1 :  // LEFT
      saved_explosion_addr + 1;  // RIGHT
  // Control signals
  assign check_done = ((st == CHECK_BLOCKS) && (dir_cnt == 2'b00));
  assign free_done = ((st == CLEAR_BLOCKS) && (dir_cnt == 2'b11));
  assign write_data = 2'b0;  // write a free_blk
  assign write_en = ((st == CLEAR_BLOCKS) && blk_status[dir_cnt]);
  assign read_req = ((st == REQ_READ) || (st == CHECK_BLOCKS));

endmodule
