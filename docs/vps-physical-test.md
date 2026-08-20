# PathLume VPS Physical Field Testing Guide

This document specifies the 18-step physical acceptance procedure for validating real VPS localization.

---

## 1. 18-Step Physical Test Sequence

1. Stand at the designated entrance origin landmark (`0,0,0`).
2. Open PathLume and scan the site QR code (`pathlume://site/controlled_test_site`).
3. Observe site loading state: `MODEL READY` -> `INITIALIZING ARCORE`.
4. Observe VPS initial state: `VPS: SEARCHING…`.
5. Point phone camera toward recognizable visual features of the venue.
6. Verify VPS transitions to `VPS: LOCALIZED ✓` (Confidence `>= 0.80`).
7. Record initial VPS position and fused pose.
8. Press **START AR NAVIGATION** toward Point A (`0,0,-5m`).
9. Walk physically forward 5.0 meters.
10. Verify ARCore pose updates continuously and smooth fused position reaches `(0.0m, 0.0m, -5.0m)`.
11. Observe remaining distance decreases from `5.0m` to `0.0m`.
12. Turn around and walk backward 5.0 meters.
13. Observe remaining distance increases back to `5.0m`.
14. Stand stationary for 30 seconds.
15. Verify distance remains constant (zero fake motion drift).
16. Walk off corridor route > 4.0 meters.
17. Verify off-route detection triggers A* route recalculation.
18. Walk physically to Point C (`5m, 0, -10m`) and verify physical arrival triggers only upon proximity (`<= 2.5m`).
