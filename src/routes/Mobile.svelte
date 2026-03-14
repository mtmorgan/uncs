<script lang="ts">
  import P5, { type p5 } from "p5-svelte";
  import { DirectedGraph } from "graphology";
  import { calculateMobile, type NodeAttributes } from "$lib/mobile";
  import { onMount } from "svelte";

  const { unc_graph } = $props();

  // 1. Reactive State
  let graph = $state(new DirectedGraph<NodeAttributes>());
  let version = $state(0);

  // 2. Derived Data for P5
  const elements = $derived.by(() => {
    version; // track dependency
    const nodes = graph
      .nodes()
      .map((id) => ({ id, ...graph.getNodeAttributes(id) }));
    const edges = graph.edges().map((id) => ({
      source: graph.getNodeAttributes(graph.source(id)),
      target: graph.getNodeAttributes(graph.target(id)),
    }));
    return { nodes, edges };
  });

  // 3. P5 Sketch
  const sketch = (p5: p5) => {
    p5.setup = () => {
      p5.createCanvas(800, 600);
      p5.textAlign(p5.CENTER);
    };

    p5.draw = () => {
      p5.background(250);

      // Draw Connections (Strings)
      p5.stroke(150);
      for (const edge of elements.edges) {
        if (edge.source.x !== undefined && edge.target.x !== undefined) {
          p5.line(edge.source.x, edge.source.y!, edge.target.x, edge.target.y!);
        }
      }

      // Draw Nodes
      for (const node of elements.nodes) {
        if (node.x === undefined) continue;

        if (node.which === "person_node") {
          p5.fill("#e63946");
          p5.noStroke();
          p5.ellipse(node.x, node.y!, 20, 20);
          p5.fill(0);
          p5.text(node.id, node.x, node.y! + 25);
        } else {
          p5.fill(50);
          p5.rectMode(p5.CENTER);
          p5.rect(node.x, node.y!, 40, 6, 2);
        }
      }
    };
  };

  let mounted = $state(false);
  onMount(() => {
    graph.import({
      nodes: unc_graph.nodes.filter(
        (node: { attributes: { which: string } }) =>
          node.attributes.which !== "synonym_node",
      ),
      edges: unc_graph.edges,
    });
    calculateMobile(graph);
    version++;
    mounted = true;
  });
</script>

<div class="container">
  {#if mounted}
    <P5 {sketch} />
  {/if}
</div>

<style>
  .container {
    display: flex;
    justify-content: center;
    padding: 20px;
  }
</style>
