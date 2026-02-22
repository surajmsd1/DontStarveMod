#!/bin/bash
# Syntax check all Lua files before uploading to Workshop
# Run from mod directory: ./check_syntax.sh

echo "=== Checking Lua Syntax ==="

errors=0

for f in *.lua scripts/**/*.lua; do
    if [ -f "$f" ]; then
        if luac -p "$f" 2>/dev/null; then
            echo "✓ $f"
        else
            echo "✗ $f"
            luac -p "$f"
            errors=$((errors + 1))
        fi
    fi
done

echo ""
if [ $errors -eq 0 ]; then
    echo "=== All files OK! Safe to upload. ==="
else
    echo "=== $errors file(s) have errors! Fix before uploading. ==="
    exit 1
fi
