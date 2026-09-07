# PATHLUME Physical AR Testing & Drift Mitigation Guide

## 1. System Architecture & Coordinate Transformations

### Coordinate Space Pipeline
```
[Floor Space Coordinates]  (Origin (0,0,0) at Floor QR)
          ↓
[CoordinateTransform (T)]  Rigid Transform T(p) = R * p + t  (Scale = 1.0)
          ↓
[ARCore World Space]       3D World-Space Coordinates (Y-Up, Right-Handed)
          ↓
[Camera View & Projection]  Model-View-Projection Matrix Pipeline
          ↓
[OpenGL ES Renderer]       Native 3D Geometry (Path, Arrows, Destination Beacon)
```

### Coordinate System Conventions
- **Floor Space**: Right-handed 3D coordinate system. `(0, 0, 0)` is anchored at the center of the registered physical Floor QR Code tag. `+X` points right along floor plane, `+Y` points vertically up, `+Z` points forward along floor plane.
- **ARCore World Space**: Right-handed Y-Up 3D coordinate system established by ARCore when the session starts. `+X` points right, `+Y` points up, `+Z` points backwards.
- **Rigid Transform**: Strict rigid transformation matrix (translation vector \(\vec{t}\) + rotation quaternion \(q\)). Scale factor is strictly locked to `1.0` (no arbitrary scale hacks).

---

## 2. Physical QR Code Sizing & Placement Specifications

- **QR Tag Dimensions**: Printed square size: `0.20m x 0.20m` (20cm x 20cm) standard paper size.
- **QR Placement Height**: Mounted flat on wall at eye level (`1.4m – 1.6m` above floor) or flat on floor.
- **Lighting & Surface**: Minimum 150 lux indirect lighting. Avoid high specular reflections on glossy lamination.
- **Detection Distance**: Recommended scanning distance `0.5m – 1.8m` from camera.

---

## 3. Physical Test Procedures (Tests A through H)

### Test A: Static Anchoring Test
1. Place physical QR code tag at floor origin.
2. Scan QR tag to establish alignment and route calculation.
3. Keep physical phone completely stationary on a tripod for 60 seconds.
4. **Verification Criteria**: Verified that rendered 3D path lines and destination marker remain locked in 3D world space without jitter or visible floating drift.

### Test B: Straight Walking Test
1. Register a 5-meter straight corridor path with START and DESTINATION nodes.
2. Scan QR code and walk slowly along corridor at normal speed (~1.0 m/s).
3. **Verification Criteria**: Path geometry remains anchored to corridor floor; waypoint index advances smoothly; distance remaining decreases monotonically to 0.0m.

### Test C: Turn Guidance Test
1. Register a L-shaped path (5m straight \(\to\) 90° right turn \(\to\) 5m straight).
2. Walk route and observe HUD turn instruction updates.
3. **Verification Criteria**: Instruction updates from `GO STRAIGHT` to `TURN RIGHT` at 2.0m prior to turn; 3D direction arrows rotate in OpenGL world space aligned with segment vector.

### Test D: Long Walk & Drift Monitoring Test
1. Walk a 50-meter indoor route spanning multiple corridors.
2. Observe `DriftMonitor` confidence state transition from `HIGH` to `MEDIUM` to `LOW` as cumulative distance increases.
3. **Verification Criteria**: System detects distance threshold (\(>50\text{m}\)) and advises periodic QR relocalization without crashing.

### Test E: Tracking Interruption Test
1. Cover camera lens for 3 seconds during active navigation session.
2. **Verification Criteria**: ARCore tracking state changes from `TRACKING` to `PAUSED`/`STOPPED`; `NavigationService` enters `RELOCALIZING` state, freezing progress calculation; un-covering lens restores `TRACKING` and resumes navigation smoothly.

### Test F: QR Relocalization Test
1. Walk until tracking confidence degrades.
2. Press `RELOCALIZE` button and scan a second physical QR code tag.
3. **Verification Criteria**: Alignment transform \(T\) is re-computed cleanly; route geometry re-projects to new world transform without teleportation or resetting position to `(0,0,0)`.

### Test G: Off-Route Detection & Auto-Recalculation Test
1. Intentionally walk 4.0 meters sideways off designated navigation corridor.
2. **Verification Criteria**: `OffRouteDetector` dual-threshold hysteresis activates after 3 consecutive frames; `NavigationService` triggers A* recalculation from user's current nearest node; new path renders instantly.

### Test H: Destination Arrival Test
1. Walk within 1.5 meters of destination node and pause for 1.5 seconds.
2. **Verification Criteria**: Arrival counter confirms proximity; HUD presents `YOU HAVE ARRIVED!` banner; route rendering clears safely.

---

## 4. Physical Validation & Status Summary

| Test Case | Implementation Status | Automated Test Result | Emulator Verification | Physical Device Validation |
| :--- | :--- | :--- | :--- | :--- |
| **Test A: Static Test** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test B: Straight Walk** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test C: Turn Test** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test D: Long Walk** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test E: Tracking Loss** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test F: QR Relocalize** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test G: Off-Route** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |
| **Test H: Arrival** | IMPLEMENTED | PASSED | VERIFIED | **NOT TESTED (Requires Physical AR Device)** |

> [!IMPORTANT]
> **Physical Accuracy Disclaimer**: Visual Inertial Odometry (VIO) tracking accuracy depends on physical camera hardware, lighting, surface texture density, and device IMU sensor calibration. Final physical accuracy metrics (e.g. mean drift error in centimeters) must be measured on physical ARCore-supported Android hardware during field deployment testing.
