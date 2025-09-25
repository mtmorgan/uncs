<script lang="ts">
  import { onMount } from "svelte";
  let ancestryElement: HTMLDivElement;
  let notesElement: HTMLParagraphElement;

  import Graph from "graphology";
  import { circular } from "graphology-layout";
  import FA2Layout from "graphology-layout-forceatlas2/worker";
  import Sigma from "sigma";

  import unc_graph from "./unc_graph.json";

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
    update.size = 2;
    return update;
  });
  graph.updateNodeAttributes("0001", (attributes) => {
    // root is special
    const update = { ...attributes };
    update.size = 5;
    update.color = "purple";
    return update;
  });
  circular.assign(graph); // x, y coordinates to seed layout algorithm

  onMount(() => {

    // Create Sigma.js graph, with node click displaying notes

    const renderer = new Sigma(graph, ancestryElement);
    renderer.on("clickNode", ({ node }) => {
      const attributes = graph.getNodeAttributes(node);
      const label = nodeLabel(attributes);
      const siblings = attributes.siblings || "Unknown";
      const notes = attributes.notes || "None";
      notesElement.innerHTML =
        label + "<br/>Siblings: " + siblings + "<br/>Notes: " + notes;
    });

    // Graph layout

    const layout = new FA2Layout(graph, { settings: { gravity: 3 } });
    layout.start();
    setTimeout(() => {
      layout.stop();
    }, 5000);
  });
</script>

<div
  id="ancestry-container"
  bind:this={ancestryElement}
  style="height: 400px; width: 100%; border: 1px solid #ccc;"
></div>

<p id="notes-element" bind:this={notesElement}></p>
