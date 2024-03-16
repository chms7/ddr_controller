module tb_mc_axi_vip;

//------------------------------------------------------------------------------
// AXI clock, reset and interface signals
//------------------------------------------------------------------------------
parameter PERIOD  = 10;

logic aclk = 0 ;
logic aresetn = 0 ;

initial forever #(PERIOD/2) aclk = ~aclk; // 100MHz
initial         #(1000)     aresetn = 1;

wire clk;
wire clk_ddr;
wire clk_ddr_dqs;
wire clk_ref;

artix7_pll
u_pll
(
    .clkref_i(aclk)

    // Outputs
    ,.clkout0_o(clk)         // 100
    ,.clkout1_o(clk_ddr)     // 400
    ,.clkout2_o(clk_ref)     // 200
    ,.clkout3_o(clk_ddr_dqs) // 400 (phase 90)
);

//------------------------------------------------------------------------------
// AXI parameters and types
//------------------------------------------------------------------------------
typedef axi_vip_master_pkg::axi_vip_master_mst_t axi_mst_agent_t;

localparam AXI_ADDR_W   = axi_vip_master_pkg::axi_vip_master_VIP_ADDR_WIDTH;
localparam AXI_DATA_W   = axi_vip_master_pkg::axi_vip_master_VIP_DATA_WIDTH;
localparam AXI_STRB_W   = AXI_DATA_W / 8;
localparam AXI_BURST_W  = 2;
localparam AXI_CACHE_W  = 4;
localparam AXI_PROT_W   = 3;
localparam AXI_REGION_W = 4;
localparam AXI_USER_W   = 4;
localparam AXI_QOS_W    = 4;
localparam AXI_LEN_W    = 8;
localparam AXI_SIZE_W   = 3;
localparam AXI_RESP_W   = 2;

localparam AXI_BEATS_MAX = 2**AXI_LEN_W;

typedef logic [AXI_ADDR_W-1:0]   axi_addr_t;
typedef logic [AXI_DATA_W-1:0]   axi_data_t;
typedef logic [AXI_STRB_W-1:0]   axi_strb_t;
typedef logic [AXI_LEN_W-1:0]    axi_len_t;
typedef logic [AXI_CACHE_W-1:0]  axi_cache_t;
typedef logic [AXI_PROT_W-1:0]   axi_prot_t;
typedef logic [AXI_REGION_W-1:0] axi_region_t;
typedef logic [AXI_QOS_W-1:0]    axi_qos_t;

typedef enum logic [AXI_BURST_W-1:0] {
    AXI_BURST_FIXED = 2'b00,
    AXI_BURST_INCR  = 2'b01,
    AXI_BURST_WRAP  = 2'b10,
    AXI_BURST_RSVD  = 2'b11
} axi_burst_t;

typedef enum logic [AXI_RESP_W-1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
} axi_resp_t;

typedef enum logic [AXI_SIZE_W-1:0] {
    AXI_SIZE_1B    = 3'b000,
    AXI_SIZE_2B    = 3'b001,
    AXI_SIZE_4B    = 3'b010,
    AXI_SIZE_8B    = 3'b011,
    AXI_SIZE_16B   = 3'b100,
    AXI_SIZE_32B   = 3'b101,
    AXI_SIZE_64B   = 3'b110,
    AXI_SIZE_128B  = 3'b111
} axi_size_t;


axi_addr_t   axi_awaddr;
axi_len_t    axi_awlen;
axi_size_t   axi_awsize;
axi_burst_t  axi_awburst;
logic        axi_awlock;
axi_cache_t  axi_awcache;
axi_prot_t   axi_awprot;
axi_region_t axi_awregion;
axi_qos_t    axi_awqos;
logic        axi_awvalid;
logic        axi_awready;
axi_data_t   axi_wdata;
axi_strb_t   axi_wstrb;
logic        axi_wlast;
logic        axi_wvalid;
logic        axi_wready;
axi_resp_t   axi_bresp;
logic        axi_bvalid;
logic        axi_bready;
axi_addr_t   axi_araddr;
axi_len_t    axi_arlen;
axi_size_t   axi_arsize;
axi_burst_t  axi_arburst;
logic        axi_arlock;
axi_cache_t  axi_arcache;
axi_prot_t   axi_arprot;
axi_region_t axi_arregion;
axi_qos_t    axi_arqos;
logic        axi_arvalid;
logic        axi_arready;
axi_data_t   axi_rdata;
axi_resp_t   axi_rresp;
logic        axi_rlast;
logic        axi_rvalid;
logic        axi_rready;

