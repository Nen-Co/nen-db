# 🎨 NenDB Graph Visualizer

> **Interactive web-based graph visualization for NenDB embedded database**

## 🚀 Quick Start

### 1. Start NenDB Server with Visualizer

```bash
# Build NenDB
zig build

# Start the HTTP server
./zig-out/bin/nendb serve
```

### 2. Open the Visualizer

Open your browser and navigate to:
```
http://localhost:8080/visualizer
```

### 3. View Your Graph

The visualizer will automatically load your graph data and display it with:
- **Interactive nodes** that you can drag around
- **Zoom and pan** functionality
- **Real-time statistics** in the sidebar
- **Force-directed layout** for optimal visualization

## ✨ Features

### 🎯 **Core Visualization**
- **Interactive Graph**: Drag nodes, zoom, and pan
- **Force-Directed Layout**: Automatic positioning using D3.js physics simulation
- **Real-time Updates**: Refresh button to reload latest data
- **Responsive Design**: Works on desktop and mobile devices

### 📊 **Data Display**
- **Node Information**: Shows node IDs and labels
- **Edge Relationships**: Displays connections between nodes
- **Database Statistics**: Live node/edge counts and utilization
- **Metadata Display**: Shows graph properties and metrics

### 🎨 **Visual Features**
- **Modern UI**: Clean, professional interface
- **Color-coded Elements**: Different colors for nodes and edges
- **Smooth Animations**: Fluid transitions and interactions
- **Accessible Design**: Keyboard navigation and screen reader support

## 🔌 API Endpoints

The visualizer uses these HTTP endpoints:

### Graph Data API
```
GET /graph/visualizer/data
```
Returns complete graph data in JSON format:
```json
{
  "nodes": [...],
  "edges": [...],
  "metadata": {
    "node_count": 15,
    "edge_count": 23,
    "utilization": 45.67
  }
}
```

### Individual Data APIs
```
GET /graph/visualizer/nodes    # Node data only
GET /graph/visualizer/edges    # Edge data only
GET /graph/stats               # Database statistics
```

### Visualizer Interface
```
GET /visualizer                # HTML interface
```

## 🛠️ Technical Details

### Architecture
- **Frontend**: Modern HTML5 + CSS3 + JavaScript (ES6+)
- **Visualization**: D3.js v7 for graph rendering and physics simulation
- **Backend**: NenDB HTTP server with CORS support
- **Data Format**: JSON with nodes and edges arrays

### Data Structure
```typescript
interface GraphData {
  nodes: Array<{
    id: string | number;
    label?: string;
    group?: string;
    x?: number;
    y?: number;
  }>;
  edges: Array<{
    source: string | number;
    target: string | number;
    label?: string;
    weight?: number;
  }>;
  metadata: {
    node_count: number;
    edge_count: number;
    utilization: number;
  };
}
```

### Performance
- **Static Memory**: Uses NenDB's efficient SoA layout
- **Batch Processing**: Optimized data export
- **Client-side Rendering**: Smooth 60fps interactions
- **Memory Efficient**: Handles graphs with thousands of nodes

## 🎮 Usage Examples

### Basic Usage
1. Start NenDB server: `./zig-out/bin/nendb serve`
2. Open visualizer: `http://localhost:8080/visualizer`
3. Click "🔄 Refresh Graph" to load data
4. Drag nodes to rearrange the layout
5. Use mouse wheel to zoom in/out

### Advanced Features
- **Node Selection**: Click on nodes to highlight them
- **Edge Inspection**: Hover over edges to see relationships
- **Layout Control**: Use the physics simulation controls
- **Export Options**: Save graph as SVG or PNG (coming soon)

## 🔧 Customization

### Styling
The visualizer uses CSS custom properties for easy theming:
```css
:root {
  --primary-color: #007bff;
  --secondary-color: #6c757d;
  --background-color: #f8f9fa;
  --text-color: #495057;
}
```

