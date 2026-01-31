`timescale 1ns/1ps

// =============================================================
// Testbench: QMF Analysis Core
// -------------------------------------------------------------
// Functional verification testbench for qmf_analysis_core.
//
// Verification goals:
// - Validate QMF analysis behavior using a known prototype
//   (Johnston 8A, 8 taps).
// - Observe low-band / high-band separation on a mixed
//   low-frequency + high-frequency input signal.
// - Produce CSV output for offline inspection and plotting.
//
// Notes:
// - This testbench is intentionally simple and deterministic.
// - It is NOT intended to be a generic verification framework.
// =============================================================
module tb_qmf_analysis_core;

    // ========================================================================
    // 1. PARAMETERS & SIGNAL DECLARATIONS
    // ========================================================================
    parameter integer DATAW     = 16;
    parameter integer COEFW     = 16;
    parameter integer NTAPS     = 8;   // Validation configuration: Johnston 8A
    parameter integer OUT_SHIFT = 15;  // Q15 * Q15 = Q30 -> shift back to Q15

    reg  clk;
    reg  rstn;
    reg  en;
    reg  signed [DATAW-1:0] din;
    reg  [NTAPS*COEFW-1:0]  h0_coef_flat;

    wire signed [DATAW-1:0] dout_low;
    wire signed [DATAW-1:0] dout_high;

    // File handling
    integer f;
    integer i;

    // Real-valued variables for stimulus generation (simulation only)
    real phase_low;
    real phase_high;
    real ampl_low;
    real ampl_high;
    real sin_val;
    real pi;

    // ========================================================================
    // 2. DUT INSTANTIATION
    // ========================================================================
    qmf_analysis_core #(
        .DATAW    (DATAW),
        .COEFW    (COEFW),
        .NTAPS    (NTAPS),
        .OUT_SHIFT(OUT_SHIFT)
    ) uut (
        .clk         (clk),
        .rstn        (rstn),
        .en          (en),
        .din         (din),
        .h0_coef_flat(h0_coef_flat),
        .dout_low    (dout_low),
        .dout_high   (dout_high)
    );

    // ========================================================================
    // 3. CLOCK GENERATION
    // ========================================================================
    // 100 MHz clock (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // 4. MAIN STIMULUS SEQUENCE
    // ========================================================================
    initial begin
        // --------------------------------------------------------------------
        // A. CSV FILE INITIALIZATION
        // --------------------------------------------------------------------
        i = 0;
        f = $fopen("tb_data_qmf_analysis_core.csv", "w");
        if (f == 0) begin
            $display("ERROR: Failed to open output CSV file.");
            $finish;
        end

        // CSV header
        $fwrite(f, "time_ns,din,dout_low,dout_high\n");

        // --------------------------------------------------------------------
        // B. PROTOTYPE FILTER COEFFICIENTS (Johnston 8A, Q15)
        // --------------------------------------------------------------------
        // Floating-point reference values:
        //   h0 =  0.009389
        //   h1 = -0.070651
        //   h2 =  0.069428
        //   h3 =  0.48998
        //   h4 =  0.48998
        //   h5 =  0.069428
        //   h6 = -0.070651
        //   h7 =  0.009389
        //
        // Converted to signed Q15 (scaled by 32768).
        //
        // Note on ordering:
        // The flattened vector is packed such that:
        //   h0 occupies bits [0 +: 16]
        //   h1 occupies bits [16 +: 16]
        //   ...
        //   h7 occupies the MSBs
        // This matches the expected ordering in fir_core.
        h0_coef_flat = {
             16'd308,    // h7
            -16'd2315,   // h6
             16'd2275,   // h5
             16'd16056,  // h4
             16'd16056,  // h3
             16'd2275,   // h2
            -16'd2315,   // h1
             16'd308     // h0
        };

        // --------------------------------------------------------------------
        // C. RESET AND INITIAL CONDITIONS
        // --------------------------------------------------------------------
        rstn = 1'b0;
        en   = 1'b0;
        din  = '0;

        phase_low  = 0.0;
        phase_high = 0.0;
        ampl_low   = 10000.0; // Low-frequency component amplitude
        ampl_high  = 5000.0;  // High-frequency component amplitude
        pi         = 3.14159265359;

        #100;
        rstn = 1'b1;
        #20;
        en   = 1'b1;

        $display("QMF analysis simulation started.");

        // --------------------------------------------------------------------
        // D. INPUT SIGNAL LOOP
        // --------------------------------------------------------------------
        // Generate a composite signal:
        // - Low-frequency sinusoid (Fs / 50)
        // - High-frequency sinusoid (Fs / 4)
        //
        // Observe separation into low-band and high-band outputs.
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);

            // Update phases
            phase_low  = phase_low  + (2.0 * pi / 50.0);
            phase_high = phase_high + (2.0 * pi / 4.0);

            // Composite signal
            sin_val = (ampl_low  * $sin(phase_low)) +
                      (ampl_high * $sin(phase_high));

            // Convert to signed fixed-point input
            din = $rtoi(sin_val);

            // Small delay to ensure stable outputs before logging
            #1;
            $fwrite(
                f,
                "%0d,%0d,%0d,%0d\n",
                $time,
                $signed(din),
                $signed(dout_low),
                $signed(dout_high)
            );
        end

        // --------------------------------------------------------------------
        // E. END OF SIMULATION
        // --------------------------------------------------------------------
        $display("Simulation complete. Output written to tb_data_qmf_analysis_core.csv");
        $fclose(f);
        $stop;
    end

endmodule
