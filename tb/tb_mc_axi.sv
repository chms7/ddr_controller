`timescale 1 ns / 100ps

module tb_mc_axi;

`include "../rtl/config/mc_defines.svh"

//-----------------------------------------------------------------
// Clock / Reset
//-----------------------------------------------------------------
parameter PERIOD  = 10;

logic osc = 0 ;
logic rst = 1 ;

initial forever #(PERIOD/2) osc = ~osc; // 100MHz
initial         #(1000)     rst = 0;

//-----------------------------------------------------------------
// Dump Wave
//-----------------------------------------------------------------
initial begin
  $dumpfile("../sim/wave.vcd");
  $dumpvars(0, tb_mc_axi);
end

//-----------------------------------------------------------------
// PLL
//-----------------------------------------------------------------
wire clk;
wire clk_ddr;
wire clk_ddr_dqs;
wire clk_ref;

artix7_pll u_pll (
  .clkref_i(osc)

  // Outputs
  ,.clkout0_o(clk)         // 100
  ,.clkout1_o(clk_ddr)     // 400
  ,.clkout2_o(clk_ref)     // 200
  ,.clkout3_o(clk_ddr_dqs) // 400 (phase 90)
);

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
  .rst_i              ( rst              ),

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
    .REQ_BUF_DEPTH  ( 4  ))
 u_mc_axi_top (
    .clk_i                   ( clk                    ),
    .rst_n_i                 ( ~rst                  ),

    .axi_awvalid_i           ( axi_awvalid_w            ),
    .axi_awid_i              ( axi_awid_w               ),
    .axi_awaddr_i            ( axi_awaddr_w             ),
    .axi_awsize_i            ( axi_awsize_w             ),
    .axi_awlen_i             ( axi_awlen_w              ),
    .axi_awburst_i           ( axi_awburst_w            ),
    .axi_awready_o           ( axi_awready_w            ),

    .axi_wvalid_i            ( axi_wvalid_w             ),
    .axi_wdata_i             ( axi_wdata_w              ),
    .axi_wstrb_i             ( axi_wstrb_w              ),
    .axi_wlast_i             ( axi_wlast_w              ),
    .axi_wready_o            ( axi_wready_w             ),

    .axi_bvalid_o            ( axi_bvalid_w             ),
    .axi_bid_o               ( axi_bid_w                ),
    .axi_bresp_o             ( axi_bresp_w              ),
    .axi_bready_i            ( axi_bready_w             ),

    .axi_arvalid_i           ( axi_arvalid_w            ),
    .axi_arid_i              ( axi_arid_w               ),
    .axi_araddr_i            ( axi_araddr_w             ),
    .axi_arsize_i            ( axi_arsize_w             ),
    .axi_arlen_i             ( axi_arlen_w              ),
    .axi_arburst_i           ( axi_arburst_w            ),
    .axi_arready_o           ( axi_arready_w            ),

    .axi_rvalid_o            ( axi_rvalid_w             ),
    .axi_rid_o               ( axi_rid_w                ),
    .axi_rdata_o             ( axi_rdata_w              ),
    .axi_rresp_o             ( axi_rresp_w              ),
    .axi_rlast_o             ( axi_rlast_w              ),
    .axi_rready_i            ( axi_rready_w             ),

    .dfi_cs_n_o              ( dfi_cs_n             ),
    .dfi_ras_n_o             ( dfi_ras_n            ),
    .dfi_cas_n_o             ( dfi_cas_n            ),
    .dfi_we_n_o              ( dfi_we_n             ),
    .dfi_reset_n_o           ( dfi_reset_n          ),
    .dfi_cke_o               ( dfi_cke              ),
    .dfi_odt_o               ( dfi_odt              ),
    .dfi_bank_o              ( dfi_bank             ),
    .dfi_address_o           ( dfi_address          ),
    .dfi_wrdata_o            ( dfi_wrdata           ),
    .dfi_wrdata_mask_o       ( dfi_wrdata_mask      ),
    .dfi_wrdata_en_o         ( dfi_wrdata_en        ),
    .dfi_rddata_en_o         ( dfi_rddata_en        ),
    .dfi_rddata_i            ( dfi_rddata           ),
    .dfi_rddata_valid_i      ( dfi_rddata_valid     ),
    .dfi_init_start_o        ( dfi_init_start       ),
    .dfi_dram_clk_disable_o  ( dfi_dram_clk_disable ),
    .dfi_init_complete_i     ( dfi_init_complete    )
);

//-----------------------------------------------------------------
// mem_read: Perform read transfer (128-bit)
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// Test
//-----------------------------------------------------------------
reg [127:0] data;
initial
begin
    dfi_init_complete <= 1'b0;
    axi_awvalid_w     <= 1'b0;
    axi_wvalid_w      <= 1'b0;
    axi_wlast_w       <= 1'b0;
    #10000
        dfi_init_complete <= 1'b1;

    @(posedge u_mc_axi_top.mc_mem_accept_w)
    @(posedge clk);
      axi_awvalid_w <= 1'b1;
      axi_awid_w    <= 4'b0000;
      axi_awaddr_w  <= 32'h00000100;
      axi_awsize_w  <= 3'b101;
      axi_awlen_w   <= 8'h4;
      axi_awburst_w <= 2'b01;

      axi_wvalid_w  <= 1'b1;
      axi_wdata_w   <= 32'hFFFF_1111;
    @(posedge clk);
      axi_wdata_w   <= 32'h2222_3333;
    @(posedge clk);
      axi_wdata_w   <= 32'h4444_5555;
    @(posedge clk);
      axi_wdata_w   <= 32'h6666_7777;
      axi_wlast_w   <= 1'b1;
    @(posedge clk);
      axi_awvalid_w <= 1'b0;
      axi_wvalid_w  <= 1'b0;
      axi_wlast_w   <= 1'b0;

    @(posedge u_mc_axi_top.mc_mem_accept_w)
    @(posedge clk);
      axi_awvalid_w <= 1'b1;
      axi_awid_w    <= 4'b0000;
      axi_awaddr_w  <= 32'h00000200;
      axi_awsize_w  <= 3'b101;
      axi_awlen_w   <= 8'h4;
      axi_awburst_w <= 2'b01;

      axi_wvalid_w  <= 1'b1;
      axi_wdata_w   <= 32'hAAAA_BBBB;
    @(posedge clk);
      axi_wdata_w   <= 32'h2222_3333;
    @(posedge clk);
      axi_wdata_w   <= 32'h4444_5555;
    @(posedge clk);
      axi_wdata_w   <= 32'h6666_7777;
      axi_wlast_w   <= 1'b1;
    @(posedge clk);
      axi_awvalid_w <= 1'b0;
      axi_wvalid_w  <= 1'b0;
      axi_wlast_w   <= 1'b0;




    #10000
    @(posedge clk);   
    $finish;

end

endmodule