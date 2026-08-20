# PathLume Navigation Data Contract

This document defines the shared navigation graph data model produced by Web Hub and consumed by Android A* pathfinding.

---

## 1. NavNode Data Structure

```json
{
  "id": "n1",
  "type": "ENTRANCE",
  "floorId": "floor_1",
  "buildingId": "b1",
  "x": 0.0,
  "y": 0.0,
  "z": 0.0,
  "label": "Entrance Origin"
}
```

### Node Types
- `ENTRANCE`: Site entrance or origin node.
- `WALKABLE`: Standard corridor node.
- `DESTINATION`: Target location node.
- `STAIR`: Staircase connector node.
- `ELEVATOR`: Elevator shaft connector node.
- `ESCALATOR`: Escalator connector node.
- `CORRIDOR`: Main hallway node.
- `INTERSECTION`: Corridor junction node.
- `WAYPOINT`: Secondary navigation point.

---

## 2. NavEdge Data Structure

```json
{
  "id": "e1",
  "from": "n1",
  "to": "n2",
  "distance": 5.0,
  "walkable": true,
  "transitionType": "walk",
  "accessible": true,
  "wheelchairAccessible": true,
  "stairsRequired": false
}
```

### Transition Types
- `walk`: Standard horizontal corridor walking path.
- `stairs`: Vertical stair transition between floors.
- `elevator`: Vertical elevator shaft transition between floors.
- `ramp`: Wheelchair accessible ramp transition.
- `escalator`: Escalator transition.
