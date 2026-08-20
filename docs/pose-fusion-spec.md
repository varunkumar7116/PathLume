# PathLume Timestamp-Aware Pose Fusion Specification

This document details the mathematical fusion model combining low-latency ARCore relative motion deltas with high-accuracy VPS absolute localization.

---

## 1. Pose Fusion State Equations

$$\mathbf{P}_{\text{fused}}(t) = \mathbf{P}_{\text{VPS}}(t_0) + \Delta \mathbf{P}_{\text{ARCore}}(t - t_0)$$

Where:
- $\mathbf{P}_{\text{VPS}}(t_0)$: Last validated absolute position from VPS at timestamp $t_0$.
- $\Delta \mathbf{P}_{\text{ARCore}}(t - t_0)$: Accumulated 6DoF motion delta measured by ARCore between $t_0$ and $t$.

---

## 2. Drift Correction Smoothing

When a new VPS localization result arrives at $t_1$:
1. Calculate position residual: $\mathbf{e} = \mathbf{P}_{\text{VPS}}(t_1) - \mathbf{P}_{\text{fused}}(t_1)$
2. If $\|\mathbf{e}\| > 10.0\text{m}$ (impossible jump): **REJECT** result.
3. If $\|\mathbf{e}\| \le 10.0\text{m}$: Apply smooth exponential blend $\alpha = 0.35$ to avoid visual camera popping.
$$\mathbf{P}_{\text{corrected}} = \mathbf{P}_{\text{fused}} + \alpha \cdot \mathbf{e}$$
