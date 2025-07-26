#!/usr/bin/env python3
"""
Resize building asset images to 128x128 pixels.

This script processes all PNG images in the assets/images/building directory
and creates 128x128 pixel versions in a new directory called assets/images/building/resized.
"""

import os
from pathlib import Path
from PIL import Image

def resize_building_images(input_dir="assets/images/building/original", output_dir="assets/images/building", size=(128, 128)):
    """
    Resize all PNG building images to the specified size.
    
    Args:
        input_dir: Directory containing source images
        output_dir: Directory to save resized images
        size: Tuple of (width, height) for resizing
    """
    # Create output directory if it doesn't exist
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Get all PNG files in input directory
    input_path = Path(input_dir)
    png_files = list(input_path.glob("*.png"))
    
    if not png_files:
        print(f"No PNG files found in {input_dir}")
        return
    
    print(f"Found {len(png_files)} PNG files to process...")
    
    # Process each image
    for png_file in png_files:
        try:
            # Open the image
            with Image.open(png_file) as img:
                # Convert to RGBA if not already (to handle transparency)
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                
                # Resize the image using high-quality resampling
                resized_img = img.resize(size, Image.Resampling.LANCZOS)
                
                # Create output filename
                output_file = output_path / png_file.name
                
                # Save the resized image
                resized_img.save(output_file, 'PNG')
                
                print(f"✓ Resized {png_file.name} to {size[0]}x{size[1]}")
                
        except Exception as e:
            print(f"✗ Error processing {png_file.name}: {str(e)}")
    
    print(f"\nAll images processed. Resized images saved to: {output_dir}")

def main():
    """Main function to run the resizing script."""
    print("Building Asset Image Resizer")
    print("=" * 30)
    
    # Check if PIL is available
    try:
        from PIL import Image
    except ImportError:
        print("Error: Pillow (PIL) is not installed.")
        print("Please install it using: pip install Pillow")
        return
    
    # Resize images
    resize_building_images()
    
    print("\nDone! Check the 'assets/images/building/resized' directory for your 128x128 images.")

if __name__ == "__main__":
    main()