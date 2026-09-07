# PATHLUME Architecture Overview

PATHLUME is a Walk-to-Map Indoor AR Navigation System designed specifically for Android.

## System Architecture

```text
PATHLUME
│
├── Flutter Application (UI & Application Logic)
│   ├── Presentation Layer (HomeScreen, BuildingDetailScreen, FloorRegistrationScreen, FloorQrScreen)
│   ├── State Management (RegistrationEngine State Machine)
│   ├── Data Models (Building, Floor, NavigationNode, NavigationEdge, NavigationGraph, Destination, QRPayload)
│   ├── Repositories (BuildingRepository, LocalBuildingRepository)
│   └── Services (ARService, AndroidARService, SimulatedARService)
│
├── Platform Channel Bridge
│   ├── MethodChannel ("com.pathlume.app/ar_channel")
│   └── EventChannel ("com.pathlume.app/ar_events")
│
└── Android Native Layer (Kotlin + ARCore)
    ├── ARCoreManager & ARSessionManager
    ├── ARPoseManager (6DoF Tracking)
    ├── ARAnchorManager (Spatial Anchor Management)
    ├── ARRenderer (Native OpenGL ES AR Rendering)
    └── ARMethodChannel (Platform Channel Handler)
```

## Platform Channel & Service Abstraction

Flutter logic communicates through the `ARService` interface (`services/ar_service.dart`).
- `AndroidARService`: Routes commands to native Kotlin code via platform channels.
- `SimulatedARService`: Provides developer test mode simulation of 3D poses without physical AR hardware.
- `BuildingRepository`: Abstract interface backed by `LocalBuildingRepository` for file-system JSON persistence.

```text
Flutter UI → BuildingRepository → Local Storage (JSON)
Flutter UI → RegistrationEngine → ARService (AndroidARService / SimulatedARService) → ARCore / Simulator
```

This decoupled architecture ensures application data can seamlessly migrate to Firebase or cloud synchronization in future phases without breaking UI or registration logic.
