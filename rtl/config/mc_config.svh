/*
 * @Design: mc_config
 * @Author: Zhao Siwei 
 * @Email:  cheems@foxmail.com
 * @Date:   2023-10-31
 * @Description: Configurable parameters
 */

// DDR
parameter FREQ_CORE_MHZ     = 100;
parameter FREQ_IO_MHZ       = 4*FREQ_CORE_MHZ; // 8n-prefetch
parameter FREQ_PHY_MHZ      = 4*FREQ_CORE_MHZ; // 8n-prefetch
parameter FREQ_RATIO_PHY2MC = 1;      // 1:1
parameter FREQ_MC_MHZ       = FREQ_PHY_MHZ/FREQ_RATIO_PHY2MC;
parameter DDR_FREQ_MHZ      = 100;    // 100 MHz
parameter DDR_DQ_W          = 16;     // DQ width
parameter DDR_BA_W          = 3;      // Bank address
parameter DDR_RA_W          = 15;     // Row  address
parameter DDR_CA_W          = 10;     // Col  address
parameter DDR_ADDR_W        = DDR_RA_W;
parameter DDR_ADDR_ENCODE   = "BRC";  // BRC: | bank | row  | col  |
                                      // RBC: | row  | bank | col  |
parameter DDR_BL            = 8;      // Burst length
parameter DDR_BT            = "SEQ";  // Burst type

// DFI
parameter DFI_DATA_W        = 32;

// MEM
parameter MEM_ADDR_W        = 32;
parameter MEM_DATA_W        = DDR_DQ_W*DDR_BL;
parameter MEM_MASK_W        = MEM_DATA_W/8;