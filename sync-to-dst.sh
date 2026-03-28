#!/bin/bash
# Sync mod to DST mods folder
# Run this after making changes to deploy to game

SRC="/Users/surajkopparam/IdeaProjects/DontStarveMod/DontStarveMod"
DST="/Users/surajkopparam/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods/DontStarveMod"

echo "=== Syncing Mystery Box Mod to DST ==="
echo "From: $SRC"
echo "To:   $DST"
echo ""

# Create destination if needed
mkdir -p "$DST/scripts/prefabs"
mkdir -p "$DST/scripts/widgets"
mkdir -p "$DST/scripts/challenges"
mkdir -p "$DST/scripts/events"
mkdir -p "$DST/scripts/core"

# Sync only mod files (exclude dev/build stuff)
rsync -av --delete \
    --exclude='.git' \
    --exclude='.git*' \
    --exclude='docs' \
    --exclude='logs' \
    --exclude='examples' \
    --exclude='specs' \
    --exclude='src' \
    --exclude='sync-to-dst.sh' \
    --exclude='check_syntax.sh' \
    --exclude='.DS_Store' \
    --exclude='.*' \
    --exclude='*.md' \
    --exclude='*.json' \
    --exclude='*.log' \
    --include='modinfo.lua' \
    --include='modmain.lua' \
    --include='scripts/***' \
    --include='*.tex' \
    --include='*.xml' \
    --include='*.png' \
    --exclude='*' \
    "$SRC/" "$DST/"

# Touch all files to update timestamps (forces game to detect changes)
find "$DST" -type f -name "*.lua" -exec touch {} \;

echo ""
echo "=== Sync complete! ==="
echo "Files updated at: $(date)"
echo ""
echo "In DST console, use: c_reset() to reload"
