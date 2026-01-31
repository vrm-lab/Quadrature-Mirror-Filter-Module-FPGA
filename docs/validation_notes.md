# Validation Notes

This repository is validated through **RTL simulation only**.

No hardware performance claims are made.

---

## Validation Scope

The testbench suite validates:

✅ Subband separation behavior  
✅ Reconstruction correctness  
✅ AXI-Stream handshake robustness  
✅ AXI-Lite register functionality  
✅ Fixed-point numerical stability  

---

## What Is NOT Validated

❌ Audio quality metrics (THD, SNR, PSNR)  
❌ Long-duration stress tests  
❌ Hardware timing closure across PVT corners  
❌ Real-time software interaction  

---

## Methodology

- Deterministic sine-based stimulus
- Known QMF reference coefficients (Johnston 8A)
- Visual waveform inspection via CSV plots

This approach prioritizes:
- Correct signal flow
- Structural integrity
- Numerical sanity

---

## Engineering Position

> This project demonstrates **correctness**, not **optimality**.

It is intended as:
- A reference
- A learning resource
- A reusable DSP building block

Not as a finished audio product.
