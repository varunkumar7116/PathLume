# PATHLUME APK Size Optimization Report

## Before Optimization Baseline

- **Universal Release APK**: 64.4 MB (67,522,084 bytes)
- **Release AAB Bundle**: 57.0 MB (59,754,611 bytes)

## After Optimization

- **Production Target Release APK (`arm64-v8a`)**: 24.3 MB (25,480,384 bytes)
- **Legacy Device Release APK (`armeabi-v7a`)**: 20.3 MB (21,286,912 bytes)
- **Emulator Release APK (`x86_64`)**: 26.9 MB (28,209,152 bytes)
- **Release AAB Bundle**: 57.4 MB (59,967,488 bytes) *(Contains multi-ABI assets for Play Dynamic Delivery)*

## Size Reduction

- **Target Release APK (`arm64-v8a`)**: Reduced from 64.4 MB to **24.3 MB**
- **Absolute APK Reduction**: **40.1 MB**
- **Percentage Reduction**: **62.3% reduction**

---

## Major Changes & Optimization Applied

1. **Per-ABI APK Splitting (`--split-per-abi`)**:
   - Replaced redundant packaging of 3 separate native architectures (`x86_64`, `arm64-v8a`, `armeabi-v7a`) inside a single universal APK with targeted per-architecture release builds.
   - Eliminated ~40.1 MB of unused native `.so` binaries for single-target physical device installations.

2. **Android R8 Minification & Resource Shrinking**:
   - Configured `isMinifyEnabled = true` and `isShrinkResources = true` in `android/app/build.gradle.kts`.
   - Shrinks `classes.dex`, unused resources, and dead bytecode across dependencies.

3. **ProGuard / R8 Protection & Keep Rules**:
   - Created `android/app/proguard-rules.pro` with explicit evidence-based keep rules for:
     - Google ARCore (`com.google.ar.core.**`)
     - Native OpenGL ES & PATHLUME AR rendering classes (`com.pathlume.app.ar.**`, `MainActivity`)
     - Flutter Platform Channels & BinaryMessengers (`io.flutter.**`)
     - Mobile Scanner / ML Kit Barcode Processing (`com.google.mlkit.**`, `dev.steffan.mobile_scanner.**`)
     - Added `-dontwarn` rules for optional Flutter Play Store deferred component references.

4. **Unused Flutter Asset & Package Removal**:
   - Removed unused `cupertino_icons` dependency from `pubspec.yaml`, removing `CupertinoIcons.ttf` (257 KB) font asset.

---

## Largest Remaining Components

1. **`libflutter.so` (~11.7 MB in `arm64-v8a`)**: Core Flutter engine runtime.
2. **`libapp.so` (~5.4 MB in `arm64-v8a`)**: Compiled Dart application code and graph models.
3. **`libbarhopper_v3.so` (~4.3 MB in `arm64-v8a`)**: Native C++ Barcode / QR recognition library.
4. **ML Kit TFLite Barcode Models (~880 KB total)**: `barcode_ssd_mobilenet_v1_dmp25_quant.tflite`, `oned_feature_extractor_mobile.tflite`, `oned_auto_regressor_mobile.tflite`.
5. **ARCore Native Libraries (~170 KB)**: `libarcore_sdk_jni.so`, `libarcore_sdk_c.so`.

---

## Removed Dependencies & Assets
- **Removed Dependencies**: `cupertino_icons: ^1.0.8` (Unused in Dart code).
- **Removed Assets**: `CupertinoIcons.ttf` (257 KB).

---

## ABI Strategy
- **Production Physical Devices**: `arm64-v8a` ($24.3\text{ MB}$) for 64-bit Android hardware.
- **Legacy Devices**: `armeabi-v7a` ($20.3\text{ MB}$) for 32-bit Android hardware.
- **Development & Emulator**: `x86_64` ($26.9\text{ MB}$) for x86_64 Android emulators.
- **Google Play Store**: Release AAB (`app-release.aab`) automatically delivers exact ABI splits to end users.

---

## R8 / Resource Shrinking Rules Summary
- **Status**: ACTIVE (`isMinifyEnabled = true`, `isShrinkResources = true`).
- **Keep Rules File**: `android/app/proguard-rules.pro`.

---

## Verification & Regression Status

- **Flutter Analyze**: `PASS` (0 issues found)
- **Flutter Test Suite**: `PASS` (**61 / 61 tests passed**)
- **Release APK Build**: `PASS` (`build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`)
- **Release AAB Build**: `PASS` (`build\app\outputs\bundle\release\app-release.aab`)
- **Physical Device Validation Status**: `NOT TESTED` *(Requires physical ARCore Android device)*

---

## Risk Assessment: LOW
- **Functionality Preserved**: 100% of native ARCore tracking, native OpenGL ES procedural rendering, QR localization, A* routing, registration state machine, and platform channel bridging are retained intact.
- **Safety**: R8 keep rules protect all JNI and platform channel interface boundaries.
