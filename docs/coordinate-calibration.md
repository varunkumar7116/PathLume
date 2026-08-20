# Coordinate Systems & Calibration Reference

This document defines the mathematical mapping, transforms, and unit conventions between all coordinate frames in PathLume indoor AR navigation.

---

## 1. Coordinate Frame Definitions

### A. ARCore Local Tracking World (`ARCore WORLD`)
- **Origin**: Position of device rear camera when Google ARCore session tracking initializes.
- **Axes**:
  - `+Y`: Up (aligned with local gravity vector)
  - `-Z`: Forward (pointing along camera line of sight at session start)
  - `+X`: Right (perpendicular to Y and Z)
- **Scale**: Metric (`1.0 unit = 1.0 meter`)
- **Handedness**: Right-Handed Cartesian System

### B. Canonical Site World (`SITE WORLD`)
- **Origin**: Building reference origin `(0.0, 0.0, 0.0)` defined in published site JSON (`Site.kt`).
- **Axes**:
  - `+Y`: Vertical elevation above ground floor level (meters)
  - `-Z`: North / Main building corridor depth (meters)
  - `+X`: East / Cross-corridor width (meters)
- **Scale**: `1.0` (Uniform 1:1 metric scale)
- **Handedness**: Right-Handed Cartesian System

### C. 3D GLB Model Mesh Frame (`GLB WORLD`)
- **Origin**: Origin specified in 3D modeling software (Blender/Photogrammetry software export origin).
- **Axes**: Standard GLTF Y-up convention (`+Y` Up, `+X` Right, `-Z` Forward).
- **Transformation Matrix to Site World**:
  ```
  P_site = (P_glb * Scale) + Translation
  Rotation_site = (Rotation_glb + Rotation_config) % 360
  ```

### D. Navigation Mesh Frame (`NavMesh / A*`)
- **Origin**: Identical to `SITE WORLD` origin `(0.0, 0.0, 0.0)`.
- **Polygon Centroids & Nodes**: Vertices and A* waypoints stored in metric `SITE WORLD` coordinates.

---

## 2. Coordinate Transformation Pipeline

```
          ARCore 6DoF Motion Delta
                     │
                     ▼
          [ ARCorePose (X, Y, Z) ]
                     │
                     ▼
       WorldCoordinateManager.transformVPSToSite
                     │
                     ▼
             [ FusedPose (Site) ]
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
    A* Router              Distance & Arrival
  (Nearest Poly)          (3D Euclidean Norm)
         │                       │
         ▼                       ▼
  Route Nodes (Site)       Physical Telemetry
```

---

## 3. Metric Verification Rule

1. **Units**: `1.0 unit` MUST strictly equal `1.0 meter`.
2. **Vertical Axis**: `+Y` MUST strictly align with the physical gravity vector (UP).
3. **Distance Norm**: Euclidean 3D norm:
   $$\text{distance} = \sqrt{(X_2 - X_1)^2 + (Y_2 - Y_1)^2 + (Z_2 - Z_1)^2}$$
