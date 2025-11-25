`timescale 1ns / 1ps

/**
* Module: sprite_rom
* Description: Simple combinational ROM that sources sprite pixel data.
* The ROM contents are initialised from a hex text file (one 12-bit value per line).
*
* Parameters:
* - SPRITE_W / SPRITE_H: Dimensions of the sprite, used for bounds checking.
* - DATA_WIDTH: Bit width of each stored pixel entry.
* - MEM_INIT_FILE: Path to the initialisation hex file.
*/
module sprite_rom #(
    parameter int SPRITE_W = 32,
    parameter int SPRITE_H = 48,
    parameter int DATA_WIDTH = 12,
    parameter string MEM_INIT_FILE = "",
    localparam int DEPTH = SPRITE_W * SPRITE_H,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] data
);

  (* rom_style = "distributed" *)
  logic [DATA_WIDTH-1:0] mem[0:DEPTH-1];

  initial begin
    if (MEM_INIT_FILE != "") begin
      $readmemh(MEM_INIT_FILE, mem);
    end
  end

  assign data = mem[addr];

endmodule
