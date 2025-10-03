#!/usr/bin/env python3
"""
NenDB vs KuzuDB Performance Comparison
=====================================

This script benchmarks NenDB against KuzuDB for various graph operations.
"""

import time
import random
import statistics
import kuzu
import requests
import json
from typing import List, Tuple, Dict

class KuzuBenchmark:
    """Benchmark KuzuDB performance"""
    
    def __init__(self, db_path: str = "kuzu_benchmark.db"):
        self.db = kuzu.Database(db_path)
        self.conn = kuzu.Connection(self.db)
        
    def setup_schema(self):
        """Create basic graph schema"""
        self.conn.execute("CREATE NODE TABLE Person(id INT64, name STRING, PRIMARY KEY(id))")
        self.conn.execute("CREATE REL TABLE KNOWS(FROM Person TO Person, since INT64)")
        
    def insert_nodes(self, count: int) -> float:
        """Insert nodes and measure time"""
        start_time = time.time()
        
        for i in range(count):
            self.conn.execute(f"CREATE (p:Person {{id: {i}, name: 'Person{i}'}})")
            
        end_time = time.time()
        return end_time - start_time
        
    def insert_edges(self, count: int) -> float:
        """Insert edges and measure time"""
        start_time = time.time()
        
        for i in range(count):
            # Create random connections
            from_id = random.randint(0, count - 1)
            to_id = random.randint(0, count - 1)
            if from_id != to_id:
                self.conn.execute(f"""
                    MATCH (p1:Person {{id: {from_id}}}), (p2:Person {{id: {to_id}}})
                    CREATE (p1)-[:KNOWS {{since: {i}}}]->(p2)
                """)
                
        end_time = time.time()
        return end_time - start_time
        
    def traverse_graph(self, hops: int) -> float:
        """Perform graph traversal and measure time"""
        start_time = time.time()
        
        result = self.conn.execute(f"""
            MATCH (p1:Person)-[:KNOWS*1..{hops}]->(p2:Person)
            RETURN p1.id, p2.id
            LIMIT 1000
        """)
        
        # Consume the result
        results = result.get_as_df()
        
        end_time = time.time()
        return end_time - start_time

class NenDBBenchmark:
    """Benchmark NenDB performance via HTTP API"""
    
    def __init__(self, base_url: str = "http://localhost:8080"):
        self.base_url = base_url
        
    def check_health(self) -> bool:
        """Check if NenDB server is running"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
            
    def get_stats(self) -> Dict:
        """Get database statistics"""
        response = requests.get(f"{self.base_url}/graph/stats")
        return response.json()
        
    def run_algorithm(self, algorithm: str) -> float:
        """Run graph algorithm and measure time"""
        start_time = time.time()
        
        response = requests.post(f"{self.base_url}/graph/algorithms/{algorithm}")
        
        end_time = time.time()
        return end_time - start_time

def run_benchmarks():
    """Run comprehensive benchmarks"""
    print("🚀 NenDB vs KuzuDB Performance Comparison")
    print("=" * 50)
    
    # Initialize benchmarks
    kuzu_bench = KuzuBenchmark()
    nendb_bench = NenDBBenchmark()
    
    # Check NenDB availability
    if not nendb_bench.check_health():
        print("❌ NenDB server not running. Please start with: nendb serve")
        return
        
    print("✅ NenDB server is running")
    
    # Setup KuzuDB
    print("\n📊 Setting up KuzuDB...")
    kuzu_bench.setup_schema()
    
    # Test datasets
    test_sizes = [100, 1000, 5000]
    
    results = {
        'kuzu': {},
        'nendb': {}
    }
    
    for size in test_sizes:
        print(f"\n🔬 Testing with {size} nodes...")
        
        # KuzuDB benchmarks
        print("  📈 KuzuDB node insertion...")
        kuzu_node_time = kuzu_bench.insert_nodes(size)
        
        print("  📈 KuzuDB edge insertion...")
        kuzu_edge_time = kuzu_bench.insert_edges(size * 2)
        
        print("  📈 KuzuDB graph traversal...")
        kuzu_traverse_time = kuzu_bench.traverse_graph(2)
        
        # NenDB benchmarks
        print("  📈 NenDB algorithm execution...")
        nendb_bfs_time = nendb_bench.run_algorithm("bfs")
        nendb_dijkstra_time = nendb_bench.run_algorithm("dijkstra")
        nendb_pagerank_time = nendb_bench.run_algorithm("pagerank")
        
        # Store results
        results['kuzu'][size] = {
            'node_insertion': kuzu_node_time,
            'edge_insertion': kuzu_edge_time,
            'traversal': kuzu_traverse_time
        }
        
        results['nendb'][size] = {
            'bfs': nendb_bfs_time,
            'dijkstra': nendb_dijkstra_time,
            'pagerank': nendb_pagerank_time
        }
        
        print(f"    KuzuDB: {kuzu_node_time:.3f}s nodes, {kuzu_edge_time:.3f}s edges")
        print(f"    NenDB:  {nendb_bfs_time:.3f}s BFS, {nendb_dijkstra_time:.3f}s Dijkstra")
    
    # Print summary
    print("\n📊 Performance Summary")
    print("=" * 30)
    
    for size in test_sizes:
        print(f"\nDataset size: {size} nodes")
        print(f"KuzuDB - Node insertion: {results['kuzu'][size]['node_insertion']:.3f}s")
        print(f"NenDB  - BFS algorithm:  {results['nendb'][size]['bfs']:.3f}s")
    
    # Get final stats
    nendb_stats = nendb_bench.get_stats()
    print(f"\n📈 NenDB Final Stats:")
    print(f"  Nodes: {nendb_stats.get('nodes', 0)}")
    print(f"  Edges: {nendb_stats.get('edges', 0)}")
    print(f"  Utilization: {nendb_stats.get('utilization', 0):.2f}%")

if __name__ == "__main__":
    run_benchmarks()
