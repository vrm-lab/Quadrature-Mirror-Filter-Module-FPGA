# Design Rationale

This QMF implementation is intentionally designed as a
**transparent and verifiable DSP reference**, not a black-box IP.

---

## Why QMF?

Quadrature Mirror Filters are widely used in:
- Subband coding
- Audio filter banks
- Multirate signal processing

They provide:
- Clear frequency separation
- Perfect or near-perfect reconstruction
- A well-documented theoretical foundation

---

## Why Johnston 8A?

The Johnston 8A prototype filter is used because it is:
- Widely cited in literature
- Compact (8 taps)
- Symmetric and well-behaved in fixed-point

It is used here strictly as a **validation reference**,
not as a claim of optimal performance.

---

## FIR-Based Architecture

- Both analysis and synthesis stages are FIR-based
- Coefficients are programmable via AXI-Lite
- Filter symmetry is handled explicitly

This choice favors:
- Predictability
- Debuggability
- Easy inspection in simulation

---

## Fixed-Point Discipline

- Q15 coefficients
- Explicit output scaling
- Saturation logic at final stages

No implicit casting or hidden truncation is used.

---

## Explicit Over Implicit

Design choices deliberately avoid:
- Auto-generated DSP blocks
- Implicit multirate tricks
- Tool-dependent optimizations

This makes the design easier to:
- Review
- Modify
- Reuse in other DSP chains
