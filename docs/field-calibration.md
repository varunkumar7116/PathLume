# Field Calibration & Physical Landmark Measurement Guide

This document defines the field calibration procedure for physically aligning 3D AR landmarks and GLB models with real building physical landmarks.

---

## 1. Field Calibration Setup Procedure

1. **Select Physical Test Site**: Load `controlled_test_site` (`data/sites/controlled_test_site.json`).
2. **Identify 3 Physical Landmarks**:
   - Landmark 1 (Entrance Origin): Entrance Doorframe Centre (`X=0.0m, Y=0.0m, Z=0.0m`).
   - Landmark 2 (Point A): Corridor Pillar 5m North (`X=0.0m, Y=0.0m, Z=-5.0m`).
   - Landmark 3 (Point B): Elevator Junction 10m North (`X=0.0m, Y=0.0m, Z=-10.0m`).
3. **Physical Distance Verification**:
   - Measure physical floor distances between Landmark 1, Landmark 2, and Landmark 3 using a physical measuring tape.
   - Confirm physical floor distance matches `5.00m` and `10.00m` within `±0.1m` tolerance.

---

## 2. Landmark Calibration Adjustment Rules

If AR marker does NOT visually align with the physical landmark:

> [!CAUTION]
> **DO NOT PATCH RANDOM OFFSETS IN CODE.**

Follow this systematic root-cause resolution tree:
1. **Scale Error**: If physical distance = 5.0m but AR distance = 4.0m, adjust `coordinateSystem.scale` in site JSON (`scale = 5.0 / 4.0 = 1.25`).
2. **Rotation Error**: If physical movement is North but AR marker drifts East, adjust `coordinateSystem.rotation.y` in site JSON (`rotation.y += deltaDegrees`).
3. **Translation Error**: If origin is offset by constant vector, adjust `coordinateSystem.translation` in site JSON (`translation = (Tx, Ty, Tz)`).
4. **Floor Height Error**: If AR marker floats above floor level, adjust `floorHeight` elevation parameter in site JSON.

---

## 3. Final Field Calibration Values Template

```json
{
  "siteId": "controlled_test_site",
  "coordinateSystem": {
    "translation": { "x": 0.0, "y": 0.0, "z": 0.0 },
    "rotation": { "x": 0.0, "y": 0.0, "z": 0.0 },
    "scale": 1.0
  }
}
```
