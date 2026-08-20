# PathLume Android Site Loading & Version Resolution Flow

This document specifies the exact runtime sequence executed by the Android app when scanning a QR code.

---

## 1. Android Runtime Loading Sequence

```
[ QR Code Scanner ]
       ↓ (Scans pathlume://site/{siteId})
[ Site ID Extracted ]
       ↓
[ Fetch Root Document: sites/{siteId} ]
       ↓
[ Read publishedVersion Pointer (e.g. "v1") ]
       ↓
[ Check Local Site Cache: siteId_v1 ]
   ├── IF CACHED & INTEGRITY VALID -> Load from Local Cache
   └── IF NEW VERSION -> Fetch sites/{siteId}/versions/v1 Manifest
       ↓
[ Fetch GLB Asset: sites/{siteId}/models/v1/model.glb via ModelCacheManager ]
       ↓
[ Load SITE WORLD Calibration Matrix ]
       ↓
[ Load Floor Elevations & NavMesh Graph ]
       ↓
[ Load Building Destinations ]
       ↓
[ Display "MODEL READY" & Initialize ARCore 6DoF Session ]
       ↓
[ Launch AR Navigation in SITE WORLD ]
```
