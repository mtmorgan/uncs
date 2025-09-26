<script>
  import { Styles, Container } from "@sveltestrap/sveltestrap";
  import People from "./People.svelte";
  import Ancestry from "./Ancestry.svelte";
  import Geography from "./Geography.svelte";
</script>

<Styles />

<Container fluid>

  <h1>Uncs</h1>

  <p>
    'Uncs' is, apparently, a term used by the younger peoples to refer to older
    individuals with unappreciated wisdom.
  </p>

  <p>This project looks at our family genealogical history.</p>

  <h2>People</h2>

  <People />

  <h2>Ancestry</h2>

  <Ancestry />

<h2>Geographical genealogy</h2>

  <Geography />

  <h2>Implementation notes</h2>

  <p>Ancestry information was collated by Rachel.</p>

  <p>
    This application uses the <a href="https://svelte.dev">svelte</a>
    framework. Data are displayed using
    <a href="https://datatables.net/">DataTables</a>. The ancestry graph uses
    <a href="https://graphology.github.io/">graphology</a>
    and
    <a href="https://www.sigmajs.org/">Sigma.js</a>.
  </p>

</Container>
