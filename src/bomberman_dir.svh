// bomberman_dir.svh
`ifndef BOMBERMAN_DIR_SVH
`define BOMBERMAN_DIR_SVH


localparam int UP = 0;
localparam int DOWN = 1;
localparam int LEFT = 2;
localparam int RIGHT = 3;
localparam int BOMB_TIME = 3;

// Global map/sprite geometry defaults (single source of truth)
localparam int MAP_NUM_ROW_DEF = 11;
localparam int MAP_NUM_COL_DEF = 19;
localparam int MAP_TILE_PX_DEF = 64;
localparam int MAP_MEM_WIDTH_DEF = 2;
localparam int SPRITE_W_PX_DEF = 32;
localparam int SPRITE_H_PX_DEF = 48;

// Percentages
localparam int ten_pct = 32'h1999999A;  // 10%

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
  ITEM_STATE_ACTIVE
} item_state_t;

typedef enum logic {
  GAME_ACTIVE,
  GAME_OVER
} game_over_state_t;


typedef enum logic {
  WAIT,
  CHECK
} check_state_t;


typedef enum logic {
  READ_IDLE,
  READ_BUSY
} read_state_t;

typedef enum logic [6:0] {
  SEG_0   = 7'b0000001,
  SEG_1   = 7'b1001111,
  SEG_2   = 7'b0010010,
  SEG_3   = 7'b0000110,
  SEG_4   = 7'b1001100,
  SEG_5   = 7'b0100100,
  SEG_6   = 7'b0100000,
  SEG_7   = 7'b0001111,
  SEG_8   = 7'b0000000,
  SEG_9   = 7'b0000100,
  SEG_A   = 7'b0001000,
  SEG_B   = 7'b1100000,
  SEG_C   = 7'b0110001,
  SEG_D   = 7'b1000010,
  SEG_E   = 7'b0110000,
  SEG_F   = 7'b0111000,
  SEG_OFF = 7'b1111111
} seven_seg_t;


typedef enum int {
  HUD_ITEM_BOMB  = 0,
  HUD_ITEM_RANGE = 1,
  HUD_ITEM_SPEED = 2
} hud_item_t;

`endif
