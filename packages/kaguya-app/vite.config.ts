// SPDX-License-Identifier: MPL-2.0

import { defineConfig } from 'vite'
import preact from '@preact/preset-vite'
import rescript from '@jihchi/vite-plugin-rescript'

export default defineConfig({
  plugins: [preact(), rescript()],
  build: {
    // Ensure proper asset paths for Cloudflare Workers
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        manualChunks: undefined
      }
    }
  }
})
