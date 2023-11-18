## rst_n && cke

```
dfi_reset_n = '0;
dfi_cke     = '1;

#1000 dfi_reset_n = '1;

tb_xilinx.u_ram.reset: at time 1005000.0 ps ERROR: CKE must be inactive when RST_N goes inactive.
tb_xilinx.u_ram.reset: at time 1005000.0 ps ERROR: CKE must be maintained inactive for 10 ns before RST_N goes inactive.
```