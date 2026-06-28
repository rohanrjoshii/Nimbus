#!/bin/bash
set -e

APP_NAME="Nimbus"
BUNDLE_ID="com.akshayjoshi.nimbus"
VERSION="1.0"

echo "🚀 Compiling Nimbus in optimized Release mode (-O)..."
swiftc Sources/Nimbus/*.swift -O -o Nimbus_Release -framework AppKit -framework SwiftUI -framework Combine

echo "📦 Creating $APP_NAME.app bundle..."

# Clean previous bundle
rm -rf "$APP_NAME.app"

# Create bundle structure
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Copy binary
mv Nimbus_Release "$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Copy App Icon if it exists
if [ -f "Sources/AppIcon.icns" ]; then
    echo "🎨 Copying AppIcon.icns to resources..."
    cp "Sources/AppIcon.icns" "$APP_NAME.app/Contents/Resources/AppIcon.icns"
else
    echo "⚠️ Warning: Sources/AppIcon.icns not found!"
fi

# Copy optional custom lock/unlock sounds (lock.aiff / unlock.wav / etc.)
# Looks in repo root and a Sounds/ folder. Falls back to system sounds if absent.
for base in lock unlock; do
    for ext in aiff wav m4a mp3 caf; do
        for dir in "." "Sounds"; do
            if [ -f "$dir/$base.$ext" ]; then
                echo "🔊 Bundling $dir/$base.$ext"
                cp "$dir/$base.$ext" "$APP_NAME.app/Contents/Resources/$base.$ext"
            fi
        done
    done
done

# Create Info.plist with accessory mode LSUIElement enabled
cat > "$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Nimbus reads what's playing in Spotify, Apple Music, and your browser to show it in the Dynamic Island.</string>
    <key>NSLocationUsageDescription</key>
    <string>Nimbus uses your location to show local weather conditions.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Nimbus uses your location to show local weather conditions.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Nimbus shows your upcoming events in the calendar widget.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Nimbus shows your upcoming events in the calendar widget.</string>
</dict>
</plist>
EOF

# Make executable
chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"

echo "✅ $APP_NAME.app created successfully!"
echo "📍 Location: $(pwd)/$APP_NAME.app"
echo "Double-click to launch."
