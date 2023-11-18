/*
 * @Design: mc_top
 * @Author: Zhao Siwei 
 * @Email:  cheems@foxmail.com
 * @Date:   2023-10-31
 * @Description: Top module of ddr controller
 */

module mc_top #(
  localparam DDR_CORE_FREQ_MHZ  = 100,
  localparam DDR_IO_FREQ_MHZ    = 4*DDR_CORE_FREQ_MHZ, // 8n-prefetch
  localparam DDR_PHY_FREQ_MHZ   = 4*DDR_CORE_FREQ_MHZ, // 8n-prefetch
  localparam DDR_MC_FREQ_MHZ    = 400,
  localparam DDR_FREQ_MHZ = 100,  // 100 MHz
  localparam DDR_DQ_W     = 16,   // DQ width
  localparam DDR_BA_W     = 3,    // bank address
  localparam DDR_RA_W     = 15,   // row  address 14?
  localparam DDR_CA_W     = 10,   // col  address
  localparam DDR_ADDR_W   = DDR_RA_W,
  localparam DDR_BL       = 8,    // burst length
  localparam DFI_DATA_W   = 32,
  localparam MEM_ADDR_W   = 32,
  localparam MEM_DATA_W   = DDR_DQ_W*DDR_BL,
  localparam MEM_MASK_W   = MEM_DATA_W/8
) (
  input                     clk_i,
  input                     rst_n_i,

  // memory interface
  input  [MEM_ADDR_W  -1:0] mem_addr_i,
  input  [MEM_MASK_W  -1:0] mem_wr_i,
  input                     mem_rd_i,
  input  [MEM_DATA_W  -1:0] mem_wrdata_i,
  output [MEM_DATA_W  -1:0] mem_rddata_o,
  output                    mem_accept_o,
  output                    mem_ack_o,

  // dfi interface
  output [DDR_RA_W    -1:0] dfi_address_o,
  output [DDR_BA_W    -1:0] dfi_bank_o,
  output                    dfi_cs_n_o,
  output                    dfi_ras_n_o,
  output                    dfi_cas_n_o,
  output                    dfi_we_n_o,
  output                    dfi_cke_o,
  output                    dfi_reset_n_o,
  output                    dfi_odt_o,

  output [DFI_DATA_W  -1:0] dfi_wrdata_o,
  output                    dfi_wrdata_en_o,
  output [DFI_DATA_W/8-1:0] dfi_wrdata_mask_o,

  output                    dfi_rddata_en_o,
  input  [DFI_DATA_W  -1:0] dfi_rddata_i,
  input                     dfi_rddata_valid_i,

  output                    dfi_init_start_o,
  input                     dfi_init_complete_i,
  output                    dfi_dram_clk_disable_o
);
  // ---------------------------------------------------------------------------
  // Parameters & Defines
  // ---------------------------------------------------------------------------
  // Command Encode
  localparam CMD_MRS      = 4'b0000; // 0
  localparam CMD_REF      = 4'b0001; // 1
  localparam CMD_PRE      = 4'b0010; // 2
  localparam CMD_ACT      = 4'b0011; // 3
  localparam CMD_WRITE    = 4'b0100; // 4
  localparam CMD_READ     = 4'b0101; // 5
  localparam CMD_ZQCL     = 4'b0110; // 6
  localparam CMD_NOP      = 4'b0111; // 7
  // FSM Encode
  localparam STATE_INIT   = 4'd0;
  localparam STATE_REF    = 4'd1;
  localparam STATE_PRE    = 4'd2;
  localparam STATE_ACT    = 4'd3;
  localparam STATE_WRITE  = 4'd4;
  localparam STATE_READ   = 4'd5;
  localparam STATE_IDLE   = 4'd7;
  // Mode Configuration
  // - DLL disabled (low speed only)
  // - CL=6
  // - AL=0
  // - CWL=6
  localparam MRS_MR0_BL = 2'b00; // Fixed BL8
  localparam MRS_MR0_BT = 1'b0;   // Sequential
  localparam MRS_MR0  = 15'h0120;
  localparam MRS_MR1  = 15'h0001;
  localparam MRS_MR2  = 15'h0008;
  localparam MRS_MR3  = 15'h0000;
  // DDR Timing
  localparam CYCLE_TIME_NS  = 1000 / DDR_FREQ_MHZ;

  localparam DDR_AL_C       = 0;
  localparam DDR_CWL_C      = 6;
  localparam DDR_WL_C       = DDR_AL_C + DDR_CWL_C;
  localparam DDR_CL_C       = 6;
  localparam DDR_RL_C       = DDR_AL_C + DDR_CL_C;
  // localparam DDR_RL_C       = 5;
  // localparam DDR_BL       = 8;
  
  localparam DDR_TXPR_C     = 5;                    // 5 cycles
  localparam DDR_TMRD_C     = 4;                    // 4 cycles
  localparam DDR_TMOD_C     = 12;                   // 12 cycles
  localparam DDR_TZQINIT_C  = 512;                  // 512 cycles
  localparam DDR_TRP_C      = 15  / CYCLE_TIME_NS;  // 15 ns
  localparam DDR_TRFC_C     = 260 / CYCLE_TIME_NS;  // 260 ns
  localparam DDR_TRCD_C     = 15  / CYCLE_TIME_NS;  // 15 ns
  localparam DDR_TWTR_C     = 4;                    // 4 cycles
  localparam DDR_TCCD_C     = 4;                    // 4 cycles
  // localparam DDR_TRP_C    = (15 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
  // localparam DDR_TRFC_C   = (260 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
  // localparam DDR_TRCD_C   = (15 + (CYCLE_TIME_NS-1)) / CYCLE_TIME_NS;
  // localparam DDR_TWTR_C   = 5 + 1;

  // Standard R/W -> W->R (non-sequential)
  localparam DDR_WTR_C = DDR_WL_C + DDR_BL + DDR_TWTR_C;
  localparam DDR_WTW_C = DDR_TCCD_C;
  localparam DDR_RW_NONSEQ_C = DDR_WL_C + DDR_BL + DDR_TWTR_C;
  localparam DDR_RW_SEQ_C    = DDR_RW_NONSEQ_C + 1 - DDR_BL;
  // localparam DDR_RW_SEQ_C    = DDR_RW_NONSEQ_C + 1 - DDR_BL;

  // DDR Init: 700us + tXPR + (15?) + 3*tMRD + tMOD + tZQinit + tRP
  localparam DDR_INIT_C     = 700000/CYCLE_TIME_NS + DDR_TXPR_C + 15 + 3*DDR_TMRD_C
                                  + DDR_TMOD_C + DDR_TZQINIT_C + DDR_TRP_C;
  localparam INIT_TIME_RST      = DDR_INIT_C - 200000 / CYCLE_TIME_NS;  // 200us
  localparam INIT_TIME_CKE      = INIT_TIME_RST - 500000 / CYCLE_TIME_NS;   // 500us
  localparam INIT_TIME_MRS      = INIT_TIME_CKE - DDR_TXPR_C - 15; // ?
  localparam INIT_TIME_ZQCL     = INIT_TIME_MRS - 3*DDR_TMRD_C - DDR_TMOD_C;
  localparam INIT_TIME_PRE      = INIT_TIME_ZQCL - DDR_TZQINIT_C;

  // PHY Timing
  localparam TPHY_WRLAT_C = 3;
  localparam TRDDATA_EN_C = 4;
  localparam TPHY_RDLAT_C = 4;
  // localparam TPHY_WRLAT_C        = DDR_WL_C-1;
  // localparam TPHY_RDLAT_C        = DDR_RL_C-1;
  
  // Refresh Timer
  localparam DDR_REF_C  = (64000000/(2**DDR_RA_W)) / CYCLE_TIME_NS; // refresh per 64ms/RA
  // localparam DDR_REF_C = (64000*DDR_FREQ_MHZ) / 8192;
  localparam REF_TIMER_W    = 15;
  
  localparam ADDR_BIT_ALLBANK = 10;
  localparam ADDR_BIT_AUTOPRE = 10;

  // ---------------------------------------------------------------------------
  // Input Process
  // ---------------------------------------------------------------------------
  // Address Decode
  // BRC: | bank | row  | col  |
  wire [DDR_BA_W-1:0] addr_bank_w = mem_addr_i[DDR_BA_W+DDR_RA_W+DDR_CA_W-1:DDR_RA_W+DDR_CA_W];
  wire [DDR_RA_W-1:0] addr_row_w  = mem_addr_i[DDR_RA_W+DDR_CA_W-1:DDR_CA_W];
  wire [DDR_CA_W-1:0] addr_col_w  = mem_addr_i[DDR_CA_W-1:0];
  // // RBC: | row  | bank | col  |
  // wire [DDR_RA_W-1:0] addr_row_w  = mem_addr_i[DDR_RA_W+DDR_BA_W+DDR_CA_W-1:DDR_BA_W+DDR_CA_W];
  // wire [DDR_BA_W-1:0] addr_bank_w = mem_addr_i[DDR_BA_W+DDR_CA_W-1:DDR_CA_W];
  // wire [DDR_CA_W-1:0] addr_col_w  = mem_addr_i[DDR_CA_W-1:0];

  // Read & Write Request
  wire mem_req_rd_w =   mem_rd_i;
  wire mem_req_wr_w = | mem_wr_i;
  wire mem_req_w    = mem_req_rd_w | mem_req_wr_w;
  
  
  // ---------------------------------------------------------------------------
  // FSM State
  // ---------------------------------------------------------------------------
  reg [3:0] next_state_d,   state_q;
  reg [3:0] target_state_d, target_state_q;

  reg  refresh_req_q;
  wire cmd_accept_w;

  reg [2**DDR_BA_W-1:0] bank_has_openrow_q;
  reg [DDR_RA_W-1:0   ] addr_openrow_q [2**DDR_BA_W-1:0];

  always @(*) begin
    next_state_d    = state_q;
    target_state_d  = target_state_q;

    case (state_q)
      STATE_INIT: begin
        // wait the first REFRESH after init done
        if (refresh_req_q)
          next_state_d = STATE_IDLE;
      end

      STATE_IDLE: begin
        // Refresh
        if (refresh_req_q) begin
          if (|bank_has_openrow_q) begin
            // precharge the row, then refresh
            next_state_d   = STATE_PRE;
            target_state_d = STATE_REF;
          end else begin
            // directly refresh
            next_state_d   = STATE_REF;
          end
        // Read/Write
        end else if (mem_req_w) begin
          if (bank_has_openrow_q[addr_bank_w] & (addr_openrow_q[addr_bank_w] == addr_row_w)) begin
            // PFH (Page Fast Hit): READ/WRITE
            if (mem_req_rd_w)
              next_state_d   = STATE_READ;
            else
              next_state_d   = STATE_WRITE;
          end else if (bank_has_openrow_q[addr_bank_w]) begin
            // PM (Page Miss): PRE -> ACT -> READ/WRITE
              next_state_d   = STATE_PRE;
            if (mem_req_rd_w)
              target_state_d   = STATE_READ;
            else
              target_state_d   = STATE_WRITE;
          end else begin
            // PH (Page Hit): ACT -> READ/WRITE
              next_state_d   = STATE_ACT;
            if (mem_req_rd_w)
              target_state_d   = STATE_READ;
            else
              target_state_d   = STATE_WRITE;
          end
        // None
        end else begin
          next_state_d = STATE_IDLE;
        end
      end
      
      STATE_PRE: begin
        if (target_state_q == STATE_REF)
          // precharge the row, then refresh
          next_state_d = STATE_REF;
        else
          // precharge the row, then activate
          next_state_d = STATE_ACT;
      end
      
      STATE_ACT: begin
        // activate the row, then read/write
        next_state_d = target_state_q;
      end
      
      STATE_READ: begin
        next_state_d = STATE_IDLE;
      end
      
      STATE_WRITE: begin
        next_state_d = STATE_IDLE;
      end

      STATE_REF: begin
        next_state_d = STATE_IDLE;
      end
      default: ;
    endcase
  end

  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      state_q         <= STATE_INIT;
      target_state_q  <= STATE_IDLE;
    end else if (cmd_accept_w) begin
      // update state only when cmd accepted
      state_q         <= next_state_d;
      target_state_q  <= target_state_d;
    end else begin
      state_q         <= state_q;
      target_state_q  <= target_state_q;
    end
  end
  
  // ---------------------------------------------------------------------------
  // Bank & Row State
  // ---------------------------------------------------------------------------
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      bank_has_openrow_q <= '0;
      for (integer bank_idx = 0; bank_idx < 2**DDR_BA_W; bank_idx = bank_idx + 1)
        addr_openrow_q[bank_idx] <= '0;
    end else begin
      bank_has_openrow_q <= bank_has_openrow_q;
      for (integer bank_idx = 0; bank_idx < 2**DDR_BA_W; bank_idx = bank_idx + 1)
        addr_openrow_q[bank_idx] <= addr_openrow_q[bank_idx];

      case (state_q)
        STATE_ACT: begin
          // specific bank's row is activated
          bank_has_openrow_q[addr_bank_w] <= 1'b1;
          addr_openrow_q    [addr_bank_w] <= addr_row_w;
        end
        STATE_PRE: begin
          if (target_state_q == STATE_REF) begin
            // all banks are precharged
            bank_has_openrow_q              <= '0;
          end else begin
            // specific bank is precharged
            bank_has_openrow_q[addr_bank_w] <= '0;
          end
        end
        default: ;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Refresh Timer
  // ---------------------------------------------------------------------------
  reg [REF_TIMER_W-1:0] refresh_timer_q;
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      refresh_timer_q <= DDR_INIT_C;  // ddr init
    else if (~dfi_init_complete_i)
      refresh_timer_q <= DDR_INIT_C;  // hold when phy init
    else if (refresh_timer_q == '0)
      refresh_timer_q <= DDR_REF_C;   // normal refresh
    else
      refresh_timer_q <= refresh_timer_q - 1;
  end
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      refresh_req_q <= 1'b0;
    else if (refresh_timer_q == '0) // generate refresh request
      refresh_req_q <= 1'b1;
    else if (state_q == STATE_REF)  // refresh request accepted
      refresh_req_q <= 1'b0;
    else
      refresh_req_q <= refresh_req_q;
  end

  // ---------------------------------------------------------------------------
  // Command Generate
  // ---------------------------------------------------------------------------
  reg [3:0           ] cmd_d,   cmd_q;
  reg [DDR_BA_W-1:0  ] bank_d,  bank_q;
  reg [DDR_RA_W-1:0  ] addr_d,  addr_q;
  reg                  cke_d,   cke_q;
  reg                  reset_n_d, reset_n_q;
  
  always @(*) begin
    cmd_d     = CMD_NOP;
    bank_d    = '0;
    addr_d    = '0;
    cke_d     = 1'b1;
    reset_n_d = 1'b1;

    case (state_q)
      STATE_INIT: begin
        if (refresh_timer_q > INIT_TIME_RST) begin
          reset_n_d = 1'b0;   // reset
          cke_d     = 1'b0;
        end else if (refresh_timer_q > INIT_TIME_CKE) begin
          reset_n_d = 1'b1;
          cke_d     = 1'b0;   // cke
        end else if (refresh_timer_q == INIT_TIME_MRS) begin
          cmd_d   = CMD_MRS;
          bank_d  = 3'd2;     // MR2
          addr_d  = MRS_MR2;
        end else if (refresh_timer_q == INIT_TIME_MRS - DDR_TMRD_C) begin
          cmd_d   = CMD_MRS;
          bank_d  = 3'd3;     // MR3
          addr_d  = MRS_MR3;
        end else if (refresh_timer_q == INIT_TIME_MRS - 2*DDR_TMRD_C) begin
          cmd_d   = CMD_MRS;
          bank_d  = 3'd1;     // MR1
          addr_d  = MRS_MR1;
        end else if (refresh_timer_q == INIT_TIME_MRS - 3*DDR_TMRD_C) begin
          cmd_d   = CMD_MRS;
          bank_d  = 3'd0;     // MR0
          addr_d  = MRS_MR0;
        end else if (refresh_timer_q == INIT_TIME_ZQCL) begin
          cmd_d   = CMD_ZQCL; // ZQCL
          addr_d[ADDR_BIT_ALLBANK]  = 1'b1;
        end else if (refresh_timer_q == INIT_TIME_PRE) begin
          cmd_d   = CMD_PRE;  // precharge all banks
          addr_d[ADDR_BIT_ALLBANK]  = 1'b1;
        end
      end
      
      STATE_PRE: begin
        cmd_d  = CMD_PRE;
        if (target_state_q == STATE_REF) begin
          // precharge all banks
          addr_d[ADDR_BIT_ALLBANK] = 1'b1;
        end else begin
          // precharge specific bank
          addr_d[ADDR_BIT_ALLBANK] = 1'b0;
          bank_d     = addr_bank_w;
        end
      end
      
      STATE_ACT: begin
        cmd_d   = CMD_ACT;
        bank_d  = addr_bank_w;
        addr_d  = addr_row_w;
      end

      STATE_READ: begin
        cmd_d   = CMD_READ;
        bank_d  = addr_bank_w;
        // RA = 15, CA = 10
        addr_d[9:0]               = addr_col_w[9:0];
        addr_d[ADDR_BIT_AUTOPRE]  = 1'b0;  // disable auto-precharge
        addr_d[11]                = 1'b0; // CA[11]
        addr_d[12]                = 1'b1; // BL = 8
        addr_d[14:13]             = '0;// RFU
      end
      
      STATE_WRITE: begin
        cmd_d   = CMD_WRITE;
        bank_d  = addr_bank_w;
        // RA = 15, CA = 10
        addr_d[9:0]               = addr_col_w[9:0];
        addr_d[ADDR_BIT_AUTOPRE]  = 1'b0;  // disable auto-precharge
        addr_d[11]                = 1'b0; // CA[11]
        addr_d[12]                = 1'b1; // BL = 8
        addr_d[14:13]             = '0;// RFU
      end

      STATE_REF: begin
        cmd_d   = CMD_REF;
        // REF doesn't need address
      end
      default: ;
    endcase
  end
  
  // send command only when last command accepted
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      cmd_q   <= CMD_NOP;
      bank_q  <= '0;
      addr_q  <= '0;
    end else if (~dfi_init_complete_i) begin
      cmd_q   <= 4'b1111; // phy init
      bank_q  <= '0;
      addr_q  <= '0;
    end else if (cmd_accept_w) begin
      cmd_q   <= cmd_d;   // send command
      bank_q  <= bank_d;
      addr_q  <= addr_d;
    end else begin
      cmd_q   <= CMD_NOP;
      bank_q  <= '0;
      addr_q  <= '0;
    end
  end

  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      reset_n_q <= 1'b0;
      cke_q     <= 1'b0;
    end else begin
      reset_n_q <= reset_n_d;
      cke_q     <= cke_d;
    end
  end
  
  // ---------------------------------------------------------------------------
  // Command Delay
  // ---------------------------------------------------------------------------
  localparam DELAY_W = 6;
  reg [DELAY_W-1:0] delay_d, delay_q;
  
  always @(*) begin
    delay_d = delay_q;

    if (delay_q == '0) begin
      case (cmd_d)
      // case (cmd_q)
        CMD_ACT:    delay_d = DDR_TRCD_C;
        CMD_PRE:    delay_d = DDR_TRP_C;
        CMD_READ:   delay_d = DDR_RW_NONSEQ_C;
        CMD_WRITE:  delay_d = DDR_RW_NONSEQ_C;
        CMD_REF:    delay_d = DDR_TRFC_C;
        default:    delay_d = '0;
      endcase
    end else begin
      delay_d = delay_q - 1;
    end
  end
  
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      delay_q <= '0;
    else
      delay_q <= delay_d;
  end
  assign cmd_accept_w = (delay_q == '0) || (cmd_d == CMD_NOP);

  // ---------------------------------------------------------------------------
  // Read Operation
  // ---------------------------------------------------------------------------
  // DFI delay counter
  reg [3:0] cnt_dfi_rddly_q;
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      cnt_dfi_rddly_q <= '0;
    else if (cmd_q == CMD_READ)
      cnt_dfi_rddly_q <= 4'd15;
    else if (cnt_dfi_rddly_q > 0)
      cnt_dfi_rddly_q <= cnt_dfi_rddly_q - 1;
    else
      cnt_dfi_rddly_q <= '0;
  end

  // read cmd -> trddata_en -> dfi_rddata_en * 4 cycles
  wire dfi_rddata_en_w =  (cnt_dfi_rddly_q < (15 - TRDDATA_EN_C + 2)) &
                          (cnt_dfi_rddly_q > (15 - TRDDATA_EN_C - 3));

  // sample dfi_rddata * 4 cycles
  wire dfi_rddata_sample_w =  (cnt_dfi_rddly_q < (15 - TPHY_RDLAT_C - 4)) &
                              (cnt_dfi_rddly_q > (15 - TPHY_RDLAT_C - 9));
  
  // concat DFI_DATA_W * n/2 -> MEM_DATA_W
  //           [ 32 * 4 ]    ->  [ 128 ]  
  reg [MEM_DATA_W-1:0] mem_rddata_q;
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      mem_rddata_q <= '0;
    end else if (dfi_rddata_sample_w) begin
      mem_rddata_q <= {mem_rddata_q[MEM_DATA_W-DFI_DATA_W-1:0], dfi_rddata_i[DFI_DATA_W-1:0]};
    end else begin
      mem_rddata_q <= '0;
    end
  end
  
  // read acknowledge
  wire rd_ack_w = cnt_dfi_rddly_q == 4'd2;

  // ---------------------------------------------------------------------------
  // Write Operation
  // ---------------------------------------------------------------------------
  // buffer of input write data
  wire [MEM_DATA_W-1:0] mem_wrdata_buf_w;
  wire wrdata_push_rdy_w, wrdata_pop_vld_w;
  reg  [1:0]            wrdata_idx_q;

  mc_fifo_sync #(
    .WIDTH ( 128 ),
    .DEPTH ( 4   )
  ) u_mc_fifo (
    .clk_i        ( clk_i                                    ),
    .rst_n_i      ( rst_n_i                                  ),

    .push_i       ( (state_q == STATE_WRITE ) & cmd_accept_w ),
    .push_data_i  ( mem_wrdata_i                             ),
    .push_rdy_o   ( wrdata_push_rdy_w                        ),

    .pop_i        ( wrdata_idx_q == 2'd3                     ),
    .pop_data_o   ( mem_wrdata_buf_w                         ),
    .pop_vld_o    ( wrdata_pop_vld_w                         )
  );

  // DFI delay counter
  reg [3:0] cnt_dfi_wrdly_q;
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      cnt_dfi_wrdly_q <= '0;
    else if (cmd_q == CMD_WRITE)
      cnt_dfi_wrdly_q <= 15;
    else if (cnt_dfi_wrdly_q > 0)
      cnt_dfi_wrdly_q <= cnt_dfi_wrdly_q - 1;
    else
      cnt_dfi_wrdly_q <= '0;
  end

  // write cmd -> tphy_wrlat -> (dfi_wrdata_en & dfi_wrdata) * 4 cycles
  wire dfi_wrdata_set_w = (cnt_dfi_wrdly_q < (15 - TPHY_WRLAT_C + 2)) &
                          (cnt_dfi_wrdly_q > (15 - TPHY_WRLAT_C - 3));
  
  // dfi_wrdata_en * 4 cycles
  reg dfi_wrdata_en_q;
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i)
      dfi_wrdata_en_q <= 1'b0;
    else if (dfi_wrdata_set_w)
      dfi_wrdata_en_q <= 1'b1;
    else
      dfi_wrdata_en_q <= 1'b0;
  end
  
  // split MEM_DATA_W -> DFI_DATA_W * n/2
  //        [ 128 ]   ->    [ 32 * 4 ]
  reg [DFI_DATA_W-1:0] dfi_wrdata_q;
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      dfi_wrdata_q <= '0;
      wrdata_idx_q <= '0;
    end else if (dfi_wrdata_set_w) begin
      case (wrdata_idx_q)
        2'd0: dfi_wrdata_q <= mem_wrdata_buf_w[DFI_DATA_W-1:0];
        2'd1: dfi_wrdata_q <= mem_wrdata_buf_w[2*DFI_DATA_W-1:DFI_DATA_W];
        2'd2: dfi_wrdata_q <= mem_wrdata_buf_w[3*DFI_DATA_W-1:2*DFI_DATA_W];
        2'd3: dfi_wrdata_q <= mem_wrdata_buf_w[4*DFI_DATA_W-1:3*DFI_DATA_W];
      endcase
      wrdata_idx_q <= wrdata_idx_q + 1;
    end else begin
      dfi_wrdata_q <= '0;
      wrdata_idx_q <= '0;
    end
  end
  
  // write acknowledge
  wire wr_ack_w = (state_q == STATE_WRITE) & cmd_accept_w;


  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------
  // memory interface
  assign mem_rddata_o = mem_rddata_q;
  assign mem_accept_o = ((state_q == STATE_READ) | (state_q == STATE_WRITE && wrdata_push_rdy_w)) & cmd_accept_w;
  assign mem_ack_o    = rd_ack_w | wr_ack_w;

  // dfi interface
  assign dfi_bank_o             = bank_q;
  assign dfi_address_o          = addr_q;
  assign {dfi_cs_n_o, dfi_ras_n_o, dfi_cas_n_o, dfi_we_n_o}
                                = cmd_q;
  assign dfi_cke_o              = cke_q;
  assign dfi_reset_n_o          = reset_n_q;
  assign dfi_odt_o              = 1'b0;

  assign dfi_wrdata_o           = dfi_wrdata_q;
  assign dfi_wrdata_mask_o      = '0;
  assign dfi_wrdata_en_o        = dfi_wrdata_en_q;
  
  assign dfi_rddata_en_o        = dfi_rddata_en_w;

  assign dfi_init_start_o       = 1'b0;
  assign dfi_dram_clk_disable_o = 1'b0;
  
endmodule
