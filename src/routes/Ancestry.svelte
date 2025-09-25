<script lang="ts">
  import { onMount } from "svelte";
  let ancestryElement: HTMLDivElement;

  import Graph from "graphology";
  import { circular } from "graphology-layout";
  import FA2Layout from "graphology-layout-forceatlas2/worker";
  import Sigma from "sigma";

  import unc_graph from "./unc_graph.json";

  // create edges between person_nodes, rather than via relation_nodes
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

  const p_graph = {
    nodes: unc_graph.nodes.filter(
      (node) => node.attributes.which === "person_node"
    ),
    edges: p_edges,
  };

  const nodeLabel = (attributes) => {
    let label = attributes.name;
    if (attributes.date) {
      label += " (" + attributes.date + ")";
    }
    return label;
  };

  const graph = new Graph();
  graph.import(p_graph);
  graph.updateEachNodeAttributes((nodeId, attributes) => {
    return {
      ...attributes,
      size: 2,
      label: nodeLabel(attributes),
    };
  });
  circular.assign(graph); // x, y coordinates

  onMount(() => {
    const renderer = new Sigma(graph, ancestryElement);
    renderer.setSetting("nodeReducer", (node, attributes) => {
      if (node === "0001") {
        return {
          ...attributes,
          size: 5,
          color: "purple",
        };
      }
      return attributes;
    });

    const layout = new FA2Layout(graph, { settings: { gravity: 3 }});
    layout.start();
    setTimeout(() => {
      layout.stop();
    }, 5000);
  });
</script>

<div
  id="ancestry-container"
  bind:this={ancestryElement}
  style="height: 500px; border: 1px solid #ccc;"
></div>
