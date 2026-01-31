# Testbench Overview — QMF Module

This directory contains **SystemVerilog testbenches** used to verify the
**Quadrature Mirror Filter (QMF)** implementation at multiple abstraction levels.

The testbenches are designed to validate:
- functional correctness,
- fixed-point behavior,
- deterministic latency,
- AXI-Stream and AXI-Lite protocol handling,

without turning the repository into a runnable application or framework.

All testbenches generate **CSV outputs** for offline inspection and plotting.

---

## Verification Philosophy

The testbenches in this repository follow these principles:

- **Deterministic & cycle-accurate**
- **Explicit fixed-point arithmetic**
- **Clear separation of concerns**
- **No hidden buffering or adaptive behavior**
- **Validation-oriented, not feature-oriented**

These testbenches are intended to:
> demonstrate *design decisions*, not *design possibilities*.

---

## Testbench Hierarchy

Verification is organized into **three levels**:

### 1️⃣ Core-Level Testbenches (No AXI)

These testbenches validate **pure DSP behavior** without protocol overhead.

| Testbench | Description |
|---------|------------|
| `tb_qmf_analysis_core.sv` | Verifies QMF analysis core (low/high subband split) |
| `tb_qmf_synthesis_core.sv` | Verifies QMF synthesis core using back-to-back analysis |
| `tb_qmf_system_core.sv` | End-to-end QMF system (analysis → synthesis) |

**Purpose**:
- Validate arithmetic correctness
- Observe subband behavior
- Inspect reconstruction quality
- Confirm fixed latency

---

### 2️⃣ AXI Wrapper-Level Testbenches

These testbenches verify **AXI-Stream and AXI-Lite integration** for each block.

| Testbench | Description |
|---------|------------|
| `tb_qmf_analysis_axis.sv` | AXI-based QMF analysis wrapper |
| `tb_qmf_synthesis_axis.sv` | AXI-based QMF synthesis wrapper |

**Purpose**:
- Verify AXI-Lite register access (write + readback)
- Validate AXI-Stream handshaking and backpressure
- Confirm correct data/control alignment through pipelines

---

### 3️⃣ System-Level AXI Testbench (Top-Level)

| Testbench | Description |
|---------|------------|
| `tb_qmf_system_axis.sv` | Full AXI system: analysis → synthesis |

**Purpose**:
- Validate **independent AXI-Lite control paths**
- Verify **robust AXI-Stream handshake under backpressure**
- Confirm correct end-to-end data flow

This is the **highest-level verification artifact** in the repository.

---

## Test Configuration

All testbenches use the same **fixed validation configuration**:

- **Prototype filter**: Johnston 8A
- **Number of taps**: 8
- **Fixed-point format**: Q15
- **Latency**: deterministic and documented per module

The configuration is intentionally **locked** to keep verification:
- reproducible,
- analyzable,
- and comparable across test levels.

The design itself supports other tap counts via parameterization, but
**those configurations are outside the scope of this verification set**.

---

## Johnston 8A Reference

The QMF prototype filter used in all testbenches is based on:

```bibtex
@inproceedings{Johnston1980,
   author    = {James D. Johnston},
   title     = {A filter family designed for use in quadrature mirror filter banks},
   booktitle = {IEEE International Conference on Acoustics, Speech, and Signal Processing (ICASSP)},
   pages     = {291--294},
   year      = {1980},
   doi       = {10.1109/ICASSP.1980.1171025}
}
```

This filter is widely used as a reference QMF prototype
and is suitable for validating:

- subband separation behavior,
- reconstruction characteristics,
- and fixed-point implementation quality.

---

## CSV Output Notes

- CSV logs are generated for offline inspection only.
- Logged input samples are **not cycle-aligned** with outputs
  due to pipeline latency.

The logs are intended for:
- waveform visualization,
- sanity checking,
- relative comparison between signals.

They are **not intended for automated metric evaluation**.

---

## Scope Statement

This testbench suite:

- ✅ Validates functional correctness
- ✅ Demonstrates AXI integration quality
- ✅ Shows fixed-point DSP discipline

This testbench suite does **not**:

- ❌ Provide bitstreams
- ❌ Provide runtime software
- ❌ Aim to be a reusable verification framework

---

## Status

**This testbench suite is considered complete.**

The scope is intentionally fixed to preserve clarity and consistency
across the QMF repository and related DSP building blocks.
