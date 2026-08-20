# PathLume VPS Provider API & Payload Contract

This document specifies the exact network contract for `POST /vps/localize`.

---

## 1. Request Payload (`POST /vps/localize`)

```json
{
  "siteId": "controlled_test_site",
  "versionId": "v1",
  "mapId": "vps_controlled_mesh",
  "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
  "cameraMetadata": {
    "resolutionWidth": 1920,
    "resolutionHeight": 1080,
    "focalLengthPx": 1420.5,
    "orientation": 90
  },
  "timestampMs": 1771520000000
}
```

---

## 2. Response Payload

```json
{
  "provider": "Immersal VPS Engine",
  "success": true,
  "vpsState": "VPS_LOCALIZED",
  "position": {
    "x": 0.12,
    "y": 0.00,
    "z": -0.08
  },
  "orientation": {
    "pitch": 0.0,
    "roll": 0.0,
    "yaw": 0.0
  },
  "confidence": 0.88,
  "floor": 1,
  "latencyMs": 320,
  "errorCode": null,
  "errorMessage": null
}
```
