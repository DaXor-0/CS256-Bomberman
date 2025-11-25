// bomberman_dir.svh
`ifndef BOMBERMAN_DIR_SVH
`define BOMBERMAN_DIR_SVH

typedef enum logic [3:0] {
  DIR_NONE  = 4'b0000,
  DIR_UP    = 4'b1000,
  DIR_DOWN  = 4'b0100,
  DIR_LEFT  = 4'b0010,
  DIR_RIGHT = 4'b0001
} dir_t;


localparam int UP = 0;
localparam int DOWN = 1;
localparam int LEFT = 2;
localparam int RIGHT = 3;

`endif
