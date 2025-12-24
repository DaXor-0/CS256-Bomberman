VERILATOR ?= verilator
TOP ?= game_top
SRC_DIR := ../../src
SIM_SRC := $(SRC_DIR)/*.sv
OBJ_DIR := obj_dir

CXXFLAGS := -O2 -std=c++17
LDFLAGS := -lsfml-graphics -lsfml-window -lsfml-system

VERILATOR_FLAGS := -Wall --cc --exe --build --top-module $(TOP) -I$(SRC_DIR) \
	-Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE -Wno-PROCASSINIT -Wno-UNUSEDPARAM \
	-Wno-REDEFMACRO -Wno-EOFNEWLINE -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN

all:
	$(VERILATOR) $(VERILATOR_FLAGS) \
		-CFLAGS "$(CXXFLAGS)" \
		-LDFLAGS "$(LDFLAGS)" \
		--Mdir $(OBJ_DIR) \
		main.cpp $(SIM_SRC)

run: all
	./$(OBJ_DIR)/V$(TOP)

clean:
	rm -rf $(OBJ_DIR)
