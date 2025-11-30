// UART receiver
// CLKS_PER_BIT sets the number of clk cycles per UART bit (baud tick).
// rx_dv pulses high for one clk when a full byte is received on rx_byte.
module uart_rx #(
    parameter int CLKS_PER_BIT = 868
) (
    input  wire       clk,
    input  wire       rx,
    output reg        rx_dv,
    output reg  [7:0] rx_byte
);

  typedef enum logic [2:0] {
    S_IDLE,
    S_START,
    S_DATA,
    S_STOP
  } state_t;

  state_t       state = S_IDLE;
  logic   [9:0] clk_cnt = '0;
  logic   [2:0] bit_idx = '0;
  logic   [7:0] byte_reg = '0;

  // Double-flop synchronizer to bring async RX into clk domain
  logic rx_sync_1 = 1'b1, rx_sync_2 = 1'b1;
  always_ff @(posedge clk) begin
    rx_sync_1 <= rx;
    rx_sync_2 <= rx_sync_1;
  end

  always_ff @(posedge clk) begin
    rx_dv <= 1'b0;

    unique case (state)
      S_IDLE: begin  // wait for start bit (line goes low)
        clk_cnt <= '0;
        bit_idx <= '0;
        if (rx_sync_2 == 1'b0)  // start bit
          state <= S_START;
      end

      S_START: begin  // sample in middle of start bit to confirm low
        if (clk_cnt == (CLKS_PER_BIT - 1) / 2) begin
          if (rx_sync_2 == 1'b0) begin
            clk_cnt <= '0;
            state   <= S_DATA;
          end else begin
            state <= S_IDLE;  // false start
          end
        end else begin
          clk_cnt <= clk_cnt + 1;
        end
      end

      S_DATA: begin  // sample one data bit per CLKS_PER_BIT period, LSB first
        if (clk_cnt < CLKS_PER_BIT - 1) begin
          clk_cnt <= clk_cnt + 1;
        end else begin
          clk_cnt           <= '0;
          byte_reg[bit_idx] <= rx_sync_2;
          if (bit_idx < 3'd7) bit_idx <= bit_idx + 1;
          else begin
            bit_idx <= '0;
            state   <= S_STOP;
          end
        end
      end

      S_STOP: begin  // wait one stop-bit period, then flag byte valid
        if (clk_cnt < CLKS_PER_BIT - 1) begin
          clk_cnt <= clk_cnt + 1;
        end else begin
          clk_cnt <= '0;
          rx_byte <= byte_reg;
          rx_dv   <= 1'b1;
          state   <= S_IDLE;
        end
      end

    endcase
  end

endmodule