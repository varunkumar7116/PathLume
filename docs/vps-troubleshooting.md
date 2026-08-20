# PathLume VPS Diagnostic & Troubleshooting Guide

This guide provides step-by-step diagnostic resolution for VPS status codes.

---

## 1. VPS Status Diagnostic Table

| Status Code | Cause | Resolution |
| :--- | :--- | :--- |
| `VPS_SEARCHING` | Camera searching for feature points | Pan camera slowly across textured venue surfaces. |
| `VPS_LOW_CONFIDENCE` | Feature match count below threshold (`< 0.80`) | Improve lighting or move closer to mapped structures. |
| `VPS_LOST` | Camera occluded or feature tracking lost | Re-align camera with entrance landmark or main corridor. |
| `VPS_DISABLED` | VPS provider unconfigured or disabled | Check site config in Web Hub VPS panel. |
| `VPS_ERROR` | Server communication error or 503 response | Verify server API endpoint and internet connectivity. |
