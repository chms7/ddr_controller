# Directory
PRJ_DIR := $(shell pwd)
RTL_DIR := $(PRJ_DIR)/rtl
TB_DIR  := $(PRJ_DIR)/tb
SIM_DIR := $(PRJ_DIR)/sim

# Model
MODEL		:= $(wildcard $(PRJ_DIR)/model/ddr3_opens/ddr3.v)

# RTL
RTL 		:= $(wildcard $(RTL_DIR)/mc/*.*v)
RTL 		+= $(wildcard $(RTL_DIR)/phy/*.*v)

# Testbench
TB_NAME ?= mc
TB  		:= $(wildcard $(TB_DIR)/tb_$(TB_NAME).*v)

WAVE_TOOL := gtkwave

all: sim

sim:
# project.prj
	@mkdir -p $(SIM_DIR)
	@echo "" > $(SIM_DIR)/project.prj
	@echo "sv work \"$(abspath $(TB))\"" >> $(SIM_DIR)/project.prj
	@$(foreach _file,$(MODEL),echo "verilog work \"$(abspath $(_file)\"") >> $(SIM_DIR)/project.prj;)
	@$(foreach _file,$(RTL),echo "sv work \"$(abspath $(_file)\"") >> $(SIM_DIR)/project.prj;)
# run.tcl 
	@echo "" > $(SIM_DIR)/run.tcl
	@echo "run 10ms" >> $(SIM_DIR)/run.tcl
	@echo "quit" >> $(SIM_DIR)/run.tcl
# elaborate & sim
	cd $(SIM_DIR) && \
	xelab -prj project.prj -debug typical -relax -L secureip -L unisims_ver -L unimacro_ver \
		-i ../model/ddr3_opens tb_$(TB_NAME) glbl -s top_sim && \
	xsim top_sim -t run.tcl
	@cd ..

wave:
	nohup $(WAVE_TOOL) $(SIM_DIR)/wave.vcd > sim/wave_nohup &
	
clean:
	rm -rf sim ucli.key verdiLog
	
.PHONY: all sim wave clean
