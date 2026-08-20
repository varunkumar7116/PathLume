# PathLume Phase 6 Integration Audit

This audit documents the current state of Web Hub schemas, Firestore paths, Firebase Storage asset references, QR payload structures, and Android data contracts before finalizing end-to-end integration.

---

## 1. Web Hub & Firestore Data Schemas

### A. Published Firestore Collection Paths
- `sites/{siteId}`: Primary site document storing `siteId`, `name`, `type`, `description`, `publishedVersion`, `publishedAt`, `updatedAt`, `modelUrl`.
- `sites/{siteId}/versions/{versionId}`: Immutable version snapshot documents storing complete site manifest, navigation graph, destinations, and calibration.
- `publishedSites/{siteId}`: Public mirror accessible by mobile clients without administrative credentials.

### B. Firebase Storage Asset Paths
- `sites/{siteId}/models/v{version}/{filename}.glb`: Immutable 3D building models stored by site and published version.

---

## 2. Android & Web Hub Contract Compatibility

| Component | Web Hub Contract | Android Data Contract | Compatibility Status |
| :--- | :--- | :--- | :--- |
| **Site ID & Meta** | `siteId`, `name`, `type`, `description` | `Site.kt` (`siteId`, `name`, `type`, `description`) | **MATCHED** |
| **Coordinates** | Right-handed `(X, Y, Z)` meters | `Vector3D(x, y, z)` meters | **MATCHED** |
| **Floors** | `floorId`, `floorNumber`, `elevationMeters` | `Floor(id, floorNumber, name, modelUrl)` | **MATCHED** |
| **Nav Nodes** | `id`, `x`, `y`, `z`, `floorId`, `type` | `NavigationNodeData(id, x, y, z, floorId, type)` | **MATCHED** |
| **Nav Edges** | `id`, `from`, `to`, `distance`, `transitionType` | `NavigationEdgeData(from, to, distance, transitionType)` | **MATCHED** |
| **Destinations** | `id`, `name`, `category`, `floorId`, `nodeId` | `Destination(id, name, buildingId, floorId, position)` | **MATCHED** |
| **QR Payload** | `pathlume://site/{siteId}` | `QRPayload(siteId, anchorId, timestamp)` | **MATCHED** |
| **VPS Boundary** | `status: "UNAVAILABLE"` | `VPSConfiguration(provider: "NONE")` | **MATCHED** |

---

## 3. End-to-End Published Version Resolution Flow

```
[ Web Hub Admin ]
       ↓
  1. Validate Site (validateSiteConfiguration)
  2. Create Immutable Version Snapshot (v1, v2)
  3. Upload GLB to Firebase Storage (`sites/{siteId}/models/v1/model.glb`)
  4. Write Manifest & Version to Firestore (`sites/{siteId}/versions/v1`)
  5. Set `sites/{siteId}.publishedVersion = "v1"`
       ↓
[ Firebase Cloud Firestore ]
       ↓
  6. Android Scans Entrance QR (`pathlume://site/{siteId}`)
  7. Android Queries `sites/{siteId}.publishedVersion` -> Resolves "v1"
  8. Android Downloads Published Manifest (`v1`), NavGraph, Destinations, & GLB Asset
  9. Android Caches Published Version (`siteId_v1`)
 10. Android Launches ARCore 6DoF Navigation in SITE WORLD
```

---

## 4. Required Migration & Hardening Steps

1. **Atomic Version Resolution**: Android must resolve `publishedVersion` from `sites/{siteId}` and load that exact version snapshot from `sites/{siteId}/versions/{versionId}`.
2. **Local Version Caching**: Mobile app caches published site manifests by key `siteId_versionId` (`SiteCacheManager`).
3. **Telemetry Overlay**: Display `ARCore: TRACKING`, `VPS: UNAVAILABLE`, `Pose Fusion: ACTIVE`, `Site: siteId • versionId` on Android AR view.