//------------------------------------------------------------------------------
// AXI VIP Master
//------------------------------------------------------------------------------
axi_vip_master axi_mst (
    .aclk           (aclk),
    .aresetn        (aresetn),
    .m_axi_awaddr   (axi_awaddr),
    .m_axi_awlen    (axi_awlen),
    .m_axi_awsize   (axi_awsize[0+:$bits(axi_awsize)]),
    .m_axi_awburst  (axi_awburst[0+:$bits(axi_awburst)]),
    .m_axi_awlock   (axi_awlock),
    .m_axi_awcache  (axi_awcache),
    .m_axi_awprot   (axi_awprot),
    .m_axi_awregion (axi_awregion),
    .m_axi_awqos    (axi_awqos),
    .m_axi_awvalid  (axi_awvalid),
    .m_axi_awready  (axi_awready),
    .m_axi_wdata    (axi_wdata),
    .m_axi_wstrb    (axi_wstrb),
    .m_axi_wlast    (axi_wlast),
    .m_axi_wvalid   (axi_wvalid),
    .m_axi_wready   (axi_wready),
    .m_axi_bresp    (axi_bresp),
    .m_axi_bvalid   (axi_bvalid),
    .m_axi_bready   (axi_bready),
    .m_axi_araddr   (axi_araddr),
    .m_axi_arlen    (axi_arlen),
    .m_axi_arsize   (axi_arsize[0+:$bits(axi_arsize)]),
    .m_axi_arburst  (axi_arburst[0+:$bits(axi_arburst)]),
    .m_axi_arlock   (axi_arlock),
    .m_axi_arcache  (axi_arcache),
    .m_axi_arprot   (axi_arprot),
    .m_axi_arregion (axi_arregion),
    .m_axi_arqos    (axi_arqos),
    .m_axi_arvalid  (axi_arvalid),
    .m_axi_arready  (axi_arready),
    .m_axi_rdata    (axi_rdata),
    .m_axi_rresp    (axi_rresp),
    .m_axi_rlast    (axi_rlast),
    .m_axi_rvalid   (axi_rvalid),
    .m_axi_rready   (axi_rready)
);

axi_mst_agent_t axi_mst_agent;

initial begin
    axi_mst_agent = new("axi_mst_agent", axi_mst.inst.IF);
    axi_mst_agent.start_master();
end

