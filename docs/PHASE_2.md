# PATHLUME Phase 2: Building + Floor + Walk-to-Map Registration

## Overview

Phase 2 implements the complete building, floor, and walk-to-map registration system for PATHLUME. It enables physical route registration, spatial node capture, edge distance calculation, graph validation, local file-system persistence, QR payload generation, and developer simulation mode.

## Key Features & Accomplishments

1. **Building & Floor Management**:
   - Multi-building dashboard with support for creating buildings and floors.
   - Flexible floor numbering (Ground Floor `0`, First Floor `1`, Basement `-1`).
   - Decoupled `BuildingRepository` abstraction with local JSON persistence (`local_data/buildings/`).

2. **Floor Registration Engine & State Machine**:
   - State transitions: `IDLE` → `PREPARING` → `ORIGIN_SET` → `REGISTERING` → `PAUSED` → `PROCESSING` → `COMPLETED`.
   - Registration origin establishment at physical starting point.
   - Manual node capture for `START`, `WAYPOINT`, `TURN`, `DOOR`, `DESTINATION`.
   - Configurable minimum node spacing (`0.8m`) to reject accidental duplicate taps with user warning banners.
   - Sequential edge generation with 3D Euclidean spatial distance calculation: $\sqrt{\Delta x^2 + \Delta y^2 + \Delta z^2}$.

3. **Graph Processing & Validation**:
   - `GraphProcessor` enforces structural graph integrity: minimum 1 `START` node, valid paths, non-zero distances, valid node IDs, and linked destination nodes.
   - Registration summary screen for reviewing node counts, edge counts, distance, and destination metadata before saving.

4. **Floor QR Payload System**:
   - Standardized QR payload string: `PATHLUME:<buildingId>:<floorId>:<originId>:<timestamp>`.
   - `FloorQrScreen` rendering floor QR code image with metadata display and save/share options.

5. **Developer AR Simulation Mode**:
   - `SimulatedARService` providing 3D pose step simulation (`(0,0,0) → (0,0,1) → (0,0,2) → (1,0,2) → (2,0,2)`).
   - Allows complete walk-to-map registration testing without physical ARCore hardware.

6. **Safety Warning Banner**:
   - Real-time walking safety reminder: *"Stay aware of your surroundings while walking. Do not use the device while crossing hazardous areas or stairs."*
