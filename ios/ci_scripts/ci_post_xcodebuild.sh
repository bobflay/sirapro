#!/bin/sh

# ci_post_xcodebuild.sh
# This script runs after Xcode completes the build
# It can be used for cleanup, notifications, or additional processing

set -e # Exit on any error

echo "======================================"
echo "🎉 Post-build Processing"
echo "======================================"

# Setup Flutter path
FLUTTER_DIR="$HOME/flutter"
export PATH="$PATH:$FLUTTER_DIR/bin"

# Navigate to project root
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Display build info
echo "📱 Build Information:"
echo "   Product: $CI_PRODUCT"
echo "   Workflow: $CI_WORKFLOW"
echo "   Build Number: $CI_BUILD_NUMBER"
echo "   Branch: $CI_BRANCH"
echo "   Commit: $CI_COMMIT"

# You can add custom post-build actions here:
# - Send notifications to Slack/Discord
# - Upload build artifacts to custom storage
# - Run additional analysis tools
# - Generate release notes

# Example: Save build metadata (optional)
if [ "$CI_XCODEBUILD_ACTION" = "archive" ]; then
    echo "📦 Archive created successfully"
    echo "Build completed at: $(date)" > build_info.txt
    echo "Version: $(cat pubspec.yaml | grep version: | cut -d ' ' -f 2)" >> build_info.txt
fi

# Cleanup temporary files if needed
echo "🧹 Cleaning up temporary files..."
rm -rf build_info.txt || true

echo "======================================"
echo "✨ Post-build processing complete!"
echo "======================================"
