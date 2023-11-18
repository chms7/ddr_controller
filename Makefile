# Directory
PRJ_DIR := $(shell pwd)
RTL_DIR := $(PRJ_DIR)/rtl
TB_DIR  := $(PRJ_DIR)/tb
SIM_DIR := $(PRJ_DIR)/sim

# Model
MODEL ?= xilinx
ifeq ($(MODEL),micron)
MODEL_DIR := $(PRJ_DIR)/model/ddr3_micron
MODEL_RTL := $(wildcard $(MODEL_DIR)/ddr3.v)
else ifeq ($(MODEL),xilinx)
MODEL_DIR := $(PRJ_DIR)/model/ddr3_xilinx
MODEL_RTL := $(wildcard $(MODEL_DIR)/*.v)
endif

# RTL
RTL 		:= $(wildcard $(RTL_DIR)/*.*v)

# Testbench
# TB_NAME ?= $(MODEL)
TB_NAME ?= phy
TB  		:= $(wildcard $(TB_DIR)/tb_$(TB_NAME).*v)

# Tools
SIM_TOOL  ?= vcs
SIM_FLAGS := -full64 +v2k -sverilog -kdb -fsdb -ldflags -debug_access+all -LDFLAGS \
						 -Wl,--no-as-needed -Mdir=$(SIM_DIR)/csrc
WAVE_TOOL := gtkwave

all: sim

ifeq ($(MODEL),micron)

sim: # Micron
	@mkdir -p $(SIM_DIR)
	$(SIM_TOOL) $(SIM_FLAGS) \
		+incdir+$(MODEL_DIR) +define+den1024Mb +define+sg25 +define+x8 -pvalue+MEM_BITS=8 \
		$(TB) $(MODEL_RTL) $(RTL) -o $(SIM_DIR)/simv && $(SIM_DIR)/simv

else ifeq ($(MODEL),xilinx)

sim: # Xilinx
# project.prj
	@mkdir -p $(SIM_DIR)
	@echo "" > $(SIM_DIR)/project.prj
	@echo "sv work \"$(abspath $(TB))\"" >> $(SIM_DIR)/project.prj
	@$(foreach _file,$(MODEL_RTL),echo "verilog work \"$(abspath $(_file)\"") >> $(SIM_DIR)/project.prj;)
	@$(foreach _file,$(RTL),echo "sv work \"$(abspath $(_file)\"") >> $(SIM_DIR)/project.prj;)
# run.tcl 
	@echo "" > $(SIM_DIR)/run.tcl
	@echo "run 10ms" >> $(SIM_DIR)/run.tcl
	@echo "quit" >> $(SIM_DIR)/run.tcl
# elaborate & sim
	cd $(SIM_DIR) && \
	xelab -prj project.prj -debug typical -relax -L secureip -L unisims_ver -L unimacro_ver \
		-i ../model/ddr3_xilinx tb_$(TB_NAME) glbl -s top_sim && \
	xsim top_sim -t run.tcl
	@cd ..

endif

# Wave
wave:
	nohup $(WAVE_TOOL) $(SIM_DIR)/wave.vcd > sim/wave_nohup &
	
clean:
	rm -rf sim ucli.key
	
.PHONY: all sim wave clean
