# PATHLUME Data Model Documentation

This document describes the spatial data hierarchy used by PATHLUME for indoor navigation without requiring 3D CAD/BIM building models.

## Entity Hierarchy

```text
Building
│
├── buildingId
├── name
├── address
└── floors[]
       │
       ├── floorId
       ├── floorNumber
       ├── name
       ├── origin (Physical QR placement anchor)
       ├── nodes[] (Waypoints, Turns, Doors, Destinations)
       ├── edges[] (Sequential 3D Euclidean distances)
       ├── destinations[] (Named target locations)
       └── qr
```

## JSON Schema Overview

### Building Model
```json
{
  "buildingId": "building_001",
  "name": "College Main Building",
  "address": "Main Engineering Block",
  "floors": []
}
```

### Floor Model
```json
{
  "floorId": "floor_001",
  "buildingId": "building_001",
  "floorNumber": 0,
  "name": "Ground Floor",
  "origin": {
    "originId": "origin_001",
    "floorId": "floor_001",
    "position": { "x": 0.0, "y": 0.0, "z": 0.0 },
    "rotation": { "x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0 },
    "qrCodePayload": "PATHLUME:building_001:floor_001:origin_001:1757000000000",
    "createdAt": "2026-09-04T19:00:00.000Z"
  },
  "nodes": [],
  "edges": [],
  "destinations": []
}
```

### Node Model
```json
{
  "nodeId": "node_floor_001_1",
  "id": "node_floor_001_1",
  "floorId": "floor_001",
  "type": "WAYPOINT",
  "position": { "x": 1.25, "y": 0.0, "z": -4.50 },
  "rotation": { "x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0 },
  "sequence": 1,
  "name": "Waypoint 1"
}
```

### Edge Model
```json
{
  "edgeId": "edge_node_floor_001_0_node_floor_001_1",
  "fromNodeId": "node_floor_001_0",
  "toNodeId": "node_floor_001_1",
  "distance": 4.72,
  "accessible": true
}
```

### Destination Model
```json
{
  "destinationId": "dest_floor_001_0",
  "nodeId": "node_floor_001_3",
  "name": "Computer Lab 1",
  "category": "Lab"
}
```

### QR Payload Format
```text
PATHLUME:<buildingId>:<floorId>:<originId>:<timestamp>
```
