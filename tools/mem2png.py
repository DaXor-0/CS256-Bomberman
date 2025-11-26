from PIL import Image
import numpy as np

def mem_to_png(mem_file, png_file, width, height):
    values = []

    with open(mem_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('//'):
                continue

            if '//' in line:
                line = line.split('//')[0].strip()

            parts = line.replace(',', ' ').split()

            for p in parts:
                p = p.strip()

                if p.lower().startswith('0x'):
                    p = p[2:]

                if len(p) == 3:  # RGB444 format
                    try:
                        r = int(p[0], 16) * 17
                        g = int(p[1], 16) * 17
                        b = int(p[2], 16) * 17
                        values.append([r, g, b])
                    except ValueError:
                        continue

    expected = width * height
    if len(values) != expected:
        raise ValueError(
            f"Expected {expected} pixels, got {len(values)}. "
            "Check width/height or input format."
        )

    img_array = np.array(values, dtype=np.uint8).reshape((height, width, 3))
    img = Image.fromarray(img_array, mode='RGB')
    img.save(png_file)
    print(f"Saved PNG to {png_file}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Convert memory file to PNG image.")
    parser.add_argument("mem_file", help="Input memory file path")
    parser.add_argument("png_file", help="Output PNG file path")
    parser.add_argument("width", type=int, help="Image width")
    parser.add_argument("height", type=int, help="Image height")
    args = parser.parse_args()
    mem_to_png(args.mem_file, args.png_file, args.width, args.height)
