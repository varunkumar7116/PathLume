# PathLume VPS Backend Server Deployment Guide

This document details backend environment setup, API endpoint routing, and health verification for production VPS deployment.

---

## 1. Environment Variables (`.env`)

Copy `.env.example` to `.env` on your deployment server:

```ini
VPS_PROVIDER=Immersal
VPS_API_URL=https://api.immersal.com/v1/localize
VPS_API_KEY=your_immersal_developer_token_here
VPS_SECRET=your_server_side_secret_here
VPS_MAP_ID=vps_building_map_001
VPS_TIMEOUT_MS=2500
```

---

## 2. API Health Verification (`GET /api/vps/health`)

Query the server health endpoint:

```bash
curl http://localhost:8080/api/vps/health
```

Expected response when credentials are present:
```json
{
  "provider": "Immersal",
  "configured": true,
  "connected": true,
  "reachable": true,
  "mapId": "vps_building_map_001",
  "status": "CONNECTED",
  "message": "VPS provider active & connected"
}
```
