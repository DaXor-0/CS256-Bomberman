`timescale 1ns / 1ps

`include "bomberman_dir.svh"

module mem_read_controller #(
    // ---- NUMBER OF READERS ---- //
    parameter int NUM_READERS = 2,

    // ---- Map and tile geometry ----
    parameter int NUM_ROW       = MAP_NUM_ROW_DEF,
    parameter int NUM_COL       = MAP_NUM_COL_DEF,
    parameter int TILE_PX       = MAP_TILE_PX_DEF,
    parameter int MAP_MEM_WIDTH = MAP_MEM_WIDTH_DEF,
    parameter int SPRITE_W      = SPRITE_W_PX_DEF,
    parameter int SPRITE_H      = SPRITE_H_PX_DEF,


    localparam int DEPTH      = NUM_ROW * NUM_COL,
    localparam int ADDR_WIDTH = $clog2(DEPTH),
    localparam int TILE_SHIFT = $clog2(TILE_PX)
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic [           1:0] read_req,
    input  logic [ADDR_WIDTH-1:0] read_addr_req[0:1],
    output logic [ADDR_WIDTH-1:0] read_addr,
    output logic [           1:0] read_granted
);

  // --- Internal State ---
  logic read_done;

  // -----------------------------------------------------------------
  read_state_t st, nst;

  // next state ff block
  always_ff @(posedge clk)
    if (rst) st <= READ_IDLE;
    else st <= nst;

  // Next state logic
  always_comb begin
    nst = st;  // State remains unchanged if no condition triggered.
    unique case (st)
      READ_IDLE: if (read_req != 0) nst = READ_BUSY;
      READ_BUSY: if (read_done) nst = READ_IDLE;
    endcase
  end

  // read_granted, giving permission to read is sequentially controlled based on state
  always_ff @(posedge clk)
    if (rst) begin
      read_granted <= 0;
    end else begin
      unique case (st)
        READ_IDLE: begin
          unique casez (read_req)
            2'b1?: begin
              read_granted <= 2'b10;
            end
            2'b01: begin
              read_granted <= 2'b01;
            end
            default: begin
              read_granted <= 0;
            end
          endcase
        end
        READ_BUSY: if (read_done) read_granted <= 0;
      endcase
    end

  assign read_addr = (read_granted == 2'b10) ?
                      read_addr_req[1] : (read_granted == 2'b01) ? read_addr_req[0] : 0;
  assign read_done = (read_granted == 2'b10) ?
                      ~read_req[1]: (read_granted == 2'b01) ? ~read_req[0] : 0;

endmodule
