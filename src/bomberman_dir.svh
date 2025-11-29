// bomberman_dir.svh
`ifndef BOMBERMAN_DIR_SVH
`define BOMBERMAN_DIR_SVH


localparam int UP = 0;
localparam int DOWN = 1;
localparam int LEFT = 2;
localparam int RIGHT = 3;
localparam int BOMB_TIME = 3;

// Percentages
localparam int ten_pct = 32'h1999999A; // 10%

typedef enum logic [3:0] {
  DIR_NONE  = 4'b0000,
  DIR_UP    = 4'b1000,
  DIR_DOWN  = 4'b0100,
  DIR_LEFT  = 4'b0010,
  DIR_RIGHT = 4'b0001
} dir_t;

typedef enum logic [1:0] {
  NO_BLK          = 2'd0,
  PERM_BLK        = 2'd1,
  DESTROYABLE_BLK = 2'd2,
  BOMB            = 2'd3
} map_state_t;


typedef enum logic [1:0] {
  EXP_STATE_IDLE,
  EXP_STATE_ACTIVE,
  EXP_STATE_FREE_BLOCKS
} bomb_explosion_state_t;


typedef enum logic [1:0] {
  FREE_STATE_IDLE,
  FREE_STATE_REQ_READ,
  FREE_STATE_CHECK_BLOCKS,
  FREE_STATE_CLEAR_BLOCKS
} free_blocks_state_t;


typedef enum logic [1:0] {
  BOMB_LOGIC_IDLE,
  BOMB_LOGIC_PLACE,
  BOMB_LOGIC_COUNTDOWN,
  BOMB_LOGIC_EXPLODE
} bomb_logic_state_t;

typedef enum logic [1:0] {
  ITEM_STATE_IDLE,
  ITEM_STATE_PRESENT
} item_state_t;


`endif
