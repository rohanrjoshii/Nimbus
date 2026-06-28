#!/bin/bash
set -e

SOURCE_IMG="Sources/AppIconSource.png"
OUTPUT_DIR="Nimbus.iconset"

echo "🎨 Creating iconset folder..."
mkdir -p "$OUTPUT_DIR"

echo "📐 Resizing images using sips (forcing PNG format)..."
sips -s format png -z 16 16     "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_16x16.png"
sips -s format png -z 32 32     "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_16x16@2x.png"
sips -s format png -z 32 32     "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_32x32.png"
sips -s format png -z 64 64     "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_32x32@2x.png"
sips -s format png -z 128 128   "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_128x128.png"
sips -s format png -z 256 256   "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_128x128@2x.png"
sips -s format png -z 256 256   "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_256x256.png"
sips -s format png -z 512 512   "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_256x256@2x.png"
sips -s format png -z 512 512   "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_512x512.png"
sips -s format png -z 1024 1024 "$SOURCE_IMG" --out "$OUTPUT_DIR/icon_512x512@2x.png"

echo "📦 Generating Sources/AppIcon.icns using iconutil..."
iconutil -c icns "$OUTPUT_DIR" -o Sources/AppIcon.icns

echo "🧹 Cleaning up temp iconset folder..."
rm -rf "$OUTPUT_DIR"

echo "✨ AppIcon.icns generated successfully in Sources/!"
