# Bomberman on FPGA (Nexys A7, SystemVerilog)

Hardware remake of Bomberman that runs entirely on a Digilent Nexys A7-100T. It drives a 1280×800 VGA display, uses on-board push buttons for Player 1, and a UART link (e.g. Raspberry Pi + USB gamepad) for Player 2. Bomb timers are mirrored on the 7‑segment display, and a HUD shows power-up levels and game-over overlay.

![Map preview](https://github.com/user-attachments/assets/6c0356c9-8dca-4066-b6f7-fc473e838543)

## What’s here
- 2-player game logic: Player 1 on board buttons, Player 2 over UART (115200 8N1, bits [0:4] = up, down, left, right, action). LEDs [0:4] mirror the received UART buttons for debug.
- VGA renderer at 1280×800: centered 19×11 tile map (64 px tiles) with a 32 px side HUD border and 96 px top bar, animated sprites, explosions, and a game-over overlay.
- Bombs and explosions: 3 s fuse, 1 s explosion animation, clears adjacent destroyable blocks; map regenerates from ROM on reset and randomizes extra destroyable tiles while keeping spawn tiles free.
- Power-ups: speed works end-to-end; extra bomb and range are spawned, tracked, and drawn in the HUD but their gameplay effects aren’t wired into bomb logic yet.
- 7-seg display: shows active bomb countdowns for each player (digits 0 and 4).
- Test benches for movement, memory arbitration, draw pipeline, and top-level smoke test.
- Asset/scripts: sprite and map `.mem` files plus Python helpers to convert PNG ↔ mem/COE.

## To Run a fast Simulation
If you have Verilator and SFLM, you can run a fast simulation with:
- `make -C sim/verilator`
- `./sim/verilator/obj_dir/game_top`

Credits to [Flinner](https://ammar.engineer/posts/2024/12/04/pacman-on-an-fpga-in-systemverilog/) for the idea.

## Repository layout
- `src/` – SystemVerilog RTL (top: `game_top`). Includes rendering (`drawcon*`, `sprite_rom`, `vga_out`), gameplay (`player_controller`, `bomb_logic`, `explode_logic`, `free_blocks`, `power_up`), map storage (`map_mem`, `mem_multi_read_controller`), I/O (`uart_rx`, `multidigit`), and shared constants (`bomberman_dir.svh`).
- `sim/` – Test benches (`*_tb.sv`) and sample VVP/VCD outputs.
- `maps/` – Default map (`basic_map.mem`, 19×11 entries; 0=empty, 1=solid, 2=destroyable, 3=bomb runtime only).
- `sprites/` – Pre-converted sprite ROMs (player, bombs, blocks, power-ups, HUD, game-over).
- `tools/` – Python utilities for sprite/map conversion (`png2mem.py`, `mem2png.py`, `mem2coe.py`, etc.).
- `constr/` – Nexys A7 XDC with pin mappings (VGA, buttons, LEDs, 7-seg, optional UART RX on JA1).
- `bit/` – Prebuilt bitstreams from various iterations (`bit/game_top.bit` is a clean top-level build; others are historical).
- `src-rp5/` – Raspberry Pi helper to read a USB gamepad and feed Player 2 over UART (see that README for wiring).

## Build & program (Vivado)
1. Target board/part: Nexys A7-100T
2. Add all sources from `src/` (keep `bomberman_dir.svh` on the include path). Top module: `game_top`. The design uses the Xilinx Clocking Wizard IP `clk_wiz_0` to derive an ~83.456 MHz pixel clock from 100 MHz. A sim-only stub lives at `src/clk_wiz_0.v` (wrapped in `ifndef SYNTHESIS`); Vivado must regenerate the real IP, otherwise synthesis will error out due to the missing module.
3. Add memory init files: `maps/basic_map.mem` and the sprite `.mem` files under `sprites/**/mem/`. Mark them as “Memory Initialization Files” so Vivado packs them into BRAM.
4. Use `constr/nexys-a7-100t-master.xdc`. Ensure the button mappings (up/down/left/right/place_bomb), VGA pins, 7‑seg, and LEDs are enabled. Uncomment the `uart_rx` pin (JA1, PACKAGE_PIN C17) if you use Player 2 over UART.
5. Synthesize/implement and generate a bitstream. A ready-made image is available at `bit/game_top.bit` if you just want to program the board.

### Controls on hardware
- Player 1: `btnu`, `btnd`, `btnl`, `btnr`, `btnc` → up/down/left/right/place bomb.
- Player 2: UART RX (`uart_rx`) expects bits 0–4 = up, down, left, right, action at 115200 baud.
- LEDs: that mirror player 2 button presses.
- Reset: `CPU_RESETN` (active low). After a game over, pressing `down` starts a new round.
- 7‑seg: digits 0 and 4 show active bomb countdowns for P1/P2.

## Simulation (iverilog/Verilator)
- Run from the repo root so relative `.mem` paths resolve (e.g., `basic_map.mem`).
- Example (check obstacles TB):
  ```bash
  iverilog -g2012 -I src \
    sim/check_obst_tb.sv \
    src/check_obst.sv src/mem_read_controller.sv src/compute_player_blocks.sv \
    src/bomberman_dir.svh -o sim/check_obst_tb.vvp
  vvp sim/check_obst_tb.vvp
  gtkwave check_obst_tb.vcd &
  ```
- Example (top-level smoke TB with stubbed clock wizard):
  ```bash
  iverilog -g2012 -I src sim/game_top_tb.sv src/*.sv -o sim/game_top_tb.vvp
  vvp sim/game_top_tb.vvp
  ```
  If your simulator lacks Xilinx primitives, exclude `src/clk_wiz_0.v` because the TB already provides a stub.
- Verilator build artifacts for `check_obst_tb` and `player_controller_tb` are in `obj_dir/` as a reference.

## Assets & customization
- Map: `maps/basic_map.mem` is row-major (row 0, col 0 = top-left). On reset, `map_mem` copies this ROM into RAM and randomly turns some empty tiles into destroyable blocks while keeping spawn tiles clear (see hardcoded excludes in `map_mem.sv`).
- Sprite pipeline expects 12-bit RGB444 words in `.mem` files. Transparency is encoded as `F0F`.
- Conversion helpers:
  - `tools/png2mem.py <in.png> <out.mem> --sprites N --width W --height H [--background auto|none|R,G,B]`
  - `tools/mem2png.py <in.mem> <out.png> --sprites N --width W --height H [--background R,G,B]`
  - `tools/mem2coe.py` for Xilinx COE exports; `mem2png.py` is handy for visually validating assets.

## Player 2 over Raspberry Pi (optional)
- `src-rp5/gamepad.py` reads a USB gamepad with `evdev` and streams the button byte over `/dev/serial0` to the FPGA. Wiring: Pi GPIO14 (pin 8) → JA1 (`uart_rx`), and GND → GND. Enable UART on the Pi and install deps per `src-rp5/README.md`.

## Key modules at a glance
- `game_top`: ties inputs, timers, VGA pipeline, map BRAM, and gameplay FSMs together.
- `player_controller` + `check_obst`: converts screen coords to map space, checks tile collisions via `mem_multi_read_controller`.
- `bomb_logic` / `explode_logic` / `free_blocks`: place bombs, animate explosions, clear destroyable tiles.
- `power_up` + `item_generator`: spawn/track speed, bomb-count, and range power-ups with level caps and HUD feedback (only speed currently affects gameplay; bomb-count/range are HUD-only until wired in).
- `drawcon` (+ `drawcon_anim`, `drawcon_hud`, `drawcon_player_sprite`, `drawcon_gameover`): full renderer for tiles, sprites, explosions, power-ups, and overlay.
- `map_mem`: dual-port BRAM-backed map with reset-to-ROM and RNG-based block placement.
- `uart_rx`: 115200 baud receiver for Player 2 controls.
- `multidigit` / `sevenseg`: 8-digit scan for bomb countdown display.

## Geometry reference
- Screen: 1280×800
- Map: 19 cols × 11 rows, 64 px tiles → 1216×704 playfield
- HUD offset: 32 px left/right, 96 px top, 0 px bottom
- Player sprites: 32×48 px
- Bomb fuse: 3 s (`BOMB_TIME`), explosion animation: 1 s
