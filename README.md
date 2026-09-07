# 📍 PATHLUME — Advanced AR Tracking & Relocalization Indoor Navigation System

> **High-Precision Indoor Augmented Reality Navigation powered by Flutter, Native Android ARCore 6DoF VIO, ARCore Augmented Image Tracking, ARCore Depth API, PoseFusionEngine, DriftMonitor, OpenGL ES 3D Procedural Broad Ribbon Rendering, A* Graph Routing, and Cloud Firestore.**

---

## 🚀 Project Stage: Advanced AR Tracking & Relocalization Upgrade Complete (Release v2.0.0)

PATHLUME is a state-of-the-art indoor AR navigation system built for real physical environments. It has been upgraded from basic 6DoF tracking to a multi-layered spatial tracking architecture:

1. **ARCore 6DoF VIO + ARCore Augmented Image Tracking**: Integrates native `AugmentedImageDatabase` to visually lock floor origins to physical reference markers with physical dimensions.
2. **ARCore Depth API Integration**: Configures `Config.DepthMode.AUTOMATIC` where supported by device hardware for environmental confidence, with graceful fallback to `DISABLED` on unsupported devices.
3. **PoseFusionEngine**: Timestamp-validated pose fusion pipeline with velocity outlier rejection ($\le 3.5\text{ m/s}$ walking threshold with 5-frame hysteresis) and low-latency exponential position smoothing.
4. **DriftMonitor & Tracking Quality**: Real-time drift classification (`NORMAL`, `MINOR_DRIFT`, `SIGNIFICANT_DRIFT`, `RELOCALIZATION_REQUIRED`) and tracking state reporting (`GOOD`, `FAIR`, `POOR`, `RELOCALIZATION`, `LOST`).
5. **OpenGL ES Broad Ribbon Rendering**: Custom 20cm 3D Quad Ribbon geometry (`GL_TRIANGLE_STRIP`) and 3D Diamond Beacons overlaid on live OES camera frames.
6. **QR Data Identification vs. Spatial Localization**:
   - **QR Payload**: Identifies logical floor context (`PATHLUME_V1|buildingId|floorId|originId`).
   - **Augmented Image + ARCore Pose**: Establishes 3D physical world origin and rigid spatial transformation.
7. **Verification Status**:
   - `flutter analyze`: **0 Issues (Clean)**
   - `flutter test`: **69 / 69 Tests Passed (100%)**
   - Production Build: **Release APK compiled (`app-release.apk`)**

---

## 🏗️ Core Architecture & System Constraints

- **User Interface**: Flutter (Dart)
- **Native AR Engine**: Android / Kotlin (`ARCore`, `ARAugmentedImageManager`, `ARDepthManager`, `GLSurfaceView`, `OpenGL ES 2.0/3.0`)
- **Rendering Pipeline**: Procedural 3D OpenGL ES shader-based rendering (Broad 20cm Quad Ribbons & 3D Diamond Beacons; No Unity, No GLB assets, No external heavy engines)
- **Backend & Persistence**: Firebase / Cloud Firestore (`cloud_firestore`)
- **Localization Method**: QR Payload Identification + ARCore Augmented Image Visual Relocalization + ARCore 6DoF VIO (No VPS, No GPS, No fake/mocked poses)
- **Positioning Engine**: `PoseFusionEngine` + `DriftMonitor` + `CoordinateAlignmentEngine`
- **Pathfinding Algorithm**: Custom A* (A-Star) shortest path computation on `NavigationGraph`
- **Data Abstraction**: `BuildingRepository` interface with `FirebaseBuildingRepository` and `LocalBuildingRepository` implementations.

---

## 🔄 End-to-End System Workflows

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         1. FLOOR REGISTRATION WORKFLOW                      │
└─────────────────────────────────────────────────────────────────────────────┘
  REGISTER BUILDING ──► CREATE FLOOR ──► OPEN AR CAMERA ──► WAIT FOR AR TRACKING
                                                                   │
  SUCCESS ANIMATION ◄── FIRESTORE WRITE ◄── SAVE ROUTE ◄── ADD NODES & DESTINATIONS
          │
  GENERATE QR ──► PRINTABLE / DISPLAYABLE FLOOR QR CODE (PATHLUME_V1)

