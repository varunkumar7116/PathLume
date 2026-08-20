# PathLume Phase 7 Real-World VPS Integration Specification

This document details the architecture and implementation of the production VPS localization abstraction layer in PathLume.

---

## 1. Production Architecture Overview

PathLume separates high-frequency local motion tracking from low-frequency absolute visual localization.

```
       [ Rear Camera Frame ] ──> [ VpsProvider Abstraction ]
                                           │
                                  (POST /vps/localize)
                                           │
                                           ▼
   [ ARCore 6DoF Local Motion ] ──> [ PoseFusionEngine ] <── [ Absolute VPS Correction ]
                                           │
                                           ▼
                                 [ FusedPose in SITE WORLD ]
                                 (1 unit = 1m, +Y Up, -Z North)
```

---

## 2. VpsProvider Abstraction Hierarchy

```kotlin
interface VpsProvider {
    val providerName: String
    suspend fun localizeFrame(imageBase64: String, config: VpsProviderConfig): VpsLocalizationResult
}
```

### Implementations:
- `ImmersalVpsProvider`: Connects to visual feature map servers (Immersal VPS Engine).
- `GoogleGeospatialVpsProvider`: Connects to ARCore Geospatial VPS API.
- `UnavailableVpsProvider`: Honest unconfigured fallback reporting `VPS BLOCKED — REAL PROVIDER CONFIGURATION REQUIRED`.

---

## 3. VPS Quality Control Rules

Before applying absolute VPS position correction to `PoseFusionEngine`:
1. **Confidence Gate**: `confidence >= 0.80f` (Rejects low feature match counts).
2. **Freshness Gate**: Timestamp age `< 2500ms`.
3. **Map Verification**: `vpsMapId == activeSite.mapId`.
4. **Physically Plausible Jump Check**: Rejects instantaneous jumps `> 10.0 meters`.