task axi_write (
    input  axi_addr_t  addr,
    input  axi_len_t   len = 1,
    input  axi_size_t  size = AXI_SIZE_4B,
    input  axi_burst_t burst = AXI_BURST_INCR,
    input  axi_data_t  data [],
    output axi_resp_t  resp []
);
    logic [(4096/(AXI_DATA_W/8))-1:0][AXI_DATA_W-1:0] wdata; // 4096 bytes is a Xilinx AXI VIP data size
    axi_vip_pkg::xil_axi_resp_t wresp;

    for (int i=0; i<=len; i++) begin
        wdata[i] = data[i];
    end

    axi_mst_agent.AXI4_WRITE_BURST(
        .id     ('0),
        .addr   (axi_vip_pkg::xil_axi_ulong'(addr)),
        .len    (axi_vip_pkg::xil_axi_len_t'(len)),
        .size   (axi_vip_pkg::xil_axi_size_t'(size)),
        .burst  (axi_vip_pkg::xil_axi_burst_t'(burst)),
        .lock   (axi_vip_pkg::xil_axi_lock_t'('0)),
        .cache  ('0),
        .prot   ('0),
        .region ('0),
        .qos    ('0),
        .awuser ('0),
        .data   (wdata),
        .wuser  ('0),
        .resp   (wresp)
    );
    resp = new[1];
    resp[0] = axi_resp_t'(wresp);
endtask

task axi_read (
    input  axi_addr_t  addr,
    input  axi_len_t   len = 0,
    input  axi_size_t  size = AXI_SIZE_4B,
    input  axi_burst_t burst = AXI_BURST_INCR,
    output axi_data_t  data [],
    output axi_resp_t  resp []
);
    bit [4096/(AXI_DATA_W/8)-1:0][AXI_DATA_W-1:0] data_o; // 4096 bytes is a Xilinx AXI VIP data size
    axi_vip_pkg::xil_axi_resp_t [255:0] resp_o; // 256 responses is a Xilinx AXI VIP parameter
    axi_vip_pkg::xil_axi_data_beat [255:0] ruser_o;
    axi_mst_agent.AXI4_READ_BURST(
        .id     (0),
        .addr   (axi_vip_pkg::xil_axi_ulong'(addr)),
        .len    (axi_vip_pkg::xil_axi_len_t'(len)),
        .size   (axi_vip_pkg::xil_axi_size_t'(size)),
        .burst  (axi_vip_pkg::xil_axi_burst_t'(burst)),
        .lock   (axi_vip_pkg::xil_axi_lock_t'(0)),
        .cache  (0),
        .prot   (0),
        .region (0),
        .qos    (0),
        .aruser (0),
        .data   (data_o),
        .resp   (resp_o),
        .ruser  (ruser_o)
    );
    data = new[len+1];
    resp = new[len+1];
    for (int i=0; i<=len; i++) begin
        data[i] = data_o[i];
        resp[i] = axi_resp_t'(resp_o[i]);
    end;
endtask

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
wire          ddr3_clk_w;
wire          ddr3_cke_w;
wire          ddr3_reset_n_w;
wire          ddr3_ras_n_w;
wire          ddr3_cas_n_w;
wire          ddr3_we_n_w;
wire          ddr3_cs_n_w;
wire [  2:0]  ddr3_ba_w;
wire [ 13:0]  ddr3_addr_w;
wire          ddr3_odt_w;
wire [  1:0]  ddr3_dm_w;
wire [  1:0]  ddr3_dqs_w;
wire [ 15:0]  ddr3_dq_w;

wire  [ 14:0] dfi_address;
wire  [  2:0] dfi_bank;
wire          dfi_cas_n;
wire          dfi_cke;
wire          dfi_cs_n;
wire          dfi_odt;
wire          dfi_ras_n;
wire          dfi_reset_n;
wire          dfi_we_n;
wire  [ 31:0] dfi_wrdata;
wire          dfi_wrdata_en;
wire  [  3:0] dfi_wrdata_mask;
wire          dfi_rddata_en;
wire [ 31:0]  dfi_rddata;
wire          dfi_rddata_valid;

reg           dfi_init_complete;
wire          dfi_init_start;
wire          dfi_dram_clk_disable;

//-----------------------------------------------------------------
// DRAM Model
//-----------------------------------------------------------------
wire          ddr3_ck_p_w;
wire          ddr3_ck_n_w;
wire [  1:0]  ddr3_dqs_p_w;
wire [  1:0]  ddr3_dqs_n_w;

ddr3 u_ddr3 (
  .rst_n   (ddr3_reset_n_w),
  .ck      (ddr3_ck_p_w),
  .ck_n    (ddr3_ck_n_w),
  .cke     (ddr3_cke_w),
  .cs_n    (ddr3_cs_n_w),
  .ras_n   (ddr3_ras_n_w),
  .cas_n   (ddr3_cas_n_w),
  .we_n    (ddr3_we_n_w),
  .dm_tdqs (ddr3_dm_w),
  .ba      (ddr3_ba_w),
  .addr    (ddr3_addr_w),
  .dq      (ddr3_dq_w),
  .dqs     (ddr3_dqs_p_w),
  .dqs_n   (ddr3_dqs_n_w),
  .tdqs_n  (),
  .odt     (ddr3_odt_w)
);

//-----------------------------------------------------------------
// DDR PHY
//-----------------------------------------------------------------
ddr3_dfi_phy #(
  .DQS_TAP_DELAY_INIT ( 27               ),
  .DQ_TAP_DELAY_INIT  ( 0                ),
  .TPHY_RDLAT         ( 5                )
) u_phy (
  .clk_i              ( clk              ),
  .clk_ddr_i          ( clk_ddr          ),
  .clk_ddr90_i        ( clk_ddr_dqs      ),
  .clk_ref_i          ( clk_ref          ),
  .rst_i              ( ~aresetn         ),

  .dfi_cs_n_i         ( dfi_cs_n         ),
  .dfi_ras_n_i        ( dfi_ras_n        ),
  .dfi_cas_n_i        ( dfi_cas_n        ),
  .dfi_we_n_i         ( dfi_we_n         ),

  .dfi_reset_n_i      ( dfi_reset_n      ),
  .dfi_cke_i          ( dfi_cke          ),
  .dfi_odt_i          ( dfi_odt          ),

  .dfi_address_i      ( dfi_address      ),
  .dfi_bank_i         ( dfi_bank         ),

  .dfi_wrdata_i       ( dfi_wrdata       ),
  .dfi_wrdata_en_i    ( dfi_wrdata_en    ),
  .dfi_wrdata_mask_i  ( dfi_wrdata_mask  ),
  .dfi_rddata_en_i    ( dfi_rddata_en    ),

  .dfi_rddata_o       ( dfi_rddata       ),
  .dfi_rddata_valid_o ( dfi_rddata_valid ),
  .dfi_rddata_dnv_o   (                  ),

  .ddr3_ck_p_o        ( ddr3_ck_p_w      ),
  .ddr3_ck_n_o        ( ddr3_ck_n_w      ),
  .ddr3_cke_o         ( ddr3_cke_w       ),
  .ddr3_reset_n_o     ( ddr3_reset_n_w   ),
  .ddr3_ras_n_o       ( ddr3_ras_n_w     ),
  .ddr3_cas_n_o       ( ddr3_cas_n_w     ),
  .ddr3_we_n_o        ( ddr3_we_n_w      ),
  .ddr3_cs_n_o        ( ddr3_cs_n_w      ),
  .ddr3_ba_o          ( ddr3_ba_w        ),
  .ddr3_addr_o        ( ddr3_addr_w      ),
  .ddr3_odt_o         ( ddr3_odt_w       ),
  .ddr3_dm_o          ( ddr3_dm_w        ),
  .ddr3_dqs_p_io      ( ddr3_dqs_p_w     ),
  .ddr3_dqs_n_io      ( ddr3_dqs_n_w     ),
  .ddr3_dq_io         ( ddr3_dq_w        )
);

//-----------------------------------------------------------------
// DDR Controller
//-----------------------------------------------------------------
parameter AXI_ID_WIDTH   = 4;
parameter AXI_ADDR_WIDTH = 32;
parameter AXI_DATA_WIDTH = 32;
parameter REQ_BUF_DEPTH  = 4;

logic                        axi_awvalid_w;
logic [AXI_ID_WIDTH-1:0]     axi_awid_w   ;
logic [AXI_ADDR_WIDTH-1:0]   axi_awaddr_w ;
logic [2:0]                  axi_awsize_w ;
logic [7:0]                  axi_awlen_w  ;
logic [1:0]                  axi_awburst_w;
logic                        axi_awready_w;
                                          ;
logic                        axi_wvalid_w ;
logic [AXI_DATA_WIDTH-1:0]   axi_wdata_w  ;
logic [AXI_DATA_WIDTH/8-1:0] axi_wstrb_w  ;
logic                        axi_wlast_w  ;
logic                        axi_wready_w ;
                                          ;
logic                        axi_bvalid_w ;
logic [AXI_ID_WIDTH-1:0]     axi_bid_w    ;
logic [1:0]                  axi_bresp_w  ;
logic                        axi_bready_w ;
                                          ;
logic                        axi_arvalid_w;
logic [AXI_ID_WIDTH-1:0]     axi_arid_w   ;
logic [AXI_ADDR_WIDTH-1:0]   axi_araddr_w ;
logic [2:0]                  axi_arsize_w ;
logic [7:0]                  axi_arlen_w  ;
logic [1:0]                  axi_arburst_w;
logic                        axi_arready_w;
                                          ;
logic                        axi_rvalid_w ;
logic [AXI_ID_WIDTH-1:0]     axi_rid_w    ;
logic [AXI_DATA_WIDTH-1:0]   axi_rdata_w  ;
logic [1:0]                  axi_rresp_w  ;
logic                        axi_rlast_w  ;
logic                        axi_rready_w ;

mc_axi_top #(
    .AXI_ID_WIDTH   ( 4  ),
    .AXI_ADDR_WIDTH ( 32 ),
    .AXI_DATA_WIDTH ( 32 ),
    .REQ_BUF_DEPTH  ( 4  )
) u_mc_axi_top (
    .clk_i                   ( aclk                           ),
    .rst_n_i                 ( aresetn                        ),

    .axi_awvalid_i           ( axi_awvalid                    ),
    .axi_awid_i              ( '0                             ),
    .axi_awaddr_i            ( axi_awaddr                     ),
    .axi_awsize_i            ( axi_awsize                     ),
    .axi_awlen_i             ( axi_awlen                      ),
    .axi_awburst_i           ( axi_awburst                    ),
    .axi_awready_o           ( axi_awready                    ),

    .axi_wvalid_i            ( axi_wvalid                     ),
    .axi_wdata_i             ( axi_wdata                      ),
    .axi_wstrb_i             ( axi_wstrb                      ),
    .axi_wlast_i             ( axi_wlast                      ),
    .axi_wready_o            ( axi_wready                     ),

    .axi_bvalid_o            ( axi_bvalid                     ),
    .axi_bid_o               ( axi_bid                        ),
    .axi_bresp_o             ( axi_bresp[0+:$bits(axi_bresp)] ),
    .axi_bready_i            ( axi_bready                     ),

    .axi_arvalid_i           ( axi_arvalid                    ),
    .axi_arid_i              ( '0                             ),
    .axi_araddr_i            ( axi_araddr                     ),
    .axi_arsize_i            ( axi_arsize                     ),
    .axi_arlen_i             ( axi_arlen                      ),
    .axi_arburst_i           ( axi_arburst                    ),
    .axi_arready_o           ( axi_arready                    ),

    .axi_rvalid_o            ( axi_rvalid                     ),
    .axi_rid_o               ( axi_rid                        ),
    .axi_rdata_o             ( axi_rdata                      ),
    .axi_rresp_o             ( axi_rresp[0+:$bits(axi_rresp)] ),
    .axi_rlast_o             ( axi_rlast                      ),
    .axi_rready_i            ( axi_rready                     ),

    .dfi_cs_n_o              ( dfi_cs_n                       ),
    .dfi_ras_n_o             ( dfi_ras_n                      ),
    .dfi_cas_n_o             ( dfi_cas_n                      ),
    .dfi_we_n_o              ( dfi_we_n                       ),
    .dfi_reset_n_o           ( dfi_reset_n                    ),
    .dfi_cke_o               ( dfi_cke                        ),
    .dfi_odt_o               ( dfi_odt                        ),
    .dfi_bank_o              ( dfi_bank                       ),
    .dfi_address_o           ( dfi_address                    ),
    .dfi_wrdata_o            ( dfi_wrdata                     ),
    .dfi_wrdata_mask_o       ( dfi_wrdata_mask                ),
    .dfi_wrdata_en_o         ( dfi_wrdata_en                  ),
    .dfi_rddata_en_o         ( dfi_rddata_en                  ),
    .dfi_rddata_i            ( dfi_rddata                     ),
    .dfi_rddata_valid_i      ( dfi_rddata_valid               ),
    .dfi_init_start_o        ( dfi_init_start                 ),
    .dfi_dram_clk_disable_o  ( dfi_dram_clk_disable           ),
    .dfi_init_complete_i     ( dfi_init_complete              )
);

//-------------------------------------------------------------------
// Testbench body
//-------------------------------------------------------------------
initial begin : tb_main
    axi_data_t  data [];
    axi_resp_t  resp [];

    wait(aresetn);
    repeat(3) @(posedge aclk);

    $display("Do write...");
    data = new[4];
    data = {32'h12345678, 32'h9abcdeff, 32'h11223344, 32'h55667788};
    axi_write(.addr('h100), .len(data.size()-1), .data(data), .resp(resp));
    data = {32'hffffffff, 32'h87654321, 32'h11223344, 32'h55667788};
    axi_write(.addr('h110), .len(data.size()-1), .data(data), .resp(resp));
    data = {32'haaaabbbb, 32'hccccdddd, 32'heeeeffff, 32'h11111111};
    axi_write(.addr('h100000), .len(data.size()-1), .data(data), .resp(resp));

    $display("Do read...");
    axi_read(.addr('h100), .len(3), .data(data), .resp(resp));
    foreach(data[i])
        $display("\t%0d: data=0x%08x, resp=%0s", i, data[i], resp[i].name());
    $display("Do read...");
    axi_read(.addr('h110), .len(3), .data(data), .resp(resp));
    foreach(data[i])
        $display("\t%0d: data=0x%08x, resp=%0s", i, data[i], resp[i].name());
    $display("Do read...");
    axi_read(.addr('h100000), .len(3), .data(data), .resp(resp));
    foreach(data[i])
        $display("\t%0d: data=0x%08x, resp=%0s", i, data[i], resp[i].name());

    #1000;
    $stop;
end

initial begin
  $dumpfile("wave.vcd");
  $dumpvars(0, tb_mc_axi_vip);
end

endmodule