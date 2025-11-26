`timescale 1ns/1ps

module sprite_rom_tb;
    
    
    parameter int    SPRITE_W      = 32;
    parameter int    SPRITE_H      = 48;
    parameter int    NUM_FRAMES    = 9;
    parameter int    DATA_WIDTH    = 12;
    parameter string MEM_INIT_FILE = "player_1.mem";

  logic [$clog2(SPRITE_W*SPRITE_H*NUM_FRAMES)-1:0] addr;
  logic [11:0] data;

  sprite_rom  dut (
      .addr(addr),
      .data(data)
  );

  initial begin
    $dumpfile("sprite_rom_tb.vcd");
    $dumpvars(0, sprite_rom_tb);

    // print all the 32x64 sprite data
    for (int y = 0; y < 64; y++) begin
      for (int x = 0; x < 32; x++) begin
      addr = y * 32 + x;
      #5; // wait for data to stabilize
      $write("%03h ", data);
      end
      $write("\n");
    end
    #20;
  end

endmodule
