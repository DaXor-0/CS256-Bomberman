`timescale 1ns/1ps

module mem_read_controller
#(
    // ---- NUMBER OF READERS ---- //
    parameter int NUM_READERS = 2,
    
    // ---- Map and tile geometry ----
    parameter int NUM_ROW     = 11,
    parameter int NUM_COL     = 19,
    parameter int TILE_PX     = 64,
    parameter int MAP_MEM_WIDTH = 2,
    parameter int SPRITE_W  = 32,
    parameter int SPRITE_H  = 48,
        

    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)

)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic [1:0] read_req,
    input  logic [ADDR_WIDTH-1:0]  read_addr_req [0:1],
    output logic [ADDR_WIDTH-1:0]  read_addr,
    output logic [1:0]             read_granted 
);

    // --- Internal State ---

    // -----------------------------------------------------------------
    typedef enum logic { IDLE, BUSY } read_state;

    read_state st, nst;

    // next state ff block
    always_ff @(posedge clk)
    if (rst) st <= IDLE;
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
    if (rst)
    begin
        read_granted <= 0;
    end 
    else 
    begin
    case (st)
      IDLE:
      begin
        casez (read_req)
          2'b1?: 
          begin
            read_granted <= 2'b10;
          end
          2'b01: 
          begin
            read_granted <= 2'b01;
          end
          2'b00: 
          begin
            read_granted <= 0;
          end
        endcase
      end
      BUSY:
      if (read_done) read_granted <= 0;
    endcase
    end

    assign read_addr = (read_granted == 2'b10) ? read_addr_req[1] : (read_granted == 2'b01) ? read_addr_req[0] : 0;
    assign read_done = (read_granted == 2'b10) ? ~read_req[1]: (read_granted == 2'b01) ? ~read_req[0] : 0;

endmodule