## Integration Overview

This repository also includes an **integration-level validation**
that combines multiple RTL building blocks into a single streaming pipeline:

QMF Analysis → Dual Gain → QMF Synthesis

The integration demonstrates that:

- QMF subbands can be independently processed in the frequency domain
- Gain modules operate correctly inside a multi-stage AXI-Stream pipeline
- Subband-domain processing is correctly reflected in the reconstructed output
- AXI-Stream handshakes remain stable across chained modules

Integration artifacts include:

- System-level architecture diagram
- RTL testbench waveforms
- CSV logs for offline inspection

The integration is provided to **validate composability and correctness**.
It is **not intended as a production reference design or performance benchmark**.
