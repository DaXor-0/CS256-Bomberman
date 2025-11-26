import argparse
from pathlib import Path
from PIL import Image

def double_image_size(input_path, output_path):
    # Open image (Pillow will load it as 8-bit per channel internally,
    # even if the original is 4 bits per channel)
    img = Image.open(input_path)

    # Get current size
    width, height = img.size

    # New size (double)
    new_size = (width * 2, height * 2)

    # High-quality resize
    img_resized = img.resize(new_size, Image.LANCZOS)

    # Ensure we save as PNG
    output_path = Path(output_path)
    if output_path.suffix.lower() != ".png":
        output_path = output_path.with_suffix(".png")

    img_resized.save(output_path, format="PNG")
    print(f"Doubled image saved to: {output_path}")

def main():
    parser = argparse.ArgumentParser(
        description="Double the size of a PNG image (supports 4 bits per channel)."
    )
    parser.add_argument("input", help="Path to input PNG image")
    parser.add_argument("output", help="Path to output PNG image")

    args = parser.parse_args()
    double_image_size(args.input, args.output)

if __name__ == "__main__":
    main()
