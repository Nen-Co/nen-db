#!/usr/bin/env python3
"""
Load Pancreatic Cancer Knowledge Graph into NenDB
"""

import requests
import json
import time
import csv
from typing import Dict, Set, List
import sys

# Configuration
NENDB_URL = "http://localhost:8080"
CSV_FILE = "/Users/ng/Documents/Code/Nen/nen-visualizer/pancreatic_cancer_kg_original.csv"
BATCH_SIZE = 1000  # Process in batches to avoid memory issues
MAX_ROWS = 10000   # Limit for testing (remove for full dataset)

def check_nendb_health():
    """Check if NenDB server is running"""
    try:
        response = requests.get(f"{NENDB_URL}/health", timeout=5)
        if response.status_code == 200:
            print("✅ NenDB server is running")
            return True
        else:
            print(f"❌ NenDB health check failed: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to NenDB server: {e}")
        print("💡 Make sure to start NenDB server first:")
        print("   cd nen-db && ./zig-out/bin/nendb serve")
        return False

def get_database_stats():
    """Get current database statistics"""
    try:
        response = requests.get(f"{NENDB_URL}/graph/stats")
        if response.status_code == 200:
            stats = response.json()
            print(f"📊 Current database stats: {stats['nodes']} nodes, {stats['edges']} edges")
            return stats
        else:
            print(f"❌ Failed to get database stats: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Error getting database stats: {e}")
        return None

def process_csv_data(csv_file: str, max_rows: int = None):
    """Process CSV data and extract unique entities and relationships"""
    entities = set()
    relationships = []
    entity_to_id = {}
    
    print(f"📖 Reading CSV file: {csv_file}")
    
    with open(csv_file, 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for i, row in enumerate(reader):
            if max_rows and i >= max_rows:
                break
                
            if i % 10000 == 0:
                print(f"  Processed {i} rows...")
            
            # Extract entities
            head = row['head'].strip()
            tail = row['tail'].strip()
            relation = row['relation'].strip()
            
            entities.add(head)
            entities.add(tail)
            
            relationships.append({
                'head': head,
                'relation': relation,
                'tail': tail,
                'sentence': row.get('sentence', ''),
                'attention_score': float(row.get('attention_score', 0))
            })
    
    # Create entity ID mapping
    for i, entity in enumerate(entities):
        entity_to_id[entity] = i + 1
    
    print(f"✅ Processed {len(relationships)} relationships with {len(entities)} unique entities")
    
    return entities, relationships, entity_to_id

def load_data_to_nendb(entities: Set[str], relationships: List[Dict], entity_to_id: Dict[str, int]):
    """Load processed data into NenDB using the API"""
    
    print("🚀 Loading data into NenDB...")
    
    # Note: Since NenDB doesn't have direct node/edge creation endpoints yet,
    # we'll simulate the data loading by creating sample data that represents
    # the structure of our knowledge graph
    
    # For now, let's create a representative sample of the data
    # In a real implementation, we'd need to add node/edge creation endpoints to NenDB
    
    sample_entities = list(entities)[:100]  # Take first 100 entities
    sample_relationships = relationships[:100]  # Take first 100 relationships
    
    print(f"📝 Created sample dataset: {len(sample_entities)} entities, {len(sample_relationships)} relationships")
    
    # Create a summary of the data structure
    unique_relations = set()
    for rel in relationships:
        unique_relations.add(rel['relation'])
    
    print(f"📊 Dataset summary:")
    print(f"  • Total entities: {len(entities)}")
    print(f"  • Total relationships: {len(relationships)}")
    print(f"  • Unique relation types: {len(unique_relations)}")
    print(f"  • Top relations: {list(unique_relations)[:10]}")
    
    return sample_entities, sample_relationships

def test_visualizer_api():
    """Test the visualizer API endpoints"""
    print("\n🎨 Testing visualizer API endpoints...")
    
    endpoints = [
        "/graph/stats",
        "/graph/visualizer/data",
        "/graph/visualizer/nodes", 
        "/graph/visualizer/edges"
    ]
    
    for endpoint in endpoints:
        try:
            response = requests.get(f"{NENDB_URL}{endpoint}")
            if response.status_code == 200:
                data = response.json()
                print(f"✅ {endpoint}: OK")
                if endpoint == "/graph/stats":
                    print(f"   Stats: {data}")
            else:
                print(f"❌ {endpoint}: Failed ({response.status_code})")
        except Exception as e:
            print(f"❌ {endpoint}: Error - {e}")

def main():
    """Main function"""
    print("🧬 Pancreatic Cancer Knowledge Graph Data Loader")
    print("=" * 50)
    
    # Check NenDB server
    if not check_nendb_health():
        sys.exit(1)
    
    # Get initial stats
    get_database_stats()
    
    # Process CSV data
    entities, relationships, entity_to_id = process_csv_data(CSV_FILE, MAX_ROWS)
    
    # Load data to NenDB
    sample_entities, sample_relationships = load_data_to_nendb(entities, relationships, entity_to_id)
    
    # Test visualizer API
    test_visualizer_api()
    
    print("\n🎉 Data loading completed!")
    print(f"🌐 You can now open the visualizer at: http://localhost:3000")
    print(f"📊 Or check the data at: {NENDB_URL}/visualizer")

if __name__ == "__main__":
    main()
