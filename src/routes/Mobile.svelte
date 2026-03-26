<script lang="ts">
  import P5, { type p5 } from "p5-svelte";
  import { DirectedGraph } from "graphology";
  import {
    calculateMobile,
    layoutClassic,
    type NodeAttributes,
  } from "$lib/mobile";
  import { onMount } from "svelte";
  import {
    Col,
    FormGroup,
    Label,
    Input,
    Button,
  } from "@sveltestrap/sveltestrap";

  const COLOR = { person: "red", relation: "black" };

  const { unc_graph } = $props();

  let width = $state(0);
  let height = $state(0);

  // 1. Reactive State
  let graph = new DirectedGraph<NodeAttributes>();
  let version = $state(0);
  let displayDepth: number = $state(7);
  const displayDepthOptions = Array.from({ length: 9 }, (_, i) => i + 1);
  let p5Instance: p5;
  let looping = $state(false);

  // P5 Sketch

  const toggleLoop = () => {
    looping = !looping;
    if (looping) {
      p5Instance.loop();
    } else {
      p5Instance.noLoop();
    }
  };

  const drawGraph = (p5: p5, graph: DirectedGraph<NodeAttributes>) => {
    const SIZE = 4;
    const DAMPING = 0.98; // High = less friction, Low = heavy air
    const WIND_STRENGTH = 0.005;

    const drawNode = (node: string) => {
      const attr = graph.getNodeAttributes(node);
      const children = graph.outNeighbors(node);

      p5.push();

      const radius = Math.pow(((3 / 4) * attr.weight!) / Math.PI, 1 / 3) * SIZE;
      if (attr.which === "person_node") {
        // Persons are spheres proportional to weight
        p5.translate(attr.x!, radius * 1.7, 0);
        p5.fill(COLOR.person).strokeWeight(0).sphere(radius); // Persons are 3D spheres
      } else {
        // Relations are horizontal bars
        p5.translate(attr.x!, radius * 1.5, 0);

        // Rotation
        p5.rotateY(attr.angle);
        const wind =
          (p5.noise(p5.frameCount * 0.01, node.length) - 0.5) *
          (WIND_STRENGTH / (attr.weight || 1));
        attr.velocity += wind;
        attr.velocity *= DAMPING; // Damping factor
        attr.angle += attr.velocity;
        graph.setNodeAttribute(node, "velocity", attr.velocity);
        graph.setNodeAttribute(node, "angle", attr.angle);

        const barDim = Math.max(2 / (2 + attr.depth!), 1);
        p5.push();
        p5.translate(attr.offset!, 0, 0)
          .fill(COLOR.relation)
          .box(attr.width!, barDim, barDim);
        p5.pop();
      }
      // p5.stroke(100).strokeWeight(2).line(0, 0, 0, 0, -attr.x!, -attr.y!);
      if (attr.depth! < displayDepth - 1) {
        children.forEach((child) => drawNode(child));
      }
      p5.pop(); // Restore coordinate system for siblings
    };

    const root = graph.nodes().filter((n) => graph.inDegree(n) === 0)[0];
    drawNode(root);
  };

  const sketch = (p5: p5) => {
    p5Instance = p5;
    p5.setup = () => {
      p5.createCanvas(width, height, p5.WEBGL);
      p5.textAlign(p5.CENTER);
    };

    p5.draw = () => {
      !looping && p5.noLoop();
      p5.background(250)
        .orbitControl()
        .ambientLight(200)
        .pointLight(255, 255, 255, 0, 200, 200);
      p5.push();
      p5.translate(0, -130, 0); // Move root to the top of the scene
      drawGraph(p5, graph);
      p5.pop();
    };

    p5.mouseClicked = () => {
      if (
        p5.mouseX >= 0 &&
        p5.mouseX <= p5.width &&
        p5.mouseY >= 0 &&
        p5.mouseY <= p5.height
      ) {
      }
    };
  };

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
  });

  $effect(() => {
    layoutClassic(graph, displayDepth);
  });
</script>

<FormGroup row>
  <Label for="displayDepth" sm={2} class="text-nowrap">Generations:</Label>
  <Col sm={2}>
    <Input type="select" id="displayDepth" bind:value={displayDepth}>
      {#each displayDepthOptions as option}
        <option value={option}>
          {option}
        </option>
      {/each}
    </Input>
  </Col>
  <Col sm={4}>
    <Button outline color="dark" on:click={toggleLoop}>
      {looping ? "Pause" : "Continue"}
    </Button>
  </Col>
</FormGroup>

<div
  class="canvas-container"
  bind:clientWidth={width}
  bind:clientHeight={height}
>
  {#if width && height}
    <P5 {sketch} />
  {/if}
</div>

<style>
  .canvas-container {
    width: 100%;
    height: 250px; /* Or use vh/vw */
    background: #f0f0f0;
  }

  :global(canvas) {
    cursor: pointer;
  }
</style>
