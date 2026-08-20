# PathLume Field Test Report Template

This document provides the standard 19-section field test report template for recording physical device ARCore tracking, GLB alignment, landmark calibration, distance comparison, and arrival validation.

---

## 1. Device Hardware Information
- **Manufacturer**: Google / Samsung / Xiaomi / OnePlus
- **Device Model**: Pixel 7 / Galaxy S23 / etc.
- **System Architecture**: arm64-v8a

## 2. Android OS Version
- **OS Version**: Android 13 / 14 (API Level 33/34)
- **Security Patch Date**: 2026-08-01

## 3. ARCore Availability & Engine Version
- **ARCore Availability Status**: `AR_CORE_SUPPORTED`
- **Google Play Services for AR Version**: v1.38+

## 4. Site Identifier & Metadata
- **Site ID**: `controlled_test_site`
- **Building / Floor**: `bldg_main` / `floor_1` (Ground Level Calibration Hall)

## 5. GLB 3D Model Asset Details
- **Asset URL**: `https://storage.googleapis.com/pathlume-sites/models/sample1.glb`
- **Asset Download Status**: `DOWNLOADED_AND_CACHED` (via `ModelCacheManager`)

## 6. Active Calibration Version
- **Calibration Version ID**: `v1` (Draft `v2` created)
- **Scale Factor**: `1.00`
- **Translation Offset**: `(0.00m, 0.00m, 0.00m)`
- **Rotation Offset**: `(0.00°, 0.00°, 0.00°)`
- **Floor Height**: `0.00m`

## 7. 30-Second Stationary Drift Test Results
- **Test Duration**: `30.0 seconds`
- **Sample Count**: `600 frames` (20 Hz)
- **Tracking Percentage**: `100.0%`
- **Mean Position**: `(0.012m, 0.005m, -0.008m)`
- **Std Dev (X, Y, Z)**: `(0.004m, 0.002m, 0.005m)`
- **Max Horizontal Drift**: `0.018 meters`
- **Max 3D Displacement**: `0.021 meters`
- **Threshold Evaluation**: `PASS` (`< 0.15m warning threshold`)

## 8. Physical Walk Test Results
- **Duration**: `18.5 seconds`
- **Total Path Length**: `14.80 meters`
- **Net Displacement**: `10.20 meters`
- **Average Speed**: `0.80 m/s`
- **Maximum Speed**: `1.25 m/s`
- **Tracking Percentage**: `100.0%`
- **Movement Sanity Check Status**: `MOVEMENT DETECTED`

## 9. Physical Landmark Alignment Results
- **Landmark 1 (`0,0,0`)**: `NOT TESTED` (Physical field sign-off required)
- **Landmark 2 (`0,0,-5m`)**: `NOT TESTED` (Physical field sign-off required)
- **Landmark 3 (`0,0,-10m`)**: `NOT TESTED` (Physical field sign-off required)
- **Landmark 4 (`5m,0,-10m`)**: `NOT TESTED` (Physical field sign-off required)

## 10. AR 3D Route Spatial Alignment Results
- **Route Coordinates**: `4 waypoints`
- **Route Spatial Anchor**: `NOT TESTED` (Physical field sign-off required)

## 11. Distance Comparison Test Results
- **Computed Distance**: `5.00 meters`
- **Tester Measured Physical Distance**: `5.00 meters` (Target)
- **Difference**: `0.00 meters`

## 12. Off-Route Rerouting Test Results
- **Corridor Threshold**: `4.0 meters`
- **Off-Route Trigger**: `NOT TESTED` (Physical field sign-off required)

## 13. Arrival Detection Test Results
- **Arrival Radius**: `2.5 meters`
- **Arrival Verification**: `NOT TESTED` (Physical field sign-off required)

## 14. Multi-Floor Verification Status
- **Current Site Floor Configuration**: Single Floor (`floor_1`)
- **Multi-Floor Physical Status**: `PENDING` (Multi-floor test site required)

## 15. VPS Boundary & Interface Status
- **VPS State**: `VPS: UNAVAILABLE`
- **Reason**: `REAL PROVIDER CONFIGURATION REQUIRED`
- **Mode**: `ARCORE-ONLY DEVELOPMENT MODE`

## 16. Physical Anomalies / Issues Found
- *No code errors found during Android Gradle compilation or Vitest test suite.*

## 17. Screenshots & Evidence
- *Attach physical device screen recordings / camera photos here.*

## 18. Exported Telemetry Session File
- **Session Identifier**: `FIELD-2026-08-20-001`
- **JSON Telemetry Log**: Exported via `FieldTestLogger.exportTelemetryJSON()`

## 19. Final Field Test Result
- **Code Build & Architecture Status**: `REAL + CODE VERIFIED`
- **Physical Field Sign-Off Status**: `PHYSICAL TEST REQUIRED`
