# Xcode Cloud CI/CD Scripts for SIRA PRO

This folder contains custom scripts for Xcode Cloud to build your Flutter app automatically.

## 📋 Scripts Overview

### 1. `ci_post_clone.sh` ⚡
**When it runs:** Immediately after Xcode Cloud clones your repository

**What it does:**
- Installs Flutter SDK (latest stable version)
- Configures Flutter environment
- Runs `flutter pub get` to install dependencies
- Runs `pod install` for iOS dependencies
- Verifies the setup with `flutter doctor`

### 2. `ci_pre_xcodebuild.sh` 🔨
**When it runs:** Just before Xcode starts building

**What it does:**
- Ensures Flutter dependencies are current
- Builds the Flutter iOS framework
- Runs Flutter tests (optional)
- Prepares the app for Xcode build

### 3. `ci_post_xcodebuild.sh` 🎉
**When it runs:** After Xcode completes the build

**What it does:**
- Displays build information
- Performs cleanup tasks
- Can be customized for notifications or additional processing

---

## 🚀 Setup Instructions

### Step 1: Prepare Your Xcode Project

1. Open Terminal and navigate to your project:
   ```bash
   cd /Users/ibrahimfleifel/code/sirapro
   open ios/Runner.xcworkspace
   ```

2. In Xcode, configure your project:
   - Select the **Runner** target
   - Go to **Signing & Capabilities**
   - Choose your Team
   - Set a unique Bundle Identifier (e.g., `com.yourcompany.sirapro`)

### Step 2: Set Up Xcode Cloud

1. **In Xcode:** Go to **Product → Xcode Cloud → Create Workflow**

2. **Choose your Git provider:**
   - GitHub (recommended)
   - GitLab
   - Bitbucket
   - Or use Xcode Cloud Git

3. **Grant Repository Access:**
   - For GitHub: Install Xcode Cloud GitHub app
   - For others: Follow the authentication flow

### Step 3: Configure Workflows

#### Recommended Workflow 1: Pull Request Validation
```
Name: PR Checks
Trigger: Pull Request to 'main'
Environment: macOS (Xcode Latest)
Actions:
  - Build for iOS Simulator
  - Run Tests
Archive: No
```

#### Recommended Workflow 2: Beta Deployment
```
Name: Beta Release
Trigger: Branch 'main' changes
Environment: macOS (Xcode Latest)
Actions:
  - Build for iOS Device
  - Run Tests
  - Archive
Post-Actions:
  - Deploy to TestFlight (Internal Testing)
```

#### Recommended Workflow 3: Production Release
```
Name: Production Release
Trigger: Tag matching 'v*.*.*'
Environment: macOS (Xcode Latest)
Actions:
  - Build for iOS Device
  - Run Tests
  - Archive
Post-Actions:
  - Deploy to TestFlight (External Testing)
  - (Optional) Submit to App Store
```

### Step 4: Configure Environment Variables (If Needed)

If your app uses API keys or secrets:

1. In **App Store Connect** → **Your App** → **Xcode Cloud** → **Settings**
2. Add environment variables:
   ```
   EXAMPLE_API_KEY=your_key_here
   FLUTTER_ENV=production
   ```

3. Access them in your Flutter app using:
   ```dart
   const apiKey = String.fromEnvironment('EXAMPLE_API_KEY');
   ```

### Step 5: Flutter Version

The script uses the latest stable Flutter version from the stable channel. This ensures compatibility and automatically gets updates. If you need a specific version, you can modify `ci_post_clone.sh` to checkout a specific tag instead of the stable branch.

---

## 🔧 Customization Options

### Enable Build Runner (if using code generation)

In `ci_post_clone.sh`, uncomment line 46:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Disable Tests in CI

In `ci_pre_xcodebuild.sh`, comment out lines 26-27:
```bash
# echo "🧪 Running Flutter tests..."
# flutter test || echo "⚠️  Some tests failed, but continuing build..."
```

### Add Slack Notifications

In `ci_post_xcodebuild.sh`, add:
```bash
if [ "$CI_XCODEBUILD_ACTION" = "archive" ]; then
    curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"✅ Build successful: '"$CI_PRODUCT"' #'"$CI_BUILD_NUMBER"'"}' \
    YOUR_SLACK_WEBHOOK_URL
fi
```

---

## 📱 Testing the Setup Locally

Before pushing to Xcode Cloud, test the scripts locally:

```bash
# Make sure you're in the project root
cd /Users/ibrahimfleifel/code/sirapro

# Test Flutter setup
flutter pub get
flutter test
flutter build ios --release

# Test iOS pod install
cd ios
pod install
```

---

## 🐛 Troubleshooting

### Build fails with "Flutter not found"
- Check that `ci_post_clone.sh` is executable: `ls -la ios/ci_scripts/`
- Verify Flutter version is valid: https://flutter.dev/docs/development/tools/sdk/releases

### Pod install fails
- Ensure CocoaPods is updated in `ci_post_clone.sh`
- Check your Podfile for syntax errors

### Tests are timing out
- Increase timeout in Xcode Cloud workflow settings
- Or disable tests temporarily in `ci_pre_xcodebuild.sh`

### Archive upload fails
- Verify your bundle identifier is unique
- Check signing certificates in Xcode
- Ensure App Store Connect has the app created

---

## 📚 Additional Resources

- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)

---

## ✅ Next Steps

1. **Commit these scripts to Git:**
   ```bash
   git add ios/ci_scripts/
   git commit -m "Add Xcode Cloud CI/CD scripts"
   git push origin main
   ```

2. **Open Xcode and create your first workflow**

3. **Make a test commit to trigger the build**

4. **Monitor builds in App Store Connect**

---

## 📝 Notes

- These scripts use the latest stable Flutter version
- The scripts automatically run `flutter clean` and `pub get`
- CocoaPods are automatically updated and installed
- Tests run before archiving (can be disabled)

**Happy Building! 🚀**
