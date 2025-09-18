<script lang="ts">
  import { onMount } from "svelte";
  let ancestryElement: HTMLDivElement;

  import Graph from "graphology";
  import { random } from "graphology-layout";
  import FA2Layout from "graphology-layout-forceatlas2/worker";
  import Sigma from "sigma";

  import unc_graph from "./unc_graph.json";
  unc_graph.nodes = unc_graph.nodes.filter(
    (node) => node.attributes.which !== "synonym_node"
  );

  const nodeSize = (attributes) => {
    return attributes.which === "person_node" ? 2 : 0.1;
  };

  const nodeLabel = (attributes) => {
    let label = "";
    if (attributes.which === "person_node") {
      label = attributes.name;
      if (attributes.date) {
        label += " (" + attributes.date + ")";
      }
    }
    return label;
  };

  const graph = new Graph();
  graph.import(unc_graph);
  graph.updateEachNodeAttributes((nodeId, attributes) => {
    return {
      ...attributes,
      size: nodeSize(attributes),
      label: nodeLabel(attributes),
    };
  });
  random.assign(graph); // x, y coordinates

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

    const layout = new FA2Layout(graph);
    layout.start();
    setTimeout(() => {
      layout.stop();
      console.log("ForceAtlas2 layout stopped.");
    }, 5000);
  });
</script>

<div
  id="ancestry-container"
  bind:this={ancestryElement}
  style="height: 500px; border: 1px solid #ccc;"
></div>
