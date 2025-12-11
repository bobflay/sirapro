#!/bin/sh

# ci_pre_xcodebuild.sh
# This script runs before Xcode starts building your app
# It ensures Flutter build is ready and all assets are generated

set -e # Exit on any error

echo "======================================"
echo "🔨 Pre-build Flutter Preparation"
echo "======================================"

# Setup Flutter path
FLUTTER_DIR="$HOME/flutter"
export PATH="$PATH:$FLUTTER_DIR/bin"

# Navigate to project root
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Ensure dependencies are up to date
echo "📦 Ensuring dependencies are current..."
flutter pub get

# Build Flutter framework for iOS
echo "🏗️  Building Flutter iOS framework..."
flutter build ios-framework --no-debug --no-profile --release

# Generate localization files if you use them (uncomment if needed)
# flutter gen-l10n

# Run tests before building (optional, comment out if you want faster builds)
echo "🧪 Running Flutter tests..."
flutter test || echo "⚠️  Some tests failed, but continuing build..."

# Ensure Flutter is ready
echo "✅ Checking Flutter status..."
flutter doctor

echo "======================================"
echo "✨ Pre-build preparation complete!"
echo "======================================"
