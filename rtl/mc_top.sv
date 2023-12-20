/*
 * @Design: mc_top
 * @Author: Zhao Siwei 
 * @Email:  cheems@foxmail.com
 * @Date:   2023-10-31
 * @Description: Top module of ddr controller
 */

module mc_top #(
  // DDR
  parameter FREQ_CORE_MHZ     = 100,
  parameter FREQ_IO_MHZ       = 4*FREQ_CORE_MHZ, // 8n-prefetch
  parameter FREQ_PHY_MHZ      = 4*FREQ_CORE_MHZ, // 8n-prefetch
  parameter FREQ_RATIO_PHY2MC = 1,      // 1:1
  parameter FREQ_MC_MHZ       = FREQ_PHY_MHZ/FREQ_RATIO_PHY2MC,
  parameter DDR_FREQ_MHZ      = 100,    // 100 MHz
  parameter DDR_DQ_W          = 16,     // DQ width
  parameter DDR_BA_W          = 3,      // Bank address
  parameter DDR_RA_W          = 15,     // Row  address
  parameter DDR_CA_W          = 10,     // Col  address
  parameter DDR_ADDR_W        = DDR_RA_W,
  parameter DDR_ADDR_ENCODE   = "BRC",  // BRC: | bank | row  | col  |
                                        // RBC: | row  | bank | col  |
  parameter DDR_BL            = 8,      // Burst length
  parameter DDR_BT            = "SEQ",  // Burst type
  // DFI
  parameter DFI_DATA_W        = 32,
  // MEM
  parameter MEM_ADDR_W        = 32,
  parameter MEM_DATA_W        = DDR_DQ_W*DDR_BL,
  parameter MEM_MASK_W        = MEM_DATA_W/8
) (
  input                     clk_i,
  input                     rst_n_i,

  // Memory Interface
  input  [MEM_MASK_W  -1:0] mem_wr_i,
  input                     mem_rd_i,
  input  [MEM_ADDR_W  -1:0] mem_addr_i,
  input  [MEM_DATA_W  -1:0] mem_wrdata_i,
  output [MEM_DATA_W  -1:0] mem_rddata_o,
  output                    mem_accept_o,
  output                    mem_ack_o,

  // DFI Interface
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
  // FSM Encode
  localparam STATE_INIT   = 4'd0;
  localparam STATE_REF    = 4'd1;
  localparam STATE_PRE    = 4'd2;
  localparam STATE_ACT    = 4'd3;
  localparam STATE_WRITE  = 4'd4;
  localparam STATE_READ   = 4'd5;
  localparam STATE_IDLE   = 4'd7;

  // Command Encode
  localparam CMD_MRS      = 4'b0000; // 0
  localparam CMD_REF      = 4'b0001; // 1
  localparam CMD_PRE      = 4'b0010; // 2
  localparam CMD_ACT      = 4'b0011; // 3
  localparam CMD_WRITE    = 4'b0100; // 4
  localparam CMD_READ     = 4'b0101; // 5
  localparam CMD_ZQCL     = 4'b0110; // 6
  localparam CMD_NOP      = 4'b0111; // 7
  localparam CMD_INIT     = 4'b1111; // 15

  // Mode Register Configuration
  localparam MRS_MR0_BL     = 2'b00;   // BL = 8
  localparam MRS_MR0_BT     = 1'b0;    // Sequential
  localparam MRS_MR0_CL     = 4'b0100; // CL = 6 CK
  localparam MRS_MR0_DLL    = 1'b1;    // DLL Reset: yes
  localparam MRS_MR0_WR     = 3'b000;  // WR = 16 CK
  localparam MRS_MR0_PD     = 1'b0;    // Precharge PD: DLL off
  localparam MRS_MR0  = {2'd0, MRS_MR0_PD, MRS_MR0_WR, MRS_MR0_DLL, 1'b0,
                         MRS_MR0_CL[3:1], MRS_MR0_BT, MRS_MR0_CL[0], MRS_MR0_BL};

  localparam MRS_MR1_DLL    = 1'b1;    // DLL: disable
  localparam MRS_MR1_ODS    = 2'b00;   // ODS: RZQ/6 (40ohm)
  localparam MRS_MR1_RTT    = 3'b000;  // RTT,norm: disable
  localparam MRS_MR1_AL     = 2'b00;   // AL = 0 CK
  localparam MRS_MR1_WL     = 1'b0;    // Write Leveling: disable
  localparam MRS_MR1_TDQS   = 1'b0;    // TDQS: disable
  localparam MRS_MR1_Qoff   = 1'b0;    // Q off
  localparam MRS_MR1  = {2'd0, MRS_MR1_Qoff, MRS_MR1_TDQS, 1'b0, MRS_MR1_RTT[2], 1'b0,
                         MRS_MR1_WL, MRS_MR1_RTT[1], MRS_MR1_ODS[1], MRS_MR1_AL,
                         MRS_MR1_RTT[0], MRS_MR1_ODS[0], MRS_MR1_DLL};

  localparam MRS_MR2_CWL    = 3'b001;  // CWL = 6 CK
  localparam MRS_MR2_ASR    = 1'b0;    // ASR: disabled
  localparam MRS_MR2_SRT    = 1'b0;    // SRT: normal
  localparam MRS_MR2_RTTWR  = 2'b00;   // RTT(WR): disable
  localparam MRS_MR2 = {4'd0, MRS_MR2_RTTWR, 1'd0, MRS_MR2_SRT, MRS_MR2_ASR, MRS_MR2_CWL, 3'd0};

  localparam MRS_MR3_MPR_RF = 2'b00;   // MPR READ Function: Predefined pattern
  localparam MRS_MR3_MPR    = 1'b0;    // MPR Enable: Normal DRAM operations
  localparam MRS_MR3 = {12'd0, MRS_MR3_MPR, MRS_MR3_MPR_RF};

  // DDR Timing
  localparam tCK_ns  = 1000 / DDR_FREQ_MHZ;

  localparam nAL       = 0;
  localparam nCWL      = 6;
  localparam nWL       = nAL + nCWL;
  localparam nCL       = 6;
  localparam nRL       = nAL + nCL;
  
  localparam nXPR     = 5;            // 5 cycles
  localparam nMRD     = 4;            // 4 cycles
  localparam nMOD     = 12;           // 12 cycles
  localparam nZQINIT  = 512;          // 512 cycles
  localparam nRP      = 15  / tCK_ns; // 15 ns
  localparam nRFC     = 260 / tCK_ns; // 260 ns
  localparam nRCD     = 15  / tCK_ns; // 15 ns
  localparam nWTR     = 4;            // 4 cycles
  localparam nCCD     = 4;            // 4 cycles
  // localparam nRP    = (15 + (tCK_ns-1)) / tCK_ns;
  // localparam nRFC   = (260 + (tCK_ns-1)) / tCK_ns;
  // localparam nRCD   = (15 + (tCK_ns-1)) / tCK_ns;
  // localparam nWTR   = 5 + 1;

  // Standard R/W -> W->R (non-sequential)
  localparam DDR_WTR_C = nWL + DDR_BL + nWTR;
  localparam DDR_WTW_C = nCCD;
  localparam DDR_RW_NONSEQ_C = nWL + DDR_BL + nWTR;
  localparam DDR_RW_SEQ_C    = DDR_RW_NONSEQ_C + 1 - DDR_BL;
  // localparam DDR_RW_SEQ_C    = DDR_RW_NONSEQ_C + 1 - DDR_BL;

  // DDR Init: 700us + tXPR + (15?) + 3*tMRD + tMOD + tZQinit + tRP
  localparam INIT_TIME_TOTAL     = 700000/tCK_ns + nXPR + 15 + 3*nMRD
                                  + nMOD + nZQINIT + nRP;
  localparam INIT_TIME_RST      = INIT_TIME_TOTAL - 200000 / tCK_ns;  // 200us
  localparam INIT_TIME_CKE      = INIT_TIME_RST - 500000 / tCK_ns;   // 500us
  localparam INIT_TIME_MRS      = INIT_TIME_CKE - nXPR - 15; // ?
  localparam INIT_TIME_ZQCL     = INIT_TIME_MRS - 3*nMRD - nMOD;
  localparam INIT_TIME_PRE      = INIT_TIME_ZQCL - nZQINIT;

  // PHY Timing
  localparam nPHY_WRLAT = 3;
  localparam nRDDATA_EN = 4;
  localparam nPHY_RDLAT = 4;
  // localparam nPHY_WRLAT        = nWL-1;
  // localparam nPHY_RDLAT        = nRL-1;
  
  // Refresh Timer
  localparam DDR_REF_C  = (64000000/(2**DDR_RA_W)) / tCK_ns; // refresh per 64ms/RA
  // localparam DDR_REF_C = (64000*DDR_FREQ_MHZ) / 8192;
  localparam REF_TIMER_W    = 17;
  
  localparam ADDR_BIT_ALLBANK = 10;
  localparam ADDR_BIT_AUTOPRE = 10;

  // ---------------------------------------------------------------------------
  // Input Process
  // ---------------------------------------------------------------------------
  // Address Decode
  wire [DDR_BA_W-1:0] addr_bank_w;
  wire [DDR_RA_W-1:0] addr_row_w;
  wire [DDR_CA_W-1:0] addr_col_w;

  generate
    if (DDR_ADDR_ENCODE == "RBC") begin
      // RBC: | row  | bank | col  |
      assign addr_row_w  = mem_addr_i[DDR_RA_W+DDR_BA_W+DDR_CA_W-1:DDR_BA_W+DDR_CA_W];
      assign addr_bank_w = mem_addr_i[DDR_BA_W+DDR_CA_W-1:DDR_CA_W];
      assign addr_col_w  = {mem_addr_i[DDR_CA_W-1:3], 3'd0};
    end else begin // default
      // BRC: | bank | row  | col  |
      assign addr_bank_w = mem_addr_i[DDR_BA_W+DDR_RA_W+DDR_CA_W-1:DDR_RA_W+DDR_CA_W];
      assign addr_row_w  = mem_addr_i[DDR_RA_W+DDR_CA_W-1:DDR_CA_W];
      assign addr_col_w  = {mem_addr_i[DDR_CA_W-1:3], 3'd0};
    end
  endgenerate

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
              target_state_d = STATE_READ;
            else
              target_state_d = STATE_WRITE;
          end else begin
            // PH (Page Hit): ACT -> READ/WRITE
              next_state_d   = STATE_ACT;
            if (mem_req_rd_w)
              target_state_d = STATE_READ;
            else
              target_state_d = STATE_WRITE;
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
      refresh_timer_q <= INIT_TIME_TOTAL;  // ddr init
    else if (~dfi_init_complete_i)
      refresh_timer_q <= INIT_TIME_TOTAL;  // hold when phy init
    else if (refresh_timer_q == '0)
      refresh_timer_q <= DDR_REF_C;        // normal refresh
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
        end else if (refresh_timer_q == INIT_TIME_MRS - nMRD) begin
          cmd_d   = CMD_MRS;
          bank_d  = 3'd3;     // MR3
          addr_d  = MRS_MR3;
        end else if (refresh_timer_q == INIT_TIME_MRS - 2*nMRD) begin
          cmd_d   = CMD_MRS;
          bank_d  = 3'd1;     // MR1
          addr_d  = MRS_MR1;
        end else if (refresh_timer_q == INIT_TIME_MRS - 3*nMRD) begin
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
          bank_d                   = addr_bank_w;
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
        addr_d[9:0]   = addr_col_w;
        addr_d[14:11] = '0;
        addr_d[ADDR_BIT_AUTOPRE]  = 1'b0;  // disable auto-precharge
      end
      
      STATE_WRITE: begin
        cmd_d   = CMD_WRITE;
        bank_d  = addr_bank_w;
        // RA = 15, CA = 10
        addr_d[9:0]   = addr_col_w;
        addr_d[14:11] = '0;
        addr_d[ADDR_BIT_AUTOPRE]  = 1'b0;  // disable auto-precharge
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
      cmd_q   <= CMD_INIT; // phy init
      bank_q  <= '0;
      addr_q  <= '0;
    end else if (cmd_accept_w) begin
      cmd_q   <= cmd_d;    // send command
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
        CMD_ACT:    delay_d = nRCD;
        CMD_PRE:    delay_d = nRP;
        CMD_READ:   delay_d = DDR_RW_NONSEQ_C;
        CMD_WRITE:  delay_d = DDR_RW_NONSEQ_C;
        CMD_REF:    delay_d = nRFC;
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
  wire dfi_rddata_en_w     =  (cnt_dfi_rddly_q < (15 - nRDDATA_EN + 2)) &
                              (cnt_dfi_rddly_q > (15 - nRDDATA_EN - 3));

  // sample dfi_rddata * 4 cycles
  wire dfi_rddata_sample_w =  (cnt_dfi_rddly_q < (15 - nPHY_RDLAT - 4)) &
                              (cnt_dfi_rddly_q > (15 - nPHY_RDLAT - 9));
  
  // concat DFI_DATA_W * n/2 -> MEM_DATA_W
  //           [ 32 * 4 ]    ->  [ 128 ]  
  reg [MEM_DATA_W-1:0] mem_rddata_q;
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      mem_rddata_q <= '0;
    end else if (dfi_rddata_sample_w) begin
      mem_rddata_q <= {dfi_rddata_i[DFI_DATA_W-1:0], mem_rddata_q[MEM_DATA_W-1:DFI_DATA_W]};
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
  wire dfi_wrdata_set_w = (cnt_dfi_wrdly_q < (15 - nPHY_WRLAT + 2)) &
                          (cnt_dfi_wrdly_q > (15 - nPHY_WRLAT - 3));
  
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
