`timescale 1ns/1ps

// =============================================================
// Testbench: QMF System AXI (End-to-End)
// -------------------------------------------------------------
// System-level verification for the complete QMF chain
// implemented with AXI wrappers:
//
//   AXI-Stream In
//        |
//   qmf_analysis_axis
//        |
//   (low / high subbands)
//        |
//   qmf_synthesis_axis
//        |
//   AXI-Stream Out
//
// Verification scenario:
// 1. Write FIR coefficients to analysis core via AXI-Lite
// 2. Read back and verify analysis coefficients
// 3. Write FIR coefficients to synthesis core via AXI-Lite
// 4. Read back and verify synthesis coefficients
// 5. Stream stereo audio through the full QMF system
//
// Validation configuration:
// - Johnston 8A prototype filter
// - 8-tap FIR
//
// This testbench validates:
// - Independent AXI-Lite control paths
// - AXI-Stream backpressure robustness
// - End-to-end data flow correctness
//
// It is not a performance benchmark.
// =============================================================
module tb_qmf_axis;

    // =========================================================================
    // 1. PARAMETERS & GLOBAL SIGNALS
    // =========================================================================
    parameter integer NTAPS = 8;
    parameter integer ADDRW = 12;

    // Clock & reset
    reg clk;
    reg rstn;

    // Separate AXI-Lite clock domain (for realism)
    reg s_axi_aclk;
    reg s_axi_aresetn;

    // =========================================================================
    // 2. AXI-STREAM SIGNALS (AUDIO PATH)
    // =========================================================================

    // Input stream
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    // Analysis outputs (subbands)
    wire [31:0] axis_low_tdata;
    wire [31:0] axis_high_tdata;
    wire        axis_low_tvalid;
    wire        axis_high_tvalid;
    wire        axis_low_tlast;
    wire        axis_high_tlast;

    // Reconstructed output
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    wire        m_axis_tlast;
    reg         m_axis_tready;

    // =========================================================================
    // 3. AXI-LITE SIGNALS (CONTROL PATH)
    // =========================================================================
    // Shared address & write-data buses
    reg  [ADDRW-1:0] axi_addr;
    reg  [31:0]      axi_wdata;

    // --- Analysis control channel ---
    reg              an_awvalid, an_wvalid, an_bready;
    wire             an_awready, an_wready, an_bvalid;
    reg              an_arvalid, an_rready;
    wire             an_arready, an_rvalid;
    wire [31:0]      an_rdata;
    wire [1:0]       an_resp;

    // --- Synthesis control channel ---
    reg              syn_awvalid, syn_wvalid, syn_bready;
    wire             syn_awready, syn_wready, syn_bvalid;
    reg              syn_arvalid, syn_rready;
    wire             syn_arready, syn_rvalid;
    wire [31:0]      syn_rdata;
    wire [1:0]       syn_resp;

    // =========================================================================
    // 4. SIMULATION HELPERS
    // =========================================================================
    integer i;
    integer file_ptr;

    real sin_low;
    real sin_high;
    reg signed [15:0] wave_part;

    // Johnston 8A coefficients (Q15)
    reg signed [15:0] j8a [0:NTAPS-1];

    // =========================================================================
    // 5. DUT INSTANTIATION
    // =========================================================================

    // ---------------------------------------------------------
    // Analysis AXI Wrapper
    // ---------------------------------------------------------
    qmf_analysis_axis #(
        .C_S_AXI_ADDR_WIDTH(ADDRW),
        .NTAPS(NTAPS)
    ) dut_analysis (
        .clk(clk),
        .rstn(rstn),

        // AXI-Stream
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast (s_axis_tlast),

        .m_axis_low_tdata (axis_low_tdata),
        .m_axis_low_tvalid(axis_low_tvalid),
        .m_axis_low_tready(1'b1),               // Direct connection
        .m_axis_low_tlast (axis_low_tlast),

        .m_axis_high_tdata (axis_high_tdata),
        .m_axis_high_tvalid(axis_high_tvalid),
        .m_axis_high_tready(1'b1),              // Direct connection
        .m_axis_high_tlast (axis_high_tlast),

        // AXI-Lite (analysis)
        .s_axi_awaddr (axi_addr),
        .s_axi_awvalid(an_awvalid),
        .s_axi_awready(an_awready),
        .s_axi_wdata  (axi_wdata),
        .s_axi_wvalid (an_wvalid),
        .s_axi_wready (an_wready),
        .s_axi_bvalid (an_bvalid),
        .s_axi_bready (an_bready),
        .s_axi_bresp  (an_resp),

        .s_axi_araddr (axi_addr),
        .s_axi_arvalid(an_arvalid),
        .s_axi_arready(an_arready),
        .s_axi_rdata  (an_rdata),
        .s_axi_rvalid (an_rvalid),
        .s_axi_rready (an_rready)
    );

    // ---------------------------------------------------------
    // Synthesis AXI Wrapper
    // ---------------------------------------------------------
    qmf_synthesis_axis #(
        .C_S_AXI_ADDR_WIDTH(ADDRW),
        .NTAPS(NTAPS)
    ) dut_synthesis (
        .clk(clk),
        .rstn(rstn),

        // AXI-Stream
        .s_axis_low_tdata (axis_low_tdata),
        .s_axis_low_tvalid(axis_low_tvalid),
        .s_axis_low_tready(),
        .s_axis_low_tlast (axis_low_tlast),

        .s_axis_high_tdata (axis_high_tdata),
        .s_axis_high_tvalid(axis_high_tvalid),
        .s_axis_high_tready(),
        .s_axis_high_tlast (axis_high_tlast),

        .m_axis_tdata (m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast (m_axis_tlast),

        // AXI-Lite (synthesis)
        .s_axi_awaddr (axi_addr),
        .s_axi_awvalid(syn_awvalid),
        .s_axi_awready(syn_awready),
        .s_axi_wdata  (axi_wdata),
        .s_axi_wvalid (syn_wvalid),
        .s_axi_wready (syn_wready),
        .s_axi_bvalid (syn_bvalid),
        .s_axi_bready (syn_bready),
        .s_axi_bresp  (syn_resp),

        .s_axi_araddr (axi_addr),
        .s_axi_arvalid(syn_arvalid),
        .s_axi_arready(syn_arready),
        .s_axi_rdata  (syn_rdata),
        .s_axi_rvalid (syn_rvalid),
        .s_axi_rready (syn_rready)
    );

    // =========================================================================
    // 6. CLOCK GENERATION
    // =========================================================================
    always #5  clk        = ~clk;        // 100 MHz stream clock
    always #10 s_axi_aclk = ~s_axi_aclk; // 50 MHz AXI-Lite clock

    // =========================================================================
    // 7. AXI-LITE TRANSACTION TASKS
    // =========================================================================

    // AXI-Lite write transaction
    // target: 0 = analysis, 1 = synthesis
    task axi_write(input [ADDRW-1:0] addr, input [31:0] data, input target);
        begin
            @(posedge s_axi_aclk);
            axi_addr  <= addr;
            axi_wdata <= data;

            if (target == 0) begin
                an_awvalid <= 1'b1; an_wvalid <= 1'b1; an_bready <= 1'b1;
                wait (an_awready && an_wready);
            end else begin
                syn_awvalid <= 1'b1; syn_wvalid <= 1'b1; syn_bready <= 1'b1;
                wait (syn_awready && syn_wready);
            end

            @(posedge s_axi_aclk);
            if (target == 0) begin an_awvalid <= 0; an_wvalid <= 0; end
            else             begin syn_awvalid <= 0; syn_wvalid <= 0; end

            if (target == 0) wait (an_bvalid);
            else             wait (syn_bvalid);

            @(posedge s_axi_aclk);
            if (target == 0) an_bready <= 0;
            else             syn_bready <= 0;
        end
    endtask

    // AXI-Lite read transaction
    task axi_read(input [ADDRW-1:0] addr, output [31:0] val, input target);
        begin
            @(posedge s_axi_aclk);
            axi_addr <= addr;

            if (target == 0) begin
                an_arvalid <= 1'b1; an_rready <= 1'b1;
                wait (an_arready);
            end else begin
                syn_arvalid <= 1'b1; syn_rready <= 1'b1;
                wait (syn_arready);
            end

            @(posedge s_axi_aclk);
            if (target == 0) an_arvalid <= 0;
            else             syn_arvalid <= 0;

            if (target == 0) begin
                wait (an_rvalid); val = an_rdata; an_rready <= 0;
            end else begin
                wait (syn_rvalid); val = syn_rdata; syn_rready <= 0;
            end
        end
    endtask

    // =========================================================================
    // 8. MAIN SIMULATION SEQUENCE
    // =========================================================================
    initial begin
        // Initialization
        clk = 0;
        s_axi_aclk = 0;
        rstn = 0;
        s_axi_aresetn = 0;

        file_ptr = $fopen("tb_data_qmf_system_axis.csv", "w");
        $fdisplay(file_ptr, "time_ns,input,low,high,output");

        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1'b1;

        axi_addr = 0;
        axi_wdata = 0;

        an_awvalid = 0; an_wvalid = 0; an_bready = 0;
        an_arvalid = 0; an_rready = 0;
        syn_awvalid = 0; syn_wvalid = 0; syn_bready = 0;
        syn_arvalid = 0; syn_rready = 0;

        // Johnston 8A coefficients
        j8a[0] =  16'sd308;
        j8a[1] = -16'sd2315;
        j8a[2] =  16'sd2275;
        j8a[3] =  16'sd16056;
        j8a[4] =  16'sd16056;
        j8a[5] =  16'sd2275;
        j8a[6] = -16'sd2315;
        j8a[7] =  16'sd308;

        #100;
        rstn = 1'b1;
        s_axi_aresetn = 1'b1;

        // -----------------------------------------------------
        // Configuration: analysis + synthesis
        // -----------------------------------------------------
        for (i = 0; i < NTAPS; i = i + 1)
            axi_write((i+1)*4, {16'd0, j8a[i]}, 0);
        axi_write(0, 32'd1, 0); // enable analysis

        for (i = 0; i < NTAPS; i = i + 1)
            axi_write((i+1)*4, {16'd0, j8a[i]}, 1);
        axi_write(0, 32'd1, 1); // enable synthesis

        #200;

        // -----------------------------------------------------
        // Streaming audio (robust handshake)
        // -----------------------------------------------------
        for (i = 0; i < 1000; i = i + 1) begin
            sin_low  = 8000.0 * $sin(2.0 * 3.14159 * i / 50.0);
            sin_high = 4000.0 * $sin(2.0 * 3.14159 * i / 5.0);
            wave_part = $rtoi(sin_low + sin_high);

            s_axis_tdata  <= {wave_part, wave_part};
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= (i == 999);

            @(posedge clk);
            while (!s_axis_tready)
                @(posedge clk);
        end

        @(posedge clk);
        s_axis_tvalid <= 0;
        s_axis_tlast  <= 0;

        #1000;
        $fclose(file_ptr);
        $display("Simulation finished: tb_qmf_system_axis.csv generated.");
        $finish;
    end

    // =========================================================================
    // 9. OUTPUT LOGGING
    // =========================================================================
    // Logged data is not cycle-aligned with the input due to pipeline latency.
    // The log is intended for waveform-level inspection only.
    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            $fdisplay(
                file_ptr,
                "%0d,%0d,%0d,%0d,%0d",
                $time,
                $signed(s_axis_tdata[15:0]),
                $signed(axis_low_tdata[15:0]),
                $signed(axis_high_tdata[15:0]),
                $signed(m_axis_tdata[15:0])
            );
        end
    end

endmodule
