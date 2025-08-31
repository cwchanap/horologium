#!/usr/bin/env python3
"""
Terrain Asset Processor for Horologium Game

This script processes AI-generated terrain assets and prepares them for the game:
1. Resizes all assets to appropriate sizes based on their type
2. Organizes them into the correct directory structure
3. Handles 1:1 aspect ratio terrain assets properly

The game uses these standard sizes:
- Base terrain tiles: 64x64 pixels (matches grid cell size)
- Large features (big trees, large rocks): 80x96 pixels
- Medium features (medium rocks): 48x40 pixels  
- Small features (small trees, bushes, small rocks): 32x24 pixels
- Water features: Variable sizes based on feature type
"""

from pathlib import Path
from PIL import Image

# Asset size mappings based on terrain system analysis
TERRAIN_SIZES = {
    # Base terrain (matches grid cell size)
    'base': (64, 64),
    
    # Large features (trees, large rocks)
    'large_features': (80, 96),
    
    # Medium features
    'medium_features': (48, 40),
    
    # Small features
    'small_features': (32, 24),
    
    # Water features (rivers, lakes)
    'water_features': (64, 64),
    
    # Special features
    'paths': (64, 64),
}

# Asset categorization based on filename patterns
ASSET_CATEGORIES = {
    # Base terrain types
    'base': [
        'grass_base', 'dirt_base', 'sand_base', 
        'rock_base', 'water_base', 'snow_base'
    ],
    
    # Large features
    'large_features': [
        'tree_oak_large', 'tree_pine_large', 'rock_large', 'lake_large'
    ],
    
    # Medium features  
    'medium_features': [
        'rock_medium', 'lake_small'
    ],
    
    # Small features
    'small_features': [
        'tree_oak_small', 'tree_pine_small', 'rock_small',
        'bush_green', 'bush_flowering'
    ],
    
    # Water features
    'water_features': [
        'river_horizontal', 'river_vertical',
        'river_corner_tl', 'river_corner_tr', 
        'river_corner_bl', 'river_corner_br'
    ],
    
    # Paths and transitions
    'paths': [
        'path_dirt', 'path_stone', 'bridge_wood', 'bridge_stone'
    ]
}

def determine_asset_category(filename):
    """Determine the category and size for an asset based on its filename."""
    name_lower = filename.lower().replace('.png', '')
    
    for category, patterns in ASSET_CATEGORIES.items():
        for pattern in patterns:
            if pattern in name_lower:
                return category, TERRAIN_SIZES[category]
    
    # Default to base terrain size for unknown assets
    return 'base', TERRAIN_SIZES['base']

def create_directory_structure():
    """Create the complete terrain asset directory structure."""
    base_dir = Path("assets/images/terrain")
    
    directories = [
        "base",
        "features/trees",
        "features/rocks", 
        "features/bushes",
        "features/water",
        "paths",
        "details",
        "effects"
    ]
    
    for directory in directories:
        dir_path = base_dir / directory
        dir_path.mkdir(parents=True, exist_ok=True)
        print(f"✓ Created directory: {dir_path}")

def resize_and_organize_terrain_assets(input_dir="assets/images/background/original"):
    """
    Process all terrain assets from the input directory.
    Resize them appropriately and place them in the correct terrain directories.
    """
    input_path = Path(input_dir)
    
    if not input_path.exists():
        print(f"Error: Input directory '{input_dir}' does not exist")
        return False
    
    # Create terrain directory structure
    create_directory_structure()
    
    # Get all PNG files
    png_files = list(input_path.glob("*.png"))
    
    if not png_files:
        print(f"No PNG files found in {input_dir}")
        return False
    
    print(f"Found {len(png_files)} terrain assets to process...")
    
    success_count = 0
    
    for png_file in png_files:
        try:
            # Determine category and target size
            category, target_size = determine_asset_category(png_file.name)
            
            # Determine output path based on asset type
            output_path = get_output_path(png_file.name, category)
            
            if output_path.exists():
                print(f"~ Skipping {png_file.name} (already exists at {output_path})")
                continue
            
            # Process the image
            with Image.open(png_file) as img:
                # Convert to RGBA for transparency support
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                
                # Resize maintaining quality
                resized_img = img.resize(target_size, Image.Resampling.LANCZOS)
                
                # Save to appropriate location
                resized_img.save(output_path, 'PNG')
                
                print(f"✓ Processed {png_file.name} → {output_path} ({target_size[0]}x{target_size[1]})")
                success_count += 1
                
        except (IOError, OSError) as e:
            print(f"✗ Error processing {png_file.name}: {str(e)}")
    
    print(f"\nProcessed {success_count} terrain assets successfully!")
    return True

