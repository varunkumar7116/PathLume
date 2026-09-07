# PATHLUME — Walk-to-Map Registration & Navigation Pipeline Architecture

## 1. Overview

PATHLUME implements a complete **Walk-to-Map** indoor navigation workflow. Users register physical indoor floors by placing a QR reference origin and walking along floor paths to capture 3D spatial nodes, edges, turns, doors, and named destinations.

The pipeline guarantees that only structurally sound, fully validated, persistent navigation graphs can transition to `READY` status for indoor navigation.

---

## 2. Complete State Machine Lifecycle

Floor registration follows an explicit, strict state machine preventing invalid or incomplete graphs from being consumed by navigation:

```
[DRAFT / PREPARING]
       ↓
[TRACKING_INITIALIZING] (ARCore pose acquisition)
       ↓
[READY] (Origin placement prompt)
       ↓
[ORIGIN_SET] (Node 0 created + Floor QR anchor generated)
       ↓
[REGISTERING] (Walking & adding spatial nodes, edges, turns, doors, destinations)
       ↓
[PAUSED] (Interruption / pause)
       ↓
[COMPLETING] (User finishes walk)
       ↓
[VALIDATING] (GraphValidator evaluates 18 structural rules)
       ↙           ↘
 (Passes)          (Fails)
   ↓                  ↓
[READY]            [ERROR / DRAFT] (Saved without deletion; fixable)
```

---

## 3. Registration & Node Capture

1. **Origin Placement (Node 0)**:
   - Placed at AR camera position `(0.0, 0.0, 0.0)` with identity orientation.
   - Assigns sequence `0` and type `NodeType.start`.
   - Generates persistent `FloorOrigin` metadata and QR payload: `PATHLUME_V1|<buildingId>|<floorId>|<originId>`.

2. **Spacing & Freshness Rules**:
   - Minimum node spacing threshold: `0.8 meters` (configurable).
   - Pose freshness: timestamp age must be `<= 500 ms` with positive timestamp (`timestamp > 0`).
   - Prevents duplicate node creation on rapid single clicks.

3. **Edge Generation**:
   - Sequential edges `Edge(Node N-1 → Node N)` created with Euclidean 3D distance.
   - All edge endpoints verified against existing node IDs.
   - Bidirectional traversal supported for symmetric pathfinding.

4. **Semantic Markers**:
   - `MARK TURN`: Marks current node as turn junction without duplicate node creation.
   - `MARK DOOR`: Attaches door attribute to current node.
   - `MARK DESTINATION`: Attaches named destination label (e.g., "Lab 101") to node.

---

## 4. 18-Rule Graph Validation (`GraphValidator`)

Before a floor can transition to `READY FOR NAVIGATION`, `GraphValidator` checks all 18 rules:

1. **Minimum Node Count**: Graph contains at least 2 nodes.
2. **Unique Node IDs**: No duplicate or blank node IDs.
3. **Sequence Integrity**: Sequences strictly non-negative and valid.
4. **Finite Coordinates**: No `NaN` or `Infinity` in X, Y, Z positions.
5. **Node Type Validity**: Valid node enum types (`start`, `waypoint`, `turn`, `door`, `destination`, `elevator`, `stairs`).
6. **Valid Endpoint References**: Edges reference extant node IDs.
7. **No Self-Loops**: No edges where `fromNodeId == toNodeId`.
8. **Positive Non-Zero Distances**: Edge distances strictly `> 0.0m`.
9. **BFS Path Connectivity**: Graph connected from `START` node.
10. **Destination Reachability**: Every destination reachable via BFS from `START`.
11. **No Orphan Nodes**: No disconnected nodes with 0 connected edges.
12. **Start Origin Node**: Exactly one `START` origin node present.
13. **Unique Destination IDs**: No duplicate destination IDs.
14. **Coordinate Consistency**: Internal scale defaults to 1.0 (meters).

---

## 5. Persistence & Data Model Integrity

- Repositories: `LocalBuildingRepository` serializes buildings, floors, nodes, edges, destinations, and coordinate system metadata to JSON.
- Stability: Node IDs, Destination IDs, Edge IDs, and 3D floating-point coordinates remain 100% identical across saves and app restarts.

---

## 6. Navigation Integration & Simulation Mode

- **A* Pathfinder**: Calculates optimal route based on physical edge weights.
- **Route Projector**: Projects user position along active route segments.
- **Off-Route Detector**: Monitors drift (> 3.0m hysteresis) and triggers automatic recalculation.
- **Simulation Mode**: Uses the exact same `NavigationGraph`, `AStarPathfinder`, `RouteProjector`, and `NavigationService` classes as live AR navigation.
