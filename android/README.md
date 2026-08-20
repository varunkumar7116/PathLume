# PathLume Android Application

This directory contains the native Android application for **PathLume** built with **Kotlin**, **Jetpack Compose**, **CameraX**, **ML Kit Barcode Scanning**, and **Google ARCore**.

---

## 📋 Prerequisites

Before building and running the application, ensure you have the following installed on your development machine:

1. **Java Development Kit (JDK)**: Version 17 or higher.
2. **Android SDK**: API Level 34 (Android 14) with Build Tools installed.
3. **Android Device / Emulator**:
   - Physical device running Android 7.0 (API 24) or higher with Camera permission enabled.
   - For AR navigation features, a device supporting [Google Play Services for AR (ARCore)](https://developers.google.com/ar/devices) is recommended.

---

## 🚀 How to Build & Run

### 1. Build the APK

To compile the application and generate the Debug APK executable:

#### **On Windows (PowerShell / Command Prompt):**
```powershell
cd android
.\gradlew.bat assembleDebug
```

#### **On macOS / Linux:**
```bash
cd android
chmod +x gradlew
./gradlew assembleDebug
```

The compiled APK will be generated at:
```
android/app/build/outputs/apk/debug/app-debug.apk
```

---

### 2. Install and Run on Connected Device / Emulator

Ensure your Android device is connected via USB with **USB Debugging** enabled, or an Android Virtual Device (AVD) emulator is running.

#### **Option A: Install via Gradle (Recommended)**
```powershell
cd android
.\gradlew.bat installDebug
```
This automatically compiles, transfers, installs, and grants necessary development permissions to the app on your connected device.

#### **Option B: Install via ADB**
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

#### **Option C: Open in Android Studio**
1. Launch **Android Studio**.
2. Select **Open an Existing Project** and choose the `android/` directory in this repository.
3. Wait for Gradle sync to complete.
4. Click the **Run 'app'** button (`Shift + F10`) or press **Debug**.

---

## 🛠️ App Features & Usage Guide

1. **QR Code Scanning**:
   - Open the app and grant Camera permission.
   - Point the camera reticle at a supported PathLume QR code (or test QR code).
   - Supported formats:
     - Web URL: `https://pathlume.app/s/{siteId}`
     - Custom URI: `pathlume://site/{siteId}`
     - JSON format: `{"siteId": "demo_site"}`
     - Direct string ID: `demo_site`

2. **VPS Localization & AR Navigation**:
   - Once a site is scanned or loaded, the VPS (Visual Positioning System) module calculates pose coordinates within the site model frame.
   - Follow on-screen visual directions and floor markers to navigate to target destinations.

3. **Deep Linking**:
   - Clicking a `https://pathlume.app/s/{siteId}` link on your Android device automatically opens the PathLume app directly into that specific site location.

---

## 🔍 Troubleshooting

- **AAPT / Resource Errors**: Ensure Gradle cache is clean by running `.\gradlew.bat clean`.
- **Camera Permission Denied**: Go to Android *Settings > Apps > PathLume > Permissions* and enable Camera manually.
- **ARCore Not Supported**: The app falls back gracefully to 2D compass / graph navigation on devices without ARCore hardware.
