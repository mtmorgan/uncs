<script>
  import { Styles, Container } from "@sveltestrap/sveltestrap";
  import People from "./People.svelte";
  import Ancestry from "./Ancestry.svelte";
  import Geography from "./Geography.svelte";
  import Decrypt from "./Decrypt.svelte";
  import { graphState } from "../LoadGraph.svelte";
</script>

<Styles />

<Container fluid>
  <h1>Uncs</h1>

  <p>
    An 'unc' is, apparently, a term used by the younger peoples to refer to
    older individuals with unappreciated (by the younger peoples) wisdom. This
    project looks at our family ancestry using information compiled by other
    family members. This project looks at our family ancestry.
  </p>

  <Decrypt />

  {#if graphState.name === "unc_graph.json.enc"}
    <h2>People</h2>
    <p>
      Some of the information available for people in this project is summarized
      in the table below. Additional data, e.g., sources, could also be
      extracted from the original Google sheets.
    </p>
    <People unc_graph={graphState.graph} />
  {/if}

  <h2>Ancestry</h2>

  <p>
    The graph below represents relationships between people in the previous
    table. Hover over nodes to show the name and dates (if available) of
    individuals. Click on an individual for additional information on place of
    birth, siblings, and other notes. Use the scroll wheel or two fingers on a
    touch pad to zoom in. Click and hold to move the graph.
  </p>

  <p>
    Imagine moving from the central node. The maternal lineage branches 'right'
    and the paternal lineage 'left'. Counterclockwise arcs in the graph
    represent lineages where, across generations, paternal information is
    available. Beware that in the graph some lineages cross each other visually;
    be sure to follow the lineage you're interested in!
  </p>

  <p>
    From a high-level view, the graph suggests that paternal lineages are
    generally easier to follow the maternal lineages. Also, the deepest lineages
    involve generations on the same continent (the Johnson maternal lineage in
    the US; the Morgan paternal lineage in the UK).
  </p>

  {#if graphState.name}
    {#key graphState.name}
      <Ancestry unc_graph={graphState.graph} />
    {/key}
  {/if}

  <!--
  <h2>Geographical genealogy</h2>

  <Geography />
  -->

  <h2>Implementation notes</h2>

  <p>Ancestry information was collated by Rachel.</p>

  <p>
    The original Google Sheets document was parsed using <em>R</em>,
    particularly the
    <a href="https://googlesheets4.tidyverse.org">googlesheets4</a>
    and <a href="https://dplyr.tidyverse.org/">dplyr</a> packages. The
    <em>R</em>
    representations were translated to JSON using
    <a href="https://jeroen.r-universe.dev/jsonlite">jsonlite</a>, with JSON
    further transformed using
    <a href="https://mtmorgan.github.io/rjsoncons">rjsoncons</a>. The encrypted
    version of the data were made using
    <a href="https://jeroen.r-universe.dev/sodium">sodium</a>
    in *R*.
  </p>

  <p>
    This application uses the <a href="https://svelte.dev">svelte</a>
    framework. Data decrypted in JavaScript used the
    <a href="">libsodium-wrappers-sumo</a> WASM. Data are displayed using
    <a href="https://datatables.net/">DataTables</a>. The ancestry graph uses
    <a href="https://graphology.github.io/">graphology</a>
    and
    <a href="https://www.sigmajs.org/">Sigma.js</a>. I developed the ancestry
    layout algorithm, using vague memories from Mr. Smith's high school Calculus
    class -- something about 'SOH CAH TOA' on the Nile.
  </p>

  <p>
    Package source is available on <a href="https://github.com/mtmorgan/uncs"
      >GitHub</a
    >.
  </p>
</Container>
