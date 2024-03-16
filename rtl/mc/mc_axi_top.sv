/*
 * @Design: mc_axi_top
 * @Author: Zhao Siwei 
 * @Email:  cheems@foxmail.com
 * @Date:   2024-1-7
 * @Description: AXI interface top module of mc
 */
`include "../config/mc_defines.svh"

module mc_axi_top #(
  parameter AXI_ID_WIDTH   = 4,
  parameter AXI_ADDR_WIDTH = 32,
  parameter AXI_DATA_WIDTH = 32,
  parameter REQ_BUF_DEPTH  = 4
) (
  input  logic                        clk_i,
  input  logic                        rst_n_i,

  // AXI Interface
  input  logic                        axi_awvalid_i,
  input  logic [AXI_ID_WIDTH-1:0]     axi_awid_i,
  input  logic [AXI_ADDR_WIDTH-1:0]   axi_awaddr_i,
  input  logic [2:0]                  axi_awsize_i,
  input  logic [7:0]                  axi_awlen_i,
  input  logic [1:0]                  axi_awburst_i,
  output logic                        axi_awready_o,

  input  logic                        axi_wvalid_i,
  input  logic [AXI_DATA_WIDTH-1:0]   axi_wdata_i,
  input  logic [AXI_DATA_WIDTH/8-1:0] axi_wstrb_i,
  input  logic                        axi_wlast_i,
  output logic                        axi_wready_o,

  output logic                        axi_bvalid_o,
  output logic [AXI_ID_WIDTH-1:0]     axi_bid_o,
  output logic [1:0]                  axi_bresp_o,
  input  logic                        axi_bready_i,

  input  logic                        axi_arvalid_i,
  input  logic [AXI_ID_WIDTH-1:0]     axi_arid_i,
  input  logic [AXI_ADDR_WIDTH-1:0]   axi_araddr_i,
  input  logic [2:0]                  axi_arsize_i,
  input  logic [7:0]                  axi_arlen_i,
  input  logic [1:0]                  axi_arburst_i,
  output logic                        axi_arready_o,

  output logic                        axi_rvalid_o,
  output logic [AXI_ID_WIDTH-1:0]     axi_rid_o,
  output logic [AXI_DATA_WIDTH-1:0]   axi_rdata_o,
  output logic [1:0]                  axi_rresp_o,
  output logic                        axi_rlast_o,
  input  logic                        axi_rready_i,

  // DFI Interface
  output logic [DDR_RA_W    -1:0]     dfi_address_o,
  output logic [DDR_BA_W    -1:0]     dfi_bank_o,
  output logic                        dfi_cs_n_o,
  output logic                        dfi_ras_n_o,
  output logic                        dfi_cas_n_o,
  output logic                        dfi_we_n_o,

  output logic                        dfi_cke_o,
  output logic                        dfi_reset_n_o,
  output logic                        dfi_odt_o,

  output logic                        dfi_wrdata_en_o,
  output logic [DFI_DATA_W/8-1:0]     dfi_wrdata_mask_o,
  output logic [DFI_DATA_W  -1:0]     dfi_wrdata_o,

  output logic                        dfi_rddata_en_o,
  input  logic                        dfi_rddata_valid_i,
  input  logic [DFI_DATA_W  -1:0]     dfi_rddata_i,

  output logic                        dfi_init_start_o,
  input  logic                        dfi_init_complete_i,
  output logic                        dfi_dram_clk_disable_o
);
  // ---------------------------------------------------------------------------
  // Restriction Check
  // ---------------------------------------------------------------------------
  always @(posedge clk_i) begin
    if (axi_awvalid_i & (axi_awburst_i != 2'b01) & (axi_awburst_i != 2'b00)) begin
      $display("ERROR: only support INCR burst type");
      $finish;
    end
    if (axi_awvalid_i & (axi_arburst_i != 2'b01) & (axi_arburst_i != 2'b00)) begin
      $display("ERROR: only support INCR burst type");
      $finish;
    end
    if (axi_awvalid_i & (axi_awaddr_i[2:0] != 3'b0)) begin
      $display("ERROR: only support 8-byte aligned address");
      $finish;
    end
    if (axi_awvalid_i & (axi_araddr_i[2:0] != 3'b0)) begin
      $display("ERROR: only support 8-byte aligned address");
      $finish;
    end
  end

  // ---------------------------------------------------------------------------
  // DDR Controller Interface
  // ---------------------------------------------------------------------------
  logic [MEM_MASK_W  -1:0]  mc_mem_wr_w;
  logic                     mc_mem_rd_w;
  logic [MEM_ADDR_W  -1:0]  mc_mem_addr_w;
  logic [MEM_DATA_W  -1:0]  mc_mem_wrdata_w;
  logic [MEM_DATA_W  -1:0]  mc_mem_rddata_w;
  logic                     mc_mem_accept_w;
  logic                     mc_mem_ack_w;

  // ---------------------------------------------------------------------------
  // Control FSM
  // ---------------------------------------------------------------------------
  localparam STATE_IDLE       = 3'b000;
  localparam STATE_AW_ACCEPT  = 3'b001;
  localparam STATE_W_ACCEPT   = 3'b011;
  localparam STATE_AWW_ACCEPT = 3'b010;
  localparam STATE_R_ACCEPT   = 3'b110;
  localparam STATE_R_READING  = 3'b111;

  logic [2:0] state_d, state_q;
  
  always @(*) begin
    case (state_q)
      STATE_IDLE: begin
        if (axi_awvalid_i & axi_awready_o)
          state_d = STATE_AW_ACCEPT;
        else if (axi_wvalid_i & axi_wready_o & axi_wlast_i)
          state_d = STATE_W_ACCEPT;
        else if (axi_arvalid_i & axi_arready_o)
          state_d = STATE_R_ACCEPT;
        else
          state_d = STATE_IDLE;
      end
      STATE_AW_ACCEPT: begin
        if (axi_wvalid_i & axi_wready_o & axi_wlast_i)
          state_d = STATE_AWW_ACCEPT;
        else
          state_d = STATE_AW_ACCEPT;
      end
      STATE_W_ACCEPT: begin
        if (axi_awvalid_i & axi_awready_o)
          state_d = STATE_AWW_ACCEPT;
        else
          state_d = STATE_W_ACCEPT;
      end
      STATE_AWW_ACCEPT: begin
        if (axi_bvalid_o & axi_bready_i)
          state_d = STATE_IDLE;
        else
          state_d = STATE_AWW_ACCEPT;
      end
      STATE_R_ACCEPT: begin
        if (mc_mem_accept_w)
          state_d = STATE_R_READING;
        else
          state_d = STATE_R_ACCEPT;
      end
      STATE_R_READING: begin
        if (axi_rvalid_o & axi_rready_i & axi_rlast_o)
          state_d = STATE_IDLE;
        else
          state_d = STATE_R_READING;
      end
      default:
          state_d = STATE_IDLE;
    endcase
  end
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      state_q <= STATE_IDLE;
    else
      state_q <= state_d;
  end

  // ---------------------------------------------------------------------------
  // AXI AW Channel Buffer
  // ---------------------------------------------------------------------------
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      axi_awready_o <= 1'b1;
    else if ((state_q != STATE_IDLE) & (state_q != STATE_W_ACCEPT))
      axi_awready_o <= 1'b0;
    else if (axi_awvalid_i & axi_awready_o)
      axi_awready_o <= 1'b0;
    else if (mc_mem_ack_w)
      axi_awready_o <= 1'b1;
  end

  logic [AXI_ID_WIDTH-1:0]     axi_awid_r;
  logic [AXI_ADDR_WIDTH-1:0]   axi_awaddr_r;
  logic [2:0]                  axi_awsize_r;
  logic [7:0]                  axi_awlen_r;
  logic [1:0]                  axi_awburst_r;

  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      axi_awid_r    <= '0;
      axi_awaddr_r  <= '0;
      axi_awsize_r  <= '0;
      axi_awlen_r   <= '0;
      axi_awburst_r <= '0;
    end else if (((state_q == STATE_IDLE) | (state_q == STATE_W_ACCEPT)) & axi_awvalid_i & axi_awready_o) begin
      axi_awid_r    <= axi_awid_i;
      axi_awaddr_r  <= axi_awaddr_i;
      axi_awsize_r  <= axi_awsize_i;
      axi_awlen_r   <= axi_awlen_i;
      axi_awburst_r <= axi_awburst_i;
    end else if ((state_q == STATE_AWW_ACCEPT) & mc_mem_accept_w) begin
      axi_awid_r    <= '0;
      axi_awaddr_r  <= '0;
      axi_awsize_r  <= '0;
      axi_awlen_r   <= '0;
      axi_awburst_r <= '0;
    end
  end
  
  // logic [7:0] awsize_byte_w;

  // always @ (*) begin
  //   case(axi_awsize_r)
  //       3'b000:  awsize_byte_w = 8'd1;
  //       3'b001:  awsize_byte_w = 8'd2;
  //       3'b010:  awsize_byte_w = 8'd4;
  //       3'b011:  awsize_byte_w = 8'd8;
  //       3'b100:  awsize_byte_w = 8'd16;
  //       3'b101:  awsize_byte_w = 8'd32;
  //       3'b110:  awsize_byte_w = 8'd64;
  //       3'b111:  awsize_byte_w = 8'd128;
  //       default: awsize_byte_w = 8'dx;
  //   endcase
  // end

  // ---------------------------------------------------------------------------
  // AXI W Channel Buffer
  // ---------------------------------------------------------------------------
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      axi_wready_o <= 1'b1;
    else if ((state_q != STATE_IDLE) & (state_q != STATE_AW_ACCEPT))
      axi_wready_o <= 1'b0;
    else if (axi_wvalid_i & axi_wready_o & axi_wlast_i)
      axi_wready_o <= 1'b0;
    else if (mc_mem_ack_w)
      axi_wready_o <= 1'b1;
  end
  
  logic [MEM_DATA_W-1:0] axi_wdata_r;
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      axi_wdata_r <= '0;
    end else if (((state_q == STATE_IDLE) | (state_q == STATE_AW_ACCEPT)) & axi_wvalid_i & axi_wready_o) begin
      axi_wdata_r <= {axi_wdata_i, axi_wdata_r[MEM_DATA_W-1:AXI_DATA_WIDTH]};
    end
  end

  // ---------------------------------------------------------------------------
  // AXI B Channel Buffer
  // ---------------------------------------------------------------------------
  assign axi_bid_o = axi_awid_r;

  always@(posedge clk_i or negedge rst_n_i)begin
    if(!rst_n_i)
      axi_bresp_o <= 2'b00; // OKAY
  end

  always@(posedge clk_i or negedge rst_n_i)begin
    if(!rst_n_i)
      axi_bvalid_o <= 1'b0;
    else if ((state_q == STATE_R_ACCEPT) | (state_q == STATE_R_READING))
      axi_bvalid_o <= 1'b0;
    else if(((state_q == STATE_AW_ACCEPT) & axi_wvalid_i & axi_wready_o & axi_wlast_i) | ((state_q == STATE_W_ACCEPT) & axi_awvalid_i & axi_awready_o))
      axi_bvalid_o <= 1'b1;
    else if(axi_bvalid_o & axi_bready_i)
      axi_bvalid_o <= 1'b0;
  end

  // ---------------------------------------------------------------------------
  // AXI AR Channel Buffer
  // ---------------------------------------------------------------------------
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      axi_arready_o <= 1'b1;
    else if ((state_q == STATE_AW_ACCEPT) | (state_q == STATE_W_ACCEPT) | (state_q == STATE_AWW_ACCEPT)) 
      axi_arready_o <= 1'b0;
    else if (axi_arvalid_i & axi_arready_o)
      axi_arready_o <= 1'b0;
    else if (mc_mem_ack_w)
    // else if (axi_rvalid_o & axi_rready_i & axi_rlast_o)
      axi_arready_o <= 1'b1;
  end

  logic [AXI_ID_WIDTH-1:0]     axi_arid_r;
  logic [AXI_ADDR_WIDTH-1:0]   axi_araddr_r;
  logic [2:0]                  axi_arsize_r;
  logic [7:0]                  axi_arlen_r;
  logic [1:0]                  axi_arburst_r;

  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      axi_arid_r    <= '0;
      axi_araddr_r  <= '0;
      axi_arsize_r  <= '0;
      axi_arlen_r   <= '0;
      axi_arburst_r <= '0;
    end else if ((state_q == STATE_IDLE) & axi_arvalid_i & axi_arready_o) begin
      axi_arid_r    <= axi_arid_i;
      axi_araddr_r  <= axi_araddr_i;
      axi_arsize_r  <= axi_arsize_i;
      axi_arlen_r   <= axi_arlen_i;
      axi_arburst_r <= axi_arburst_i;
    end else if (state_q == STATE_R_READING) begin
      axi_arid_r    <= '0;
      axi_araddr_r  <= '0;
      axi_arsize_r  <= '0;
      axi_arlen_r   <= '0;
      axi_arburst_r <= '0;
    end
  end
  
  // ---------------------------------------------------------------------------
  // AXI R Channel Buffer
  // ---------------------------------------------------------------------------
  logic [MEM_DATA_W-1:0] mc_mem_rdata_r;
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      mc_mem_rdata_r <= '0;
    else if (mc_mem_ack_w)
      mc_mem_rdata_r <= mc_mem_rddata_w;
  end
  
  logic [2:0] axi_rdata_state_q, axi_rdata_state_d;
  
  localparam AXI_RDATA_IDLE = 3'b000;
  localparam AXI_RDATA_1    = 3'b001;
  localparam AXI_RDATA_2    = 3'b011;
  localparam AXI_RDATA_3    = 3'b010;
  localparam AXI_RDATA_4    = 3'b110;
  
  always @(*) begin
    case (axi_rdata_state_q)
      AXI_RDATA_IDLE: begin
        if ((state_q == STATE_R_READING) & mc_mem_ack_w)
          axi_rdata_state_d = AXI_RDATA_1;
        else
          axi_rdata_state_d = AXI_RDATA_IDLE;
      end
      AXI_RDATA_1: begin
        if (axi_rvalid_o & axi_rready_i)
          axi_rdata_state_d = AXI_RDATA_2;
        else
          axi_rdata_state_d = AXI_RDATA_1;
      end
      AXI_RDATA_2: begin
        if (axi_rvalid_o & axi_rready_i)
          axi_rdata_state_d = AXI_RDATA_3;
        else
          axi_rdata_state_d = AXI_RDATA_2;
      end
      AXI_RDATA_3: begin
        if (axi_rvalid_o & axi_rready_i)
          axi_rdata_state_d = AXI_RDATA_4;
        else
          axi_rdata_state_d = AXI_RDATA_3;
      end
      AXI_RDATA_4: begin
        if (axi_rvalid_o & axi_rready_i)
          axi_rdata_state_d = AXI_RDATA_IDLE;
        else
          axi_rdata_state_d = AXI_RDATA_4;
      end
      default:
        axi_rdata_state_d = AXI_RDATA_IDLE;
    endcase
  end

  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      axi_rdata_state_q <= AXI_RDATA_IDLE;
    else
      axi_rdata_state_q <= axi_rdata_state_d;
  end
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      axi_rvalid_o <= 1'b0;
    else if (state_q != STATE_R_READING)
      axi_rvalid_o <= 1'b0;
    else if (axi_rvalid_o & axi_rready_i & axi_rlast_o)
      axi_rvalid_o <= 1'b0;
    else if ((axi_rdata_state_q == AXI_RDATA_1) | (axi_rdata_state_q == AXI_RDATA_2) | (axi_rdata_state_q == AXI_RDATA_3) | (axi_rdata_state_q == AXI_RDATA_4))
      axi_rvalid_o <= 1'b1;
  end

  always @ (*) begin
    if (axi_rdata_state_q == AXI_RDATA_1)
      axi_rdata_o = mc_mem_rdata_r[MEM_DATA_W-96-1:MEM_DATA_W-128];
    else if (axi_rdata_state_q == AXI_RDATA_2)
      axi_rdata_o = mc_mem_rdata_r[MEM_DATA_W-64-1:MEM_DATA_W-96];
    else if (axi_rdata_state_q == AXI_RDATA_3)
      axi_rdata_o = mc_mem_rdata_r[MEM_DATA_W-32-1:MEM_DATA_W-64];
    else if (axi_rdata_state_q == AXI_RDATA_4)
      axi_rdata_o = mc_mem_rdata_r[MEM_DATA_W-1:MEM_DATA_W-32];
    else
      axi_rdata_o = '0;
  end

  assign axi_rlast_o = axi_rdata_state_q == AXI_RDATA_4;

  assign axi_rid_o = axi_arid_r;

  always @(posedge clk_i or negedge rst_n_i)begin
    if(!rst_n_i)
      axi_rresp_o <= 2'b00; // OKAY
  end

  // ---------------------------------------------------------------------------
  // Write/Read Operation
  // ---------------------------------------------------------------------------
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      mc_mem_wr_w     <= '0;
      mc_mem_rd_w     <= '0;
      mc_mem_addr_w   <= '0;
      mc_mem_wrdata_w <= '0;
    end else if (state_q == STATE_AWW_ACCEPT) begin
      mc_mem_wr_w     <= '1;
      mc_mem_rd_w     <= '0;
      mc_mem_addr_w   <= axi_awaddr_r;
      mc_mem_wrdata_w <= axi_wdata_r;
    end else if (state_q == STATE_R_ACCEPT) begin
      if (mc_mem_accept_w) begin
        mc_mem_wr_w     <= '0;
        mc_mem_rd_w     <= '0;
        mc_mem_addr_w   <= '0;
        mc_mem_wrdata_w <= '0;
      end else begin
        mc_mem_wr_w     <= '0;
        mc_mem_rd_w     <= '1;
        mc_mem_addr_w   <= axi_araddr_r;
        mc_mem_wrdata_w <= '0;
      end
    end else if (mc_mem_ack_w | (state_q == STATE_R_READING))begin
      mc_mem_wr_w     <= '0;
      mc_mem_rd_w     <= '0;
      mc_mem_addr_w   <= '0;
      mc_mem_wrdata_w <= '0;
    end
  end

  // ---------------------------------------------------------------------------
  // DDR Controller
  // ---------------------------------------------------------------------------
  mc_top  u_mc_top (
    .clk_i                  ( clk_i                  ),
    .rst_n_i                ( rst_n_i                ),

    .mem_wr_i               ( mc_mem_wr_w            ),
    .mem_rd_i               ( mc_mem_rd_w            ),
    .mem_addr_i             ( mc_mem_addr_w          ),
    .mem_wrdata_i           ( mc_mem_wrdata_w        ),
    .mem_rddata_o           ( mc_mem_rddata_w        ),
    .mem_accept_o           ( mc_mem_accept_w        ),
    .mem_ack_o              ( mc_mem_ack_w           ),

    .dfi_address_o          ( dfi_address_o          ),
    .dfi_bank_o             ( dfi_bank_o             ),
    .dfi_cs_n_o             ( dfi_cs_n_o             ),
    .dfi_ras_n_o            ( dfi_ras_n_o            ),
    .dfi_cas_n_o            ( dfi_cas_n_o            ),
    .dfi_we_n_o             ( dfi_we_n_o             ),
    .dfi_cke_o              ( dfi_cke_o              ),
    .dfi_reset_n_o          ( dfi_reset_n_o          ),
    .dfi_odt_o              ( dfi_odt_o              ),
    .dfi_wrdata_en_o        ( dfi_wrdata_en_o        ),
    .dfi_wrdata_mask_o      ( dfi_wrdata_mask_o      ),
    .dfi_wrdata_o           ( dfi_wrdata_o           ),
    .dfi_rddata_en_o        ( dfi_rddata_en_o        ),
    .dfi_rddata_valid_i     ( dfi_rddata_valid_i     ),
    .dfi_rddata_i           ( dfi_rddata_i           ),
    .dfi_init_start_o       ( dfi_init_start_o       ),
    .dfi_init_complete_i    ( dfi_init_complete_i    ),
    .dfi_dram_clk_disable_o ( dfi_dram_clk_disable_o )
  );
  
endmodule
