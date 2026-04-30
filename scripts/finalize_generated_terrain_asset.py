#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

from PIL import Image


CODEX_HOME = Path.home() / ".codex"
REMOVE_CHROMA = (
    CODEX_HOME / "skills" / ".system" / "imagegen" / "scripts" / "remove_chroma_key.py"
)
GENERATED_IMAGES = CODEX_HOME / "generated_images"


def latest_generated_png() -> Path:
    pngs = list(GENERATED_IMAGES.rglob("*.png"))
    if not pngs:
        raise FileNotFoundError("No generated PNGs found under ~/.codex/generated_images")
    return max(pngs, key=lambda path: path.stat().st_mtime)


def remove_background(source: Path, temp_output: Path) -> None:
    subprocess.run(
        [
            "python3",
            str(REMOVE_CHROMA),
            "--input",
            str(source),
            "--out",
            str(temp_output),
            "--auto-key",
            "border",
            "--soft-matte",
            "--transparent-threshold",
            "12",
            "--opaque-threshold",
            "220",
            "--despill",
            "--force",
        ],
        check=True,
    )


def fit_asset(source: Path, destination: Path, width: int, height: int) -> None:
    with Image.open(source) as image:
        image = image.convert("RGBA")
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is not None:
            image = image.crop(bbox)

        image.thumbnail((width, height), Image.Resampling.LANCZOS)

        output = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        x = (width - image.width) // 2
        y = (height - image.height) // 2
        output.alpha_composite(image, (x, y))
        destination.parent.mkdir(parents=True, exist_ok=True)
        output.save(destination)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Finalize a built-in image_gen output into a terrain asset."
    )
    parser.add_argument("--dest", required=True, help="Destination PNG path.")
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument(
        "--source",
        help="Explicit generated source PNG. Defaults to the latest generated image.",
    )
    args = parser.parse_args()

    source = Path(args.source) if args.source else latest_generated_png()
    destination = Path(args.dest)

    temp_source = Path("/tmp") / f"{destination.stem}_source.png"
    temp_alpha = Path("/tmp") / f"{destination.stem}_alpha.png"

    shutil.copy2(source, temp_source)
    remove_background(temp_source, temp_alpha)
    fit_asset(temp_alpha, destination, args.width, args.height)

    print(destination)


if __name__ == "__main__":
    main()
