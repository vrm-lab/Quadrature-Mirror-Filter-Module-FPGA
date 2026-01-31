# Build Overview

This repository provides a **Quadrature Mirror Filter (QMF)** implementation
designed as a **DSP building block** for FPGA-based audio processing systems.

The project is organized around three layers:

1. **Core DSP logic**
2. **AXI-Stream / AXI-Lite wrappers**
3. **System-level integration (Vivado IP Integrator)**

---

## Design Layers

### 1. Core Level
- `qmf_analysis_core`
- `qmf_synthesis_core`

These modules implement the mathematical QMF behavior using:
- FIR-based filtering
- Fixed-point arithmetic
- Fully synchronous pipelines

They are **tool-agnostic** and suitable for reuse in non-AXI systems.

---

### 2. AXI Wrapper Level
- `qmf_analysis_axis`
- `qmf_synthesis_axis`

Responsibilities:
- AXI-Stream handshake management
- AXI-Lite register interface
- Safe enable/reset behavior
- Stereo sample formatting (32-bit AXI stream)

No DSP logic is modified at this level.

---

### 3. System Integration Level
- Vivado Block Design (`bd.tcl`)
- AXI DMA
- Zynq UltraScale+ MPSoC (KV260)

This layer exists **only for validation and demonstration**.

---

## What This Repository Is

✅ RTL-focused DSP reference  
✅ AXI-compliant and simulation-verified  
✅ Fixed-point–disciplined implementation  

---

## What This Repository Is NOT

❌ A software-driven audio framework  
❌ A drop-in IP with prebuilt bitstreams  
❌ A performance-optimized codec solution  

---

## Build Philosophy

> *Correctness first, clarity always.*

The design prioritizes:
- Explicit dataflow
- Predictable latency
- Deterministic behavior

Over:
- Aggressive optimization
- Tool-specific abstractions
