# PathLume Phase 8 Real VPS Provider Activation & Physical Validation Audit

This document summarizes the provider selection, security model, environment configuration, backend health checks, and physical acceptance testing matrix for Phase 8.

---

## 1. Provider Selection Analysis (Phase 8A)

| Provider | Auth Method | API Endpoint | Map Requirements | Latency Target | Implementation Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Immersal VPS** | API Token / Server Secret | `POST /v1/localize` | Visual mesh scan (`.bytes` map ID) | `< 1200ms` | **IMPLEMENTATION STUB / EXTERNAL CONFIG REQUIRED** |
| **Google Geospatial** | OAuth2 / GCP API Key | `POST /v1/geospatial` | ARCore VPS coverage / Street View mesh | `< 1500ms` | **STUB / GCP TOKEN REQUIRED** |
| **Unavailable Fallback** | None | Local REST `/api/vps` | None | `0ms` | **ACTIVE UNCONFIGURED FALLBACK** |

---

## 2. Server-Side Security Model (Phase 8B & 8O)

- **Secrets Isolation**: Private API keys (`VPS_API_KEY`, `VPS_SECRET`) stay strictly on the PathLume backend server (`.env`).
- **Client Identifiers**: Android mobile apps receive only public identifiers (`siteId`, `mapId`, `versionId`).
- **No Hardcoded Keys**: Audited codebase to ensure zero secrets exist in APK, JS bundles, or repository files.

---

## 3. Physical Acceptance Testing Matrix (Phase 8K)

| Test | Objective | Pass Criteria | Status |
| :--- | :--- | :--- | :--- |
| **1. Stationary** | Verify no fake motion drift | Distance remains stable for 30s | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
| **2. Forward Walk** | Verify ARCore motion updates | Distance decreases by ~5m | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
| **3. Backward Walk** | Verify orientation & direction | Distance increases by ~5m | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
| **4. Off-Route** | Verify A* recalculation | Reroutes when off corridor > 4m | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
| **5. Arrival** | Verify physical proximity | Triggers only upon physical arrival | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
| **6. VPS Loss** | Verify offline fallback | Transitions to `VPS LOST` without crash | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
| **7. VPS Recovery** | Smooth pose correction | Relocalizes without visual teleporting | **CODE VERIFIED / PHYSICAL TEST REQUIRED** |
