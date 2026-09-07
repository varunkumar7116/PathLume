# PATHLUME Localization & Alignment Specification

This document details the QR spatial localization pipeline, tracking states, confidence scoring, and relocalization architecture.

## Localization Pipeline

```text
Floor QR Scan
    ↓
Payload Validation (buildingId, floorId, originId)
    ↓
Load Registered Floor Origin
    ↓
Initialize ARCore 6DoF Camera Tracking
    ↓
Compute Rigid 3D Coordinate Transform (T)
    ↓
Continuous ARCore Pose Stream → Inverse Transform T⁻¹ → Current User Floor Position
```

## Localization Confidence Matrix

| Confidence Level | Criteria / Signals | Action / State |
| :--- | :--- | :--- |
| **HIGH** | ARCore tracking active, QR localized $< 5$ min ago, distance $< 50$ m | Normal navigation tracking |
| **MEDIUM** | ARCore tracking active, duration $5-15$ min or distance $50-150$ m | Tracking active with mild drift alert |
| **LOW** | ARCore tracking active, duration $> 15$ min or distance $> 150$ m | Recommend relocalization |
| **UNKNOWN** | ARCore tracking stopped, paused, or error | `LOST` state; prompt floor QR rescan |

## Physical QR Placement Contract

1. **Location**: Place the floor QR code flat on a wall or floor directly at the physical location defined as `originId`.
2. **Visibility**: Keep unobstructed, clean, well-illuminated.
3. **Orientation**: Fixed physical orientation aligned with registration reference.
