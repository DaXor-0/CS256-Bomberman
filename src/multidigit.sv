`timescale 1ns / 1ps


module multidigit(
  input logic clk, rst,
  input logic [3:0] dig0, dig1, dig2, dig3, dig4, dig5, dig6, dig7,
  output logic a, b, c, d, e, f, g,
  output logic [7:0] an
  );
  
  // 3-bit counter to select the current 7seg
  logic [2:0] counter;
  logic [3:0] dig;
  
  always_ff @(posedge clk)
    if (rst) counter <= 0;
    else counter <= counter + 1;
  
  
  // 7seg instantiations
  sevenseg s0 (dig, a, b, c, d, e, f, g);
    
always_comb 
begin
  case (counter)
    3'd0: begin an = 8'b11111110; dig = dig0; end
    3'd1: begin an = 8'b11111101; dig = dig1; end
    3'd2: begin an = 8'b11111011; dig = dig2; end
    3'd3: begin an = 8'b11110111; dig = dig3; end
    3'd4: begin an = 8'b11101111; dig = dig4; end
    3'd5: begin an = 8'b11011111; dig = dig5; end
    3'd6: begin an = 8'b10111111; dig = dig6; end
    3'd7: begin an = 8'b01111111; dig = dig7; end
  endcase
end
  
endmodule