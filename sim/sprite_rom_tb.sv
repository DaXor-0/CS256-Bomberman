`timescale 1ns/1ps


// Self-checking Courtesy of ChatGPT
module psprite_rom_tb;

  // ---------------- Parameters ----------------
  parameter int    SPRITE_W      = 32;
  parameter int    SPRITE_H      = 48;
  parameter int    NUM_FRAMES    = 9;
  parameter int    DATA_WIDTH    = 12;
  parameter string MEM_INIT_FILE = "player_1.mem";

  localparam int ROM_DEPTH  = SPRITE_W * SPRITE_H * NUM_FRAMES;
  localparam int ADDR_WIDTH = $clog2(ROM_DEPTH);

  // ---------------- DUT Signals ----------------
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH-1:0] data;
  int errors;
  // Instantiate DUT
  sprite_rom dut (
      .addr(addr),
      .data(data)
  );

  // ---------------- Reference Memory ----------------
  logic [DATA_WIDTH-1:0] ref_mem [0:ROM_DEPTH-1];

  // ---------------- Test Procedure ----------------
  initial begin
    // Load reference file
    $display("Loading reference memory: %s (depth=%0d)", MEM_INIT_FILE, ROM_DEPTH);
    $readmemh(MEM_INIT_FILE, ref_mem);
  end
  int fd;
  initial begin
    errors = 0;
    

    $dumpfile("sprite_rom_tb.vcd");
    $dumpvars(0, psprite_rom_tb);

    // Open output log file
    fd = $fopen("sprite_rom_compare.log", "w");
    if (!fd) begin
      $display("ERROR: Could not open output file!");
      $finish;
    end

    $fwrite(fd, "Sprite ROM comparison log\n");
    $fwrite(fd, "==========================\n\n");

    // Loop through all ROM entries
    for (int i = 0; i < ROM_DEPTH; i++) begin
      addr = i;
      #1;

      if (data !== ref_mem[i]) begin
        $fwrite(fd,
                "MISMATCH @ address %0d: expected=%03h  got=%03h\n",
                i, ref_mem[i], data);
        errors++;
      end
    end

    if (errors == 0) begin
      $display("TEST PASSED: All %0d entries match!", ROM_DEPTH);
      $fwrite(fd, "TEST PASSED: All entries match.\n");
    end else begin
      $display("TEST FAILED: %0d mismatches (see sprite_rom_compare.log).", errors);
      $fwrite(fd, "\nTEST FAILED: %0d mismatches found.\n", errors);
    end

    // Close file
    $fclose(fd);

    #10 $finish;
  end

endmodule
