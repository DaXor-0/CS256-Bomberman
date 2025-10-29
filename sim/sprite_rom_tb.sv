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

    addr = 0;
    #5 $display("[%0t] addr=%0d data=%0h", $time, addr, data);

    addr = 11'd97;   // last transparent pixel on first row
    #5 $display("[%0t] addr=%0d data=%0h", $time, addr, data);

    addr = 11'd98;   // first solid pixel
    #5 $display("[%0t] addr=%0d data=%0h", $time, addr, data);

    addr = 11'd2025; // interior pixel near bottom
    #5 $display("[%0t] addr=%0d data=%0h", $time, addr, data);

    #20 $finish;
  end

endmodule
