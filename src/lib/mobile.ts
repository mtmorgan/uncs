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
  depth?: number;
  weight?: number; // Input for persons
  x?: number;
  y?: number;
  // Relation bar
  offset?: number;
  width?: number;
  // Physics State
  angle: number;
  velocity: number;
}

export interface EdgeAttributes {
  label: "child-of" | "left-parent-of" | "right-parent-of";
}

export const roots = (source: DirectedGraph<NodeAttributes>) => {
  return source.nodes().filter((n) => source.inDegree(n) === 0);
};

export const createClassicGraph = (
  source: DirectedGraph<NodeAttributes>,
): DirectedGraph<NodeAttributes> => {
  return source.copy();
};

const descendants = new Set<string>();
const collectDescendants = (
  graph: DirectedGraph<NodeAttributes>,
  person: string,
) => {
  const collect = (person: string) => {
    graph.forEachOutNeighbor(person, (neighbor) => {
      collect(neighbor);
      if (!descendants.has(neighbor)) {
        descendants.add(neighbor);
        collect(neighbor);
      }
    });
    descendants.add(person);
  };
  collect(person);
};

export const createLeftsGraph = (
  source: DirectedGraph<NodeAttributes>,
): DirectedGraph<NodeAttributes> => {
  const removeLefts = (person: string) => {
    const relation = graph.outNeighbors(person);
    if (relation.length > 0) {
      // FIXME: are relations always length 2?
      const [lPerson, rPerson] = graph.outNeighbors(relation);
      const lRelation = graph.outNeighbors(lPerson);
      if (lRelation.length > 0) {
        // There is a grand-parent
        const [_, lrPerson] = graph.outNeighbors(lRelation);
        graph.dropEdge(relation, lPerson);
        graph.dropEdge(lRelation, lrPerson);
        graph.addEdge(relation, lrPerson);
        collectDescendants(graph, lPerson);
        removeLefts(lrPerson);
      }
      rPerson && removeLefts(rPerson);
    }
  };

  const graph = source.copy();
  descendants.clear();
  roots(graph).forEach((root) => removeLefts(root));
  descendants.forEach((node) => graph.dropNode(node));

  return graph;
};

export const layoutGraph = (
  graph: DirectedGraph<NodeAttributes>,
  maxDepth: number,
) => {
  const PERSON_UNIT_WIDTH = 4;
  const DY = 40;
  const layout = (
    node: string,
    x: number,
    y: number,
    depth: number,
  ): number => {
    if (depth >= maxDepth) return 0;
    graph.mergeNodeAttributes(node, { x, y, depth });

    const attr = graph.getNodeAttributes(node);
    const children = graph.outNeighbors(node);
    if (children.length === 0) return PERSON_UNIT_WIDTH;

    depth += attr.which === "person_node" ? 0 : 1;
    const radius = children.map((child) => layout(child, 0, DY, depth));

    if (children.length === 2) {
      // Relation
      const [l, r] = children;
      const [lRadius, rRadius] = radius;
      const wL = graph.getNodeAttribute(l, "weight") || 1;
      const wR = graph.getNodeAttribute(r, "weight") || 1;
      const offset = -(wR - wL) / 2;
      const total = wL + wR;

      const width = lRadius + rRadius + 2 * PERSON_UNIT_WIDTH;
      const lArm = (wR / total) * width;
      const rArm = (wL / total) * width;
      graph.setNodeAttribute(l, "x", -lArm);
      graph.setNodeAttribute(r, "x", +rArm);
      graph.mergeNodeAttributes(node, {
        offset: (offset * width) / total,
        width,
      });
      return Math.max(lArm + lRadius, rArm + rRadius);
    }

    // Default: Either parent -> relation, or relation w/ single child
    return radius[0];
  };

  roots(graph).forEach((node) => layout(node, 0, -10, 0));
};

export const calculateMobile = (graph: DirectedGraph<NodeAttributes>) => {
  const setWeight = (node: string): number => {
    const isPerson = graph.getNodeAttribute(node, "which") === "person_node";
    let weight = isPerson ? 1 : 0;
    graph.forEachOutNeighbor(node, (child) => (weight += setWeight(child)));
    graph.mergeNodeAttributes(node, { weight, angle: 0, velocity: 0 });
    return weight;
  };

  roots(graph).forEach((root) => setWeight(root));
};
