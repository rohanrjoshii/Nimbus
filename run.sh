#!/bin/bash
# Compile and run the Nimbus Dynamic Island app

echo "Compiling Nimbus..."
swiftc Sources/Nimbus/*.swift -o Nimbus -framework AppKit -framework SwiftUI -framework Combine

if [ $? -eq 0 ]; then
    echo "Compilation successful! Starting Nimbus..."
    # Start in the background so the terminal stays interactive, or run directly
    ./Nimbus
else
    echo "Compilation failed!"
fi
