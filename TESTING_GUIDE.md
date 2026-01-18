# Testing Guide - The Right Direction

## Prerequisites

### 1. Install Flutter SDK

**Windows:**
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter` (or your preferred location)
3. Add `C:\flutter\bin` to your system PATH:
   - Search "Environment Variables" in Windows
   - Edit "Path" under User variables
   - Add `C:\flutter\bin`
4. Restart your terminal

**Verify installation:**
```powershell
flutter doctor -v
```

### 2. Install Development Tools

**For Android development:**
- Install [Android Studio](https://developer.android.com/studio)
- In Android Studio: Tools → SDK Manager → Install Android SDK
- Tools → Device Manager → Create Virtual Device (emulator)

**For iOS development (Mac only):**
- Install Xcode from App Store
- Run: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
- Run: `sudo xcodebuild -runFirstLaunch`

### 3. Environment Configuration

Create a `.env` file in the project root for the Gemini API key:
```
GEMINI_API_KEY=your_api_key_here
```

Get a free API key from: https://makersuite.google.com/app/apikey

---

## Step-by-Step Verification

### Step 1: Get Dependencies
```powershell
cd "c:\Users\Bradl\Desktop\TDR\The-Right-Direction\the_right_direction"
flutter pub get
```

**Expected output:** "Got dependencies!" with no errors

### Step 2: Analyze Code
```powershell
flutter analyze
```

**Expected output:** "No issues found!" (warnings are acceptable for initial development)

### Step 3: List Connected Devices
```powershell
flutter devices
```

**Expected output:** At least one device (emulator or physical device)

### Step 4: Run the App
```powershell
# For Android emulator or connected device:
flutter run

# For specific device:
flutter run -d <device_id>

# For web (limited functionality):
flutter run -d chrome

# For iOS simulator (Mac only):
flutter run -d "iPhone 15 Pro"
```

---

## Testing Modes

### Testing Deaf Mode

1. **Launch app** → App starts in Deaf Mode by default
2. **Grant permissions** when prompted (microphone, camera)
3. **Speech-to-Text test:**
   - Tap the microphone button to enable speech recognition
   - Speak into your device
   - Verify text appears on screen
4. **Sign Language test:**
   - Enable sign recognition toggle
   - Make ASL signs in front of camera
   - Verify gesture recognition feedback
5. **Mode switch test:**
   - Swipe horizontally across the screen
   - Feel for 3 haptic blips (Blind Mode activation)

### Testing Blind Mode

1. **Swipe to switch** from Deaf Mode
2. **Grant camera permission** if prompted
3. **Object detection test:**
   - Point camera at various objects
   - Listen for TTS announcements
   - Feel haptic feedback patterns
4. **Proximity test:**
   - Move closer to objects
   - Verify haptic intensity increases
   - Verify TTS warnings become more urgent
5. **LiDAR test (iPhone 12 Pro+ only):**
   - Verify depth overlay appears
   - Test in low-light conditions

### Testing Accessibility

1. **Enable VoiceOver/TalkBack:**
   - iOS: Settings → Accessibility → VoiceOver → On
   - Android: Settings → Accessibility → TalkBack → On
2. **Navigate the app** using screen reader gestures
3. **Verify all buttons have proper labels**
4. **Test swipe gestures work with screen reader active**

---

## Device-Specific Testing

### Physical Device (Recommended)
```powershell
# Enable USB debugging on Android device, then:
flutter run
```

**Why physical device is best:**
- ✅ Real camera and microphone access
- ✅ Actual haptic feedback
- ✅ LiDAR support (iOS)
- ✅ True performance metrics
- ✅ Real accessibility features

### Android Emulator
```powershell
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>

# Run app
flutter run
```

**Limitations:**
- ⚠️ No real haptics (simulated)
- ⚠️ Camera requires webcam passthrough
- ⚠️ Microphone requires host passthrough
- ⚠️ No LiDAR support

### iOS Simulator (Mac only)
```powershell
open -a Simulator
flutter run
```

**Limitations:**
- ⚠️ No haptics
- ⚠️ No camera
- ⚠️ No LiDAR
- ⚠️ No microphone

### Web (Chrome)
```powershell
flutter run -d chrome
```

**Limitations:**
- ❌ No haptics
- ⚠️ Limited camera API
- ⚠️ No LiDAR
- ⚠️ Different permission model

---

## Automated Testing

### Run Unit Tests
```powershell
flutter test
```

### Run Integration Tests
```powershell
flutter test integration_test/
```

### Generate Coverage Report
```powershell
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Debug Mode Features

When running with `flutter run`:

| Key | Action |
|-----|--------|
| `r` | Hot reload (apply changes) |
| `R` | Hot restart (full restart) |
| `p` | Toggle debug paint |
| `o` | Toggle platform (iOS/Android) |
| `q` | Quit |

### View Logs
```powershell
# In separate terminal while app is running:
flutter logs
```

### Attach Debugger
1. Run with: `flutter run`
2. Open Chrome DevTools (for web) or VS Code debugger
3. Set breakpoints in Dart code

---

## Why This Testing Approach Is Correct

### 1. Progressive Verification
We verify each layer independently:
- **Dependencies** → Ensures all packages resolve
- **Static analysis** → Catches type errors and lint issues
- **Runtime** → Validates actual behavior

### 2. Platform-Appropriate Testing
| Feature | Physical Device | Emulator | Web |
|---------|-----------------|----------|-----|
| Core Logic | ✅ | ✅ | ✅ |
| Camera | ✅ | ⚠️ | ⚠️ |
| Microphone | ✅ | ⚠️ | ⚠️ |
| Haptics | ✅ | ❌ | ❌ |
| LiDAR | ✅ (iOS Pro) | ❌ | ❌ |
| Accessibility | ✅ | ⚠️ | ⚠️ |

### 3. Accessibility-First Validation
For an accessibility app, we must test WITH accessibility features enabled:
- Screen readers (VoiceOver/TalkBack)
- Switch control
- Reduced motion settings
- High contrast mode

### 4. Real-World Conditions
Physical device testing captures:
- Actual sensor behavior
- Real network conditions
- True battery/performance impact
- Genuine haptic feedback quality

### 5. Iterative Development
Hot reload (`r`) allows rapid iteration:
1. Make code change
2. Press `r` to reload
3. See change immediately
4. No full rebuild required

---

## Troubleshooting

### "flutter: command not found"
Add Flutter to PATH:
```powershell
$env:Path += ";C:\flutter\bin"
```

### "No devices found"
```powershell
# For Android:
flutter config --android-sdk "C:\Users\<user>\AppData\Local\Android\Sdk"

# Start emulator manually:
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd <avd_name>
```

### "Gradle build failed"
```powershell
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### "CocoaPods not installed" (Mac)
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
flutter run
```

### Permission denied on camera/microphone
- Android: Settings → Apps → The Right Direction → Permissions
- iOS: Settings → Privacy → Camera/Microphone → The Right Direction

---

## Quick Start Command Sequence

```powershell
# Navigate to project
cd "c:\Users\Bradl\Desktop\TDR\The-Right-Direction\the_right_direction"

# Get dependencies
flutter pub get

# Analyze for errors
flutter analyze

# Run on connected device
flutter run
```

If you have an Android phone:
1. Enable Developer Options (tap Build Number 7 times)
2. Enable USB Debugging
3. Connect via USB
4. Accept the debugging prompt on phone
5. Run `flutter run`
