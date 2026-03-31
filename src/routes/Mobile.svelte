<script lang="ts">
  import P5, { type p5 } from "p5-svelte";
  import { DirectedGraph } from "graphology";
  import {
    roots,
    calculateMobile,
    createClassicGraph,
    createLeftsGraph,
    createCalderLeftsGraph,
    layoutGraph,
    type NodeAttributes,
    type Mobile,
  } from "$lib/mobile";
  import { onMount, untrack } from "svelte";
  import {
    Row,
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
  // Scale mobile to fit bootstrap width breakpoints
  let prevWidth = 0; // Local variable for comparison
  const config = [
    { bp: 1400, name: "xxl", depth: 9 },
    { bp: 1200, name: "xl", depth: 8 },
    { bp: 992, name: "lg", depth: 8 },
    { bp: 768, name: "md", depth: 7 },
    { bp: 576, name: "sm", depth: 6 },
    { bp: 0, name: "xs", depth: 5 }, // The "Smallest" associate
  ];

  // 1. Reactive State
  let sourceGraph: Mobile = new DirectedGraph<NodeAttributes>();
  let graph: Mobile = new DirectedGraph<NodeAttributes>();
  let version = $state(0);

  let displayDepth: number = $state(7);
  const displayDepthOptions = Array.from({ length: 9 }, (_, i) => i + 1);

  // Graph types

  type LayoutFunction = (graph: Mobile) => Mobile;
  const layouts: Record<string, LayoutFunction> = {
    Classic: (graph) => createClassicGraph(graph),
    Lefts: (graph) => createLeftsGraph(graph),
    Rights: (graph) => createLeftsGraph(graph),
    "Calder Lefts": (graph) => createCalderLeftsGraph(graph),
    "Calder Rights": (graph) => createCalderLeftsGraph(graph),
  } as const;
  type GraphType = keyof typeof layouts;
  const graphTypeOptions = Object.keys(layouts) as GraphType[];

  let graphType: GraphType = $state("Classic");
  const handleGraphType = (e: Event) => {
    const target = e.target as HTMLSelectElement;
    graphType = target.value as GraphType;
    graph = layouts[graphType](sourceGraph);
    layoutGraph(graph, displayDepth);
    p5Instance?.redraw();
  };

  // Looping
  let looping = $state(false);
  const toggleLoop = () => {
    looping = !looping;
    if (looping) {
      p5Instance.loop();
    } else {
      p5Instance.noLoop();
    }
  };

  // P5 Sketch

  let p5Instance: p5;

  const drawGraph = (p5: p5, graph: Mobile) => {
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

    const root = roots(graph)[0];
    drawNode(root);
  };

  const sketch = (p5: p5) => {
    p5Instance = p5;
    p5.setup = () => {
      p5.createCanvas(width, height, p5.WEBGL);
      const bin = config.find((c) => width >= c.bp);
      displayDepth = bin!.depth;
    };

    p5.draw = () => {
      !looping && p5.noLoop();
      p5.background(250)
        .orbitControl()
        .ambientLight(200)
        .pointLight(255, 255, 255, 0, 200, 200);
      p5.push();
      p5.translate(0, -height / 2, 0); // Move root to the top of the scene
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
    sourceGraph.import({
      nodes: unc_graph.nodes.filter(
        (node: { attributes: { which: string } }) =>
          node.attributes.which !== "synonym_node",
      ),
      edges: unc_graph.edges,
    });
    calculateMobile(sourceGraph);
    graph = createClassicGraph(sourceGraph);
    version++;
  });

  $effect(() => {
    // Resize P5 canvas on change in width
    if (width && height) {
      untrack(() => p5Instance?.resizeCanvas(width, height));
    }
  });

  $effect(() => {
    // Genealogy depth based on Bootstrap width
    const crossedDown = config.some((c) => prevWidth >= c.bp && width < c.bp);
    const crossedUp = config.some((c) => prevWidth < c.bp && width >= c.bp);
    if (crossedDown || crossedUp) {
      const bin = config.find((c) => width >= c.bp);
      if (crossedDown) displayDepth = Math.min(displayDepth, bin!.depth);
      if (crossedUp) displayDepth = Math.max(displayDepth, bin!.depth);
    }
    prevWidth = width;
  });

  $effect(() => {
    // Update display depth
    layoutGraph(graph, displayDepth);
    untrack(() => p5Instance?.redraw());
  });
</script>

<FormGroup row>
  <Row>
    <Label for="graphType" sm={2} class="text-nowrap">Graph type:</Label>
    <Col sm={3}>
      <Input type="select" id="graphType" onchange={handleGraphType}>
        {#each graphTypeOptions as option}
          <option value={option}>{option}</option>
        {/each}
      </Input>
    </Col>
  </Row>
  <Row>
    <Label for="displayDepth" sm={2} class="text-nowrap">Generations:</Label>
    <Col sm={3}>
      <Input type="select" id="displayDepth" bind:value={displayDepth}>
        {#each displayDepthOptions as option}
          <option value={option}>{option}</option>
        {/each}
      </Input>
    </Col>
  </Row>
  <Row>
    <Label for="looping" sm={2} class="text-nowrap">Animation:</Label>
    <Col sm={3}>
      <Button id="looping" outline color="dark" on:click={toggleLoop}>
        {looping ? "Pause" : "Continue"}
      </Button>
    </Col>
  </Row>
</FormGroup>
{#if graphType === "Classic"}
  <p>
    The 'Classic' mobile represents the genealogy as-is. The size of each person
    is proportional to the number of ancestors. The mobile is balanced, with the
    length of each arm chosen so that the force from the mass of ancestors on
    the left arm balances the force from the mass of ancestors on the right arm.
  </p>
{/if}
{#if graphType === "Lefts" || graphType === "Rights"}
  <p>
    The 'Lefts' mobile replaces each person on the left branch (the paternal
    parent) with the left branch's right parent (the paternal parent's maternal
    parent). The result is an all-right (maternal parent) mobile. Not all
    maternal parents are present on this mobile. 'Generations' is a misnomer,
    instead representing the number of levels from the root of the mobile.
  </p>
{/if}
<p>
  Animation is meant to simulate gusts of wind, with lighter nodes (people with
  fewer ancestors, at the bottom of the graph) respoding more to the gusts than
  heavier nodes. When the animation is running, use the mouse / touchpad to zoom
  and rotate the point of view.
</p>

<div bind:clientWidth={width} bind:clientHeight={height} class="canvas-wrapper">
  <P5 {sketch} />
</div>

<style>
  .canvas-wrapper {
    width: 100%;
    height: 280px;
    overflow: hidden;
  }
  :global(canvas) {
    cursor: pointer;
  }
</style>
