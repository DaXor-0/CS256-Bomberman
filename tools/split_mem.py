import numpy as np
import matplotlib.pyplot as plt
import glob
import os

def split_player_mem(input_file):
    # number of total rows and rows per sprite
    total_rows = 13824
    rows_per_sprite = 32 * 48  # 1536
    sprite_count = 9

    # output filenames in order
    output_names = [
        "down_1.mem", "down_2.mem", "down_3.mem",
        "side_1.mem", "side_2.mem", "side_3.mem",
        "up_1.mem",   "up_2.mem",   "up_3.mem"
    ]

    # --- Read and clean input ---
    with open(input_file, 'r') as f:
        lines = f.readlines()

    # Strip whitespace & ignore empty/comment lines
    data = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("//") or line.startswith("#"):
            continue
        data.append(line)

    # Safety check
    if len(data) != total_rows:
        print(f"Warning: Expected {total_rows} rows, found {len(data)}.")

    dir = "sprites/walk/mem"
    # --- Split into chunks ---
    for i in range(sprite_count):
        start = i * rows_per_sprite
        end = start + rows_per_sprite
        chunk = data[start:end]

        # Write each chunk to its .mem file
        with open(os.path.join(dir, output_names[i]), 'w') as f_out:
            for entry in chunk:
                f_out.write(entry + "\n")

        print(f"Created {output_names[i]} with {len(chunk)} rows.")

        load_mem(os.path.join(dir, output_names[i]))

    print("Done!")


# Example usage:
# split_player_mem("player_1.mem")


SPRITE_W = 32
SPRITE_H = 48
DATA_WIDTH = 12   # 4b R, 4b G, 4b B  (0–15 each)

def load_mem(fname):
    """Load a .mem file containing 12-bit RGB values."""
    with open(fname, "r") as f:
        hex_values = [line.strip() for line in f if line.strip()]

    pixels = []
    for h in hex_values:
        v = int(h, 16)
        r = (v >> 8) & 0xF
        g = (v >> 4) & 0xF
        b = (v >> 0) & 0xF
        pixels.append([r/15, g/15, b/15])

    arr = np.array(pixels).reshape(SPRITE_H, SPRITE_W, 3)

    print(f"Showing: {fname}")

    plt.figure(figsize=(4,6))
    plt.title(fname)
    plt.imshow(arr)
    plt.axis("off")
    plt.show()


# ----------- SHOW ALL SPRITES -----------
    

def main():
    split_player_mem("sprites/walk/mem/player_1.mem")

if __name__ == "__main__":
    main()