def get_output_path(filename, _category=None):
    """Determine the correct output path for a terrain asset."""
    base_dir = Path("assets/images/terrain")
    name_lower = filename.lower().replace('.png', '')
    
    # Base terrain types
    if any(terrain in name_lower for terrain in ['grass_base', 'dirt_base', 'sand_base', 'rock_base', 'water_base', 'snow_base']):
        return base_dir / "base" / filename
    
    # Tree features
    elif any(tree in name_lower for tree in ['tree_oak', 'tree_pine']):
        return base_dir / "features" / "trees" / filename
    
    # Rock features
    elif 'rock' in name_lower and 'base' not in name_lower:
        return base_dir / "features" / "rocks" / filename
    
    # Bush features
    elif 'bush' in name_lower:
        return base_dir / "features" / "bushes" / filename
    
    # Water features
    elif any(water in name_lower for water in ['river', 'lake']):
        return base_dir / "features" / "water" / filename
    
    # Paths
    elif any(path in name_lower for path in ['path', 'bridge']):
        return base_dir / "paths" / filename
    
    # Default to base
    else:
        return base_dir / "base" / filename

def convert_background_assets():
    """Convert assets from background/original to proper terrain structure."""
    print("Terrain Asset Processor - Converting Background Assets")
    print("=" * 60)
    
    success = resize_and_organize_terrain_assets()
    
    if success:
        print("\n🎉 Terrain assets processed successfully!")
        print("\nNext steps:")
        print("1. Check assets/images/terrain/ for your organized assets")
        print("2. Run the game to see terrain with proper sprites")
        print("3. Generate any missing assets using TERRAIN_ASSETS_GUIDE.md")
    else:
        print("\n❌ Asset processing failed. Check the input directory.")

def map_existing_assets():
    """Map existing background assets to terrain assets with better naming."""
    asset_mapping = {
        'dirt_base.png': 'dirt_base.png',
        'grass_base.png': 'grass_base.png', 
        'rock_base.png': 'rock_base.png',
        'sand_base.png': 'sand_base.png',
        'snow_base.png': 'snow_base.png',
        'tree_oak_1.png': 'tree_oak_small.png',  # Rename for consistency
        'tree_oak_2.png': 'tree_oak_large.png',  # Rename for consistency
    }
    
    input_path = Path("assets/images/background/original")
    
    print("Mapping existing assets to terrain naming convention:")
    for old_name, new_name in asset_mapping.items():
        old_file = input_path / old_name
        if old_file.exists():
            print(f"  {old_name} → {new_name}")
    
    return asset_mapping

def main():
    """Main function with user-friendly interface."""
    print("🌍 Horologium Terrain Asset Processor")
    print("Converting AI-generated background assets to game-ready terrain assets")
    print()
    
    # Show existing assets
    input_path = Path("assets/images/background/original")
    if input_path.exists():
        existing_files = list(input_path.glob("*.png"))
        print(f"Found {len(existing_files)} assets in {input_path}:")
        for file in existing_files:
            print(f"  • {file.name}")
        print()
    
    # Show mapping  
    map_existing_assets()
    print()
    
    # Process assets
    response = input("Process these assets for the terrain system? (y/n): ").lower().strip()
    if response in ['y', 'yes']:
        convert_background_assets()
    else:
        print("Asset processing cancelled.")

if __name__ == "__main__":
    main()
