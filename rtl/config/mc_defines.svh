/*
 * @Design: mc_defines
 * @Author: Zhao Siwei 
 * @Email:  cheems@foxmail.com
 * @Date:   2023-10-31
 * @Description: Unconfigurable parameters
 */
`include "mc_config.svh"

// ---------------------------------------------------------------------------
// FSM Encode
// ---------------------------------------------------------------------------
parameter STATE_INIT   = 4'd0;
parameter STATE_REF    = 4'd1;
parameter STATE_PRE    = 4'd2;
parameter STATE_ACT    = 4'd3;
parameter STATE_WRITE  = 4'd4;
parameter STATE_READ   = 4'd5;
parameter STATE_IDLE   = 4'd7;

// ---------------------------------------------------------------------------
// Command Encode
// ---------------------------------------------------------------------------
parameter CMD_MRS      = 4'b0000; // 0
parameter CMD_REF      = 4'b0001; // 1
parameter CMD_PRE      = 4'b0010; // 2
parameter CMD_ACT      = 4'b0011; // 3
parameter CMD_WRITE    = 4'b0100; // 4
parameter CMD_READ     = 4'b0101; // 5
parameter CMD_ZQCL     = 4'b0110; // 6
parameter CMD_NOP      = 4'b0111; // 7
parameter CMD_INIT     = 4'b1111; // 15

// ---------------------------------------------------------------------------
// Mode Register Configuration
// ---------------------------------------------------------------------------
parameter MRS_MR0_BL     = 2'b00;   // BL = 8
parameter MRS_MR0_BT     = 1'b0;    // Sequential
parameter MRS_MR0_CL     = 4'b0100; // CL = 6 CK
parameter MRS_MR0_DLL    = 1'b1;    // DLL Reset: yes
parameter MRS_MR0_WR     = 3'b000;  // WR = 16 CK
parameter MRS_MR0_PD     = 1'b0;    // Precharge PD: DLL off
parameter MRS_MR0  = {2'd0, MRS_MR0_PD, MRS_MR0_WR, MRS_MR0_DLL, 1'b0,
                       MRS_MR0_CL[3:1], MRS_MR0_BT, MRS_MR0_CL[0], MRS_MR0_BL};

parameter MRS_MR1_DLL    = 1'b1;    // DLL: disable
parameter MRS_MR1_ODS    = 2'b00;   // ODS: RZQ/6 (40ohm)
parameter MRS_MR1_RTT    = 3'b000;  // RTT,norm: disable
parameter MRS_MR1_AL     = 2'b00;   // AL = 0 CK
parameter MRS_MR1_WL     = 1'b0;    // Write Leveling: disable
parameter MRS_MR1_TDQS   = 1'b0;    // TDQS: disable
parameter MRS_MR1_Qoff   = 1'b0;    // Q off
parameter MRS_MR1  = {2'd0, MRS_MR1_Qoff, MRS_MR1_TDQS, 1'b0, MRS_MR1_RTT[2], 1'b0,
                       MRS_MR1_WL, MRS_MR1_RTT[1], MRS_MR1_ODS[1], MRS_MR1_AL,
                       MRS_MR1_RTT[0], MRS_MR1_ODS[0], MRS_MR1_DLL};

parameter MRS_MR2_CWL    = 3'b001;  // CWL = 6 CK
parameter MRS_MR2_ASR    = 1'b0;    // ASR: disabled
parameter MRS_MR2_SRT    = 1'b0;    // SRT: normal
parameter MRS_MR2_RTTWR  = 2'b00;   // RTT(WR): disable
parameter MRS_MR2 = {4'd0, MRS_MR2_RTTWR, 1'd0, MRS_MR2_SRT, MRS_MR2_ASR, MRS_MR2_CWL, 3'd0};

parameter MRS_MR3_MPR_RF = 2'b00;   // MPR READ Function: Predefined pattern
parameter MRS_MR3_MPR    = 1'b0;    // MPR Enable: Normal DRAM operations
parameter MRS_MR3 = {12'd0, MRS_MR3_MPR, MRS_MR3_MPR_RF};

// ---------------------------------------------------------------------------
// DDR Timing
// ---------------------------------------------------------------------------
parameter tCK_ns    = 1000 / DDR_FREQ_MHZ;

parameter nAL       = 0;
parameter nCWL      = 6;
parameter nWL       = nAL + nCWL;
parameter nCL       = 6;
parameter nRL       = nAL + nCL;

parameter nXPR      = 5;            // 5 cycles
parameter nMRD      = 4;            // 4 cycles
parameter nMOD      = 12;           // 12 cycles
parameter nZQINIT   = 512;          // 512 cycles
parameter nRP       = 15  / tCK_ns; // 15 ns
parameter nRFC      = 260 / tCK_ns; // 260 ns
parameter nRCD      = 15  / tCK_ns; // 15 ns
parameter nWTR      = 4;            // 4 cycles
parameter nCCD      = 4;            // 4 cycles
// parameter nRP       = (15 + (tCK_ns-1)) / tCK_ns;
// parameter nRFC      = (260 + (tCK_ns-1)) / tCK_ns;
// parameter nRCD      = (15 + (tCK_ns-1)) / tCK_ns;
// parameter nWTR      = 5 + 1;

// Standard R/W -> W->R (non-sequential)
parameter DDR_WTR_C = nWL + DDR_BL + nWTR;
parameter DDR_WTW_C = nCCD;
parameter DDR_RW_NONSEQ_C = nWL + DDR_BL + nWTR;
parameter DDR_RW_SEQ_C    = DDR_RW_NONSEQ_C + 1 - DDR_BL;
// parameter DDR_RW_SEQ_C    = DDR_RW_NONSEQ_C + 1 - DDR_BL;

// ---------------------------------------------------------------------------
// DDR Init: 700us + tXPR + (15?) + 3*tMRD + tMOD + tZQinit + tRP
// ---------------------------------------------------------------------------
parameter INIT_TIME_TOTAL    = 700000/tCK_ns + nXPR + 15 + 3*nMRD
                                + nMOD + nZQINIT + nRP;
parameter INIT_TIME_RST      = INIT_TIME_TOTAL - 200000 / tCK_ns;  // 200us
parameter INIT_TIME_CKE      = INIT_TIME_RST - 500000 / tCK_ns;   // 500us
parameter INIT_TIME_MRS      = INIT_TIME_CKE - nXPR - 15; // ?
parameter INIT_TIME_ZQCL     = INIT_TIME_MRS - 3*nMRD - nMOD;
parameter INIT_TIME_PRE      = INIT_TIME_ZQCL - nZQINIT;

// ---------------------------------------------------------------------------
// PHY Timing
// ---------------------------------------------------------------------------
parameter nPHY_WRLAT = 3;
parameter nRDDATA_EN = 4;
parameter nPHY_RDLAT = 4;
// parameter nPHY_WRLAT        = nWL-1;
// parameter nPHY_RDLAT        = nRL-1;

// ---------------------------------------------------------------------------
// Refresh Timer
// ---------------------------------------------------------------------------
parameter DDR_REF_C  = (64000000/(2**DDR_RA_W)) / tCK_ns; // refresh per 64ms/RA
// parameter DDR_REF_C = (64000*DDR_FREQ_MHZ) / 8192;

parameter REF_TIMER_W    = 17;

// ---------------------------------------------------------------------------
// Address
// ---------------------------------------------------------------------------
parameter ADDR_BIT_ALLBANK = 10;
parameter ADDR_BIT_AUTOPRE = 10;