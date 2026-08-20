# PathLume Publish Workflow & Gate Specification

This document defines the 10-step atomic publish workflow enforced by the PathLume Web Hub Publish Gate.

---

## 1. 10-Step Atomic Publish Sequence

```
1. VALIDATE SITE (validateSiteConfiguration)
       ↓
2. FREEZE DRAFT
       ↓
3. GENERATE VERSION ID (v1, v2, v3)
       ↓
4. UPLOAD IMMUTABLE GLB MODEL (`sites/{siteId}/models/v{version}/model.glb`)
       ↓
5. WRITE VERSION DOCUMENT SNAPSHOT (`sites/{siteId}/versions/v{version}`)
       ↓
6. WRITE MANIFEST (`sites/{siteId}/versions/v{version}/manifest`)
       ↓
7. VERIFY REFERENCES & INTEGRITY HASH
       ↓
8. ATOMIC POINTER UPDATE (`sites/{siteId}.publishedVersion = v{version}`)
       ↓
9. PUBLIC MIRROR UPDATE (`publishedSites/{siteId}`)
       ↓
10. PUBLISHED & NOTIFY MOBILES
```

---

## 2. Publish Gate Rules

The Publish Gate **BLOCKS** publishing if any of the following conditions exist:
- Zero navigation nodes.
- No designated ENTRANCE node.
- Scale equal to zero.
- Destination referencing non-existent navigation node.
- Unreachable destinations.
- Missing site ID.
