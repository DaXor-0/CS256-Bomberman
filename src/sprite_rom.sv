`timescale 1ns / 1ps

/**
* Module: sprite_rom
* Description: Simple combinational ROM that sources sprite pixel data.
* The ROM contents are initialised from a hex text file (one 12-bit value per line).
*
* Parameters:
* - SPRITE_W / SPRITE_H: Dimensions of the sprite, used for bounds checking.
* - NUM_FRAMES: Number of animation frames stored in the ROM.
* - DATA_WIDTH: Bit width of each stored pixel entry.
* - MEM_INIT_FILE: Path to the initialisation hex file.
*/
module sprite_rom #(
    parameter  int    SPRITE_W      = 32,
    parameter  int    SPRITE_H      = 48,
    parameter  int    NUM_FRAMES    = 9,
    parameter  int    DATA_WIDTH    = 12,
    parameter  string MEM_INIT_FILE = "player_1.mem",
    localparam int    ADDR_WIDTH    = $clog2(SPRITE_W * SPRITE_H * NUM_FRAMES),
    localparam int    ROM_DEPTH     = SPRITE_W * SPRITE_H * NUM_FRAMES
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] data
);

  (* rom_style = "block" *)
  logic [DATA_WIDTH-1:0] rom[ROM_DEPTH];

  initial begin
    $readmemh(MEM_INIT_FILE, rom);
  end

  always_ff @(posedge clk) begin
    data <= rom[addr];  // 1-cycle read latency for BRAM inference
  end

endmodule
