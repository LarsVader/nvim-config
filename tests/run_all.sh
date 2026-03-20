#!/bin/bash
# Run all Neovim config tests
# Usage: bash tests/run_all.sh
# Run from the nvim config directory: cd ~/.config/nvim && bash tests/run_all.sh

cd "$(dirname "$0")/.."

PASS=0
FAIL=0
FAILED_FILES=""

for spec in tests/*_spec.lua; do
    name=$(basename "$spec")
    echo ""
    echo "Running: $name"
    echo "----------------------------------------"

    output=$(nvim --headless -u tests/minimal_init.lua \
        +"lua require('plenary.busted').run('$spec')" 2>&1)

    echo "$output"

    # Strip ANSI escape codes before checking results
    clean=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

    if echo "$clean" | grep -q "Failed :.*0"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILED_FILES="$FAILED_FILES $name"
    fi
done

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed (out of $(($PASS + $FAIL)) spec files)"
if [ -n "$FAILED_FILES" ]; then
    echo "Failed:$FAILED_FILES"
fi
echo "========================================"

[ "$FAIL" -eq 0 ]
