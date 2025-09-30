<script lang="ts">
  import { onMount } from "svelte";
  import DataTable from "datatables.net-dt";
  import unc_graph from "./unc_graph.json";

  //let DataTable: typeof import("datatables.net");
  let peopleTableElement: HTMLTableElement;
  let people = unc_graph.nodes
    .filter((node) => node.attributes.which === "person_node")
    .map((node) => {
      return { key: node.key, ...node.attributes };
    });

  onMount(async () => {
    let columns = [
      { title: "Key", data: "key", orderable: true },
      { title: "Name", data: "name", orderable: true },
    ];
    if (people[0].key !== people[0].name) {
      columns = columns.concat(
        { title: "Date", data: "date", orderable: true },
        { title: "Place", data: "place", orderable: true },
        { title: "Siblings", data: "siblings" },
        { title: "Notes", data: "notes" }
      );
    }

    new DataTable(peopleTableElement, {
      data: people,
      columns: columns,
      scrollY: "300px",
      paging: false,
    });
  });
</script>

<svelte:head>
  <link
    rel="stylesheet"
    type="text/css"
    href="https://cdn.datatables.net/2.0.8/css/dataTables.dataTables.min.css"
  />
  <style>
    /* Custom CSS to align cells to the top */
    table.dataTable tbody td,
    table.dataTable thead th {
      vertical-align: top;
    }
  </style>
</svelte:head>

<table
  id="people-datatable"
  bind:this={peopleTableElement}
  class="display"
  style="width: 100%"
></table>
