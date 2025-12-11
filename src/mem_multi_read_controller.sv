`timescale 1ns/1ps

`include "bomberman_dir.svh"

module mem_multi_read_controller
#(
    // ---- NUMBER OF READERS ---- //
    // Max bombs per player = 3, 2 players, 3*2 explode readers, 2 player obst readers. 8 readers total.
    parameter int NUM_READERS = 8, 
    
    // ---- Map and tile geometry ----
    parameter int NUM_ROW     = MAP_NUM_ROW_DEF,
    parameter int NUM_COL     = MAP_NUM_COL_DEF,
    parameter int TILE_PX     = MAP_TILE_PX_DEF,
    parameter int MAP_MEM_WIDTH = MAP_MEM_WIDTH_DEF,
    parameter int SPRITE_W  = SPRITE_W_PX_DEF,
    parameter int SPRITE_H  = SPRITE_H_PX_DEF,
        

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

)(
    input  logic                   clk,
    input  logic                   rst,
    input logic game_over,
    input  logic [7:0] read_req,
    input  logic [ADDR_WIDTH-1:0]  read_addr_req [0:7],
    output logic [ADDR_WIDTH-1:0]  read_addr,
    output logic [7:0] read_granted 
);

    // --- Internal State ---
    logic idx, read_done;

    // -----------------------------------------------------------------
    typedef enum logic { IDLE, BUSY } read_state;

    read_state st, nst;

    // next state ff block
    always_ff @(posedge clk)
    if (rst || game_over) st <= IDLE;
    else st <= nst;

    // Next state logic
    always_comb
    begin
        nst = st; // State remains unchanged if no condition triggered.
        case (st)
            IDLE: if (read_req != 0) nst = BUSY; 
            BUSY: if (read_done) nst = IDLE;
        endcase
    end

    // read_granted, giving permission to read is sequentially controlled based on state 
    always_ff @(posedge clk)
    if (rst || game_over)
    begin
        read_granted <= 0;
    end 
    else 
    begin
    case (st)
      IDLE:
      begin
        casez (read_req)
          8'b1???????: read_granted <= 8'b10000000;
          8'b01??????: read_granted <= 8'b01000000;
          8'b001?????: read_granted <= 8'b00100000;
          8'b0001????: read_granted <= 8'b00010000;
          8'b00001???: read_granted <= 8'b00001000;
          8'b000001??: read_granted <= 8'b00000100;
          8'b00000010: read_granted <= 8'b00000010;
          8'b00000001: read_granted <= 8'b00000001;
          8'b00000011: read_granted <= (idx) ? 8'b00000010 : 8'b00000001;
          default: read_granted <= 8'b00000000;
        endcase
      end
      BUSY:
      if (read_done) read_granted <= 0;
    endcase
    end

    // round-robin between the two players (if both request at same time)
    
    always_ff @(posedge clk)
    if (rst || game_over) idx <= 1'b0;
    else if ((read_granted[0]) && read_done) idx <= 1;
    else if ((read_granted[1]) && read_done) idx <= 0;

    // read_addr muxing based on which read_granted bit is high
    always_comb
    begin
        read_addr = '0;
        read_done = 1'b0;
        for (int i = 0; i < NUM_READERS; i++) 
        begin
            if (read_granted[i])
            begin
                read_addr = read_addr_req[i];
                read_done = ~read_req[i];
            end
        end
    end
    //assign read_addr = (read_granted == 2'b10) ? read_addr_req[1] : (read_granted == 2'b01) ? read_addr_req[0] : 0;
    //assign read_done = (read_granted == 2'b10) ? ~read_req[1]: (read_granted == 2'b01) ? ~read_req[0] : 0;

endmodule
