`timescale 1ns/1ps

module sprite_rom_tb;

  logic [10:0] addr;
  logic [11:0] data;

  sprite_rom #(
      .SPRITE_W(32),
      .SPRITE_H(64),
      .DATA_WIDTH(12),
      .MEM_INIT_FILE("sprites/walk/mem/down_1.mem")
  ) dut (
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
    #20 $finish;
  end

endmodule
