# PathLume Immutable Versioning & Rollback Specification

This document details immutable site versioning, manifest integrity, and version rollback operations.

---

## 1. Immutability Guarantee
Once version `v1` is published:
- `v1` metadata, model asset, calibration, floor layout, navigation graph, and destinations become **IMMUTABLE**.
- Subsequent edits in the Web Hub modify the active working draft and produce version `v2` upon publish.

---

## 2. Version Rollback Operation
If an administrator rolls back from `v2` to `v1`:
- `v2` documents and assets are **NOT deleted**.
- The root document pointer `sites/{siteId}.publishedVersion` is updated to `"v1"`.
- Mobile clients querying `sites/{siteId}` automatically resolve `"v1"` for all subsequent downloads.
