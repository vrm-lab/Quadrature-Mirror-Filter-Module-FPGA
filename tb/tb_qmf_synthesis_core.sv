`timescale 1ns/1ps

// ============================================================================
// Testbench: QMF Synthesis Core (Standalone Verification)
// ----------------------------------------------------------------------------
// Purpose:
//   Functional verification of qmf_synthesis_core in isolation.
//
// Scope:
//   - Direct stimulus to subband inputs (din_low, din_high)
//   - No analysis stage involved
//   - No AXI interfaces
//   - Pure core-level verification
//
// Focus:
//   - Subband reconstruction behavior
//   - Fixed-point normalization (Q15)
//   - Functional sanity checking
// ============================================================================

module tb_qmf_synthesis_core;

    // =========================================================================
    // 1. PARAMETERS
    // =========================================================================
    parameter integer DATAW     = 16;
    parameter integer COEFW     = 16;
    parameter integer NTAPS     = 8;
    parameter integer OUT_SHIFT = 15;  // Q1.15 normalization shift

    // =========================================================================
    // 2. SIGNAL DECLARATIONS
    // =========================================================================
    reg clk;
    reg rstn;
    reg en;

    // Flattened coefficient vector (prototype filter)
    reg [NTAPS*COEFW-1:0] h0_coef_flat;

    // Subband inputs (directly driven)
    reg signed [DATAW-1:0] din_low;
    reg signed [DATAW-1:0] din_high;

    // Reconstructed output
    wire signed [DATAW-1:0] dout_merged;

    // =========================================================================
    // 3. SIMULATION VARIABLES
    // =========================================================================
    integer f;
    integer i;

    real phase;
    real ampl;
    real pi;

    // =========================================================================
    // 4. DUT INSTANTIATION
    // =========================================================================
    qmf_synthesis_core #(
        .DATAW     (DATAW),
        .COEFW     (COEFW),
        .NTAPS     (NTAPS),
        .OUT_SHIFT (OUT_SHIFT)
    ) unit_synthesis (
        .clk          (clk),
        .rstn         (rstn),
        .en           (en),
        .din_low      (din_low),
        .din_high     (din_high),
        .h0_coef_flat (h0_coef_flat),
        .dout_merged  (dout_merged)
    );

    // =========================================================================
    // 5. CLOCK GENERATION (100 MHz)
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // 6. MAIN STIMULUS
    // =========================================================================
    initial begin
        // ---------------------------------------------------------------------
        // A. CSV Initialization
        // ---------------------------------------------------------------------
        f = $fopen("tb_data_qmf_synthesis_core.csv", "w");
        $fwrite(f, "time_ns,din_low,din_high,dout_merged\n");

        // ---------------------------------------------------------------------
        // B. Load Johnston 8A Prototype Coefficients
        //     Order: h7 ... h0 (flattened)
        // ---------------------------------------------------------------------
        h0_coef_flat = {
             16'd308,
            -16'd2315,
             16'd2275,
             16'd16056,
             16'd16056,
             16'd2275,
            -16'd2315,
             16'd308
        };

        // ---------------------------------------------------------------------
        // C. Reset & Initialization
        // ---------------------------------------------------------------------
        rstn     = 1'b0;
        en       = 1'b0;
        din_low  = 0;
        din_high = 0;

        pi    = 3.14159265359;
        ampl  = 10000.0;
        phase = 0.0;

        #100;
        rstn = 1'b1;
        #20;
        en   = 1'b1;

        $display("---- Starting Standalone Synthesis Core Test ----");

        // ---------------------------------------------------------------------
        // Scenario 1: Low-Band Only
        //   - High band held at zero
        //   - Low-frequency sine injected into din_low
        // ---------------------------------------------------------------------
        $display("Scenario 1: Low-band stimulus only");
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            phase   += (2.0 * pi / 40.0);
            din_low  = $rtoi(ampl * $sin(phase));
            din_high = 0;

            #1; log_to_csv();
        end

        // ---------------------------------------------------------------------
        // Scenario 2: High-Band Only
        //   - Low band held at zero
        //   - Higher-frequency sine injected into din_high
        // ---------------------------------------------------------------------
        $display("Scenario 2: High-band stimulus only");
        phase = 0.0;
        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            phase   += (2.0 * pi / 10.0);
            din_low  = 0;
            din_high = $rtoi(ampl * $sin(phase));

            #1; log_to_csv();
        end

        // ---------------------------------------------------------------------
        // Scenario 3: Composite Subband Input
        //   - Both subbands active
        //   - Evaluates reconstruction interaction
        // ---------------------------------------------------------------------
        $display("Scenario 3: Composite subband stimulus");
        phase = 0.0;
        for (i = 0; i < 400; i = i + 1) begin
            @(posedge clk);
            phase   += (2.0 * pi / 20.0);
            din_low  = $rtoi(ampl * $sin(phase));
            din_high = $rtoi((ampl/2) * $cos(phase*2));

            #1; log_to_csv();
        end

        // ---------------------------------------------------------------------
        // End Simulation
        // ---------------------------------------------------------------------
        #100;
        $display("Simulation complete. Output written to tb_data_qmf_synthesis_core.csv");
        $fclose(f);
        $stop;
    end

    // =========================================================================
    // 7. CSV Logging Task
    // =========================================================================
    task log_to_csv;
        begin
            $fwrite(f, "%0d,%d,%d,%d\n",
                    $time,
                    $signed(din_low),
                    $signed(din_high),
                    $signed(dout_merged));
        end
    endtask

endmodule
