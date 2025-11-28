`timescale 1ns / 1ps

module pbit(output Dout, input [31:0] Din, input clk
    );

wire [31:0] lfsr_out;

lfsr rng (
    .i_Clk(clk),
    .i_Enable(1'b1),
    .i_Seed_DV(1'b0),
    .i_Seed_Data(32'd0),
    .o_LFSR_Data(lfsr_out),
    .o_LFSR_Done(done)
);

// Output assignment
assign Dout = (Din > lfsr_out) ? 1'b1 : 1'b0;

endmodule
