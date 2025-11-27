#!/usr/bin/env python3
"""Convert a linear tile-map memory dump into a row/column matrix."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print a tile map stored as a linear list in matrix form."
    )
    parser.add_argument(
        "map_path",
        type=Path,
        help="Path to the map file (one value per line, hex/dec formats supported).",
    )
    parser.add_argument(
        "--rows",
        type=int,
        default=11,
        help="Number of rows in the map (default: 11).",
    )
    parser.add_argument(
        "--cols",
        type=int,
        default=19,
        help="Number of columns in the map (default: 19).",
    )
    parser.add_argument(
        "--radix",
        choices=("hex", "dec"),
        default="hex",
        help="Display the matrix values in hexadecimal or decimal (default: hex).",
    )
    return parser.parse_args()


def parse_value(token: str) -> int:
    token = token.replace("_", "").strip()
    if not token:
        raise ValueError("empty token")

    if "'" in token:
        _, radix_and_value = token.split("'", 1)
        radix = radix_and_value[:1].lower()
        value_str = radix_and_value[1:].strip()
        if radix == "h":
            return int(value_str, 16)
        if radix == "d":
            return int(value_str, 10)
        if radix == "b":
            return int(value_str, 2)
        if radix == "o":
            return int(value_str, 8)
        raise ValueError(f"unsupported radix specifier in token '{token}'")

    try:
        return int(token, 0)
    except ValueError:
        return int(token, 16)


def load_map(path: Path) -> List[int]:
    if not path.is_file():
        raise FileNotFoundError(f"Map file '{path}' does not exist")

    values: List[int] = []
    for raw_line in path.read_text().splitlines():
        line = raw_line.split("//", 1)[0].split("#", 1)[0].strip()
        if not line:
            continue
        values.append(parse_value(line))
    return values


def format_row(row: List[int], radix: str) -> str:
    if radix == "hex":
        return " ".join(f"{value:X}" for value in row)
    return " ".join(str(value) for value in row)


def main() -> None:
    args = parse_args()
    values = load_map(args.map_path)

    total = args.rows * args.cols
    if total != len(values):
        raise ValueError(
            f"Requested dimensions {args.rows}x{args.cols}={total} do not match "
            f"map size {len(values)}."
        )

    for row_idx in range(args.rows):
        start = row_idx * args.cols
        end = start + args.cols
        print(format_row(values[start:end], args.radix))


if __name__ == "__main__":
    main()
