# PathLume Canonical Coordinate System Contract (SITE WORLD)

This document serves as the single authoritative specification for spatial coordinate representation across the PathLume Web Hub, Android Mobile Application, ARCore Session, GLB 3D Assets, and VPS Spatial Localization.

---

## 1. SITE WORLD Coordinate Frame Definition

SITE WORLD is a Right-Handed Cartesian Metric Coordinate System defined as follows:

| Axis | Spatial Orientation | Unit Scale | Meaning |
| :--- | :--- | :--- | :--- |
| **+X** | East / Right | `1 unit = 1 meter` | Lateral displacement relative to site origin |
| **+Y** | Up / Vertical Elevation | `1 unit = 1 meter` | Vertical height above ground reference level |
| **-Z** | North / Forward | `1 unit = 1 meter` | Longitudinal displacement forward from site origin |
| **+Z** | South / Backward | `1 unit = 1 meter` | Longitudinal displacement backward from site origin |

---

## 2. Coordinate Transformation Pipeline

All external spatial frames are converted into SITE WORLD coordinates before processing by navigation engines or rendering.

```
       [ GLB Model Mesh ]  ─── Matrix GLB_to_SITE ───┐
                                                     │
     [ ARCore 6DoF Pose ]  ─── Matrix ARCore_to_SITE ──┼──>  [ SITE WORLD CANONICAL FRAME ]
                                                     │      (1 unit = 1 meter, +Y Up, -Z North)
  [ VPS Absolute Position ] ─── Matrix VPS_to_SITE ───┘
```

### A. GLB Model Transformation (`GLB -> SITE WORLD`)
$$\mathbf{P}_{\text{SITE}} = \mathbf{S} \cdot \mathbf{R}_y(\theta) \cdot \mathbf{P}_{\text{GLB}} + \mathbf{T}$$
Where:
- $\mathbf{S}$: Uniform scale factor (default: `1.0`)
- $\mathbf{R}_y(\theta)$: Rotation around vertical Y-axis (Yaw)
- $\mathbf{T}$: Translation vector $(T_x, T_y, T_z)$ in meters

### B. ARCore Pose Transformation (`ARCore -> SITE WORLD`)
$$\mathbf{P}_{\text{SITE}} = \mathbf{R}_{\text{calibration}} \cdot \mathbf{P}_{\text{ARCore}} + \mathbf{P}_{\text{Origin}}$$
Where:
- $\mathbf{P}_{\text{ARCore}}$: Continuous 6DoF relative pose provided by ARCore Session.
- $\mathbf{P}_{\text{Origin}}$: Physical landmark anchor or VPS initial origin offset.

### C. VPS Transformation (`VPS -> SITE WORLD`)
$$\mathbf{P}_{\text{SITE}} = \mathbf{M}_{\text{VPS\_Transform}} \cdot \mathbf{P}_{\text{VPS}}$$
*Note: VPS remains `UNAVAILABLE` until a real provider (e.g. Immersal/Google Geospatial) is connected.*

---

## 3. Web Hub & Android Application Contract Compliance

1. **Unit Metric Guarantee**: `1 unit` strictly represents `1.0 meter` in physical real-world space.
2. **NavMesh Node Representation**: All `NavNode2D` and 3D navigation waypoints must store $(X, Y, Z)$ strictly in SITE WORLD coordinates.
3. **Floor Elevations**: Floor level $0$ corresponds to $Y = 0.0\text{m}$. Floor $N$ has elevation $Y_N = N \cdot H_{\text{floor}}$ (e.g. Floor 1 at $3.5\text{m}$).
