from PIL import Image
import argparse

def halve_png_size(input_path, output_path):
    # Open the image
    with Image.open(input_path) as img:
        # Calculate new dimensions (half the width and height)
        new_width = img.width // 2
        new_height = img.height // 2
        
        # Resize the image
        resized_img = img.resize((new_width, new_height), Image.NEAREST)
        
        # Save the resized image
        resized_img.save(output_path, format="PNG")
        print(f"Image saved to {output_path} with size {new_width}x{new_height}")

# Example usage
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Halve the size of a PNG image.")
    parser.add_argument("input", help="Path to the input PNG file")
    parser.add_argument("output", help="Path to save the halved PNG file")
    args = parser.parse_args()
    halve_png_size(args.input, args.output)

