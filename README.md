# ddr_controller

## Simulation

- `MODEL` : 
  - xilinx(default with phy)
  - micron

- `TB_NAME` : 
  - xilinx(default with pht)
  - micron
  - other testbench like: tb/tb_phy -> TB_NAME=phy

```
make sim MODEL=xilinx TB_NAME=xilinx
```