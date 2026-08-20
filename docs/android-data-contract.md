# PathLume Android & Web Hub Published Data Schema Contract

This document specifies the exact JSON data contract produced by the PathLume Web Hub and consumed by the Android Mobile Application via Cloud Firestore and Cloud Storage.

---

## 1. Published Firestore Document Hierarchy

```
sites/{siteId}
├── metadata (SiteMetadata)
├── publishedManifest (PublishManifest)
├── calibration (SiteCalibrationData)
├── floors (List<FloorData>)
├── navmesh (NavGraphData)
├── destinations (List<DestinationData>)
└── vpsConfig (VPSConfigData)
```

---

## 2. Component Schema Definitions

### A. Site Metadata (`SiteMetadata`)
```json
{
  "siteId": "controlled_test_site",
  "name": "Controlled Calibration Site",
  "organization": "PathLume Engineering",
  "description": "Standardized 10m x 10m physical field test site",
  "status": "PUBLISHED",
  "publishedVersion": "v1",
  "updatedAtMs": 1771520000000
}
```

### B. Floor Data (`FloorData`)
```json
{
  "floorId": "floor_1",
  "floorName": "Ground Floor",
  "floorNumber": 1,
  "elevationMeters": 0.0,
  "modelUrl": "https://storage.googleapis.com/pathlume-sites/models/controlled_test_site.glb"
}
```

### C. Site Calibration (`SiteCalibrationData`)
```json
{
  "calibrationVersion": "v1",
  "scale": 1.0,
  "rotationX": 0.0,
  "rotationY": 0.0,
  "rotationZ": 0.0,
  "translationX": 0.0,
  "translationY": 0.0,
  "translationZ": 0.0,
  "floorHeightMeters": 3.5,
  "units": "meters",
  "coordinateSystem": "SITE_WORLD"
}
```

### D. Navigation Graph (`NavGraphData`)
```json
{
  "nodes": [
    {
      "id": "n1",
      "type": "ENTRANCE",
      "floorId": "floor_1",
      "x": 0.0,
      "y": 0.0,
      "z": 0.0,
      "label": "Entrance Origin"
    },
    {
      "id": "n2",
      "type": "WALKABLE",
      "floorId": "floor_1",
      "x": 0.0,
      "y": 0.0,
      "z": -5.0,
      "label": "Point A"
    }
  ],
  "edges": [
    {
      "id": "e1",
      "from": "n1",
      "to": "n2",
      "distance": 5.0,
      "type": "WALK",
      "accessible": true,
      "wheelchairAccessible": true
    }
  ]
}
```

### E. Destination Data (`DestinationData`)
```json
{
  "id": "d1",
  "name": "Main Reception & Entrance Desk",
  "category": "Reception",
  "buildingId": "b1",
  "floorId": "floor_1",
  "nodeId": "n1",
  "x": 0.0,
  "y": 0.0,
  "z": 0.0,
  "accessible": true,
  "searchKeywords": ["reception", "desk", "entrance", "help"]
}
```

### F. VPS Configuration (`VPSConfigData`)
```json
{
  "status": "UNAVAILABLE",
  "provider": "NONE",
  "endpoint": "",
  "siteMapId": "",
  "confidenceThreshold": 0.85
}
```

### G. Publish Manifest (`PublishManifest`)
```json
{
  "siteId": "controlled_test_site",
  "versionId": "v1",
  "publishedAtMs": 1771520000000,
  "publishedBy": "Admin Tester",
  "manifestIntegrityHash": "a1b2c3d4e5f6"
}
```
