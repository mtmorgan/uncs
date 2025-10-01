<script lang="ts">
  import { onMount } from "svelte";
  let ancestryElement: HTMLDivElement;
  let notesElement: HTMLParagraphElement;

  import Graph from "graphology";
  import { bfsFromNode } from "graphology-traversal";

  import Sigma from "sigma";

  const { unc_graph } = $props();

  // Create edges between person_nodes, rather than via relation_nodes

  const removeNode = (node: any) => {
    const r_edges = unc_graph.edges.filter((edge) => edge.target === node.key);
    const edges = r_edges.slice(1).map((r_edge) => {
      return {
        // FIXME: assumes first edge is always 'child-of'
        source: r_edges[0].source,
        target: r_edge.source,
      };
    });
    return edges;
  };
  const p_edges = unc_graph.nodes
    .filter((node) => node.attributes.which === "relation_node")
    .map(removeNode)
    .flat();

  // Import into graphology and annotate for Sigma.js

  const p_graph = {
    nodes: unc_graph.nodes.filter(
      (node) => node.attributes.which === "person_node"
    ),
    edges: p_edges,
  };

  const nodeLabel = (attributes: any) => {
    let label = attributes.name;
    if (attributes.date) {
      label += " (" + attributes.date + ")";
    }
    return label;
  };

  const graph = new Graph();
  graph.import(p_graph);
  graph.updateEachNodeAttributes((key, attributes) => {
    const update = { ...attributes };
    update.label = nodeLabel(attributes);
    update.size = 3;
    return update;
  });
  graph.updateNodeAttributes("0001", (attributes) => {
    // root is special
    const update = { ...attributes };
    update.size = 5;
    update.color = "purple";
    return update;
  });
  // circular.assign(graph); // x, y coordinates to seed layout algorithm
  bfsFromNode(graph, "0001", function (node, attr, depth) {
    if (depth === 0) {
      graph.updateNodeAttributes(node, (attributes) => {
        attributes.x = 0;
        attributes.y = 0;
        attributes.theta = 0;
        attributes.childVisits = 0;
        return attributes;
      });
    } else {
      const parent = graph.inboundNeighbors(node)[0]; // only 1
      const { x, y, theta, childVisits } = graph.getNodeAttributes(parent);
      const scale = 2 * (2 * childVisits  - 1) * Math.min(depth, 7);
      const thetaPrime = theta + Math.PI / scale;
      graph.updateNodeAttributes(node, (attributes) => {
        attributes.x = x + Math.sin(thetaPrime);
        attributes.y = y + Math.cos(thetaPrime);
        attributes.theta = thetaPrime;
        attributes.childVisits = 0;
        return attributes;
      });
      graph.setNodeAttribute(parent, "childVisits", childVisits + 1);
    }
  });

  onMount(() => {
    // Create Sigma.js graph, with node click displaying notes

    const renderer = new Sigma(graph, ancestryElement);
    renderer.on("clickNode", ({ node }) => {
      const attributes = graph.getNodeAttributes(node);
      const label = nodeLabel(attributes);
      const place = attributes.place || "Unknown";
      const siblings = attributes.siblings || "Unknown";
      const notes = attributes.notes || "None";
      notesElement.innerHTML =
        label +
        "<br/>Place: " +
        place +
        "<br/>Siblings: " +
        siblings +
        "<br/>Notes: " +
        notes;
    });
  });
</script>

<div
  id="ancestry-container"
  bind:this={ancestryElement}
  style="height: 600px; width: 100%; border: 1px solid #ccc;"
></div>

<p id="notes-element" bind:this={notesElement}></p>