┌─────────────────────────────────────────────────────────────────────────────┐
│                       2. AR LOCALIZATION & NAVIGATION WORKFLOW               │
└─────────────────────────────────────────────────────────────────────────────┘
  NAVIGATE MODE ──► SCAN FLOOR QR ──► DECODE (buildingId | floorId | originId)
                                                       │
  SELECT DESTINATION ◄── DESERIALIZE GRAPH ◄── QUERY FIRESTORE DATABASE
          │
  WAIT FOR AUGMENTED IMAGE ──► ESTABLISH RIGID FLOOR ORIGIN ──► POSE FUSION ENGINE
                                                                      │
  COMPUTE A* ROUTE ──► DRIFT MONITOR ──► OPENGL ES 3D BROAD RIBBON NAVIGATION
```

### 1. Registration Workflow
1. **Camera & AR Initialization**: The native `GLSurfaceView` mounts, binding the OES camera texture and starting an authoritative `ARCoreManager` session.
2. **Origin Anchor (Node 0)**: The user places Node 0 at a designated physical location (e.g., floor entry or pillar with the QR reference marker).
3. **Multi-Node Mapping**: As the user walks, nodes are created at regular intervals. Specific nodes can be tagged as `TURN`, `DOOR`, or `DESTINATION` (with named labels).
4. **Graph Validation**: Prior to saving, `GraphValidator` checks:
   - Minimum required nodes and finite coordinates ($x, y, z \in \mathbb{R}$).
   - Absence of self-loops and presence of positive edge distances.
   - Graph connectivity and valid destination mapping.
5. **Firestore Persistence**: The validated `NavigationGraph` is serialized to `buildings/{buildingId}/floors/{floorId}`.
6. **QR Payload Generation**: Upon successful write, a high-contrast QR code encoding `PATHLUME_V1|<buildingId>|<floorId>|<originId>` is generated for printing/mounting at the origin.

### 2. Navigation Workflow
1. **QR Scanning & Decoding**: The user opens the Navigation camera and scans the floor's QR code.
2. **Database Lookup**: The app parses `PATHLUME_V1`, queries Cloud Firestore for the exact `floorId`, and reconstructs the precise 3D `NavigationGraph`.
3. **Augmented Image Visual Relocalization**: ARCore detects the physical QR image as an `AugmentedImage`, retrieving its center pose to establish a rigid transform between world and floor space.
4. **Destination Selection & Routing**: The user selects a target destination. The A* algorithm computes the shortest path along physical waypoints.
5. **Pose Fusion & Drift Monitoring**: Incoming poses are processed by `PoseFusionEngine` (rejecting velocity outliers $> 3.5\text{ m/s}$) and monitored by `DriftMonitor`.
6. **3D OpenGL Broad Ribbon AR Rendering**: `ARRenderer` draws procedural 20cm broad quad ribbon path lines and 3D diamond beacons directly overlaid onto physical space.

---

## 🛠️ AR Tracking Stability & Thread-Safety Engine

| Architectural Component | Solution Implemented | Technical Benefit |
| :--- | :--- | :--- |
| **`ARAugmentedImageManager.kt`** | Native `AugmentedImageDatabase` tracking | Detects reference marker poses to establish spatial floor origin and trigger visual relocalization. |
| **`ARDepthManager.kt`** | Hardware `Config.DepthMode.AUTOMATIC` | Enables depth map queries on supported hardware with zero-crash `DISABLED` fallback. |
| **`PoseFusionEngine.dart`** | Timestamp validation + Outlier Rejection ($\le 3.5\text{m/s}$) | Prevents tracking glitches, false pose teleports, and accumulated sensor drift. |
| **`DriftMonitor.dart`** | Spatial drift classification engine | Categorizes spatial confidence (`NORMAL`, `MINOR_DRIFT`, `SIGNIFICANT_DRIFT`, `RELOCALIZATION_REQUIRED`). |
| **`ARAnchorManager.kt`** | `CopyOnWriteArrayList<Anchor>` & `ConcurrentHashMap` | Eliminates `ConcurrentModificationException` when mutating anchors on UI thread while rendering on GL thread. |
| **`FloorRegistrationScreen.dart`** | `key: const ValueKey('pathlume_registration_ar_view')` | Prevents `PlatformViewLink` unmounting and EGL context destruction during Flutter `setState()` rebuilds. |
| **`ARRenderer.kt`** | Custom Broad Quad Ribbon Shader (`GL_TRIANGLE_STRIP`) | Bypasses Android 1-pixel GPU line width limits to render visible 20cm broad 3D navigation paths. |
| **Diagnostics HUD** | Real-time `PATHLUME_AR` diagnostic overlay | Displays real-time session state, tracking quality, pose age, pose source, depth status, drift level, and FPS. |

---

## ⚠️ Important Tracking Accuracy Notice

Indoor AR tracking accuracy depends on physical environmental factors:
- **Visual Features**: Textured surfaces (carpets, wall artwork) provide superior VIO feature points compared to featureless white walls or glass.
- **Lighting Conditions**: Even, diffuse indoor lighting delivers optimal visual odometry performance.
- **Physical Reference Image**: The printed QR code/reference image should be high contrast, unbent, and mounted on a flat surface.
- **Device Hardware**: Devices with dedicated Depth API sensors provide enhanced environmental stability.

*Note: Spatial relocalization recovers from accumulated drift when the camera sees a registered reference image.*

---

## 📁 Repository Structure

```text
indoor navigation app/
├── android/
│   └── app/
│       ├── google-services.json           # Active Firebase configuration
│       └── src/main/kotlin/com/pathlume/app/ar/
│           ├── ARAnchorManager.kt         # Thread-safe 3D spatial anchor manager
│           ├── ARAugmentedImageManager.kt # ARCore Augmented Image tracking manager
│           ├── ARDepthManager.kt          # ARCore Depth API lifecycle controller
│           ├── ARCoreManager.kt           # Authoritative ARCore session controller
│           ├── ARRenderer.kt              # OpenGL ES 2.0/3.0 procedural broad ribbon 3D renderer
│           ├── NativeARView.kt            # PlatformView GLSurfaceView wrapper
│           └── ARMethodChannel.kt         # Flutter <-> Kotlin bridge & EventChannel telemetry
├── lib/
│   ├── firebase_options.dart              # Default Firebase platform options
│   ├── main.dart                          # Application entry & Firebase initialization
│   ├── models/
│   │   ├── navigation_graph.dart          # Graph, Node, Edge, and Destination contracts
│   │   ├── tracking_quality.dart          # TrackingQuality & TrackingQualityState models
│   │   ├── floor_origin.dart              # Rigid spatial transform & reference metadata
│   │   └── qr_payload.dart                # PATHLUME_V1 payload parser
│   ├── features/
│   │   ├── registration/                  # Floor registration & node placement UI
│   │   ├── navigation/                    # Destination selection & AR navigation UI
│   │   └── qr/                            # Printable QR code generation UI
│   └── services/
│       ├── graph_validator.dart           # Pre-save graph validation engine
│       ├── pathfinding/                   # A* (A-Star) routing implementation
│       ├── localization/                  # PoseFusionEngine, DriftMonitor, LocalizationService
│       └── repositories/
│           ├── building_repository.dart   # Abstract repository interface
│           └── firebase_building_repository.dart # Cloud Firestore implementation
├── test/                                  # 69 Unit & Widget tests
└── pubspec.yaml                           # Flutter package manifest
```

---

## ⚡ Developer Commands & Testing

### 1. Run Static Analysis
```bash
E:\flutter\bin\flutter.bat analyze
```

### 2. Run Automated Unit & Widget Tests
```bash
E:\flutter\bin\flutter.bat test
```

### 3. Build Production Release APK
```bash
E:\flutter\bin\flutter.bat build apk --release
```
*Output binary location: `build/app/outputs/flutter-apk/app-release.apk`*

### 4. Install Release APK onto Physical ARCore Device
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 📜 License & Project Credits
Developed as part of the **PATHLUME** Indoor AR Navigation Project. Built with Flutter, ARCore, Cloud Firestore, and OpenGL ES.
