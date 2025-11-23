`timescale 1ns/1ps

/**
* Module: map_mem
* Description: Simple synchronous tile map memory backed by block RAM.
* Provides a read port for the renderer and a write port for gameplay logic.
*
* MAP STATES: {no_blk, perm_blk, destroyable_blk, bomb}
* Parameters:
* - NUM_ROW / NUM_COL: Dimensions of the tile grid.
* - DATA_WIDTH: Width of each tile entry.
* - MEM_INIT_FILE: Optional hex file used to initialise the memory.
*
* no_blk          = 2'd0,
* perm_blk        = 2'd1,
* destroyable_blk = 2'd2,
* bomb            = 2'd3
*/
module map_mem #(
    parameter int NUM_ROW = 11,
    parameter int NUM_COL = 19,
    parameter int DATA_WIDTH = 2,
    parameter string MEM_INIT_FILE = "maps/basic_map.mem",
    localparam int DEPTH = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                 clk,
    input  logic                 rst,
    input  logic[ADDR_WIDTH-1:0] rd_addr_1,
    output logic[DATA_WIDTH-1:0] rd_data_1,
    input  logic[ADDR_WIDTH-1:0] rd_addr_2,
    output logic[DATA_WIDTH-1:0] rd_data_2,
    input  logic                 we,
    input  logic[ADDR_WIDTH-1:0] wr_addr,
    input  logic[DATA_WIDTH-1:0] wr_data
);

  (* ram_style = "block" *)
  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1]; // 4-bit states for the map

  // Initialise the memory if a file is provided.
  initial begin
    if (MEM_INIT_FILE != "") begin
      $readmemh(MEM_INIT_FILE, mem);
    end
  end

  always_ff @(posedge clk) begin
    if (we)
        mem[wr_addr] <= wr_data;

    if (rst) begin
        rd_data_1 <= '0;
        rd_data_2 <= '0;
    end else begin
        rd_data_1 <= mem[rd_addr_1];
        rd_data_2 <= mem[rd_addr_2];
    end
end


endmodule
