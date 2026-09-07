# PATHLUME APK Size Baseline Report

Date: 2026-09-06

## Baseline Measurements

- **Unoptimized Release APK Size**: 64.4 MB (67,522,084 bytes)
- **Unoptimized Release AAB Size**: 57.0 MB (59,754,611 bytes)
- **Release APK Path**: `build/app/outputs/flutter-apk/app-release.apk`
- **Release AAB Path**: `build/app/outputs/bundle/release/app-release.aab`

## Largest Files & Contributors Inside Baseline APK

### 1. Duplicated Native Architectures (ABIs)
The baseline APK packages **3 complete set of native `.so` binaries** for `x86_64`, `arm64-v8a`, and `armeabi-v7a`:

- **`lib/x86_64/` (Total: ~24.3 MB)**
  - `libflutter.so`: 13.05 MB
  - `libapp.so`: 5.64 MB
  - `libbarhopper_v3.so`: 5.52 MB
- **`lib/arm64-v8a/` (Total: ~21.6 MB)**
  - `libflutter.so`: 11.75 MB
  - `libapp.so`: 5.44 MB
  - `libbarhopper_v3.so`: 4.36 MB
- **`lib/armeabi-v7a/` (Total: ~17.3 MB)**
  - `libflutter.so`: 8.62 MB
  - `libapp.so`: 5.98 MB
  - `libbarhopper_v3.so`: 2.80 MB

### 2. Android Code & Resources
- `classes.dex`: 2.60 MB (R8 minification and resource shrinking are currently disabled in `android/app/build.gradle.kts`).
- `resources.arsc`: 751 KB

### 3. ML Kit / Barcode Scanning Models
- `barcode_ssd_mobilenet_v1_dmp25_quant.tflite`: 390 KB
- `oned_feature_extractor_mobile.tflite`: 276 KB
- `oned_auto_regressor_mobile.tflite`: 213 KB

### 4. Fonts & Assets
- `CupertinoIcons.ttf`: 257 KB

## High-Value Size Optimization Targets

1. **Enable Android R8 Minification & Resource Shrinking**:
   - Set `isMinifyEnabled = true` and `isShrinkResources = true` in `android/app/build.gradle.kts` release block.
   - Configure ProGuard keep rules in `android/app/proguard-rules.pro` for ARCore, OpenGL ES, JNI, and Flutter platform channels.

2. **ABI Splitting & NDK Filtering**:
   - Split APKs by ABI (`flutter build apk --split-per-abi`) or filter target ABIs in Gradle.
   - Per-ABI APK (e.g. `arm64-v8a` for modern physical Android devices) eliminates ~40MB of redundant architectures.

3. **Asset & Dependency Cleanup**:
   - Audit `pubspec.yaml` for unused assets/packages.
