# 🎮 Player 2 Gamepad Interface (Raspberry Pi → Nexys A7)

This setup allows you to use a **USB gamepad as Player 2 input** for the FPGA game.  
The gamepad is plugged into a **Raspberry Pi**, which reads the button presses and sends them to the Nexys A7 over **UART (serial)** using just **one data wire and GND**.

Player 2 inputs are transmitted as a 1-byte packet where each bit represents a button state.

---

## 🛠️ What This Does

✔ Reads USB gamepad buttons using Python (`evdev`)
✔ Packs D-pad direction + one action button into 1 byte 
✔ Sends that byte over **UART TX** from Raspberry Pi
✔ FPGA receives the byte for **Player 2 control**
✔ Game logic reads this instead of switches/buttons

---

## 🎯 Button Mapping

| Bit | Function        | Game Mapping    |
| --- | --------------- | --------------- |
| 0   | D-pad UP        | Move Up         |
| 1   | D-pad DOWN      | Move Down       |
| 2   | D-pad LEFT      | Move Left       |
| 3   | D-pad RIGHT     | Move Right      |
| 4   | Button B (or A) | Action / Fire   |
| 5–7 | Unused          | Reserved        |

---

## 📁 Files in `src-rp5/`

| File               | Purpose                                       |
| ------------------ | --------------------------------------------- |
| `gamepad.py`       | Reads controller, sends P2 commands over UART |
| `requirements.txt` | Python dependencies (evdev, pyserial)         |
| `README.md`        | This document                                 |

---

## 🔌 Wiring (Raspberry Pi → Nexys A7)

| Raspberry Pi Pin | Nexys A7 Pin | Function            |
| ---------------- | ------------ | ------------------- |
| GPIO14 (Pin 8)   | JA1          | UART TX → FPGA RX   |
| GND (Pin 6)      | GND          | Ground reference    |

Only **one data wire** and **one ground wire** are required.

---

## 📝 Vivado Constraint Changes (Nexys A7)

In your `Nexys-A7.xdc`, make sure this line is **uncommented**:

```tcl
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];
````

This maps FPGA input `uart_rx` to JA1 (used for Player 2 input).

---

## 🐍 Raspberry Pi Setup

### 0️⃣ Install required system packages

Run these commands to install all necessary tools:

```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv \
                 evtest
```

---

### 1️⃣ Enable UART

```bash
sudo raspi-config
```

Navigate to:

**Interface Options → Serial Port**

| Prompt                       | Select  |
| ---------------------------- | ------- |
| Login shell over serial?     | **No**  |
| Enable serial port hardware? | **Yes** |

Reboot to apply:

```bash
sudo reboot
```

After reboot, confirm UART exists:

```bash
ls -l /dev/serial0
```

Expected output:

```
/dev/serial0 -> ttyAMA0
```

---

### 2️⃣ Create and activate Python virtual environment

```bash
python3 -m venv gamepad
source gamepad/bin/activate
pip install -r requirements.txt
```

---

### 3️⃣ Find which `/dev/input/event*` is the gamepad

```bash
ls /dev/input/event*
sudo evtest
```

Identify the gamepad (e.g. `NSW Wired controller`) and note its event number.
Update this line in `gamepad.py` if needed:

```python
EVENT_DEV = "/dev/input/event5"
```

---

### 4️⃣ Fix permission issues (if needed)

```bash
sudo chmod 666 /dev/serial0
sudo chmod 666 /dev/input/event*
```

Or make it persistent:

```bash
sudo usermod -a -G dialout,input $USER
sudo reboot
```

---

### 5️⃣ Run the gamepad sender

```bash
python3 gamepad.py
```

The script will continuously read gamepad input and transmit a 1-byte Player 2 input packet to the FPGA via UART.

---
