# PATHLUME Phase 1: Foundation & ARCore Proof of Concept

## Overview
Phase 1 establishes the complete foundation for PATHLUME and proves that Flutter can successfully communicate with native Android ARCore and display a spatially stable AR test scene on an ARCore-supported Android device.

## Key Objectives Achieved

1. **Flutter + Android Architecture**: Clean feature-based Flutter app communicating with native Kotlin ARCore wrapper.
2. **Platform Abstraction**: Unified `ARService` interface using Flutter `MethodChannel` and `EventChannel`.
3. **ARCore Lifecycle**: Full session initialization, camera permission handling, session resume/pause, and availability checking.
4. **6DoF Pose Tracking**: Real-time position (X, Y, Z) and rotation vector stream passed to Flutter UI.
5. **Spatial Anchor Placement**: Native tap-to-place 3D test marker attached to ARCore spatial anchor.
6. **No External Heavy Dependencies**: Zero dependencies on Unity, GLB, VPS, LiDAR, or 3D building models.

## Screen Flow

1. **HomeScreen**: Welcomes user and provides button to launch AR test.
2. **ArTestScreen**:
   - Camera permission check with fallback explanation UI.
   - Live ARCore camera view rendered natively.
   - Status badge showing tracking state (`INITIALIZING`, `TRACKING`, `PAUSED`, `ERROR`).
   - 6DoF Pose HUD displaying live coordinates and heading.
   - Floating Action Buttons: `PLACE TEST MARKER` and `RESET`.
