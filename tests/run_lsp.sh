#!/bin/bash
# Run LSP integration tests
# Usage: bash tests/run_lsp.sh
# Run from the nvim config directory: cd ~/AppData/Local/nvim && bash tests/run_lsp.sh

cd "$(dirname "$0")/.."

echo ""
echo "Running: lsp_integration.lua"
echo "========================================"

output=$(nvim --headless -u tests/minimal_init.lua \
    +"luafile tests/lsp_integration.lua" 2>&1)

echo "$output"

# Strip ANSI codes and check for failures
clean=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

if echo "$clean" | grep -q "Failed : 0"; then
    echo ""
    echo "LSP integration tests: ALL PASSED"
    exit 0
else
    echo ""
    echo "LSP integration tests: FAILURES DETECTED"
    exit 1
fi
