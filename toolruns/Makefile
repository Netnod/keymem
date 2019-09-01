#===================================================================
#
# Makefile
# --------
# Makefile for building, linting and simukating the NTS key memory.
#
#
# Author: Joachim Strombergson
#
# Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#===================================================================

KEYMEM_SRC=../src/rtl/keymem.v
TB_KEYMEM_SRC =../src/tb/tb_keymem.v

CC = iverilog
CC_FLAGS = -Wall

LINT = verilator
LINT_FLAGS = +1364-2001ext+ --lint-only  -Wall -Wno-fatal -Wno-DECLFILENAME


all: keymem.sim


keymem.sim:  $(TB_KEYMEM_SRC) $(KEYMEM_SRC)
	$(CC) $(CC_FLAGS) -o keymem.sim $(TB_KEYMEM_SRC) $(KEYMEM_SRC)


sim-keymem: keymem.sim
	./keymem.sim


lint:  $(KEYMEM_SRC)
	$(LINT) $(LINT_FLAGS) $(KEYMEM_SRC)


clean:
	rm -f keymem.sim


help:
	@echo "Build system for keymem"
	@echo ""
	@echo "Supported targets:"
	@echo "------------------"
	@echo "keymem.sim:   Build key memory simulation target."
	@echo "sim-keymem    Run keymem simulation."
	@echo "lint:         Lint all rtl source files."
	@echo "clean:        Delete all built files."

#===================================================================
# EOF Makefile
#===================================================================
