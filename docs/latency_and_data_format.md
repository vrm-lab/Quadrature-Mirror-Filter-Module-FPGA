# Latency and Data Format

This document describes **data representation** and **latency behavior**
across the QMF processing chain.

---

## Data Format

### AXI-Stream
- 32-bit `TDATA`
- Stereo packed format:
  - `[15:0]`   → Left channel
  - `[31:16]`  → Right channel
- Signed two’s complement

### Core-Level Data
- 16-bit signed samples
- Q15 fixed-point arithmetic
- Explicit scaling via `OUT_SHIFT`

---

## Latency Characteristics

### FIR Latency
Latency is dominated by:
- FIR pipeline depth
- Coefficient count (`NTAPS`)
- Internal DSP staging

Latency is:
- **Deterministic**
- **Constant**
- **Independent of data content**

---

### AXI Wrapper Effects

AXI wrappers add:
- Handshake synchronization
- Optional backpressure handling

They **do not** modify:
- Numerical results
- Relative phase relationships

---

## Testbench Alignment

CSV logs:
- Are **not cycle-aligned** with outputs
- Reflect pipeline latency naturally

This is expected and intentional.

---

## Summary

- Latency is fixed and predictable
- Data formats are explicit
- No hidden buffering or re-timing exists
