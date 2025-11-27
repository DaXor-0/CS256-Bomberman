def mem_to_coe(mem_file, coe_file):
    """
    Convert a .mem file (HEX, 12-bit entries) to a .coe file.
    Expected: 13824 entries, each 12-bit hex.
    """

    # Read .mem file (ignore blank lines and comments)
    with open(mem_file, 'r') as f:
        lines = f.readlines()

    # Clean and normalize hex entries
    mem_values = []
    for line in lines:
        line = line.strip()

        # Skip comments or empty lines
        if not line or line.startswith("//") or line.startswith("#"):
            continue

        # Remove comma or semicolon if present
        line = line.replace(",", "").replace(";", "")

        # Ensure uppercase hex and zero-pad to 3 hex digits (12 bits)
        hex_val = line.upper()
        hex_val = hex_val.zfill(3)

        mem_values.append(hex_val)

    # Ensure expected number of rows (optional safety check)
    if len(mem_values) != 13824:
        print(f"Warning: expected 13824 rows, found {len(mem_values)}")

    # Write COE file
    with open(coe_file, 'w') as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")

        for i, value in enumerate(mem_values):
            if i == len(mem_values) - 1:
                # Last entry ends with semicolon
                f.write(f"{value};\n")
            else:
                f.write(f"{value},\n")

    print(f"Conversion complete! Output saved to {coe_file}")


def main():
    mem_to_coe("sprites/walk/mem/player_1.mem", "sprites/walk/coe/player_1.coe")

if __name__ == "__main__":
    main()