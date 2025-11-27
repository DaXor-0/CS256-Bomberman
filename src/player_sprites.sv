`timescale 1ns/1ps


module player_sprites #(
    parameter  int    SPRITE_W      = 32,
    parameter  int    SPRITE_H      = 48,
    parameter  int    NUM_FRAMES    = 9,
    parameter  int    DATA_WIDTH    = 12,
    parameter  string MEM_INIT_FILE = "player_1.mem",
    localparam int    ADDR_WIDTH    = $clog2(SPRITE_W * SPRITE_H)
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [$clog2(NUM_FRAMES)-1:0] frame,
    output logic [DATA_WIDTH-1:0] data
);

  logic [DATA_WIDTH-1:0] data_temp [0:NUM_FRAMES-1];

  always_comb begin
      data = data_temp[frame];
  end

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("down_1.mem")
  ) down_1 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[0])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("down_2.mem")
  ) down_2 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[1])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("down_3.mem")
  ) down_3 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[2])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("side_1.mem")
  ) side_1 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[3])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("side_2.mem")
  ) side_2 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[4])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("side_3.mem")
  ) side_3 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[5])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("up_1.mem")
  ) up_1 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[6])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("up_2.mem")
  ) up_2 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[7])
  );

  sprite_rom #(
      .SPRITE_W(SPRITE_W),
      .SPRITE_H(SPRITE_H),
      .NUM_FRAMES(1),
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_INIT_FILE("up_3.mem")
  ) up_3 (
      .clk(clk),
      .addr(addr),
      .data(data_temp[8])
  );


endmodule