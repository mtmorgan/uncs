<script lang="ts">
  import P5, { type p5 } from "p5-svelte";
  import { DirectedGraph } from "graphology";
  import {
    roots,
    calculateMobile,
    createClassicGraph,
    createSidedGraph,
    createCalderGraph,
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
    Lefts: (graph) => createSidedGraph(graph, "left"),
    Rights: (graph) => createSidedGraph(graph, "right"),
    "Calder Lefts": (graph) => createCalderGraph(graph, "left"),
    "Calder Rights": (graph) => createCalderGraph(graph, "right"),
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
  let looping = $state(true);
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

<p>
  A genealogy seems almost like a mobile. The current generation, individual
  '0001', suspending its parents '0002' and '0003', and so on. Alexander Calder
  defines the modern mobile. Here is Calder's <emph>Mobile XII.V - III.H</emph> at
  the Stedelijk in Amsterdam.
</p>

<figure>
  <img
    src="https://s3-eu-west-1.amazonaws.com/production-static-stedelijk/images/adlib/ba-164-1747713637197.jpg"
    alt="Alexander Calder's Mobile XII.V - III.H Stedelijk Museum"
    style="max-width: 100%; height: auto;"
  />
  <figcaption>
    Alexander Calder, <em>Mobile XII.V - III.H</em>, 1955. Collection of the
    <a href="https://www.stedelijk.nl/en">Stedelijk Museum Amsterdam</a>.
  </figcaption>
</figure>

<p>
  Of course Calder's mobile is pretty amazing. It is highly abstract and
  therefore modern. The color scheme is very reduced (black, basically; Calder
  uses a restricted palette of subdued primary colors). The structure is a
  repeating pattern of a shape balancing a branch, with a shape balancing a
  branch... recursively. Mobiles could have much more complicated structure, but
  Calder's are very simple. The shapes echo the biomorphism of Miro.
</p>

<p>
  The mobile is kinetic in a gentle way, responding to air currents. A great
  example is at the National Gallery in Washington, D.C., where a <a
    href="https://www.nga.gov/artworks/56517-untitled">huge mobile</a
  > drifts over the central foyer of the East Building.
</p>

<p>
  A mobile requires precise balance between the left and right arms at each
  node. The balance point is actually easy to calculate, and apparently Calder
  was an engineer so knew in principle how to perform the calculations. But in
  practice Calder developed his mobiles empirically through 'trial and error'.
</p>

<p>
  Explore the idea of genealogy as mobile. The 'Classic' representation takes
  each person in the genealogy as a node in the mobile. Parents hang on the left
  (paternal) and right (maternal) side of the individual. The volume of each
  individual is proportional to the number of ancestors in the genealogy, and
  the location of the bar balances the force of ancestors on the right and left
  arms. The animation gently blows the mobile in a quasi-mechanistic way (light
  nodes at the base of the mobile respond more than heavier nodes toward the
  top); watch for a long time to allow the shapes to explore space.
</p>

<p>
  Select different types of mobile to experience representations that take
  different views on the genealogy. Some additional detail is provided below the
  mobile when each type is selected.
</p>

<FormGroup row>
  <Row>
    <Label for="graphType" sm={2} class="text-nowrap">Mobile type:</Label>
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

<div bind:clientWidth={width} bind:clientHeight={height} class="canvas-wrapper">
  <P5 {sketch} />
</div>

{#if graphType === "Classic"}
  <p>
    The 'Classic' mobile represents the genealogy as-is. The volume of each
    person is proportional to the number of ancestors. The mobile is balanced,
    with the length of each arm chosen so that the force from the mass of
    ancestors on the left arm balances the force from the mass of ancestors on
    the right arm.
  </p>
{/if}
{#if graphType === "Lefts" || graphType === "Rights"}
  <p>
    The 'Lefts' mobile replaces the right-hand (maternal) parent with the
    parent's left-hand (paternal) parent. The result is a mobile with only
    left-hand (paternal) nodes. Not all paternal parents are present on this
    mobile. 'Generations' is a misnomer, instead representing the number of
    levels from the root of the mobile.
  </p>
  <p>
    The 'Rights' mobile is the same as the 'Lefts' mobile, except replacing the
    left parent with their right grandparent, resulting in an all-rights
    (maternal) mobile.
  </p>
{/if}
{#if graphType === "Calder Lefts" || graphType === "Calder Rights"}
  <p>
    The 'Calder Lefts' mobile expands each left-hand (paternal) parent, but
    stops at the right-hand (maternal) parent. The result is a mobile with a
    structure like Clader mobiles, where the (expanded) paternal lineage is
    balanced by the genealogical mass represented by the maternal parent .
  </p>
  <p>
    The 'Calder Rights' mobile is similar, operating on the right-hand nodes;
    the maternal lineages are expanded and balanced by the paternal parent.
  </p>
  <p>
    It's striking that these 'Calder' mobiles have such a simple structure. This
    seems to be consistent with the basic tenets of abstraction in modern art,
    with the simplicity allowing exploration of fundamental building blocks of
    the artistic experience.
  </p>
{/if}
<p>
  Animation is meant to simulate gusts of wind, with lighter nodes (people with
  fewer ancestors, at the bottom of the graph) responding more to the gusts than
  heavier nodes. When the animation is running, use the mouse / touchpad to zoom
  and rotate the point of view.
</p>

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
