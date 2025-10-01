import sodium from "libsodium-wrappers-sumo";

export const graphState = $state({
  name: '',
  graph: {}
});

// Unencrypted graph

export async function loadGraph(url) {
  let message = '';
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error status: ${response.status}`);
    }
    graphState.graph = await response.json();
    graphState.name = url.split('/').pop() ?? "";
    message = `Loaded graph '${graphState.name}'`;
  } catch (error) {
    console.error('Error fetching the file:', error);
    message = 'Failed to load file from server.';
  }

  return message;
}

// Encrypted graph

async function decrypt(url, password) {
  await sodium.ready;

  // Fetch file from server
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP error. Status: ${response.status}`);
  }
  const buffer = await response.arrayBuffer();

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

export async function loadEncryptedGraph(url, password) {
  let message = '';
  try {
    const graphText = await decrypt(url, password);
    graphState.graph = JSON.parse(graphText);
    graphState.name = url.split('/').pop() ?? "";
    message = 'Loaded encrypted graph';
  } catch (error) {
    message = "Decryption failed: incorrect password?";
  }

  return message;
}
