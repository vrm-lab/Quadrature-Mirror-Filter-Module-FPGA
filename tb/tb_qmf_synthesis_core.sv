`timescale 1ns/1ps

// =============================================================
// Testbench: QMF Synthesis Core (Back-to-Back)
// -------------------------------------------------------------
// Functional verification for qmf_synthesis_core using a
// back-to-back configuration:
//
//   qmf_analysis_core -> qmf_synthesis_core
//
// Verification goals:
// - Validate correct reconstruction behavior of the synthesis
//   stage when driven by a matching analysis stage.
// - Observe low-band / high-band subband signals and the final
//   reconstructed output.
// - Produce CSV output for offline inspection.
//
// Validation configuration:
// - Johnston 8A prototype filter
// - 8-tap FIR
//
// This testbench is intentionally simple and deterministic.
// It is not a perfect-reconstruction proof, but a practical
// sanity check under a known configuration.
// =============================================================
module tb_qmf_synthesis_core;

    // ========================================================================
    // 1. PARAMETERS
    // ========================================================================
    parameter integer DATAW     = 16;
    parameter integer COEFW     = 16;
    parameter integer NTAPS     = 8;   // Validation config: Johnston 8A
    parameter integer OUT_SHIFT = 15;  // Q15 normalization

    // ========================================================================
    // 2. SIGNALS & SIMULATION VARIABLES
    // ========================================================================
    reg clk;
    reg rstn;
    reg en;

    // Shared prototype coefficients (analysis & synthesis)
    reg [NTAPS*COEFW-1:0] h0_coef_flat;

    // Original input sample
    reg  signed [DATAW-1:0] din_original;

    // Inter-stage subband signals (analysis -> synthesis)
    wire signed [DATAW-1:0] w_subband_low;
    wire signed [DATAW-1:0] w_subband_high;

    // Final reconstructed output
    wire signed [DATAW-1:0] dout_reconstructed;

    // File logging
    integer f;
    integer i;

    // Signal generator (simulation only)
    real phase_low;
    real phase_high;
    real ampl_low;
    real ampl_high;
    real sin_val;
    real pi;

    // ========================================================================
    // 3. MODULE INSTANTIATION
    // ========================================================================

    // ---------------------------------------------------------
    // Unit 1: QMF Analysis Core
    // ---------------------------------------------------------
    // Used only to generate valid subband inputs for the
    // synthesis core under test.
    qmf_analysis_core #(
        .DATAW     (DATAW),
        .COEFW     (COEFW),
        .NTAPS     (NTAPS),
        .OUT_SHIFT (OUT_SHIFT)
    ) unit_analysis (
        .clk         (clk),
        .rstn        (rstn),
        .en          (en),
        .din         (din_original),
        .h0_coef_flat(h0_coef_flat),
        .dout_low    (w_subband_low),
        .dout_high   (w_subband_high)
    );

    // ---------------------------------------------------------
    // Unit 2: QMF Synthesis Core (DUT)
    // ---------------------------------------------------------
    qmf_synthesis_core #(
        .DATAW     (DATAW),
        .COEFW     (COEFW),
        .NTAPS     (NTAPS),
        .OUT_SHIFT (OUT_SHIFT)
    ) unit_synthesis (
        .clk         (clk),
        .rstn        (rstn),
        .en          (en),
        .din_low     (w_subband_low),
        .din_high    (w_subband_high),
        .h0_coef_flat(h0_coef_flat),
        .dout_merged (dout_reconstructed)
    );

    // ========================================================================
    // 4. CLOCK GENERATION
    // ========================================================================
    // 100 MHz clock (10 ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ========================================================================
    // 5. MAIN STIMULUS
    // ========================================================================
    initial begin
        // -----------------------------------------------------
        // A. CSV FILE INITIALIZATION
        // -----------------------------------------------------
        i = 0;
        f = $fopen("tb_data_qmf_synthesis_core.csv", "w");
        if (f == 0) begin
            $display("ERROR: Failed to open CSV output file.");
            $finish;
        end

        // Log original input, subbands, and reconstructed output
        $fwrite(f, "time_ns,din_orig,sub_low,sub_high,dout_recon\n");

        // -----------------------------------------------------
        // B. PROTOTYPE FILTER COEFFICIENTS (Johnston 8A, Q15)
        // -----------------------------------------------------
        // Flattened order: {h7, h6, ..., h0}
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

        // -----------------------------------------------------
        // C. RESET AND INITIAL CONDITIONS
        // -----------------------------------------------------
        rstn = 1'b0;
        en   = 1'b0;
        din_original = '0;

        phase_low  = 0.0;
        phase_high = 0.0;
        ampl_low   = 10000.0;
        ampl_high  = 5000.0;
        pi         = 3.14159265359;

        #100;
        rstn = 1'b1;
        #20;
        en   = 1'b1; // Enable both analysis and synthesis

        $display("Starting back-to-back QMF simulation...");

        // -----------------------------------------------------
        // D. INPUT SIGNAL LOOP
        // -----------------------------------------------------
        // Composite signal:
        // - Low-frequency sinusoid (Fs / 50)
        // - High-frequency sinusoid (Fs / 4)
        //
        // Observe:
        // - Subband separation at analysis outputs
        // - Reconstruction behavior at synthesis output
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);

            phase_low  += (2.0 * pi / 50.0);
            phase_high += (2.0 * pi / 4.0);

            sin_val = (ampl_low  * $sin(phase_low)) +
                      (ampl_high * $sin(phase_high));

            din_original = $rtoi(sin_val);

            // Small delay to ensure stable signals before logging
            #1;
            $fwrite(
                f,
                "%0d,%0d,%0d,%0d,%0d\n",
                $time,
                $signed(din_original),
                $signed(w_subband_low),
                $signed(w_subband_high),
                $signed(dout_reconstructed)
            );
        end

        // -----------------------------------------------------
        // E. END OF SIMULATION
        // -----------------------------------------------------
        #100;
        $display("Simulation complete. Output written to tb_data_qmf_synthesis_core.csv");
        $fclose(f);
        $stop;
    end

endmodule
