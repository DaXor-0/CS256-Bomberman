#!/usr/bin/env python3

from PIL import Image
import argparse

def parse_background(bg_string):
    if bg_string is None or bg_string.lower() == "none":
        return None
    try:
        parts = [int(x) for x in bg_string.split(",")]
        if len(parts) != 3:
            raise ValueError
        return tuple(parts)
    except ValueError:
        raise argparse.ArgumentTypeError(
            "Background must be 'none' or R,G,B (e.g. 0,255,0)"
        )

def hex444_to_rgba(p, bg_rgb):
    """
    Convert a 3-hex-digit RGB444 string to 8-bit RGBA.
    If p == '000':
      - if bg_rgb is None: return transparent
      - else: return bg_rgb, opaque
    """
    if p == "000":
        if bg_rgb is None:
            return (0, 0, 0, 0)  # transparent
        else:
            r, g, b = bg_rgb
            return (r, g, b, 255)

    r4 = int(p[0], 16)
    g4 = int(p[1], 16)
    b4 = int(p[2], 16)

    # Expand 4-bit to 8-bit: 0–15 → 0–255
    r = r4 * 17
    g = g4 * 17
    b = b4 * 17
    return (r, g, b, 255)

def mem_to_png_strip(mem_file, png_file, sprites, width, height, bg_rgb):
    # Parse all pixel codes
    codes = []
    with open(mem_file, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("//"):
                continue

            if "//" in line:
                line = line.split("//")[0].strip()

            parts = line.replace(",", " ").split()
            for p in parts:
                p = p.strip()
                if not p:
                    continue
                if p.lower().startswith("0x"):
                    p = p[2:]
                if len(p) != 3:
                    continue
                # Ensure valid hex
                try:
                    int(p, 16)
                except ValueError:
                    continue
                codes.append(p.upper())

    expected = sprites * width * height
    if len(codes) != expected:
        raise ValueError(
            f"Expected {expected} pixels (sprites*width*height = "
            f"{sprites}*{width}*{height}), got {len(codes)}"
        )

    # Create one big strip: sprites in a row
    total_width = sprites * width
    img = Image.new("RGBA", (total_width, height))

    idx = 0
    for sprite_index in range(sprites):
        sprite_x0 = sprite_index * width
        for y in range(height):
            for x in range(width):
                rgba = hex444_to_rgba(codes[idx], bg_rgb)
                img.putpixel((sprite_x0 + x, y), rgba)
                idx += 1

    img.save(png_file)
    print(f"Saved PNG strip to {png_file} ({total_width}x{height})")

def main():
    parser = argparse.ArgumentParser(
        description="Convert .mem sprite data (RGB444) back into a PNG strip."
    )
    parser.add_argument("mem_file", help="Input .mem file")
    parser.add_argument("png_file", help="Output PNG file")

    parser.add_argument("--sprites", type=int, default=9,
                        help="Number of sprites in a row (default: 9)")
    parser.add_argument("--width", type=int, default=32,
                        help="Sprite width in pixels (default: 32)")
    parser.add_argument("--height", type=int, default=48,
                        help="Sprite height in pixels (default: 48)")
    parser.add_argument(
        "--background",
        type=parse_background,
        default=None,
        help=("Background RGB as 'R,G,B' or 'none' for transparent 000 "
              "(default: none)"),
    )

    args = parser.parse_args()
    mem_to_png_strip(
        args.mem_file,
        args.png_file,
        args.sprites,
        args.width,
        args.height,
        args.background,
    )

if __name__ == "__main__":
    main()
