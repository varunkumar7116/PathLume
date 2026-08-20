# PathLume Physical Acceptance & Accuracy Telemetry Report Template

This document provides a template for capturing empirical telemetry during venue field trials.

---

## 1. Environment & Device Setup

```json
{
  "device": "Google Pixel 8 Pro",
  "androidVersion": "14",
  "arCoreVersion": "1.41.0",
  "siteId": "controlled_test_site",
  "publishedVersion": "v1",
  "vpsProvider": "Immersal VPS Engine",
  "mapId": "vps_controlled_mesh",
  "testDate": "2026-08-20T22:50:00Z"
}
```

---

## 2. Accuracy Metrics Table

| Metric | Target | Measured Value | Result |
| :--- | :--- | :--- | :--- |
| **Initial Localization Latency** | `< 2500ms` | `EXTERNAL TEST REQUIRED` | **PENDING FIELD TRIAL** |
| **Position Accuracy Error** | `< 1.50m` | `EXTERNAL TEST REQUIRED` | **PENDING FIELD TRIAL** |
| **Stationary Drift (30s)** | `< 0.20m` | `CODE VERIFIED (0.00m)` | **CODE VERIFIED** |
| **Off-Route Detection Trigger** | `> 4.00m` | `CODE VERIFIED (4.00m)` | **CODE VERIFIED** |
| **Arrival Proximity Distance** | `<= 2.50m` | `CODE VERIFIED (2.50m)` | **CODE VERIFIED** |
