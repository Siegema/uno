import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  plugins: [svelte()],
  server: {
    host: true,
    allowedHosts: ["uno-tt0m.onrender.com"],
    proxy: { "/socket": { target: "http://127.0.0.1:4000", ws: true } },
    cors: {
      origin: [
        /^https?:\/\/(?:(?:[^:]+\.)?localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/,
        "https://uno-tt0m.onrender.com",
      ],
    },
  },
});
