/*
 * @Design: mc_fifo_syn
 * @Author: Zhao Siwei 
 * @Email:  cheems@foxmail.com
 * @Date:   2023-11-04
 * @Description: Synchronized FIFO
 */

module mc_fifo_sync #(
  parameter   WIDTH = 8,
  parameter   DEPTH = 4,
  localparam  ADDR_W = $clog2(DEPTH)
) (
  input  wire             clk_i,
  input  wire             rst_n_i,

  input  wire             push_i,
  input  wire [WIDTH-1:0] push_data_i,
  output wire             push_rdy_o,

  input  wire             pop_i,
  output wire [WIDTH-1:0] pop_data_o,
  output wire             pop_vld_o
);
  reg [ADDR_W:0] rd_ptr, wr_ptr;

  // Empty & Full Flag
  wire fifo_empty = wr_ptr == rd_ptr;
  wire fifo_full  = (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]) &&
                    (wr_ptr[ADDR_W]     != rd_ptr[ADDR_W]);

  // Write & Read Pointer
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
    end else if (~fifo_full) begin
      if (push_i) wr_ptr <= wr_ptr + 1;
      if (pop_i)  rd_ptr <= rd_ptr + 1;
    end else begin
      wr_ptr <= wr_ptr;
      rd_ptr <= rd_ptr;
    end
  end
  
  // WIDTH * DEPTH Memory
  reg [WIDTH-1:0] mem [DEPTH-1:0];

  // Write/Push
  always @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      for (integer mem_idx = 0; mem_idx < DEPTH; mem_idx = mem_idx + 1)
        mem[mem_idx] <= '0;
    end else if (~fifo_full & push_i) begin
        mem[wr_ptr[ADDR_W-1:0]] <= push_data_i;
    end // else hold
  end
  assign push_rdy_o = ~fifo_full;

  // Read/Pop
  assign pop_data_o = mem[rd_ptr[ADDR_W-1:0]];
  assign pop_vld_o  = ~fifo_empty & pop_i;
  
endmodule
