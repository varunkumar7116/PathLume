# Physical Device Validation & ARCore Test Checklist

This document defines the physical device acceptance test checklist and coordinate system alignment specification for PathLume indoor AR navigation.

---

## 1. Site World Coordinate System Alignment Specification

All 3D components in PathLume (GLB 3D models, Google ARCore 6DoF camera poses, VPS poses, NavMesh polygon nodes, and destination targets) are transformed into a single canonical **SITE WORLD COORDINATE SYSTEM**.

### Coordinate System Parameters:
- **Units**: Meters (`1.0 unit = 1.0 meter`)
- **Up Axis**: Y-axis positive (`+Y` points UP vertically)
- **Forward Axis**: Z-axis negative (`-Z` points FORWARD into scene)
- **Right Axis**: X-axis positive (`+X` points RIGHT horizontally)
- **Handedness**: Right-Handed Cartesian Coordinate System (`+X` Right, `+Y` Up, `+Z` Back)
- **Origin `(0.0, 0.0, 0.0)`**: Canonical building site reference origin point defined during site publishing.
- **Scale**: `1.0` (Uniform 1:1 metric scale)
- **Rotation**: Euler angles in degrees `(Rx, Ry, Rz)` around site origin.
- **Translation**: 3D offset vector `(Tx, Ty, Tz)` in meters from GLB model origin to site canonical origin.

---

## 2. Physical Device Acceptance Test Checklist

### Test Metadata
- **Device Model**: Google Pixel / Samsung Galaxy (ARCore Compatible)
- **Android OS Version**: Android 12+ (API 31+)
- **ARCore Service Version**: Google Play Services for AR v1.38+
- **APK Version**: PathLume v0.4.1 (`app-debug.apk`)
- **Test Date**: 2026-08-20

---

### Test Execution Checklist

| Test Item | Verification Requirement | Code Status | Physical Device Status |
| :--- | :--- | :--- | :--- |
| **A. ARCore Support Check** | Check `ARCoreSessionManager.checkArCoreSupport()`. Displays error card on unsupported hardware; starts session on supported devices. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **B. Camera Permission** | Requests `android.permission.CAMERA` gracefully before session launch. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **C. Real Camera Feed** | Shows live rear camera view via `PreviewView` / ARCore surface; no static/simulated filter overlays. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **D. ARCore Tracking** | Session transitions to `TrackingState.TRACKING` and returns valid 6DoF `camera.pose`. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **E. Real Motion Response** | Stationary phone -> pose stable. Walking forward -> pose X/Z updates proportionally. Turning phone -> yaw heading changes. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **F. Developer Diagnostics** | Telemetry overlay renders ARCore 6DoF, `FusedPose`, navigation metrics, and honest `VPS: UNAVAILABLE` status. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **G. Published GLB Loading** | Downloads site GLB model from Firebase Storage / site metadata into local cache (`ModelCacheManager`). | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **H. SITE WORLD Alignment** | Applies `WorldCoordinateManager` scaling, rotation, and translation matrices to GLB geometry. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **I. Dynamic Navigation Start**| A* path calculation starts from current `FusedPose` in SITE WORLD, never default/hardcoded node or QR scan pose. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **J. Stationary Distance Test**| Remaining distance remains constant when phone is stationary (zero timer/drift decrements). | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **K. Walking Distance Test** | Distance decreases as user physically approaches destination target; increases when walking away. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **L. Real Off-Route Reroute**| Triggers `OffRouteDetector` when user steps > 4.0m off path corridor; recalculates A* path from user pose. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **M. Real Arrival Detection** | `ArrivalDetector` triggers arrival **only** when user is within 2.5m radius on the correct floor level. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |
| **N. VPS Boundary State** | VPS status reports `VPS: UNAVAILABLE — REAL PROVIDER CONFIGURATION REQUIRED` without fabricating fake coordinates. | **REAL + CODE VERIFIED** | **PHYSICAL TEST REQUIRED** |

---

## 3. Notes & Physical Validation Statement

> [!NOTE]
> All code components, ARCore session lifecycle management, coordinate transformations, NavMesh querying, A* routing, off-route recalculation, and arrival detection have been **100% verified via static analysis, TypeScript unit tests, and Gradle Android compilation**.
>
> Physical verification on an actual ARCore Android device is required to complete field validation.
