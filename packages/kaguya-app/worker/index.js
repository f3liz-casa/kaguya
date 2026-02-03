// SPDX-License-Identifier: MPL-2.0
// Cloudflare Worker entry point for Kaguya with Static Assets

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // Try to serve the static asset
    try {
      // First, try to get the exact asset
      let response = await env.ASSETS.fetch(request);
      
      // If we get a 404, check if it's a client-side route
      // For SPA routing, serve index.html for non-asset paths
      if (response.status === 404) {
        // Check if the path looks like an asset (has extension)
        const hasExtension = /\.[^/.]+$/.test(url.pathname);
        
        // If no extension, it's likely a client-side route - serve index.html
        if (!hasExtension || url.pathname === '/') {
          const indexRequest = new Request(new URL('/', request.url), request);
          response = await env.ASSETS.fetch(indexRequest);
        }
      }
      
      // Add security headers
      const headers = new Headers(response.headers);
      headers.set('X-Content-Type-Options', 'nosniff');
      headers.set('X-Frame-Options', 'DENY');
      headers.set('X-XSS-Protection', '1; mode=block');
      headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
      
      // Add CSP header for security
      headers.set('Content-Security-Policy', 
        "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
        "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; " +
        "img-src 'self' data: https: http:; " +
        "connect-src 'self' https://*; " +
        "font-src 'self' data: https://cdn.jsdelivr.net; " +
        "media-src 'self' https: http:;"
      );
      
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers
      });
    } catch (error) {
      // If something goes wrong, return a simple error page
      return new Response('Internal Server Error', { 
        status: 500,
        headers: { 'Content-Type': 'text/plain' }
      });
    }
  }
};
