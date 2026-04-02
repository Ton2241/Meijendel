#!/usr/bin/env python3

import argparse
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Maak een schone CSV voor plot_jaar_stikstof."
    )
    parser.add_argument("--input", required=True, help="Pad naar bron-CSV")
    parser.add_argument("--output", required=True, help="Pad naar doel-CSV")
    return parser.parse_args()


def main():
    args = parse_args()
    df = pd.read_csv(args.input)
    keep = ["plot_id", "jaar", "bron", "stikstof_mean", "stikstof_median"]
    df = df[keep].copy()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
