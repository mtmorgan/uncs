import devtoolsJson from "vite-plugin-devtools-json";
import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";

export default defineConfig({
  plugins: [
    sveltekit(),
    devtoolsJson(),
    mkcert(), // Support https
  ],
  server: {
    https: true, // Enable HTTPS
  },
});
