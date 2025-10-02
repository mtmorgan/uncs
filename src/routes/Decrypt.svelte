<script lang="ts">
  import {
    Form,
    FormGroup,
    Label,
    Button,
    Input,
    InputGroup,
  } from "@sveltestrap/sveltestrap";
  import { onMount } from "svelte";
  import { loadGraph, loadEncryptedGraph } from "../LoadGraph.svelte.js";
import { resolve } from '$app/paths';

  const jsonGraph = resolve('/unc_graph.json');
  const jsonGraphEncrypted = resolve('/unc_graph.json.enc');

  // DOM elements
  let password: string;
  let status: HTMLElement;

  async function handleDecryption(): Promise<void> {
    status.textContent = "Fetching and decrypting file...";
    const response = await loadEncryptedGraph(jsonGraphEncrypted, password);
    status.textContent = response;
  }

  onMount(async () => {
    // Preload unencrypted graph, in case user doesn't want to decrypt
    await loadGraph(jsonGraph);
  });
</script>

<p>
  The ancestry file is encrypted and requires a password. Without the password,
  information identifying individuals is not displayed. The password was shared
  on WhatsApp. Enter the password below and click 'Decrypt' to load the encrypted data.
</p>

<Form on:submit={handleDecryption}>
  <InputGroup>
    <Input
      type="password"
      id="password"
      bind:value={password}
      placeholder=""
      required
      autocomplete="current-password"
    />
  <Button type="submit" color="primary">Decrypt</Button>
  </InputGroup>
</Form>

<p id="status" bind:this={status}></p>