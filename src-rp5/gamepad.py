#!/usr/bin/env python3
from evdev import InputDevice, ecodes
import serial
import struct

# Your controller:
EVENT_DEV = "/dev/input/event5"

# Open input device
dev = InputDevice(EVENT_DEV)

ser = serial.Serial('/dev/ttyAMA0', 115200)

# Bit positions in our 1-byte packet
BIT_UP     = 0
BIT_DOWN   = 1
BIT_LEFT   = 2
BIT_RIGHT  = 3
BIT_ACTION = 4  # Button B (BTN_EAST)

buttons = 0  # 8-bit value, we only use bits 0–4

def set_bit(value, bit):
    return value | (1 << bit)

def clear_bit(value, bit):
    return value & ~(1 << bit)

print("Starting gamepad → FPGA UART bridge...")
print(f"Using input device: {EVENT_DEV}")
print("Press Ctrl+C to stop.")

for event in dev.read_loop():
    updated = False

    # D-pad: ABS_HAT0Y (17) = up/down, ABS_HAT0X (16) = left/right
    if event.type == ecodes.EV_ABS:
        if event.code == 17:  # ABS_HAT0Y
            if event.value == -1:   # up
                buttons = set_bit(buttons, BIT_UP)
                buttons = clear_bit(buttons, BIT_DOWN)
            elif event.value == 1:  # down
                buttons = set_bit(buttons, BIT_DOWN)
                buttons = clear_bit(buttons, BIT_UP)
            else:  # 0 = neutral
                buttons = clear_bit(buttons, BIT_UP)
                buttons = clear_bit(buttons, BIT_DOWN)
            updated = True

        elif event.code == 16:  # ABS_HAT0X
            if event.value == -1:   # left
                buttons = set_bit(buttons, BIT_LEFT)
                buttons = clear_bit(buttons, BIT_RIGHT)
            elif event.value == 1:  # right
                buttons = set_bit(buttons, BIT_RIGHT)
                buttons = clear_bit(buttons, BIT_LEFT)
            else:  # 0 = neutral
                buttons = clear_bit(buttons, BIT_LEFT)
                buttons = clear_bit(buttons, BIT_RIGHT)
            updated = True

    # Action button: BTN_EAST (305) – your B button
    elif event.type == ecodes.EV_KEY and event.code == 305:
        if event.value == 1:   # pressed
            buttons = set_bit(buttons, BIT_ACTION)
        else:                  # released
            buttons = clear_bit(buttons, BIT_ACTION)
        updated = True

    if updated:
        # Debug print (optional, you can comment this out later)
        print(f"Buttons byte: {buttons:08b}")
        # Send 1 byte over UART
        ser.write(struct.pack('B', buttons))
