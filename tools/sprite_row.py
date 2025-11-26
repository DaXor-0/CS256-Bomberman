import argparse
from PIL import Image

def main():
    parser = argparse.ArgumentParser(description="Convert a grid sprite sheet to a single-row sprite sheet.")
    parser.add_argument("input_path", help="Path to input sprite sheet image")
    parser.add_argument("output_path", help="Path to save the output image")
    parser.add_argument("--sprite_w", type=int, default=32, help="Width of each sprite (default: 32)")
    parser.add_argument("--sprite_h", type=int, default=48, help="Height of each sprite (default: 48)")
    parser.add_argument("--rows", type=int, default=3, help="Number of rows in the spritesheet (default: 3)")
    parser.add_argument("--cols", type=int, default=3, help="Number of columns in the spritesheet (default: 3)")
    parser.add_argument("--border_internal", type=int, default=2, help="Internal border between sprites (default: 2)")
    parser.add_argument("--border_outer", type=int, default=0, help="Outer border around the spritesheet (default: 0)")

    args = parser.parse_args()

    sheet = Image.open(args.input_path).convert("RGBA")

    sprites = []
    for row in range(args.rows):
        for col in range(args.cols):
            left = args.border_outer + col * (args.sprite_w + args.border_internal)
            top = args.border_outer + row * (args.sprite_h + args.border_internal)
            right = left + args.sprite_w
            bottom = top + args.sprite_h

            sprite = sheet.crop((left, top, right, bottom))
            sprites.append(sprite)

    new_width = args.sprite_w * len(sprites)
    new_height = args.sprite_h
    out = Image.new("RGBA", (new_width, new_height))

    for i, sprite in enumerate(sprites):
        out.paste(sprite, (i * args.sprite_w, 0))

    out.save(args.output_path)
    print(f"Saved: {args.output_path}")

if __name__ == "__main__":
    main()
