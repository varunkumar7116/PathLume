# PATHLUME 3D Coordinate Systems & Alignment Mathematics

This document specifies the exact coordinate frame conventions and transformation mathematics used in PATHLUME.

## Coordinate Frames

### 1. FLOOR SPACE
- Right-handed 3D Cartesian system established during floor registration.
- **Scale**: $1 \text{ unit} = 1.0 \text{ meter}$.
- **Origin $(0,0,0)$**: Physical location of the registered Floor Origin QR code.
- **Axes**:
  - $+X$: Horizontal right along corridor/room
  - $+Y$: Upright vertical height
  - $+Z$: Forward depth along registration path

### 2. ARCORE WORLD SPACE
- Right-handed 3D coordinate system initialized by Android ARCore when camera tracking begins.
- **Origin $(0,0,0)$**: Camera position at the exact moment ARCore session initializes.
- **Axes**:
  - $+X$: Right relative to camera at startup
  - $+Y$: Up aligned with gravity vector
  - $+Z$: Forward relative to camera at startup

## Spatial Alignment Mathematics

The rigid 3D transformation $T = (t, R)$ consists of a 3D translation vector $t \in \mathbb{R}^3$ and a rotation quaternion $R \in \mathbb{H}$.

### Forward Transformation ($Floor \rightarrow ARWorld$)
$$\mathbf{p}_{\text{AR}} = T(\mathbf{p}_{\text{floor}}) = R \cdot \mathbf{p}_{\text{floor}} + t$$

```dart
Vector3D transformFloorToAR(Vector3D floorPoint)
```

### Inverse Transformation ($ARWorld \rightarrow Floor$)
$$\mathbf{p}_{\text{floor}} = T^{-1}(\mathbf{p}_{\text{AR}}) = R^{-1} \cdot (\mathbf{p}_{\text{AR}} - t)$$

```dart
Vector3D transformARToFloor(Vector3D arPoint)
```

Both functions are fully implemented in [coordinate_transform.dart](file:///e:/indoor%20navigation%20app/lib/models/coordinate_transform.dart).
