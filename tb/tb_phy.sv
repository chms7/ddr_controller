`timescale 1 ns / 100ps

module tb_phy ;

`include "simulation.vh"

//-----------------------------------------------------------------
// Clock / Reset
//-----------------------------------------------------------------
`CLOCK_GEN(osc, 10)    // 100MHz
`RESET_GEN(rst, 1000)  // delay 1000ns

//-----------------------------------------------------------------
// Misc
//-----------------------------------------------------------------
`TB_VCD(tb_phy, "wave.vcd")

//-----------------------------------------------------------------
// PLL
//-----------------------------------------------------------------
wire clk;
wire clk_ddr;
wire clk_ddr_dqs;
wire clk_ref;

artix7_pll
u_pll
(
    .clkref_i(osc)

    // Outputs
    ,.clkout0_o(clk)         // 100
    ,.clkout1_o(clk_ddr)     // 400
    ,.clkout2_o(clk_ref)     // 200
    ,.clkout3_o(clk_ddr_dqs) // 400 (phase 90)
);

//-----------------------------------------------------------------
// Command Encode
//-----------------------------------------------------------------
localparam CMD_W             = 4;
localparam CMD_NOP           = 4'b0111;
localparam CMD_ACTIVE        = 4'b0011;
localparam CMD_READ          = 4'b0101;
localparam CMD_WRITE         = 4'b0100;
localparam CMD_PRECHARGE     = 4'b0010;
localparam CMD_REFRESH       = 4'b0001;
localparam CMD_LOAD_MODE     = 4'b0000;
localparam CMD_ZQCL          = 4'b0110;
// Mode Configuration
// - DLL disabled (low speed only)
// - CL=6
// - AL=0
// - CWL=6
localparam MR0_REG           = 15'h0120;
localparam MR1_REG           = 15'h0001;
localparam MR2_REG           = 15'h0008;
localparam MR3_REG           = 15'h0000;

localparam DDR_BA_W       = 3;    // bank address
localparam DDR_RA_W       = 15;   // row  address 14?
localparam DDR_CA_W       = 10;   // col  address

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

ddr3 u_ram (
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
  phy_top #
    (
     .TCQ                               (TCQ),
     .REFCLK_FREQ                       (REFCLK_FREQ),
     .nCS_PER_RANK                      (nCS_PER_RANK),
     .CAL_WIDTH                         (CAL_WIDTH),
     .CALIB_ROW_ADD                     (CALIB_ROW_ADD),
     .CALIB_COL_ADD                     (CALIB_COL_ADD),
     .CALIB_BA_ADD                      (CALIB_BA_ADD),
     .CS_WIDTH                          (CS_WIDTH),
     .nCK_PER_CLK                       (nCK_PER_CLK),
     .CKE_WIDTH                         (CKE_WIDTH),
     .DRAM_TYPE                         (DRAM_TYPE),
     .SLOT_0_CONFIG                     (SLOT_0_CONFIG),
     .SLOT_1_CONFIG                     (SLOT_1_CONFIG),
     .CLK_PERIOD                        (CLK_PERIOD),
     .BANK_WIDTH                        (BANK_WIDTH),
     .CK_WIDTH                          (CK_WIDTH),
     .COL_WIDTH                         (COL_WIDTH),
     .DM_WIDTH                          (DM_WIDTH),
     .DQ_CNT_WIDTH                      (DQ_CNT_WIDTH),
     .DQ_WIDTH                          (DQ_WIDTH),
     .DQS_CNT_WIDTH                     (DQS_CNT_WIDTH),
     .DQS_WIDTH                         (DQS_WIDTH),
     .DRAM_WIDTH                        (DRAM_WIDTH),
     .ROW_WIDTH                         (ROW_WIDTH),
     .RANK_WIDTH                        (RANK_WIDTH),
     .AL                                (AL),
     .BURST_MODE                        (BURST_MODE),
     .BURST_TYPE                        (BURST_TYPE),
     .nAL                               (nAL),
     .nCL                               (nCL),
     .nCWL                              (nCWL),
     .tRFC                              (tRFC),
     .OUTPUT_DRV                        (OUTPUT_DRV),
     .REG_CTRL                          (REG_CTRL),
     .RTT_NOM                           (RTT_NOM),
     .RTT_WR                            (RTT_WR),
     .WRLVL                             (WRLVL),
     .PHASE_DETECT                      (PHASE_DETECT),
     .IODELAY_HP_MODE                   (IODELAY_HP_MODE),
     .IODELAY_GRP                       (IODELAY_GRP),
     // Prevent the following simulation-related parameters from
     // being overridden for synthesis - for synthesis only the
     // default values of these parameters should be used
     // synthesis translate_off
     .SIM_BYPASS_INIT_CAL               (SIM_BYPASS_INIT_CAL),
     // synthesis translate_on
     .nDQS_COL0                         (nDQS_COL0),
     .nDQS_COL1                         (nDQS_COL1),
     .nDQS_COL2                         (nDQS_COL2),
     .nDQS_COL3                         (nDQS_COL3),
     .DQS_LOC_COL0                      (DQS_LOC_COL0),
     .DQS_LOC_COL1                      (DQS_LOC_COL1),
     .DQS_LOC_COL2                      (DQS_LOC_COL2),
     .DQS_LOC_COL3                      (DQS_LOC_COL3),
     .USE_DM_PORT                       (USE_DM_PORT),
     .DEBUG_PORT                        (DEBUG_PORT)
     )
    phy_top0
      (
       /*AUTOINST*/
       // Outputs
       .ddr_ck_p                  (ddr_ck),
       .ddr_ck_n                  (ddr_ck_n),
       .ddr_addr                  (ddr_addr),
       .ddr_ba                    (ddr_ba),
       .ddr_ras_n                 (ddr_ras_n),
       .ddr_cas_n                 (ddr_cas_n),
       .ddr_we_n                  (ddr_we_n),
       .ddr_cs_n                  (ddr_cs_n),
       .ddr_cke                   (ddr_cke),
       .ddr_odt                   (ddr_odt),
       .ddr_reset_n               (ddr_reset_n),
       .ddr_parity                (ddr_parity),
       .ddr_dm                    (ddr_dm),
       .ddr_dqs_p                 (ddr_dqs),
       .ddr_dqs_n                 (ddr_dqs_n),
       .ddr_dq                    (ddr_dq),
    //    .pd_PSEN                   (pd_PSEN),
    //    .pd_PSINCDEC               (pd_PSINCDEC),
    //    .dbg_wrlvl_start           (dbg_wrlvl_start),
    //    .dbg_wrlvl_done            (dbg_wrlvl_done),
    //    .dbg_wrlvl_err             (dbg_wrlvl_err),       
    //    .dbg_wl_dqs_inverted       (dbg_wl_dqs_inverted),
    //    .dbg_wr_calib_clk_delay    (dbg_wr_calib_clk_delay),
    //    .dbg_wl_odelay_dqs_tap_cnt (dbg_wl_odelay_dqs_tap_cnt),
    //    .dbg_wl_odelay_dq_tap_cnt  (dbg_wl_odelay_dq_tap_cnt),
    //    .dbg_tap_cnt_during_wrlvl  (dbg_tap_cnt_during_wrlvl),
    //    .dbg_wl_edge_detect_valid  (dbg_wl_edge_detect_valid),
    //    .dbg_rd_data_edge_detect   (dbg_rd_data_edge_detect),
    //    .dbg_rdlvl_start           (dbg_rdlvl_start),
    //    .dbg_rdlvl_done            (dbg_rdlvl_done),
    //    .dbg_rdlvl_err             (dbg_rdlvl_err),
    //    .dbg_cpt_first_edge_cnt    (dbg_cpt_first_edge_cnt),
    //    .dbg_cpt_second_edge_cnt   (dbg_cpt_second_edge_cnt),
    //    .dbg_rd_bitslip_cnt        (dbg_rd_bitslip_cnt),
    //    .dbg_rd_clkdly_cnt         (dbg_rd_clkdly_cnt),
    //    .dbg_rd_active_dly         (dbg_rd_active_dly),
    //    .dbg_rd_data               (dbg_rddata),
    //    .dbg_cpt_tap_cnt           (dbg_cpt_tap_cnt),
    //    .dbg_rsync_tap_cnt         (dbg_rsync_tap_cnt),
    //    .dbg_dqs_tap_cnt           (dbg_dqs_tap_cnt),
    //    .dbg_dq_tap_cnt            (dbg_dq_tap_cnt),
    //    .dbg_phy_pd                (dbg_phy_pd),
    //    .dbg_phy_read              (dbg_phy_read),
    //    .dbg_phy_rdlvl             (dbg_phy_rdlvl),       
    //    .dbg_phy_top               (dbg_phy_top),       
       // Inouts
        // Inputs
       .clk_mem                   (clk_mem),
       .clk                       (clk),
       .clk_rd_base               (clk_rd_base),
       .rst                       (rst),

       .slot_0_present            (slot_0_present),
       .slot_1_present            (slot_1_present),

       .dfi_address0              (dfi_address0),
       .dfi_address1              (dfi_address1),
       .dfi_bank0                 (dfi_bank0),
       .dfi_bank1                 (dfi_bank1),

       .dfi_cs_n0                 (dfi_cs_n0),
       .dfi_cs_n1                 (dfi_cs_n1),
       .dfi_ras_n0                (dfi_ras_n0),
       .dfi_ras_n1                (dfi_ras_n1),
       .dfi_cas_n0                (dfi_cas_n0),
       .dfi_cas_n1                (dfi_cas_n1),
       .dfi_we_n0                 (dfi_we_n0),
       .dfi_we_n1                 (dfi_we_n1),
       .dfi_cke0                  ({CKE_WIDTH{1'b1}}),
       .dfi_cke1                  ({CKE_WIDTH{1'b1}}),
       .dfi_reset_n               (dfi_reset_n),
       .dfi_odt0                  (dfi_odt0),
       .dfi_odt1                  (dfi_odt1),

       .dfi_wrdata_en             (dfi_wrdata_en[0]),
       .dfi_wrdata_mask           (dfi_wrdata_mask),
       .dfi_wrdata                (dfi_wrdata),

       .dfi_rddata_en             (dfi_rddata_en[0]),
       .dfi_rddata_valid          (dfi_rddata_valid),
       .dfi_rddata                (dfi_rddata),

       .dfi_init_complete         (dfi_init_complete),
       .dfi_dram_clk_disable      (dfi_dram_clk_disable),

       .io_config_strobe          (io_config_strobe),
       .io_config                 (io_config),
    //    .pd_PSDONE                 (pd_PSDONE),
    //    .dbg_wr_dqs_tap_set        (dbg_wr_dqs_tap_set),
    //    .dbg_wr_dq_tap_set         (dbg_wr_dq_tap_set),
    //    .dbg_wr_tap_set_en         (dbg_wr_tap_set_en),         
    //    .dbg_idel_up_all           (dbg_idel_up_all),       
    //    .dbg_idel_down_all         (dbg_idel_down_all),
    //    .dbg_idel_up_cpt           (dbg_idel_up_cpt),
    //    .dbg_idel_down_cpt         (dbg_idel_down_cpt),
    //    .dbg_idel_up_rsync         (dbg_idel_up_rsync),
    //    .dbg_idel_down_rsync       (dbg_idel_down_rsync),
    //    .dbg_sel_idel_cpt          (dbg_sel_idel_cpt),
    //    .dbg_sel_all_idel_cpt      (dbg_sel_all_idel_cpt),
    //    .dbg_sel_idel_rsync        (dbg_sel_idel_rsync),
    //    .dbg_sel_all_idel_rsync    (dbg_sel_all_idel_rsync),
    //    .dbg_pd_off                (dbg_pd_off),
    //    .dbg_pd_maintain_off       (dbg_pd_maintain_off),
    //    .dbg_pd_maintain_0_only    (dbg_pd_maintain_0_only),
    //    .dbg_pd_inc_cpt            (dbg_pd_inc_cpt),
    //    .dbg_pd_dec_cpt            (dbg_pd_dec_cpt),
    //    .dbg_pd_inc_dqs            (dbg_pd_inc_dqs),
    //    .dbg_pd_dec_dqs            (dbg_pd_dec_dqs), 
    //    .dbg_pd_disab_hyst         (dbg_pd_disab_hyst),
    //    .dbg_pd_disab_hyst_0       (dbg_pd_disab_hyst_0),
    //    .dbg_pd_msb_sel            (dbg_pd_msb_sel),
    //    .dbg_pd_byte_sel           (dbg_pd_byte_sel),
    //    .dbg_inc_rd_fps            (dbg_inc_rd_fps),
    //    .dbg_dec_rd_fps            (dbg_dec_rd_fps)
       );
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
// DDR Core
//-----------------------------------------------------------------
reg  [ 15:0]  ram_wr;
reg           ram_rd;
reg  [ 31:0]  ram_addr;
reg  [127:0]  mem_write_data;
reg  [ 15:0]  ram_req_id;
wire          ram_accept;
wire          ram_ack;
wire          ram_error;
wire [ 15:0]  ram_resp_id;
wire [127:0]  ram_read_data;

reg  [ 15:0]  mem_wr;
reg           mem_rd;
reg  [ 31:0]  mem_addr;
reg  [127:0]  mem_wrdata;
reg  [ 15:0]  mem_req_id;
wire          mem_accept;
wire          mem_ack;
wire          mem_error;
wire [ 15:0]  mem_resp_id;
wire [127:0]  mem_rddata;

mc_top u_mc_top (
    .clk_i                   ( clk ),
    .rst_n_i                 ( ~rst ),
    .mem_addr_i              ( mem_addr          ),
    .mem_rd_i                ( mem_rd            ),
    .mem_wr_i                ( mem_wr            ),
    .mem_wrdata_i            ( mem_wrdata        ),
    .mem_rddata_o            ( mem_rddata        ),
    .mem_accept_o            ( mem_accept        ),
    .mem_ack_o               ( mem_ack           ),

    .dfi_cs_n_o              ( dfi_cs_n          ),
    .dfi_ras_n_o             ( dfi_ras_n         ),
    .dfi_cas_n_o             ( dfi_cas_n         ),
    .dfi_we_n_o              ( dfi_we_n          ),
    .dfi_reset_n_o           ( dfi_reset_n       ),
    .dfi_cke_o               ( dfi_cke           ),
    .dfi_odt_o               ( dfi_odt           ),
    .dfi_bank_o              ( dfi_bank          ),
    .dfi_address_o           ( dfi_address       ),
    .dfi_wrdata_o            ( dfi_wrdata        ),
    .dfi_wrdata_mask_o       ( dfi_wrdata_mask   ),
    .dfi_wrdata_en_o         ( dfi_wrdata_en     ),
    .dfi_rddata_en_o         ( dfi_rddata_en     ),
    .dfi_rddata_i            ( dfi_rddata        ),
    .dfi_rddata_valid_i      ( dfi_rddata_valid  ),
    .dfi_init_start_o        ( dfi_init_start         ),
    .dfi_dram_clk_disable_o  ( dfi_dram_clk_disable   ),
    .dfi_init_complete_i     ( dfi_init_complete      )
);

// ddr3_core #(
//      .DDR_WRITE_LATENCY(4)
//     ,.DDR_READ_LATENCY(4)
//     ,.DDR_MHZ(100)
// ) u_ddr_core (
//     .clk_i(clk)
//     ,.rst_i(rst)

//     // Configuration (unused)
//     ,.cfg_enable_i(1'b1)
//     ,.cfg_stb_i(1'b0)
//     ,.cfg_data_i(32'b0)
//     ,.cfg_stall_o()

//     ,.inport_wr_i(ram_wr)
//     ,.inport_rd_i(ram_rd)
//     ,.inport_addr_i(ram_addr)
//     ,.inport_write_data_i(mem_write_data)
//     ,.inport_req_id_i(ram_req_id)
//     ,.inport_accept_o(ram_accept)
//     ,.inport_ack_o(ram_ack)
//     ,.inport_error_o(ram_error)
//     ,.inport_resp_id_o(ram_resp_id)
//     ,.inport_read_data_o(ram_read_data)

//     ,.dfi_address_o(dfi_address)
//     ,.dfi_bank_o(dfi_bank)
//     ,.dfi_cas_n_o(dfi_cas_n)
//     ,.dfi_cke_o(dfi_cke)
//     ,.dfi_cs_n_o(dfi_cs_n)
//     ,.dfi_odt_o(dfi_odt)
//     ,.dfi_ras_n_o(dfi_ras_n)
//     ,.dfi_reset_n_o(dfi_reset_n)
//     ,.dfi_we_n_o(dfi_we_n)
//     ,.dfi_wrdata_o(dfi_wrdata)
//     ,.dfi_wrdata_en_o(dfi_wrdata_en)
//     ,.dfi_wrdata_mask_o(dfi_wrdata_mask)
//     ,.dfi_rddata_en_o(dfi_rddata_en)
//     ,.dfi_rddata_i(dfi_rddata)
//     ,.dfi_rddata_valid_i(dfi_rddata_valid)
//     ,.dfi_rddata_dnv_i(dfi_rddata_dnv)
// );

//-----------------------------------------------------------------
// ram_read: Perform read transfer (128-bit)
//-----------------------------------------------------------------
task mem_read;
    input  [31:0]  addr;
    output [127:0] data;
begin
    mem_rd     <= 1'b1;
    mem_addr   <= addr;
    mem_req_id <= mem_req_id + 1;
    @(posedge clk);

    while (!mem_accept)
    begin
        @(posedge clk);
    end
    mem_rd     <= 1'b0;

    while (!mem_ack)
    begin
        @(posedge clk);
    end

    data = mem_rddata;
end
endtask

//-----------------------------------------------------------------
// mem_write: Perform write transfer (128-bit)
//-----------------------------------------------------------------
task mem_write;
    input [31:0]  addr;
    input [127:0] data;
    input [15:0]  mask;
begin
    mem_wr     <= mask;
    mem_addr   <= addr;
    mem_wrdata <= data;
    // mem_req_id <= mem_req_id + 1;
    @(posedge clk);

    while (!mem_accept)
    begin
        @(posedge clk);
    end
    mem_wr <= 16'b0;

    while (!mem_ack)
    begin
        @(posedge clk);
    end
end
endtask

//-----------------------------------------------------------------
// Initialisation
//-----------------------------------------------------------------
reg [127:0] data;
initial
begin
    dfi_init_complete = 1'b0;
    #10000
        dfi_init_complete = 1'b1;
    mem_rd     = 1'b0;

    mem_write({'0, DDR_BA_W'('d0), DDR_RA_W'('d0),    DDR_CA_W'('d0)},   128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_1234_4321, 16'hFFFF);
    mem_write({'0, DDR_BA_W'('d2), DDR_RA_W'('d2),    DDR_CA_W'('d2)},   128'h1111_2222_3333_4444_5555_6666_7777_8888, 16'hFFFF);
    mem_write({'0, DDR_BA_W'('d0), DDR_RA_W'('d0),    DDR_CA_W'('d999)}, 128'h1111_2222_3333_4444_5555_6666_7777_8888, 16'hFFFF);
    mem_write({'0, DDR_BA_W'('d0), DDR_RA_W'('d1),    DDR_CA_W'('d999)}, 128'h1111_2222_3333_4444_5555_6666_7777_8888, 16'hFFFF);
    mem_write({'0, DDR_BA_W'('d2), DDR_RA_W'('d2),    DDR_CA_W'('d999)}, 128'hFFFF_1111_FFFF_1111_FFFF_1111_FFFF_1111, 16'hFFFF);
    mem_write({'0, DDR_BA_W'('d2), DDR_RA_W'('d1234), DDR_CA_W'('d999)}, 128'hFFFF_1111_FFFF_1111_FFFF_1111_FFFF_1111, 16'hFFFF);
    mem_read ({'0, DDR_BA_W'('d2), DDR_RA_W'('d2),    DDR_CA_W'('d2)}, data);
    mem_read ({'0, DDR_BA_W'('d2), DDR_RA_W'('d1234), DDR_CA_W'('d999)}, data);
    // mem_read(16000, data);



    // mem_addr   = 32'h0000_0000;
    // mem_wr     = 16'd1;
    // mem_wrdata = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111;
    // @(posedge clk);

    // while (!mem_accept)
    // begin
    //     @(posedge clk);
    // end
    // mem_wr = 16'b0;

    // while (!mem_ack)
    // begin
    //     @(posedge clk);
    // end
    
    // mem_addr   = 32'h0000_0001;
    // mem_rd     = 1'b0;
    // mem_wr     = 16'd1;
    // mem_wrdata = 128'hFFFF_EEEE_DDDD_CCCC_BBBB_AAAA_9999_8888;
    // @(posedge clk);

    // while (!mem_accept)
    // begin
    //     @(posedge clk);
    // end
    // mem_wr = 16'b0;

    // while (!mem_ack)
    // begin
    //     @(posedge clk);
    // end



    // dfi_cs_n    = '1;
    // dfi_ras_n   = '1;
    // dfi_cas_n   = '1;
    // dfi_we_n    = '1;

    // dfi_reset_n = '0;
    // dfi_cke     = '0;
    // dfi_odt     = '1;

    // dfi_address = '0;
    // dfi_bank    = '0;
    // dfi_wrdata      = '0;
    // dfi_wrdata_en   = '0;
    // dfi_wrdata_mask = '0;
    // dfi_rddata_en   = '0;
    
    // #1000 dfi_reset_n = '1;
    // #1000 dfi_cke     = '1;
    // #1000000
    //     {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_LOAD_MODE;
    //     dfi_bank    = 3'd2;
    //     dfi_address = MR2_REG;
    // #1000000
    //     {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_LOAD_MODE;
    //     dfi_bank    = 3'd3;
    //     dfi_address = MR3_REG;
    // #1000000
    //     {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_LOAD_MODE;
    //     dfi_bank    = 3'd1;
    //     dfi_address = MR1_REG;
    // #1000000
    //     {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_LOAD_MODE;
    //     dfi_bank    = 3'd0;
    //     dfi_address = MR0_REG;
    // #1000000
    //     {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_ZQCL;
    //     // dfi_bank    = 3'd0;
    //     dfi_address[10] = 1'b1;
    // #1000000
    //     {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_PRECHARGE;
    //     // dfi_bank    = 3'd0;
    //     dfi_address[10] = 1'b1;
    
    // @(posedge clk);
    // dfi_address = 14'd1;
    // dfi_bank    = 3'd0;
    // {dfi_cs_n, dfi_ras_n, dfi_cas_n, dfi_we_n} = CMD_WRITE;
    // dfi_wrdata      = 32'hABCDEFFF;
    // dfi_wrdata_en   = 1'b1;
    // dfi_wrdata_mask = '0;




    // ram_wr         = 0;
    // ram_rd         = 0;
    // ram_addr       = 0;
    // mem_write_data = 0;
    // ram_req_id     = 0;

    // @(posedge clk);
    
    // mem_write(0,  128'hffeeddccbbaa99887766554433221100, 16'hFFFF);
    // mem_write(16, 128'hbeaffeadd0d0600d5555AAAA00000000, 16'hFFFF);
    // mem_write(32, 128'hffffffff111111112222222233333333, 16'hFFFF);

    // ram_read(0, data);
    // if (data != 128'hffeeddccbbaa99887766554433221100)
    // begin
    //     $fatal(1, "ERROR: Data mismatch!");
    // end

    // ram_read(16, data);
    // if (data != 128'hbeaffeadd0d0600d5555AAAA00000000)
    // begin
    //     $fatal(1, "ERROR: Data mismatch!");
    // end

    // ram_read(32, data);
    // if (data != 128'hffffffff111111112222222233333333)
    // begin
    //     $fatal(1, "ERROR: Data mismatch!");
    // end
    
    // #100000
    @(posedge clk);   
    $finish;

end

endmodule