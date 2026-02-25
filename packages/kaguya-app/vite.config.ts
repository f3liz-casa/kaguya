// SPDX-License-Identifier: MPL-2.0

import path from 'path'
import { fileURLToPath } from 'url'
import { defineConfig } from 'vite'
import preact from '@preact/preset-vite'
import rescript from '@jihchi/vite-plugin-rescript'
import UnoCSS from 'unocss/vite'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  resolve: {
    alias: {
      // Allows %%raw imports to reference src/ files via '@/' from compiled lib/es6/src/
      '@kaguya-src': path.resolve(__dirname, 'src'),
    },
  },
  plugins: [UnoCSS(), preact(), rescript(),
    // OAuth2 proxy for dev server (production uses Cloudflare Worker)
    {
      name: 'oauth-proxy',
      configureServer(server) {
        server.middlewares.use('/api/oauth-proxy/', async (req, res) => {
          const targetUrl = decodeURIComponent(req.url.slice(1)); // remove leading /
          if (!targetUrl.startsWith('https://')) {
            res.writeHead(400);
            res.end('Only HTTPS targets allowed');
            return;
          }
          try {
            const proxyRes = await fetch(targetUrl, {
              method: req.method,
              headers: { 'Content-Type': req.headers['content-type'] || 'application/json' },
              body: req.method !== 'GET' && req.method !== 'HEAD' ? await new Promise((resolve) => {
                const chunks = [];
                req.on('data', c => chunks.push(c));
                req.on('end', () => resolve(Buffer.concat(chunks)));
              }) : undefined,
            });
            const body = await proxyRes.text();
            res.writeHead(proxyRes.status, {
              'Content-Type': proxyRes.headers.get('content-type') || 'application/json',
              'Access-Control-Allow-Origin': '*',
            });
            res.end(body);
          } catch (e) {
            res.writeHead(502);
            res.end('Proxy error: ' + e.message);
          }
        });
      }
    }],
  build: {
    target:"esnext",
    // Ensure proper asset paths for Cloudflare Workers
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          // Split vendor chunks for better caching
          if (id.includes('node_modules')) {
            if (id.includes('preact')) {
              return 'vendor-preact';
            }
            if (id.includes('unocss')) {
              return 'vendor-unocss';
            }
            if (id.includes('@picocss')) {
              return 'vendor-pico';
            }
            return 'vendor';
          }
        }
      }
    }
  }
})
