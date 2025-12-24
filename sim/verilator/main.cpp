#include <SFML/Graphics.hpp>
#include <verilated.h>

#include <cstdint>
#include <deque>

#include "Vgame_top.h"

namespace {
constexpr int kWidth = 1280;
constexpr int kHeight = 800;
constexpr int kScale = 1;
constexpr int kStepsPerLoop = 5000;
constexpr int kUartClksPerBit = 868;
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  Vgame_top dut;
  dut.CPU_RESETN = 0;
  dut.uart_rx = 1;

  sf::RenderWindow window(
      sf::VideoMode(sf::Vector2u(kWidth * kScale, kHeight * kScale)),
      "Bomberman (Verilator + SFML)");
  window.setFramerateLimit(60);

  sf::Texture texture(sf::Vector2u(kWidth, kHeight));
  sf::Sprite sprite(texture);
  sprite.setScale(sf::Vector2f(static_cast<float>(kScale), static_cast<float>(kScale)));

  std::vector<std::uint8_t> pixels(static_cast<size_t>(kWidth) * kHeight * 4, 0);

  bool p1_up = false;
  bool p1_down = false;
  bool p1_left = false;
  bool p1_right = false;
  bool p1_bomb = false;

  bool p2_up = false;
  bool p2_down = false;
  bool p2_left = false;
  bool p2_right = false;
  bool p2_bomb = false;

  std::deque<uint8_t> uart_queue;
  uint8_t uart_last_byte = 0;
  bool uart_active = false;
  int uart_bit_idx = 0;
  int uart_bit_ticks = 0;
  uint8_t uart_shift = 0;
  bool uart_line = true;

  bool pix_prev = false;
  bool frame_ready = false;
  int reset_cycles = 40;
  vluint64_t sim_time = 0;
  bool sent_initial_p2 = false;

  auto queue_p2_uart = [&]() {
    uint8_t byte = 0;
    if (p2_up) byte |= 1u << 0;
    if (p2_down) byte |= 1u << 1;
    if (p2_left) byte |= 1u << 2;
    if (p2_right) byte |= 1u << 3;
    if (p2_bomb) byte |= 1u << 4;
    if (byte != uart_last_byte) {
      uart_queue.push_back(byte);
      uart_last_byte = byte;
    }
  };

  auto uart_step = [&]() {
    if (!uart_active) {
      if (!uart_queue.empty()) {
        uart_shift = uart_queue.front();
        uart_queue.pop_front();
        uart_active = true;
        uart_bit_idx = -1;  // start bit
        uart_bit_ticks = kUartClksPerBit;
      } else {
        uart_line = true;
        return;
      }
    }

    if (uart_bit_ticks == 0) {
      uart_bit_idx++;
      uart_bit_ticks = kUartClksPerBit;
      if (uart_bit_idx >= 8) {
        if (uart_bit_idx == 8) {
          uart_line = true;  // stop bit
        } else {
          uart_active = false;
          uart_line = true;
          return;
        }
      }
    }

    if (uart_active) {
      if (uart_bit_idx < 0) {
        uart_line = false;  // start bit
      } else if (uart_bit_idx < 8) {
        uart_line = (uart_shift >> uart_bit_idx) & 0x1;
      } else {
        uart_line = true;
      }
      uart_bit_ticks--;
    }
  };

  auto tick = [&]() {
    uart_step();
    dut.uart_rx = uart_line;

    dut.CLK100MHZ = 0;
    dut.eval();
    sim_time++;

    dut.CLK100MHZ = 1;
    dut.eval();
    sim_time++;

    const bool pix_now = dut.pix_clk;
    if (pix_now && !pix_prev) {
      if (dut.display_enabled) {
        const int x = static_cast<int>(dut.sx);
        const int y = static_cast<int>(dut.sy);
        if (x >= 0 && x < kWidth && y >= 0 && y < kHeight) {
          const size_t idx = (static_cast<size_t>(y) * kWidth + x) * 4;
          pixels[idx + 0] = static_cast<std::uint8_t>(dut.o_pix_r * 17);
          pixels[idx + 1] = static_cast<std::uint8_t>(dut.o_pix_g * 17);
          pixels[idx + 2] = static_cast<std::uint8_t>(dut.o_pix_b * 17);
          pixels[idx + 3] = 255;

          if (x == kWidth - 1 && y == kHeight - 1) {
            frame_ready = true;
          }
        }
      }
    }

    pix_prev = pix_now;
  };

  while (window.isOpen() && !Verilated::gotFinish()) {
    while (auto event = window.pollEvent()) {
      if (event->is<sf::Event::Closed>()) {
        window.close();
      } else if (const auto* key = event->getIf<sf::Event::KeyPressed>()) {
        if (key->code == sf::Keyboard::Key::W) p1_up = true;
        if (key->code == sf::Keyboard::Key::S) p1_down = true;
        if (key->code == sf::Keyboard::Key::A) p1_left = true;
        if (key->code == sf::Keyboard::Key::D) p1_right = true;
        if (key->code == sf::Keyboard::Key::Space) p1_bomb = true;
        if (key->code == sf::Keyboard::Key::Up) p2_up = true;
        if (key->code == sf::Keyboard::Key::Down) p2_down = true;
        if (key->code == sf::Keyboard::Key::Left) p2_left = true;
        if (key->code == sf::Keyboard::Key::Right) p2_right = true;
        if (key->code == sf::Keyboard::Key::Enter) p2_bomb = true;
        queue_p2_uart();
      } else if (const auto* key = event->getIf<sf::Event::KeyReleased>()) {
        if (key->code == sf::Keyboard::Key::W) p1_up = false;
        if (key->code == sf::Keyboard::Key::S) p1_down = false;
        if (key->code == sf::Keyboard::Key::A) p1_left = false;
        if (key->code == sf::Keyboard::Key::D) p1_right = false;
        if (key->code == sf::Keyboard::Key::Space) p1_bomb = false;
        if (key->code == sf::Keyboard::Key::Up) p2_up = false;
        if (key->code == sf::Keyboard::Key::Down) p2_down = false;
        if (key->code == sf::Keyboard::Key::Left) p2_left = false;
        if (key->code == sf::Keyboard::Key::Right) p2_right = false;
        if (key->code == sf::Keyboard::Key::Enter) p2_bomb = false;
        queue_p2_uart();
      }
    }

    if (reset_cycles > 0) {
      dut.CPU_RESETN = 0;
      reset_cycles--;
    } else {
      dut.CPU_RESETN = 1;
    }

    if (dut.CPU_RESETN && !sent_initial_p2) {
      queue_p2_uart();
      sent_initial_p2 = true;
    }

    dut.up = p1_up;
    dut.down = p1_down;
    dut.left = p1_left;
    dut.right = p1_right;
    dut.place_bomb = p1_bomb;

    for (int i = 0; i < kStepsPerLoop; ++i) {
      tick();
    }

    if (frame_ready) {
      texture.update(pixels.data(), sf::Vector2u(kWidth, kHeight), sf::Vector2u(0, 0));
      window.clear();
      window.draw(sprite);
      window.display();
      frame_ready = false;
    }
  }

  dut.final();
  return 0;
}
