import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import path from "path";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "src") },
  },
  server: {
    proxy: {
      // Proxy /api/* to Flask backend in local dev
      "/api": {
        target: "http://localhost:5000",
        changeOrigin: true,
      },
    },
  },
});
