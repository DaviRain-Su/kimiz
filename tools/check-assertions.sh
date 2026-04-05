#!/usr/bin/env bash
# Assertion Density Checker - TigerBeetle Standard
# Target: 1.5 assertions per function

set -e

MIN_DENSITY=${1:-1.5}
DIR=${2:-src}
CI_MODE=${CI_MODE:-false}

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Assertion Density Report - TigerBeetle Standard ($MIN_DENSITY/fn)  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

total_files=0
total_functions=0
total_asserts=0
files_above=0
files_below=0

declare -a files_data

while IFS= read -r file; do
    # Skip test files
    if [[ "$file" == *"test"* ]]; then
        continue
    fi
    
    fns=$(grep -c "^[[:space:]]*\(pub \)\?fn " "$file" 2>/dev/null || echo 0)
    asserts=$(grep -c "assert(" "$file" 2>/dev/null || echo 0)
    
    if [ "$fns" -eq 0 ]; then
        continue
    fi
    
    density=$(echo "scale=2; $asserts / $fns" | bc -l)
    
    total_files=$((total_files + 1))
    total_functions=$((total_functions + fns))
    total_asserts=$((total_asserts + asserts))
    
    if [ $(echo "$density >= $MIN_DENSITY" | bc -l) -eq 1 ]; then
        files_above=$((files_above + 1))
    else
        files_below=$((files_below + 1))
    fi
    
    files_data+=("$file|$fns|$asserts|$density")
done < <(find "$DIR" -name "*.zig" -type f)

overall_density=$(echo "scale=2; $total_asserts / $total_functions" | bc -l)
percent_of_target=$(echo "scale=1; ($overall_density / $MIN_DENSITY) * 100" | bc -l)

echo "📊 Overall Statistics:"
echo "  Total Files:      $total_files"
echo "  Total Functions:  $total_functions"
echo "  Total Asserts:    $total_asserts"
echo "  Average Density:  ${overall_density}/fn (${percent_of_target}% of target)"
echo ""

if [ $(echo "$overall_density >= $MIN_DENSITY" | bc -l) -eq 1 ]; then
    echo "✅ TARGET MET! Average density exceeds ${MIN_DENSITY}/fn"
    EXIT_CODE=0
else
    gap=$(echo "scale=0; ($total_functions * $MIN_DENSITY) - $total_asserts" | bc -l)
    echo "❌ TARGET NOT MET! Need $gap more asserts to reach ${MIN_DENSITY}/fn"
    EXIT_CODE=1
fi
echo ""

echo "🌟 Files Exceeding Target ($files_above):"
for data in "${files_data[@]}"; do
    IFS='|' read -r file fns asserts density <<< "$data"
    if [ $(echo "$density >= $MIN_DENSITY" | bc -l) -eq 1 ]; then
        echo "  ✅ $file: $fns fns, $asserts asserts (${density}/fn)"
    fi
done

echo ""
echo "⚠️  Files Below Target ($files_below):"
for data in "${files_data[@]}"; do
    IFS='|' read -r file fns asserts density <<< "$data"
    if [ $(echo "$density < $MIN_DENSITY" | bc -l) -eq 1 ]; then
        needed=$(echo "scale=0; ($fns * $MIN_DENSITY) - $asserts" | bc -l)
        echo "  ❌ $file: $fns fns, $asserts asserts (${density}/fn, need +$needed)"
    fi
done
echo ""

exit $EXIT_CODE
