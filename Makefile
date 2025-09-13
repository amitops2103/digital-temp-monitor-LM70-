TOPLEVEL_LANG = verilog

VERILOG_SOURCES = $(CURDIR)/src/project.v

MODULE = tb_cocotb
TOPLEVEL = digital_temp_monitor_top
SIM = icarus

COCOTB_TESTCASE_DIR := $(CURDIR)/test
export PYTHONPATH := $(COCOTB_TESTCASE_DIR)

include $(shell cocotb-config --makefiles)/Makefile.sim


