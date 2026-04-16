#!/bin/bash
# Compile SSDT-USB-WORK.asl to AML

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASL_FILE="$SCRIPT_DIR/SSDT-USB-WORK.asl"
AML_FILE="$SCRIPT_DIR/SSDT-USB-WORK.aml"

echo "=== Compiling SSDT-USB-WORK ==="

# Check for iasl
if ! command -v iasl &> /dev/null; then
    echo "iasl not found. Installing macOS iasl..."
    # Try common locations
    if [ -f /usr/local/bin/iasl ]; then
        IASL="/usr/local/bin/iasl"
    elif [ -f /opt/homebrew/bin/iasl ]; then
        IASL="/opt/homebrew/bin/iasl"
    else
        echo "Please install iasl:"
        echo "  brew install acpica"
        exit 1
    fi
else
    IASL="iasl"
fi

echo "Using: $IASL"
echo "Input: $ASL_FILE"
echo "Output: $AML_FILE"

# Compile
"$IASL" -p "$AML_FILE" "$ASL_FILE"

if [ $? -eq 0 ]; then
    echo "=== Compilation successful ==="
    ls -la "$AML_FILE"
    echo ""
    echo "To install to EFI:"
    echo "  sudo cp $AML_FILE /Volumes/EFI/EFI/OC/ACPI/"
    echo "  # Then add to config.plist ACPI -> Add"
else
    echo "=== Compilation failed ==="
    exit 1
fi
