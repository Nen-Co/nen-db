#!/usr/bin/env python3
"""
Update NenDB API to use the full pancreatic cancer dataset
This script will modify the Zig code to include the full dataset
"""

import json
import os

def update_nendb_api():
    """Update the NenDB API to use the full dataset"""
    
    # Read the full dataset
    with open('/Users/ng/Documents/Code/Nen/nen-db/pancreatic_cancer_full_data.json', 'r') as f:
        data = json.load(f)
    
    # Create the JSON response string for Zig
    nodes_json = json.dumps(data['nodes'], separators=(',', ':'))
    edges_json = json.dumps(data['edges'], separators=(',', ':'))
    
    # Create the full JSON response
    full_json = json.dumps({
        'nodes': data['nodes'],
        'edges': data['edges'],
        'metadata': data['metadata']
    }, separators=(',', ':'))
    
    print("✅ Full dataset loaded and prepared for NenDB API")
    print(f"📊 Dataset stats:")
    print(f"  • Nodes: {len(data['nodes'])}")
    print(f"  • Edges: {len(data['edges'])}")
    print(f"  • Entity groups: {data['metadata']['entity_groups']}")
    print(f"  • Top relations: {list(data['metadata']['relation_types'].keys())[:5]}")
    
    # Save the JSON string for manual insertion into Zig code
    with open('/Users/ng/Documents/Code/Nen/nen-db/full_data_json.txt', 'w') as f:
        f.write(full_json)
    
    print(f"\n💾 Full JSON data saved to: /Users/ng/Documents/Code/Nen/nen-db/full_data_json.txt")
    print(f"📝 Next step: Update the Zig code to use this data")
    
    return full_json

if __name__ == "__main__":
    update_nendb_api()
