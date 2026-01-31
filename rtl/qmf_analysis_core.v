// =============================================================
// QMF Analysis Core
// -------------------------------------------------------------
// Implements the analysis stage of a two-channel Quadrature
// Mirror Filter (QMF) bank.
//
// - Low-pass branch uses prototype filter h0[n]
// - High-pass branch is derived as h1[n] = h0[n] * (-1)^n
//
// Both branches are implemented using identical FIR cores,
// differing only in coefficient sign alternation.
//
// This module performs *pure analysis filtering*:
// no decimation, no buffering, no AXI logic.
// =============================================================
module qmf_analysis_core #(
    parameter integer DATAW     = 16,   // Input/output data width
    parameter integer COEFW     = 16,   // FIR coefficient width
    parameter integer NTAPS     = 128,  // Number of FIR taps
    parameter integer OUT_SHIFT = 15    // Output scaling / normalization
)(
    input  wire clk,
    input  wire rstn,
    input  wire en,

    // Input sample stream
    input  wire signed [DATAW-1:0] din,

    // Prototype low-pass coefficients (flattened array)
    input  wire [NTAPS*COEFW-1:0]  h0_coef_flat,

    // Analysis subband outputs
    output wire signed [DATAW-1:0] dout_low,
    output wire signed [DATAW-1:0] dout_high
);

    // ---------------------------------------------------------
    // High-pass coefficient generation
    // ---------------------------------------------------------
    // QMF property:
    //   h1[n] = h0[n] * (-1)^n
    //
    // This is implemented by alternating the sign of the
    // prototype coefficients at elaboration time.
    // ---------------------------------------------------------
    wire [NTAPS*COEFW-1:0] h1_coef_flat;

    genvar i;
    generate
        for (i = 0; i < NTAPS; i = i + 1) begin : gen_h1
            assign h1_coef_flat[i*COEFW +: COEFW] =
                (i % 2 == 0) ?
                    h0_coef_flat[i*COEFW +: COEFW] :
                   -$signed(h0_coef_flat[i*COEFW +: COEFW]);
        end
    endgenerate

    // ---------------------------------------------------------
    // Low-pass analysis filter
    // ---------------------------------------------------------
    // Uses the prototype FIR coefficients h0[n].
    // The FIR core is treated as a verified arithmetic primitive.
    // ---------------------------------------------------------
    fir_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .OUT_SHIFT(OUT_SHIFT)
    ) filter_lp (
        .clk        (clk),
        .rstn       (rstn),
        .en         (en),
        .clear_state(1'b0),
        .din        (din),
        .coef_flat  (h0_coef_flat),
        .dout       (dout_low)
    );

    // ---------------------------------------------------------
    // High-pass analysis filter
    // ---------------------------------------------------------
    // Implements the complementary QMF branch using h1[n].
    // Identical FIR structure to the low-pass path.
    // ---------------------------------------------------------
    fir_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .OUT_SHIFT(OUT_SHIFT)
    ) filter_hp (
        .clk        (clk),
        .rstn       (rstn),
        .en         (en),
        .clear_state(1'b0),
        .din        (din),
        .coef_flat  (h1_coef_flat),
        .dout       (dout_high)
    );

endmodule
