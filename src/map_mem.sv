`timescale 1ns/1ps

`include "bomberman_dir.svh"

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

    input  logic [ADDR_WIDTH-1:0] rd_addr_1,
    output logic [DATA_WIDTH-1:0] rd_data_1,
    input  logic [ADDR_WIDTH-1:0] rd_addr_2,
    output logic [DATA_WIDTH-1:0] rd_data_2,

    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data
);

    // -----------------------------
    // ROM: stores original map
    // -----------------------------
    (* ram_style = "block" *)
    logic [DATA_WIDTH-1:0] init_rom [0:DEPTH-1];

    initial begin
        if (MEM_INIT_FILE != "")
            $readmemh(MEM_INIT_FILE, init_rom);
    end

    // -----------------------------
    // RAM: actual modifiable map
    // -----------------------------
    (* ram_style = "block" *)
    logic [DATA_WIDTH-1:0] map_ram [0:DEPTH-1];


    // -----------------------------
    // Random Obstacle Generator - Using Pbits
    // -----------------------------
    logic place_dest_blk;
    localparam int TEN_PCT = 32'h7FFFFFFF; // 50%
    pbit pbit_inst (
        .Dout(place_dest_blk), // generate block condition
        .Din(TEN_PCT),    // 10% chance to output 1/True 
        .clk(clk),
        .rst(rst)
    );

    // Simple FSM to copy ROM → RAM when rst is high
    typedef enum logic {IDLE, RESET_COPY} state_t;
    state_t state;

    logic [ADDR_WIDTH-1:0] copy_idx;
    logic [DATA_WIDTH-1:0] rom_val;
    
    
    always_comb
      rom_val = init_rom[copy_idx];

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= RESET_COPY;
            copy_idx  <= '0;
        end
        else begin
            case (state)
                RESET_COPY: 
                begin
                    
                    // If ROM says no_blk (0) and RNG is high → place destroyable block (2)
                    if (rom_val == 2'd0 && place_dest_blk && (copy_idx != 20) && (copy_idx != 21) && (copy_idx != 39)
                                                          && (copy_idx != 188) && (copy_idx != 187) && (copy_idx != 169))
                        map_ram[copy_idx] <= 2'h2;   // destroyable_blk
                    else
                        map_ram[copy_idx] <= rom_val;

                    copy_idx <= copy_idx + 1;

                    if (copy_idx == DEPTH-1)
                        state <= IDLE;
                end


                IDLE: begin
                    if (we)
                        map_ram[wr_addr] <= wr_data;
                end
            endcase
        end
    end

    // synchronous reads
    always_ff @(posedge clk) begin
        rd_data_1 <= map_ram[rd_addr_1];
        rd_data_2 <= map_ram[rd_addr_2];
    end

endmodule
