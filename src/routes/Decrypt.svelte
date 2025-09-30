<script lang="ts">
  import {
    Form,
    FormGroup,
    Label,
    Button,
    Input,
  } from "@sveltestrap/sveltestrap";
  import sodium from "libsodium-wrappers-sumo";

  const encodedJson = "/unc_graph.json.enc";

  // DOM elements
  let password: string;
  let status: HTMLElement;
  let output: HTMLElement;

  async function handleDecryption(): Promise<void> {
    await sodium.ready;

    status.textContent = "Fetching and decrypting file...";
    output.textContent = "";

    try {
      const fileData = await fetchFile(encodedJson);
      const decryptedContent = decrypt(fileData, password);
      status.textContent = "File decrypted successfully.";
      output.textContent = decryptedContent;
    } catch (error) {
      console.error("Decryption failed:", error);
      status.textContent = "Decryption failed: incorrect password?";
    }
  }

  async function fetchFile(url: string): Promise<ArrayBuffer> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error. Status: ${response.status}`);
    }
    return await response.arrayBuffer();
  }

  function decrypt(buffer: ArrayBuffer, password: string): string {
    // ArrayBuffer as Uint8Array
    const bytes = new Uint8Array(buffer);

    // Extract salt (32 bytes), nonce (24 bytes), and cipher
    const salt = bytes.slice(0, 32);
    const nonce = bytes.slice(32, 56);
    const cipher = bytes.slice(56);

    // Derive key from password, following R sodium package `scrypt()`
    const key = sodium.crypto_pwhash_scryptsalsa208sha256(
      32,
      password,
      salt,
      sodium.crypto_pwhash_scryptsalsa208sha256_OPSLIMIT_INTERACTIVE,
      sodium.crypto_pwhash_scryptsalsa208sha256_MEMLIMIT_INTERACTIVE
    );

    // Decrypt cipher buffer
    const decrypted = sodium.crypto_secretbox_open_easy(
      cipher,
      nonce,
      key
    );

    return new TextDecoder().decode(decrypted);
  }
</script>

<p>
  The ancestry file is encrypted and requires a password. Without the password,
  information identifying individuals is not displayed. The password was shared
  on WhatsApp.
</p>

<Form on:submit={handleDecryption}>
  <FormGroup>
    <Label for="password">Enter password:</Label>
    <Input
      type="password"
      id="password"
      bind:value={password}
      placeholder=""
      required
    />
  </FormGroup>
  <Button type="submit" color="primary">Submit</Button>
</Form>

<p id="status" bind:this={status}></p>
<pre id="output" bind:this={output}></pre>
