SHELL := /bin/bash

DOCS_DIR := $(CURDIR)/docs
BUILD_DIR := $(DOCS_DIR)/build
EXT_DIR := $(CURDIR)/vscode-markdown-paste-image

.PHONY: help run clean ext-compile ext-package ext-install ext-clean

help:
	@echo "Targets:"
	@echo "  make run  # build + live-reload with sphinx-autobuild"
	@echo "  make clean  # remove docs build output"
	@echo "  make ext-compile  # lint + compile the local VS Code extension"
	@echo "  make ext-package  # package the local VS Code extension (.vsix)"
	@echo "  make ext-install  # install the latest packaged .vsix"
	@echo "  make ext-clean  # remove extension build outputs (*.vsix, out, out_test)"

run:
	@cd "$(DOCS_DIR)" && \
		source "$$HOME/anaconda3/etc/profile.d/conda.sh" && \
		conda activate phinx && \
		sphinx-autobuild source/ build/html/

clean:
	@echo "Removing $(BUILD_DIR) ..."
	@rm -rf "$(BUILD_DIR)"
	@echo "Done."

ext-compile:
	@cd "$(EXT_DIR)" && \
		npm run compile

ext-package:
	@cd "$(EXT_DIR)" && \
		npx vsce package

ext-install:
	@cd "$(EXT_DIR)" && \
		code --install-extension ./vscode-markdown-paste-image-local-*.vsix

ext-clean:
	@echo "Removing extension build artifacts ..."
	@rm -rf "$(EXT_DIR)/out" "$(EXT_DIR)/out_test" "$(EXT_DIR)"/*.vsix
	@echo "Done."
