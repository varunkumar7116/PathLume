# PathLume Web Hub to Android End-to-End Integration Contract

This document summarizes the end-to-end integration contract ensuring that data published by the Web Hub is consumed losslessly by the Android application.

---

## 1. End-to-End Summary Matrix

| Data Asset | Web Hub Source | Firestore Storage Path | Android Target Model |
| :--- | :--- | :--- | :--- |
| **Site Metadata** | `SiteMetadata` | `sites/{siteId}` | `Site.kt` (`siteId, name, type, description`) |
| **Published Manifest** | `PublishManifest` | `sites/{siteId}/publishedManifest` | `PublishManifest` |
| **3D GLB Model** | File Upload | `sites/{siteId}/models/v{ver}/model.glb` | `ModelCacheManager` |
| **Site Calibration** | `calibration` | `sites/{siteId}/calibration` | `CoordinateSystemConfig` |
| **Floors** | `floors` | `sites/{siteId}/floors` | `Floor(id, floorNumber, name, modelUrl)` |
| **NavMesh Graph** | `nodes & edges` | `sites/{siteId}/nodes & edges` | `NavNode2D & NavigationEdge` |
| **Destinations** | `destinations` | `sites/{siteId}/destinations` | `Destination(id, name, buildingId, floorId, position)` |
| **Primary Site QR** | Canvas PNG | Payload `pathlume://site/{siteId}` | `QRScannerScreen` / `QRPayload` |
| **VPS Configuration** | `vpsConfig` | `sites/{siteId}/vps` | `VPSConfiguration(provider: "NONE")` |
