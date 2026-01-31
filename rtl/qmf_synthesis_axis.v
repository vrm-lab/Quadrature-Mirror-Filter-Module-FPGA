`timescale 1ns / 1ps

// =============================================================
// QMF Synthesis AXI Wrapper
// -------------------------------------------------------------
// AXI-Stream + AXI-Lite wrapper for the QMF synthesis core.
//
// - Accepts low-band and high-band subband streams
// - Reconstructs full-band stereo audio stream
// - Provides AXI-Lite register interface for:
//     * Global enable
//     * Prototype filter coefficients (h0[n])
//
// Responsibilities of this module:
// - AXI-Stream join and backpressure handling
// - AXI-Lite register management
// - Stereo channel handling
// - Control signal pipelining to match DSP latency
//
// All DSP arithmetic is implemented in qmf_synthesis_core.
// =============================================================
module qmf_synthesis_axis #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 12, // 4 KB AXI-Lite space
    parameter integer NTAPS               = 8   // FIR tap count (validation config)
)(
    input  wire clk,
    input  wire rstn,

    // ---------------------------------------------------------
    // AXI-Stream Slave: Low-Band Input
    // ---------------------------------------------------------
    input  wire [31:0] s_axis_low_tdata,
    input  wire        s_axis_low_tvalid,
    output wire        s_axis_low_tready,
    input  wire        s_axis_low_tlast,

    // ---------------------------------------------------------
    // AXI-Stream Slave: High-Band Input
    // ---------------------------------------------------------
    input  wire [31:0] s_axis_high_tdata,
    input  wire        s_axis_high_tvalid,
    output wire        s_axis_high_tready,
    input  wire        s_axis_high_tlast,

    // ---------------------------------------------------------
    // AXI-Stream Master: Reconstructed Output
    // ---------------------------------------------------------
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    // ---------------------------------------------------------
    // AXI-Lite Interface (Control & Coefficients)
    // ---------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg [1:0]   s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    // =========================================================================
    // 1. AXI4-LITE REGISTER FILE
    // =========================================================================
    // Address map (identical to analysis wrapper):
    //   0x00 : Control register
    //          bit[0] = global enable
    //
    //   0x04, 0x08, ... :
    //          FIR prototype coefficients h0[n]
    // =========================================================================

    reg signed [15:0]  h0_regs [0:NTAPS-1]; // Prototype FIR coefficients
    reg                reg_en;              // Global enable
    wire [NTAPS*16-1:0] h0_flat;             // Flattened coefficient array

    // ---------------------------------------------------------
    // AXI-Lite WRITE logic
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            reg_en        <= 1'b0;
        end else begin
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;

                if (s_axi_awaddr == 0)
                    reg_en <= s_axi_wdata[0];
                else
                    h0_regs[s_axi_awaddr[C_S_AXI_ADDR_WIDTH-1:2] - 1]
                        <= s_axi_wdata[15:0];
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            if (s_axi_awready && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // AXI-Lite READ logic
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00; // OKAY

                if (s_axi_araddr == 0)
                    s_axi_rdata <= {31'd0, reg_en};
                else
                    s_axi_rdata <= {
                        16'd0,
                        h0_regs[s_axi_araddr[C_S_AXI_ADDR_WIDTH-1:2] - 1]
                    };
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready)
                    s_axi_rvalid <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------
    // Flatten coefficient array for DSP core
    // ---------------------------------------------------------
    genvar k;
    generate
        for (k = 0; k < NTAPS; k = k + 1) begin : flatten_coeffs
            assign h0_flat[k*16 +: 16] = h0_regs[k];
        end
    endgenerate

    // =========================================================================
    // 2. AXI-STREAM JOIN, BACKPRESSURE, AND PIPELINING
    // =========================================================================
    // Both subband inputs must be present simultaneously.
    // Processing proceeds only when:
    //   - low-band VALID asserted
    //   - high-band VALID asserted
    //   - output stream ready
    // =========================================================================

    wire join_valid = s_axis_low_tvalid && s_axis_high_tvalid;

    // Core enable condition
    wire core_en = reg_en && join_valid && m_axis_tready;

    // Upstream ready is asserted only when the core accepts data
    assign s_axis_low_tready  = core_en;
    assign s_axis_high_tready = core_en;

    // ---------------------------------------------------------
    // QMF Synthesis Core Instantiation (Stereo)
    // ---------------------------------------------------------

    // Left channel: bits [15:0]
    wire signed [15:0] dout_merged_L;
    qmf_synthesis_core #(.NTAPS(NTAPS)) synthesis_L (
        .clk(clk),
        .rstn(rstn),
        .en(core_en),
        .din_low (s_axis_low_tdata [15:0]),
        .din_high(s_axis_high_tdata[15:0]),
        .h0_coef_flat(h0_flat),
        .dout_merged(dout_merged_L)
    );

    // Right channel: bits [31:16]
    wire signed [15:0] dout_merged_R;
    qmf_synthesis_core #(.NTAPS(NTAPS)) synthesis_R (
        .clk(clk),
        .rstn(rstn),
        .en(core_en),
        .din_low (s_axis_low_tdata [31:16]),
        .din_high(s_axis_high_tdata[31:16]),
        .h0_coef_flat(h0_flat),
        .dout_merged(dout_merged_R)
    );

    // ---------------------------------------------------------
    // Control signal pipelining (2-cycle latency)
    // ---------------------------------------------------------
    // The synthesis core introduces:
    //   - 1 cycle from FIR filtering
    //   - 1 cycle from subband summation
    //
    // VALID and LAST are delayed by two cycles
    // to maintain alignment with output data.
    // ---------------------------------------------------------
    reg [1:0] valid_pipe;
    reg [1:0] last_pipe;

    always @(posedge clk) begin
        if (!rstn) begin
            valid_pipe <= 2'b00;
            last_pipe  <= 2'b00;
        end else if (m_axis_tready) begin
            // Stage 1
            valid_pipe[0] <= join_valid && reg_en;
            last_pipe [0] <= s_axis_low_tlast; // Low & High assumed aligned

            // Stage 2
            valid_pipe[1] <= valid_pipe[0];
            last_pipe [1] <= last_pipe [0];
        end
        // When stalled, pipeline registers hold their state
    end

    // ---------------------------------------------------------
    // Output assignment
    // ---------------------------------------------------------
    assign m_axis_tdata  = {dout_merged_R, dout_merged_L};
    assign m_axis_tvalid = valid_pipe[1];
    assign m_axis_tlast  = last_pipe[1];

endmodule
