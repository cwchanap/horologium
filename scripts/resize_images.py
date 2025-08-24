#!/usr/bin/env python3
"""
Resize asset images for Horologium game.

This script processes all PNG images in specified directories and creates
resized versions. Supports buildings, resources, and other asset types.
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image

def resize_images(asset_type="building", input_dir=None, output_dir=None, size=(128, 128)):
    """
    Resize all PNG images to the specified size.
    
    Args:
        asset_type: Type of asset (building, resource, etc.)
        input_dir: Directory containing source images (if None, uses default)
        output_dir: Directory to save resized images (if None, uses default)
        size: Tuple of (width, height) for resizing
    """
    # Set default directories based on asset type
    if input_dir is None:
        input_dir = f"assets/images/{asset_type}/original"
    if output_dir is None:
        output_dir = f"assets/images/{asset_type}"
    
    # Create output directory if it doesn't exist
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Get all PNG files in input directory
    input_path = Path(input_dir)
    if not input_path.exists():
        print(f"Error: Input directory '{input_dir}' does not exist")
        return False
    
    png_files = list(input_path.glob("*.png"))
    
    if not png_files:
        print(f"No PNG files found in {input_dir}")
        return False
    
    print(f"Found {len(png_files)} PNG files to process...")
    
    # Process each image
    success_count = 0
    for png_file in png_files:
        output_file = output_path / png_file.name
        if output_file.exists():
            print(f"~ Skipping {png_file.name} (already exists)")
            continue

        try:
            # Open the image
            with Image.open(png_file) as img:
                # Convert to RGBA if not already (to handle transparency)
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')

                # Resize the image using high-quality resampling
                resized_img = img.resize(size, Image.Resampling.LANCZOS)

                # Save the resized image
                resized_img.save(output_file, 'PNG')

                print(f"✓ Resized {png_file.name} to {size[0]}x{size[1]}")
                success_count += 1

        except (IOError, OSError) as e:
            print(f"✗ Error processing {png_file.name}: {str(e)}")
    
    print(f"\nProcessed {success_count} images successfully. Resized images saved to: {output_dir}")
    return True

def main():
    """Main function to run the resizing script."""
    parser = argparse.ArgumentParser(description='Resize asset images for Horologium game')
    parser.add_argument('asset_type', nargs='?', default='building', 
                       help='Type of asset to resize (building, resource, etc.)')
    parser.add_argument('--input', '-i', help='Input directory path')
    parser.add_argument('--output', '-o', help='Output directory path')
    parser.add_argument('--size', '-s', default='128x128', 
                       help='Size in format WIDTHxHEIGHT (default: 128x128)')
    
    args = parser.parse_args()
    
    # Parse size
    try:
        width, height = map(int, args.size.split('x'))
        size = (width, height)
    except ValueError:
        print("Error: Size must be in format WIDTHxHEIGHT (e.g., 128x128)")
        return
    
    print(f"Asset Image Resizer - {args.asset_type.title()} Assets")
    print("=" * 50)
    
    # Check if PIL is available
    try:
        Image.open
    except NameError:
        print("Error: Pillow (PIL) is not installed.")
        print("Please install it using: pip install Pillow")
        return
    
    # Resize images
    success = resize_images(
        asset_type=args.asset_type,
        input_dir=args.input,
        output_dir=args.output,
        size=size
    )
    
    if success:
        print(f"\nDone! Check the output directory for your {size[0]}x{size[1]} {args.asset_type} images.")
    else:
        print(f"\nProcess completed with errors. Please check the input directory and try again.")

def resize_resource_images():
    """Convenience function to resize resource images specifically."""
    return resize_images(
        asset_type="resource",
        size=(32, 32)  # Resources typically use smaller icons
    )

def resize_building_images():
    """Convenience function to resize building images (for backward compatibility)."""
    return resize_images(
        asset_type="building",
        size=(128, 128)
    )

if __name__ == "__main__":
    main()