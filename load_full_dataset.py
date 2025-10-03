#!/usr/bin/env python3
"""
Load Full Pancreatic Cancer Knowledge Graph Dataset
Process the 1.4M relationships and prepare for visualization
"""

import csv
import json
import time
from collections import defaultdict
from typing import Dict, Set, List, Tuple

CSV_FILE = "/Users/ng/Documents/Code/Nen/nen-visualizer/pancreatic_cancer_kg_original.csv"
OUTPUT_FILE = "/Users/ng/Documents/Code/Nen/nen-db/pancreatic_cancer_full_data.json"
MAX_SAMPLE_SIZE = 50000  # Limit for initial visualization (can be increased)

def process_full_dataset():
    """Process the full pancreatic cancer dataset and create visualization-ready data"""
    
    print("🧬 Processing Full Pancreatic Cancer Knowledge Graph Dataset")
    print("=" * 60)
    
    entities = set()
    relationships = []
    entity_groups = defaultdict(set)
    relation_types = defaultdict(int)
    
    print(f"📖 Reading CSV file: {CSV_FILE}")
    print("⏳ Processing relationships...")
    
    start_time = time.time()
    processed_count = 0
    
    with open(CSV_FILE, 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        
        for row in reader:
            if processed_count >= MAX_SAMPLE_SIZE:
                break
                
            head = row['head'].strip()
            tail = row['tail'].strip()
            relation = row['relation'].strip()
            sentence = row.get('sentence', '').strip()
            attention_score = float(row.get('attention_score', 0))
            
            # Add entities
            entities.add(head)
            entities.add(tail)
            
            # Determine entity groups based on common patterns
            if any(keyword in head.lower() for keyword in ['cancer', 'tumor', 'carcinoma']):
                entity_groups['disease'].add(head)
            elif any(keyword in head.lower() for keyword in ['gene', 'protein', 'enzyme']):
                entity_groups['gene'].add(head)
            elif any(keyword in head.lower() for keyword in ['drug', 'therapy', 'treatment']):
                entity_groups['drug'].add(head)
            elif any(keyword in head.lower() for keyword in ['pathway', 'signaling']):
                entity_groups['pathway'].add(head)
            elif any(keyword in head.lower() for keyword in ['symptom', 'pain', 'jaundice']):
                entity_groups['symptom'].add(head)
            else:
                entity_groups['other'].add(head)
                
            if any(keyword in tail.lower() for keyword in ['cancer', 'tumor', 'carcinoma']):
                entity_groups['disease'].add(tail)
            elif any(keyword in tail.lower() for keyword in ['gene', 'protein', 'enzyme']):
                entity_groups['gene'].add(tail)
            elif any(keyword in tail.lower() for keyword in ['drug', 'therapy', 'treatment']):
                entity_groups['drug'].add(tail)
            elif any(keyword in tail.lower() for keyword in ['pathway', 'signaling']):
                entity_groups['pathway'].add(tail)
            elif any(keyword in tail.lower() for keyword in ['symptom', 'pain', 'jaundice']):
                entity_groups['symptom'].add(tail)
            else:
                entity_groups['other'].add(tail)
            
            relationships.append({
                'source': head,
                'target': tail,
                'label': relation,
                'sentence': sentence,
                'attention_score': attention_score
            })
            
            relation_types[relation] += 1
            processed_count += 1
            
            if processed_count % 10000 == 0:
                elapsed = time.time() - start_time
                rate = processed_count / elapsed
                print(f"  Processed {processed_count:,} relationships ({rate:.0f}/sec)")
    
    elapsed = time.time() - start_time
    print(f"✅ Processing completed in {elapsed:.2f} seconds")
    
    # Create entity ID mapping
    entity_to_id = {entity: i + 1 for i, entity in enumerate(sorted(entities))}
    
    # Create nodes data
    nodes = []
    for entity in sorted(entities):
        # Determine group for entity
        group = 'other'
        for group_name, group_entities in entity_groups.items():
            if entity in group_entities:
                group = group_name
                break
        
        nodes.append({
            'id': entity,
            'label': entity,
            'group': group
        })
    
    # Create edges data
    edges = []
    for rel in relationships:
        edges.append({
            'source': rel['source'],
            'target': rel['target'],
            'label': rel['label'],
            'attention_score': rel['attention_score']
        })
    
    # Create final data structure
    graph_data = {
        'nodes': nodes,
        'edges': edges,
        'metadata': {
            'node_count': len(nodes),
            'edge_count': len(edges),
            'total_entities': len(entities),
            'total_relationships': processed_count,
            'relation_types': dict(relation_types),
            'entity_groups': {k: len(v) for k, v in entity_groups.items()},
            'sample_size': MAX_SAMPLE_SIZE,
            'utilization': (len(nodes) + len(edges)) / 100000 * 100  # Mock utilization
        }
    }
    
    # Save to JSON file
    print(f"💾 Saving processed data to: {OUTPUT_FILE}")
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(graph_data, f, indent=2, ensure_ascii=False)
    
    # Print summary
    print(f"\n📊 Dataset Summary:")
    print(f"  • Total entities: {len(entities):,}")
    print(f"  • Total relationships processed: {processed_count:,}")
    print(f"  • Unique relation types: {len(relation_types)}")
    print(f"  • Entity groups: {dict(entity_groups)}")
    print(f"\n🔝 Top 10 Relation Types:")
    for rel_type, count in sorted(relation_types.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"    {rel_type}: {count:,}")
    
    print(f"\n🎯 Ready for visualization!")
    print(f"  • Nodes: {len(nodes):,}")
    print(f"  • Edges: {len(edges):,}")
    print(f"  • Data saved to: {OUTPUT_FILE}")
    
    return graph_data

def main():
    """Main function"""
    try:
        graph_data = process_full_dataset()
        print(f"\n🎉 Full dataset processing completed successfully!")
        print(f"🌐 Ready to update NenDB API with full dataset")
    except Exception as e:
        print(f"❌ Error processing dataset: {e}")
        return 1
    return 0

if __name__ == "__main__":
    exit(main())
