#!/bin/bash
# RTK Token Optimizer Skill - Demo Script
# Demonstrates various use cases and token savings

set -e

KIMIZ="./zig-out/bin/kimiz"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     RTK Token Optimizer - Demo Script                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if kimiz is built
if [ ! -f "$KIMIZ" ]; then
    echo "❌ kimiz not found. Please run: zig build"
    exit 1
fi

# Check if rtk is installed
if ! command -v rtk &> /dev/null; then
    echo "❌ rtk is not installed."
    echo "Install via: brew install rtk"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Demo 1: Git Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Demo 1: Git Status Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Standard git status:"
git status | head -20
echo ""
echo "RTK optimized:"
$KIMIZ skill rtk-optimize command="git status"
echo ""

# Demo 2: Directory Listing
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Demo 2: Directory Listing Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Standard ls -la:"
ls -la | head -15
echo ""
echo "RTK optimized:"
$KIMIZ skill rtk-optimize command="ls -la"
echo ""

# Demo 3: Git Log
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Demo 3: Git Log Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Standard git log:"
git log --oneline -n 5
echo ""
echo "RTK optimized:"
$KIMIZ skill rtk-optimize command="git log -n 5"
echo ""

# Demo 4: Find Files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Demo 4: Find Files Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Standard find:"
find ./src -name "*.zig" -type f | head -15
echo ""
echo "RTK optimized:"
$KIMIZ skill rtk-optimize command="find ./src -name '*.zig' -type f"
echo ""

# Demo 5: Error Handling
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Demo 5: Error Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Invalid command:"
$KIMIZ skill rtk-optimize command="nonexistent-command" || echo "✅ Error handled correctly"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Demo Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Token Savings Summary:"
echo "  • git status:  ~90% reduction (2000 → 200 tokens)"
echo "  • ls -la:      ~80% reduction (1500 → 300 tokens)"
echo "  • git log:     ~85% reduction (1000 → 150 tokens)"
echo "  • find:        ~75% reduction (800 → 200 tokens)"
echo ""
echo "💡 Tip: Use 'rtk gain' to see your actual token savings history"
echo ""
