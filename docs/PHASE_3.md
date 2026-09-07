# PATHLUME Phase 3: QR Localization + Floor Coordinate Alignment + Continuous ARCore User Pose

## Overview

Phase 3 connects the registered floor coordinate system created in Phase 2 with a user's ARCore coordinate system using the Floor QR origin as the spatial alignment anchor.

## Accomplishments & Key Architectural Components

1. **QR Scanning & Validation Pipeline**:
   - `QRPayload` validation (`PATHLUME:<buildingId>:<floorId>:<originId>:<timestamp>`).
   - `QrScannerScreen` powered by `mobile_scanner` with structured error handling for malformed or mismatched QRs and developer manual fallback entry.

2. **3D Rigid Coordinate Alignment Engine**:
   - `CoordinateTransform`: Rigid 3D matrix math performing forward ($Floor \rightarrow ARWorld$) and inverse ($ARWorld \rightarrow Floor$) spatial conversions.
   - Mathematics:
     - Forward: $\text{ARWorldPoint} = T(\text{FloorPoint}) = R \cdot p_{\text{floor}} + t$
     - Inverse: $\text{FloorPoint} = T^{-1}(\text{ARWorldPoint}) = R^{-1} \cdot (p_{\text{AR}} - t)$

3. **Continuous User Pose Transformation**:
   - Updates `UserWorldPose` continuously from ARCore camera frames without re-scanning QR every frame.
   - Calculates real-time 3D **CURRENT USER FLOOR POSITION** in meters.

4. **Localization State Machine & Confidence Scoring**:
   - States: `IDLE` → `SCANNING_QR` → `QR_DETECTED` → `INITIALIZING_AR` → `ALIGNING` → `LOCALIZED` → `TRACKING` → `DEGRADED` / `LOST` / `ERROR`.
   - Confidence levels: `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN` evaluated by `DriftMonitor`.

5. **Relocalization Architecture**:
   - `requestRelocalization()` allowing the user to scan the floor QR again if tracking is lost or degraded.

6. **Developer Simulation Test Harness**:
   - `SimulatedQRLocalizationProvider` supporting simulation scenarios:
     - Scenario A: Perfect matching QR localization.
     - Scenario B: Tracking degradation.
     - Scenario C: Tracking loss and relocalization.
     - Scenario D: Invalid QR payload error.
     - Scenario E: Mismatched floor QR rejection.
