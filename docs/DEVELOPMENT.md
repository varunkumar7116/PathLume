# PATHLUME Development Guide

## Environment Setup

### Prerequisites
- JDK 17 (`JAVA_HOME`)
- Android SDK (`ANDROID_HOME=E:\Android`)
- Flutter SDK (`E:\flutter\bin`)
- Android device with ARCore support (or Android Emulator with ARCore)

### Building & Running

```powershell
# Set environment
$env:ANDROID_HOME = "E:\Android"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot"
$env:PATH = "E:\flutter\bin;E:\Android\platform-tools;C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot\bin;" + $env:PATH

# Run tests
E:\flutter\bin\flutter.bat test

# Build debug APK
E:\flutter\bin\flutter.bat build apk --debug

# Build release APK
E:\flutter\bin\flutter.bat build apk --release

# Install APK on connected device
E:\Android\platform-tools\adb.exe install -r build/app/outputs/flutter-apk/app-release.apk
```

## Testing AR Features

1. Connect ARCore-supported Android device via USB with ADB debugging enabled.
2. Launch app and navigate to **Start AR Test**.
3. Accept camera permissions when prompted.
4. Move device around environment until tracking status displays `TRACKING`.
5. Tap **Place Test Marker** to place 3D marker in camera frame.
6. Verify marker remains anchored to physical coordinate system.
