include .env

# Colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
BOLD   := \033[1m
RESET  := \033[0m

# Symbols
CHECK  := ✓
ARROW  := →
GEAR   := ⚙

.PHONY: all
all: header paths build deploy pack footer

.PHONY: header
header:
	@echo ""
	@echo "$(BOLD)$(BLUE)╔════════════════════════════════════════════╗$(RESET)"
	@echo "$(BOLD)$(BLUE)║     SwiftGodot Multiplayer Build System    ║$(RESET)"
	@echo "$(BOLD)$(BLUE)╚════════════════════════════════════════════╝$(RESET)"
	@echo ""

.PHONY: footer
footer:
	@echo "$(GREEN)$(CHECK) All tasks completed successfully$(RESET)"
	@echo ""

.PHONY: paths
paths:
	@echo ""
	@echo "$(BOLD)$(CYAN)$(GEAR) Configuration$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Library:" "$(LIBRARY_NAME)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Executable:" "$(EXECUTABLE_NAME)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Build path:" "$(BUILD_PATH)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Bin path:" "$(GODOT_BIN_PATH)"
	@echo ""
	@echo "$(BOLD)$(CYAN)$(GEAR) Godot$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Executable:" "$(GODOT)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Project:" "$(GODOT_PROJECT_FILE_PATH)"
	@printf "$(YELLOW)%-20s$(RESET) %s\n" "Version:" "`$(GODOT) --version 2>/dev/null || echo 'Not found'`"
	@echo ""

define run_with_spinner
	@printf "  Building $(1) "; \
	swift build --product $(1) --build-path $(BUILD_PATH) > /tmp/swift_build_$$$$.log 2>&1 & \
	PID=$$!; \
	FRAMES="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"; \
	while kill -0 $$PID 2>/dev/null; do \
		for frame in $$FRAMES; do \
			printf "\r  Building $(1) $$frame"; \
			sleep 0.08; \
			kill -0 $$PID 2>/dev/null || break; \
		done; \
	done; \
	wait $$PID; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -eq 0 ]; then \
		printf "\r  Building $(1) $(GREEN)$(CHECK)$(RESET)  \n"; \
	else \
		printf "\r  Building $(1) $(YELLOW)⚠$(RESET)  \n"; \
		cat /tmp/swift_build_$$$$.log | tail -10; \
	fi; \
	rm -f /tmp/swift_build_$$$$.log
endef

.PHONY: build
build:
	@echo "$(BOLD)$(CYAN)$(GEAR) Building Swift library...$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@mkdir -p $(BUILD_PATH)
	$(call run_with_spinner,$(LIBRARY_NAME))
	@echo ""

.PHONY: build-all
build-all:
	@echo "$(BOLD)$(CYAN)$(GEAR) Building whole Swift package...$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@mkdir -p $(BUILD_PATH)
	$(call run_with_spinner,$(LIBRARY_NAME))
	$(call run_with_spinner,$(EXECUTABLE_NAME))
	@echo ""

.PHONY: deploy
deploy:
	@echo "$(BOLD)$(CYAN)$(GEAR) Deploying libraries...$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@mkdir -p $(GODOT_BIN_PATH)
	@rm -f $(GODOT_BIN_PATH)/libSwiftGodot.dylib
	@rm -f $(GODOT_BIN_PATH)/libSwiftLibrary.dylib
	@cp $(BUILD_PATH)/debug/libSwiftGodot.dylib $(GODOT_BIN_PATH)/libSwiftGodot.dylib
	@echo "  $(ARROW) libSwiftGodot.dylib"
	@cp $(BUILD_PATH)/debug/libSwiftLibrary.dylib $(GODOT_BIN_PATH)/libSwiftLibrary.dylib
	@echo "  $(ARROW) libSwiftLibrary.dylib"
	@echo "$(GREEN)$(CHECK) Libraries deployed to $(GODOT_BIN_PATH)$(RESET)"
	@echo ""

.PHONY: run
run:
	@echo "$(BOLD)$(CYAN)$(GEAR) Running $(EXECUTABLE_NAME)...$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@swift run $(EXECUTABLE_NAME) --build-path $(BUILD_PATH)

.PHONY: open
open:
	@echo "$(BOLD)$(CYAN)$(GEAR) Opening Godot project...$(RESET)"
	@$(GODOT) $(GODOT_PROJECT_FILE_PATH) &

.PHONY: pack
pack:
	@echo "$(BOLD)$(CYAN)$(GEAR) Creating resource pack...$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@echo "$(ARROW) Importing resources..."
	@-$(GODOT) $(GODOT_PROJECT_FILE_PATH) --headless --quit 2>/dev/null
	@echo "$(ARROW) Exporting .pck file..."
	@$(GODOT) --headless --path $(GODOT_PROJECT_DIRECTORY) --export-pack Packer ../Swift/$(EXECUTABLE_NAME)/Resources/$(LIBRARY_NAME).pck 2>/dev/null
	@echo "$(GREEN)$(CHECK) Pack created: $(EXECUTABLE_NAME)/Resources/$(LIBRARY_NAME).pck$(RESET)"
	@echo ""

.PHONY: clean
clean:
	@echo "$(BOLD)$(CYAN)$(GEAR) Cleaning build artifacts...$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@rm -rf $(BUILD_PATH)
	@echo "  $(ARROW) Removed $(BUILD_PATH)"
	@rm -f $(GODOT_BIN_PATH)/libSwiftGodot.dylib
	@rm -f $(GODOT_BIN_PATH)/libSwiftLibrary.dylib
	@echo "  $(ARROW) Removed libraries from $(GODOT_BIN_PATH)"
	@echo "$(GREEN)$(CHECK) Clean complete$(RESET)"
	@echo ""

.PHONY: help
help:
	@echo ""
	@echo "$(BOLD)$(BLUE)SwiftGodot Multiplayer - Build Commands$(RESET)"
	@echo "$(BOLD)────────────────────────────────────────────$(RESET)"
	@echo ""
	@echo "$(YELLOW)make all$(RESET)      Build library, deploy, and pack (default)"
	@echo "$(YELLOW)make build$(RESET)    Compile Swift library only"
	@echo "$(YELLOW)make build-all$(RESET) Compile library + executable"
	@echo "$(YELLOW)make deploy$(RESET)   Copy libraries to Godot/bin"
	@echo "$(YELLOW)make pack$(RESET)     Create .pck resource file"
	@echo "$(YELLOW)make run$(RESET)      Run standalone executable"
	@echo "$(YELLOW)make open$(RESET)     Open Godot project"
	@echo "$(YELLOW)make clean$(RESET)    Remove build artifacts"
	@echo "$(YELLOW)make paths$(RESET)    Show configuration"
	@echo "$(YELLOW)make help$(RESET)     Show this help"
	@echo ""
