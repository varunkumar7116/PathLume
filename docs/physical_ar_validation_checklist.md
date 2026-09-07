# PATHLUME — Physical AR Validation Checklist & Protocol

## 1. Executive Summary

This document specifies the exact physical testing protocol and validation checklist for field testing PATHLUME on physical ARCore-supported Android devices.

> [!IMPORTANT]
> **Physical AR Validation Status**: `NOT TESTED (Requires Physical AR Device)`
> All automated software pipelines (Flutter UI, native Kotlin ARCore wrapper, OpenGL ES 3D rendering, A* pathfinding, coordinate transformations, 18-rule graph validator, JSON persistence) pass 100% cleanly in unit/E2E software tests. Physical validation must be performed when an ARCore phone becomes physically available.

---

## 2. Physical Test Environment Guidance

For physical field testing, ensure the testing area adheres to the following environmental standards:

- **Lighting**: Minimum 150–300 lux indirect ambient lighting. Avoid harsh directional glares, dark shadows, or pitch-black rooms.
- **Surface Texture**: Textured carpet, tiled flooring with distinct patterns, or wall posters. Avoid featureless mono-color white walls or polished mirror surfaces.
- **Scanning Distance**: Scan physical QR code tags at a distance of `0.5m – 1.8m` at eye level (`1.4m – 1.6m` height).
- **Movement Speed**: Walk at normal indoor pace (`~0.8 – 1.2 m/s`) with steady hand posture. Avoid rapid panning or shaking of the camera.

---

## 3. Physical AR Validation Checklist (Tests A through O)

| Test ID | Test Name | Description / Procedure | Expected Result | Actual Result | Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Test A** | Camera Feed Aspect Ratio | Launch AR session; observe camera preview feed. | Full-screen background quad renders without stretching or black bar distortion. | Pending physical device test | **NOT TESTED** | Hardware camera aspect ratio match |
| **Test B** | ARCore Tracking Init | Move phone slowly in 3D space upon session start. | ARCore state transitions from `INITIALIZING` to `TRACKING` within 2 seconds. | Pending physical device test | **NOT TESTED** | Feature point extraction |
| **Test C** | Node 0 Anchor Placement | Tap `START REGISTRATION` at origin. | Node 0 3D marker appears in world space at camera origin. | Pending physical device test | **NOT TESTED** | Identity rotation reference |
| **Test D** | Node Spacing & Node 1 | Walk 1.5 meters forward and tap `ADD NODE`. | Node 1 created with sequential edge connecting Node 0 → Node 1. | Pending physical device test | **NOT TESTED** | Euclidean spacing check (≥ 0.8m) |
| **Test E** | Multi-Node Walk | Walk 10 meters capturing 5 nodes, 1 turn, 1 door, 1 destination. | All 5 nodes render as world-locked 3D Cyan cubes connected by Green line strip. | Pending physical device test | **NOT TESTED** | Graph integrity & markers |
| **Test F** | Anchor World-Locking | Place 3D markers and step back 3 meters. Pan camera around room. | Markers remain strictly fixed in physical world space (no floating or screen attachment). | Pending physical device test | **NOT TESTED** | ARCore VIO spatial stability |
| **Test G** | Observed Anchor Drift | Keep phone tracking for 60 seconds near registered anchor. | Observed displacement diagnostic stays `< 0.05m`. | Pending physical device test | **NOT TESTED** | IMU/camera drift monitoring |
| **Test H** | QR 6DoF Localization | Scan floor origin QR code tag. | System detects QR payload AND 6DoF pose, transitioning to `LOCALIZED`. | Pending physical device test | **NOT TESTED** | Rejects payload-only without pose |
| **Test I** | Coordinate Alignment | Complete QR scan and verify transform $T = (t, R)$. | Floor coordinates map deterministically to AR world coordinates ($Scale = 1.0$). | Pending physical device test | **NOT TESTED** | Rigid transform precision |
| **Test J** | Native 3D AR Route Path | Start navigation session to a registered destination. | Vibrant Cyan 3D route line renders directly on physical floor surface. | Pending physical device test | **NOT TESTED** | Native OpenGL ES rendering pass |
| **Test K** | Waypoint Advancement | Walk along rendered 3D path toward destination. | HUD current waypoint index advances smoothly; 3D direction arrows rotate in world space. | Pending physical device test | **NOT TESTED** | Waypoint projection & guidance |
| **Test L** | Off-Route Recalculation | Intentionally step 3.5 meters sideways off the navigation path. | System detects off-route (> 3.0m offset) and re-calculates A* route from nearest node. | Pending physical device test | **NOT TESTED** | Dual-threshold hysteresis (> 3.0m / < 1.5m) |
| **Test M** | Tracking Loss Recovery | Cover camera lens for 3 seconds during active navigation. | Tracking moves to `PAUSED`; UI warns user; uncovering lens restores `TRACKING` smoothly. | Pending physical device test | **NOT TESTED** | Pause/Resume lifecycle safety |
| **Test N** | Mid-Route QR Relocalization | Tap `RELOCALIZE` and scan a secondary floor QR code tag. | Alignment transform $T$ updates cleanly; route geometry re-anchors without camera jump. | Pending physical device test | **NOT TESTED** | Multi-QR relocalization |
| **Test O** | Sustained Destination Arrival | Walk within 1.5m of target destination node for 1.5 seconds. | Arrival counter confirms proximity; Gold 3D destination beacon renders; HUD shows arrival banner. | Pending physical device test | **NOT TESTED** | Sustained arrival confirmation |

---

## 4. Software Readiness Certificate

The PATHLUME software pipeline has been completely audited and verified:

- [x] **ARCore Session Lifecycle**: Audited for single creation, auto-focus configuration, clean resume/pause/destroy.
- [x] **Pose Freshness Gating**: Strictly enforces `timestamp > 0`, `age ≤ 500ms`, and finite coordinates (`no NaN / Infinity`).
- [x] **OpenGL ES 3D World Geometry**: Camera background quad pass uses `GL_TEXTURE_EXTERNAL_OES` with depth test disabled, followed by 3D world geometry pass with `GL_DEPTH_TEST` enabled. MVP matrices use actual ARCore `Anchor.pose`.
- [x] **18-Rule Graph Validator**: Passed 100% on structural, finite, non-zero edge, BFS connectivity, and reachability tests.
- [x] **Persistence & Serialization**: Saved floor maps reload 100% identically with matching Node IDs, Destination IDs, and 3D positions.
- [x] **QR Spatial Pose Gating**: `WAITING_FOR_QR_POSE` state strictly enforced when 6DoF spatial pose is missing.
- [x] **Automated Tests**: 62 / 62 tests passing.
- [x] **Static Analysis**: `flutter analyze` returns 0 issues.
- [x] **Release Build**: `flutter build apk --release` compiles cleanly (`~64.7MB`).
