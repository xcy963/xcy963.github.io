SHELL := /bin/bash

DOCS_DIR := $(CURDIR)/docs
BUILD_DIR := $(DOCS_DIR)/build

.PHONY: help run clean

help:
	@echo "Targets:"
	@echo "  make run  # build + live-reload with sphinx-autobuild"
	@echo "  make clean  # remove docs build output"

run:
	@cd "$(DOCS_DIR)" && \
		source "$$HOME/anaconda3/etc/profile.d/conda.sh" && \
		conda activate phinx && \
		sphinx-autobuild source/ build/html/

clean:
	@echo "Removing $(BUILD_DIR) ..."
	@rm -rf "$(BUILD_DIR)"
	@echo "Done."
