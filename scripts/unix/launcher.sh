#!/usr/bin/env bash
# Main Unix Orchestrator for Portable VM Launcher

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helper modules
source "$SCRIPT_DIR/detect.sh"
source "$SCRIPT_DIR/decide.sh"
source "$SCRIPT_DIR/build_command.sh"
source "$SCRIPT_DIR/display.sh"

DETECT_ONLY=0
DRY_RUN=0
LIST_VMS=0
TARGET_VM_NAME=""
NO_PROMPT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --detect-only|-d) DETECT_ONLY=1; shift ;;
        --dry-run|-n)     DRY_RUN=1; shift ;;
        --list-vms|-l)    LIST_VMS=1; shift ;;
        --vm-name|-v)     TARGET_VM_NAME="$2"; shift 2 ;;
        --no-prompt|-y)   NO_PROMPT=1; shift ;;
        *)                echo "Unknown option: $1"; exit 1 ;;
    esac
done

show_banner

# 1. Host Detection
detect_host_info "$ROOT_DIR"
show_host_info

if [ "$DETECT_ONLY" -eq 1 ]; then
    echo "  [i] Detection completed (--detect-only specified)."
    exit 0
fi

# 2. VM Selection
VMS_DIR="$ROOT_DIR/vms"
SELECTED_VM_PATH=""

if [ "$LIST_VMS" -eq 1 ]; then
    show_vm_selection "$VMS_DIR" >/dev/null
    exit 0
fi

if [ -n "$TARGET_VM_NAME" ]; then
    if [ -d "$VMS_DIR/$TARGET_VM_NAME" ]; then
        SELECTED_VM_PATH="$VMS_DIR/$TARGET_VM_NAME"
    else
        echo -e "${COLOR_RED}  [!] Error: VM '$TARGET_VM_NAME' not found in '$VMS_DIR'.${COLOR_RESET}"
        exit 1
    fi
else
    show_vm_selection "$VMS_DIR"
    if [ -z "$SELECTED_VM_PATH" ]; then
        echo "  [i] Exiting launcher."
        exit 0
    fi
fi

# 3. Decision Engine
run_decision_engine "$ROOT_DIR" "$SELECTED_VM_PATH"
show_decision_summary

if [ "$DECISION_IS_VALID" -ne 1 ]; then
    echo -e "${COLOR_RED}  [X] CANNOT LAUNCH VM DUE TO CONFIGURATION ERRORS:${COLOR_RESET}"
    for err in "${DECISION_ERRORS[@]}"; do
        echo -e "${COLOR_RED}      - $err${COLOR_RESET}"
    done
    echo ""
    exit 1
fi

# 4. Interactive Configuration Review (if not in dry-run or non-interactive mode)
if [ "$NO_PROMPT" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    invoke_interactive_config_menu_unix
    if [ $? -ne 0 ]; then
        echo "  [i] Launch cancelled by user."
        exit 0
    fi
fi

# 5. Build QEMU Command Line
build_qemu_command

echo -e "${COLOR_GREEN}  [+] GENERATED QEMU COMMAND${COLOR_RESET}"
echo -e "${COLOR_GRAY}  ----------------------------------------------------------------${COLOR_RESET}"
echo -e "${COLOR_GRAY}  $FULL_COMMAND_STR${COLOR_RESET}"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [i] Dry-run completed (--dry-run specified). VM will not be launched."
    exit 0
fi

echo -e "${COLOR_GREEN}  [*] Launching Virtual Machine '$DECISION_VM_NAME'...${COLOR_RESET}"
echo ""

# 6. Execute QEMU process
"$QEMU_PATH" "${QEMU_ARGS[@]}"
EXIT_CODE=$?

echo ""
echo "  [+] Virtual Machine session terminated with exit code $EXIT_CODE."

