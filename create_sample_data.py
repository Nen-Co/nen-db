#!/usr/bin/env python3
"""
Create sample pancreatic cancer knowledge graph data for testing the visualizer
"""

import requests
import json
import time

# Configuration
NENDB_URL = "http://localhost:8080"

def create_sample_data():
    """Create sample pancreatic cancer knowledge graph data"""
    
    # Sample pancreatic cancer knowledge graph data
    sample_data = {
        "nodes": [
            {"id": "pancreatic_cancer", "label": "Pancreatic Cancer", "group": "disease"},
            {"id": "KRAS", "label": "KRAS", "group": "gene"},
            {"id": "TP53", "label": "TP53", "group": "gene"},
            {"id": "BRCA2", "label": "BRCA2", "group": "gene"},
            {"id": "CDKN2A", "label": "CDKN2A", "group": "gene"},
            {"id": "SMAD4", "label": "SMAD4", "group": "gene"},
            {"id": "erlotinib", "label": "Erlotinib", "group": "drug"},
            {"id": "gemcitabine", "label": "Gemcitabine", "group": "drug"},
            {"id": "chemotherapy", "label": "Chemotherapy", "group": "treatment"},
            {"id": "metastasis", "label": "Metastasis", "group": "process"},
            {"id": "apoptosis", "label": "Apoptosis", "group": "process"},
            {"id": "MAPK_pathway", "label": "MAPK Pathway", "group": "pathway"},
            {"id": "diabetes", "label": "Diabetes", "group": "comorbidity"},
            {"id": "jaundice", "label": "Jaundice", "group": "symptom"},
            {"id": "pain", "label": "Pain", "group": "symptom"},
            {"id": "CA19-9", "label": "CA19-9", "group": "biomarker"},
            {"id": "insulin", "label": "Insulin", "group": "hormone"},
            {"id": "TGF-beta", "label": "TGF-β", "group": "protein"},
            {"id": "cell_cycle", "label": "Cell Cycle", "group": "process"}
        ],
        "edges": [
            {"source": "pancreatic_cancer", "target": "KRAS", "label": "mutated_in"},
            {"source": "pancreatic_cancer", "target": "TP53", "label": "mutated_in"},
            {"source": "pancreatic_cancer", "target": "BRCA2", "label": "mutated_in"},
            {"source": "pancreatic_cancer", "target": "CDKN2A", "label": "mutated_in"},
            {"source": "pancreatic_cancer", "target": "SMAD4", "label": "mutated_in"},
            {"source": "KRAS", "target": "MAPK_pathway", "label": "activates"},
            {"source": "TP53", "target": "apoptosis", "label": "regulates"},
            {"source": "BRCA2", "target": "erlotinib", "label": "interacts_with"},
            {"source": "CDKN2A", "target": "MAPK_pathway", "label": "inhibits"},
            {"source": "SMAD4", "target": "TP53", "label": "underexpressed_in"},
            {"source": "erlotinib", "target": "metastasis", "label": "inhibits"},
            {"source": "gemcitabine", "target": "cell_cycle", "label": "biomarker_for"},
            {"source": "chemotherapy", "target": "apoptosis", "label": "suppresses"},
            {"source": "metastasis", "target": "MAPK_pathway", "label": "treats"},
            {"source": "metastasis", "target": "apoptosis", "label": "mutated_in"},
            {"source": "diabetes", "target": "erlotinib", "label": "suppresses"},
            {"source": "jaundice", "target": "pain", "label": "activates"},
            {"source": "insulin", "target": "CA19-9", "label": "biomarker_for"},
            {"source": "insulin", "target": "apoptosis", "label": "underexpressed_in"},
            {"source": "TGF-beta", "target": "KRAS", "label": "inhibits"},
            {"source": "cell_cycle", "target": "CA19-9", "label": "treats"},
            {"source": "pancreatic_cancer", "target": "diabetes", "label": "associated_with"},
            {"source": "pancreatic_cancer", "target": "jaundice", "label": "causes"},
            {"source": "pancreatic_cancer", "target": "CA19-9", "label": "biomarker_for"}
        ],
        "metadata": {
            "node_count": 19,
            "edge_count": 24,
            "utilization": 15.2
        }
    }
    
    return sample_data

def test_api_endpoints():
    """Test all API endpoints"""
    print("🧪 Testing API endpoints...")
    
    endpoints = [
        ("/health", "GET"),
        ("/graph/stats", "GET"),
        ("/graph/visualizer/data", "GET"),
        ("/graph/visualizer/nodes", "GET"),
        ("/graph/visualizer/edges", "GET"),
        ("/import/csv", "POST")
    ]
    
    for endpoint, method in endpoints:
        try:
            if method == "GET":
                response = requests.get(f"{NENDB_URL}{endpoint}", timeout=5)
            else:
                response = requests.post(f"{NENDB_URL}{endpoint}", timeout=5)
            
            if response.status_code == 200:
                print(f"✅ {method} {endpoint}: OK")
                if endpoint == "/graph/stats":
                    print(f"   Stats: {response.json()}")
            else:
                print(f"❌ {method} {endpoint}: HTTP {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"❌ {method} {endpoint}: Connection error - {e}")

def main():
    """Main function"""
    print("🧬 Pancreatic Cancer Knowledge Graph - Sample Data Creator")
    print("=" * 60)
    
    # Test API endpoints
    test_api_endpoints()
    
    print("\n📊 Sample Data Structure:")
    sample_data = create_sample_data()
    
    print(f"  • Nodes: {len(sample_data['nodes'])}")
    print(f"  • Edges: {len(sample_data['edges'])}")
    print(f"  • Node groups: {set(node['group'] for node in sample_data['nodes'])}")
    print(f"  • Edge types: {set(edge['label'] for edge in sample_data['edges'])}")
    
    print("\n🎨 Visualizer Testing:")
    print("  • Next.js Visualizer: http://localhost:3000")
    print("  • NenDB Server: http://localhost:8080")
    print("  • Redirect Page: http://localhost:8080/visualizer")
    
    print("\n📝 Note: The current NenDB implementation shows the database state")
    print("   (which starts empty). To see the sample data, we would need to")
    print("   implement CSV import or node/edge creation endpoints in NenDB.")
    
    print("\n🔧 Next Steps:")
    print("  1. Implement CSV import in NenDB")
    print("  2. Add node/edge creation endpoints")
    print("  3. Load the full pancreatic cancer dataset")
    print("  4. Test visualization with real data")

if __name__ == "__main__":
    main()
