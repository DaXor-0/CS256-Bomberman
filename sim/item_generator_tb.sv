`timescale 1ns/1ps

module item_generator_tb;

    // ------------------------------------------------------------
    // Parameters (match DUT)
    // ------------------------------------------------------------
    localparam NUM_ROW       = 11;
    localparam NUM_COL       = 19;
    localparam TILE_PX       = 64;
    localparam MAP_MEM_WIDTH = 2;
    localparam SPRITE_W      = 32;
    localparam SPRITE_H      = 48;
    localparam ITEM_TIME     = 2;

    localparam DEPTH         = NUM_ROW * NUM_COL;
    localparam ADDR_WIDTH    = $clog2(DEPTH);

    // ------------------------------------------------------------
    // DUT I/O
    // ------------------------------------------------------------
    logic clk, rst, tick;
    logic we_in;
    logic [ADDR_WIDTH-1:0] write_addr_in;
    logic [MAP_MEM_WIDTH-1:0] write_data_in;

    logic [10:0] player_x;
    logic [9:0]  player_y;

    logic [ADDR_WIDTH-1:0] item_addr;
    logic item_active;
    logic player_on_item;   // If your version has game_win, replace it in DUT instance

    // ------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------
    item_generator #(
        .NUM_ROW(NUM_ROW), .NUM_COL(NUM_COL),
        .TILE_PX(TILE_PX),
        .MAP_MEM_WIDTH(MAP_MEM_WIDTH),
        .SPRITE_W(SPRITE_W), .SPRITE_H(SPRITE_H),
        .ITEM_TIME(ITEM_TIME)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tick(tick),
        .we_in(we_in),
        .write_addr_in(write_addr_in),
        .write_data_in(write_data_in),

        .player_x(player_x),
        .player_y(player_y),
        .probability(32'h7FFFFFFF),

        .item_addr(item_addr),
        .item_active(item_active),
        .player_on_item(player_on_item)
    );

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;    // 100 MHz

    // Tick is 1-cycle pulse at 60 Hz equivalent (fake for TB)
    initial begin
        tick = 0;
        forever begin
            #100 tick = 1;
            #10  tick = 0;
        end
    end

    // ------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------
    initial begin
        rst = 1;
        we_in = 0;
        write_addr_in = 0;
        write_data_in = 0;
        player_x = 64;
        player_y = 64;

        repeat (5) @(posedge clk);
        rst = 0;
    end

    // ------------------------------------------------------------
    // FORCE pbit to make item generation deterministic
    // ------------------------------------------------------------
    // pbit normally outputs with 5% probability — not good for TB
    // We force generate_item = 1 whenever we_in is asserted.
    initial begin
        force dut.generate_item = 1'b1;
    end

    // ------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------
    initial begin
        @(negedge rst);

        $display("\n========== TEST: Item should be generated on free block ==========\n");

        repeat (3) @(posedge clk);

        // Trigger item creation
        we_in = 1;
        write_data_in = 0;                 // must be free block
        write_addr_in = 20;

        @(posedge clk);
        we_in = 0;

        if (!item_active) begin
            $fatal("ERROR: Item should have become ACTIVE when free block written.");
        end else begin
            $display("PASS: Item activated at address %0d", item_addr);
        end

        // --------------------------------------------------------
        // Wait for item to expire
        // --------------------------------------------------------
        $display("\n========== TEST: Item timeout ==========\n");

        wait (item_active);
        wait (!item_active);

        $display("PASS: Item expired properly after countdown.");

        // --------------------------------------------------------
        // Test player collision with item
        // --------------------------------------------------------
        $display("\n========== TEST: Player collision ==========\n");

        // Create item again
        repeat (10) @(posedge clk);
        we_in = 1;
        write_addr_in = 55;
        write_data_in = 0;
        @(posedge clk);
        we_in = 0;

        if (!item_active)
            $fatal("ERROR: Item should be active!");



        repeat (5) @(posedge clk);

        if (player_on_item)
            $display("PASS: Player detected on item.");
        else
            $fatal("ERROR: Player should have been detected on item!");

        $display("\n========== ALL TESTS PASSED ==========\n");
        $finish;
    end

endmodule
