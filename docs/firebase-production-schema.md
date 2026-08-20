# PathLume Firebase Production Schema Specification

This document details the production Firestore collection layout and Firebase Storage path rules.

---

## 1. Firestore Collection Architecture

```
sites/{siteId}                                // Root Site Metadata
  ├── metadata                                // Site ID, name, description, publishedVersion
  ├── publishedManifest                       // Published Manifest (versionId, publishedAt)
  └── versions/{versionId}                    // Immutable Version Snapshot Subcollection
        ├── manifest                          // Version manifest
        ├── floors                            // Floor elevations & model references
        ├── calibration                       // SITE WORLD scale, rotation, offset
        ├── navigation                        // NavNodes & NavEdges
        ├── destinations                      // Location targets & search keywords
        ├── qr                                // Primary Site QR payload
        └── vps                               // VPS Configuration (UNAVAILABLE)
```

---

## 2. Firebase Storage Paths

- **Model Files**: `sites/{siteId}/models/v{versionId}/{filename}.glb`
- **Floor Plans**: `sites/{siteId}/floors/v{versionId}/{floorId}.png`
- **Site QR Images**: `sites/{siteId}/qr/primary_qr.png`

---

## 3. Firestore Security Rules Summary

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /sites/{siteId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.token.admin == true;
      match /versions/{versionId}/{document=**} {
        allow read: if true;
        allow write: if request.auth != null && request.auth.token.admin == true;
      }
    }
  }
}
```
