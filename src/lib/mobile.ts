import DirectedGraph from "graphology";

export interface NodeAttributes {
  which: "person_node" | "relation_node";
  name?: string; // person_node
  relation?: string; // relation_node
  // Attributes on encrypted person_nodes
  date?: string;
  place?: string;
  siblings?: string;
  notes?: string;
  // Calculated attributes
  weight?: number; // Input for persons
  offset?: number; // Horizontal distance from parent pivot (0 to 1)
  x?: number;
  y?: number;
}

export interface EdgeAttributes {
  label: "child-of" | "parent-of";
}

export const calculateMobile = (graph: DirectedGraph<NodeAttributes>) => {
  const getWeight = (node: string): number => {
    const attr = graph.getNodeAttributes(node);
    let weight = attr.which === "person_node" ? 1 : 0;
    graph.forEachOutNeighbor(node, (child) => (weight += getWeight(child)));
    graph.setNodeAttribute(node, "weight", weight);
    return weight;
  };

  const layout = (node: string, x: number, y: number, depth: number) => {
    graph.updateNodeAttributes(node, (attr) => ({ ...attr, x, y }));
    const children = graph.outNeighbors(node);
    const gap = 150 / (depth + 1); // Narrower bars as we go deeper

    if (children.length === 2) {
      const [l, r] = children;
      const wL = graph.getNodeAttribute(l, "weight") || 1;
      const wR = graph.getNodeAttribute(r, "weight") || 1;
      const total = wL + wR;
      layout(l, x - (wR / total) * gap, y + 60, depth + 1);
      layout(r, x + (wL / total) * gap, y + 60, depth + 1);
    } else {
      children.forEach((c, i) =>
        layout(c, x + (i - (children.length - 1) / 2) * gap, y + 60, depth + 1),
      );
    }
  };

  graph
    .nodes()
    .filter((n) => graph.inDegree(n) === 0)
    .forEach((root) => {
      getWeight(root);
      layout(root, 400, 50, 0);
    });
};
