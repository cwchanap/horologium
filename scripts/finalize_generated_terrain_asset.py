#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image


CODEX_HOME = Path.home() / ".codex"
DEFAULT_REMOVE_CHROMA = (
    CODEX_HOME / "skills" / ".system" / "imagegen" / "scripts" / "remove_chroma_key.py"
)
DEFAULT_GENERATED_IMAGES = CODEX_HOME / "generated_images"


def latest_generated_png(generated_images_dir: Path) -> Path:
    pngs = list(generated_images_dir.rglob("*.png"))
    if not pngs:
        raise FileNotFoundError(
            f"No generated PNGs found under {generated_images_dir}"
        )
    return max(pngs, key=lambda path: path.stat().st_mtime)


def remove_background(source: Path, temp_output: Path, remove_chroma_script: Path) -> None:
    if not remove_chroma_script.is_file():
        raise FileNotFoundError(
            f"remove_chroma_key.py not found at {remove_chroma_script}. "
            "Provide the path via --remove-chroma-key or install the codex imagegen scripts."
        )
    subprocess.run(
        [
            sys.executable,
            str(remove_chroma_script),
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
    parser.add_argument(
        "--remove-chroma-key",
        default=str(DEFAULT_REMOVE_CHROMA),
        help=(
            "Path to remove_chroma_key.py. "
            f"Defaults to {DEFAULT_REMOVE_CHROMA}"
        ),
    )
    parser.add_argument(
        "--generated-images-dir",
        default=str(DEFAULT_GENERATED_IMAGES),
        help=(
            "Directory to search for generated PNGs when --source is omitted. "
            f"Defaults to {DEFAULT_GENERATED_IMAGES}"
        ),
    )
    args = parser.parse_args()

    remove_chroma_script = Path(args.remove_chroma_key)
    generated_images_dir = Path(args.generated_images_dir)
    source = Path(args.source) if args.source else latest_generated_png(generated_images_dir)
    destination = Path(args.dest)

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        temp_source = tmp_path / f"{destination.stem}_source.png"
        temp_alpha = tmp_path / f"{destination.stem}_alpha.png"

        shutil.copy2(source, temp_source)
        remove_background(temp_source, temp_alpha, remove_chroma_script)
        fit_asset(temp_alpha, destination, args.width, args.height)

    print(destination)


if __name__ == "__main__":
    main()
