#!/usr/bin/env python3

import argparse
from PIL import Image

def to_4bit(value_8bit: int) -> int:
    return value_8bit >> 4

def rgb_to_12bit_hex(rgb):
    r, g, b = rgb
    return f"{to_4bit(r):X}{to_4bit(g):X}{to_4bit(b):X}"

def parse_background(bg_string):
    if bg_string is None or bg_string.lower() == "none":
        return None
    try:
        parts = [int(x) for x in bg_string.split(",")]
        if len(parts) != 3:
            raise ValueError
        return tuple(parts)
    except ValueError:
        raise argparse.ArgumentTypeError("Background must be 'none' or R,G,B (e.g. 255,0,0)")

def main():
    parser = argparse.ArgumentParser(
        description="Convert sprite sheet PNG into .mem format with 4-bit RGB pixels."
    )

    # Positional arguments
    parser.add_argument("input", help="Input sprite sheet PNG file")
    parser.add_argument("output", help="Output .mem file")

    # Optional arguments with defaults
    parser.add_argument("--sprites", type=int, default=9,
                        help="Number of sprites in a row (default: 9)")
    parser.add_argument("--width", type=int, default=32,
                        help="Sprite width in pixels (default: 32)")
    parser.add_argument("--height", type=int, default=48,
                        help="Sprite height in pixels (default: 48)")
    parser.add_argument("--background", type=parse_background, default=None,
                        help="Background RGB as 'R,G,B' or 'none' to auto-detect (default: none)")

    args = parser.parse_args()

    img = Image.open(args.input).convert("RGBA")
    width, height = img.size

    expected_width = args.sprites * args.width
    if height < args.height or width < expected_width:
        raise ValueError(
            f"Image too small: got {width}x{height}, "
            f"need at least {expected_width}x{args.height}"
        )

    # Detect background
    if args.background is None:
        bg_pixel = img.getpixel((0, 0))  # RGBA
        bg_rgb = bg_pixel[:3]
    else:
        bg_rgb = args.background

    pixels = img.load()
    lines = []

    for sprite_index in range(args.sprites):
        sprite_x0 = sprite_index * args.width

        for y in range(args.height):
            for x in range(args.width):
                px = pixels[sprite_x0 + x, y]
                r, g, b, a = px

                if a == 0 or (r, g, b) == bg_rgb:
                    lines.append("000")
                else:
                    lines.append(rgb_to_12bit_hex((r, g, b)))

    with open(args.output, "w") as f:
        f.write("\n".join(lines))

    print(f"Conversion complete. Saved to {args.output}")

if __name__ == "__main__":
    main()