### Node Colors
Nodes are colored based on their `kind` property:
- **Kind 1** (Users): Blue (`#007bff`)
- **Kind 2** (Products): Green (`#28a745`)
- **Kind 3** (Companies): Orange (`#fd7e14`)

### Layout Parameters
Adjust the force simulation parameters:
```javascript
simulation
  .force('link', d3.forceLink().distance(100))
  .force('charge', d3.forceManyBody().strength(-300))
  .force('center', d3.forceCenter(width/2, height/2));
```

## 📚 Integration Examples

### Python Integration
```python
import requests
import json

# Connect to NenDB server
response = requests.get('http://localhost:8080/graph/visualizer/data')
graph_data = response.json()

print(f"Graph has {len(graph_data['nodes'])} nodes and {len(graph_data['edges'])} edges")
```

### JavaScript Integration
```javascript
// Load graph data
async function loadGraph() {
  const response = await fetch('/graph/visualizer/data');
  const data = await response.json();
  
  // Process the data
  console.log('Nodes:', data.nodes);
  console.log('Edges:', data.edges);
}
```

### WASM Integration
```javascript
// Using NenDB WASM module
import NenDB from './nendb-wasm.js';

const db = await NenDB.loadFromURL('./nendb-wasm.wasm');
const nodeId = db.addNode(123);
const edgeId = db.addEdge(123, 456, 1.0);

// View in visualizer
window.open('http://localhost:8080/visualizer');
```

## 🚧 Roadmap

### Planned Features
- **Real-time Updates**: WebSocket integration for live data
- **Advanced Filtering**: Filter nodes/edges by properties
- **Multiple Layouts**: Hierarchical, circular, and custom layouts
- **Export Options**: PNG, SVG, and JSON export
- **Performance Optimization**: Large graph handling (10k+ nodes)
- **Mobile Support**: Touch gestures and responsive design

### Future Enhancements
- **Graph Algorithms**: Visualize BFS, Dijkstra, PageRank results
- **Community Detection**: Highlight clusters and communities
- **Time-based Visualization**: Animate graph evolution over time
- **3D Visualization**: Three-dimensional graph rendering
- **Collaborative Features**: Multi-user editing and annotation

## 🐛 Troubleshooting

### Common Issues

**Visualizer not loading**
- Ensure NenDB server is running on port 8080
- Check browser console for JavaScript errors
- Verify CORS headers are enabled

**No data displayed**
- Check if database has nodes and edges
- Click "🔄 Refresh Graph" button
- Verify API endpoints are responding

**Performance issues**
- Reduce graph size for better performance
- Close other browser tabs
- Use hardware acceleration in browser

### Debug Mode
Enable debug logging in browser console:
```javascript
localStorage.setItem('debug', 'true');
// Reload the page
```

## 📖 API Reference

### GET /graph/visualizer/data
Returns complete graph data for visualization.

**Response:**
```json
{
  "nodes": [
    {"id": 1, "label": "Alice", "group": "user"},
    {"id": 101, "label": "Laptop", "group": "product"}
  ],
  "edges": [
    {"source": 1, "target": 101, "label": "purchased"}
  ],
  "metadata": {
    "node_count": 2,
    "edge_count": 1,
    "utilization": 12.5
  }
}
```

### GET /graph/visualizer/nodes
Returns only node data.

### GET /graph/visualizer/edges
Returns only edge data.

### GET /graph/stats
Returns database statistics.

## 🤝 Contributing

We welcome contributions to the graph visualizer! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and test thoroughly
4. **Commit your changes**: `git commit -m 'Add amazing feature'`
5. **Push to the branch**: `git push origin feature/amazing-feature`
6. **Open a Pull Request**

### Development Setup
```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-db.git
cd nen-db

# Build the project
zig build

# Run tests
zig build test

# Start development server
./zig-out/bin/nendb serve
```

## 📄 License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **D3.js** for the powerful visualization library
- **NenDB Team** for the high-performance graph database
- **Open Source Community** for inspiration and feedback

---

**Ready to visualize your graphs?** 🚀 [Get started now!](http://localhost:8080/visualizer)
