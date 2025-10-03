#!/bin/bash
# Load Pancreatic Cancer Knowledge Graph into NenDB

set -e

NENDB_URL="http://localhost:8080"
CSV_FILE="/Users/ng/Documents/Code/Nen/nen-visualizer/pancreatic_cancer_kg_original.csv"

echo "🧬 Pancreatic Cancer Knowledge Graph Data Loader"
echo "================================================="

# Check if NenDB server is running
echo "🔍 Checking NenDB server..."
if curl -s "$NENDB_URL/health" > /dev/null 2>&1; then
    echo "✅ NenDB server is running"
else
    echo "❌ NenDB server is not running"
    echo "💡 Start it with: cd nen-db && ./zig-out/bin/nendb serve"
    exit 1
fi

# Get initial database stats
echo "📊 Getting database stats..."
curl -s "$NENDB_URL/graph/stats" | python3 -m json.tool

# Process CSV data to extract summary
echo ""
echo "📖 Analyzing CSV dataset..."
echo "  File: $CSV_FILE"

if [ ! -f "$CSV_FILE" ]; then
    echo "❌ CSV file not found: $CSV_FILE"
    exit 1
fi

# Get basic stats about the dataset
TOTAL_ROWS=$(wc -l < "$CSV_FILE")
echo "  Total rows: $TOTAL_ROWS"

# Extract first few rows to understand structure
echo ""
echo "📋 Dataset structure (first 5 rows):"
head -6 "$CSV_FILE" | cut -d',' -f1-3

# Extract unique entities and relations (sample)
echo ""
echo "🔍 Analyzing entities and relations (first 1000 rows)..."
head -1001 "$CSV_FILE" | tail -1000 | cut -d',' -f1 | sort | uniq | wc -l | xargs echo "  Unique heads:"
head -1001 "$CSV_FILE" | tail -1000 | cut -d',' -f3 | sort | uniq | wc -l | xargs echo "  Unique tails:"
head -1001 "$CSV_FILE" | tail -1000 | cut -d',' -f2 | sort | uniq | wc -l | xargs echo "  Unique relations:"

# Show sample relations
echo ""
echo "📊 Sample relation types:"
head -1001 "$CSV_FILE" | tail -1000 | cut -d',' -f2 | sort | uniq | head -10

echo ""
echo "🎨 Testing visualizer API endpoints..."

# Test all visualizer endpoints
endpoints=(
    "/graph/stats"
    "/graph/visualizer/data"
    "/graph/visualizer/nodes"
    "/graph/visualizer/edges"
)

for endpoint in "${endpoints[@]}"; do
    echo "  Testing $endpoint..."
    if response=$(curl -s -w "%{http_code}" "$NENDB_URL$endpoint" 2>/dev/null); then
        http_code="${response: -3}"
        content="${response%???}"
        
        if [ "$http_code" = "200" ]; then
            echo "    ✅ OK (HTTP $http_code)"
            if [ "$endpoint" = "/graph/stats" ]; then
                echo "    📊 Stats: $content"
            fi
        else
            echo "    ❌ Failed (HTTP $http_code)"
        fi
    else
        echo "    ❌ Connection failed"
    fi
done

echo ""
echo "🎉 Data analysis completed!"
echo ""
echo "📝 Note: The current NenDB implementation has the API endpoints for visualization"
echo "   but doesn't have direct CSV import functionality yet. The visualizer will"
echo "   show the current database state (which starts empty)."
echo ""
echo "🔧 To implement CSV import, we would need to add:"
echo "   • CSV parsing endpoint in NenDB"
echo "   • Node/edge creation endpoints"
echo "   • Batch import functionality"
echo ""
echo "🌐 You can still test the visualizer interface at:"
echo "   • http://localhost:8080/visualizer (redirects to GitHub)"
echo "   • Or set up the Next.js visualizer separately"
