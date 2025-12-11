#!/bin/sh

# ci_post_clone.sh
# This script runs after Xcode Cloud clones your repository
# It sets up Flutter and prepares the environment for building

set -e # Exit on any error

echo "======================================"
echo "🚀 Starting Flutter Setup for Xcode Cloud"
echo "======================================"

# Define Flutter version (you can change this to match your local version)
FLUTTER_VERSION="3.38.4"
FLUTTER_DIR="$HOME/flutter"

# Install Flutter
echo "📦 Installing Flutter ${FLUTTER_VERSION}..."
if [ ! -d "$FLUTTER_DIR" ]; then
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    cd "$FLUTTER_DIR"
    git checkout "$FLUTTER_VERSION"
else
    echo "Flutter already exists, updating..."
    cd "$FLUTTER_DIR"
    git fetch
    git checkout "$FLUTTER_VERSION"
fi

# Add Flutter to PATH
export PATH="$PATH:$FLUTTER_DIR/bin"

# Verify Flutter installation
echo "🔍 Verifying Flutter installation..."
flutter --version

# Disable analytics (optional, but good for CI)
flutter config --no-analytics

# Run Flutter doctor to check setup
echo "🏥 Running Flutter doctor..."
flutter doctor -v

# Navigate to project root
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Clean any previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get Flutter dependencies
echo "📥 Getting Flutter dependencies..."
flutter pub get

# Run code generation if you use build_runner (uncomment if needed)
# flutter pub run build_runner build --delete-conflicting-outputs

# Precache iOS artifacts
echo "💾 Precaching iOS artifacts..."
flutter precache --ios

# Verify iOS project
echo "✅ Verifying iOS project setup..."
cd ios

# Check if Podfile exists, if so run pod install
if [ -f "Podfile" ]; then
    echo "📦 Installing CocoaPods dependencies..."
    pod repo update || true
    pod install || pod update
else
    echo "ℹ️  No Podfile found - using Swift Package Manager"
fi

echo "======================================"
echo "✨ Flutter setup completed successfully!"
echo "======================================"
