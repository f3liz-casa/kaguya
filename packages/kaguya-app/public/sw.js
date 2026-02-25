// SPDX-License-Identifier: MPL-2.0
// sw.js - Service Worker for kaguya push notifications
//
// Handles Web Push events from push-server (push-server.f3liz.casa).
// Push-server sends pre-formatted payloads with: title, body, tag, silent, renotify, data.
// Clean-room implementation.

/// @ts-check

const SW_VERSION = '1.1.0';

// ============================================================
// Push Event Handler
// ============================================================

self.addEventListener('push', (event) => {
  if (!event.data) {
    return;
  }

  const notificationPromise = (async () => {
    let data;
    try {
      data = event.data.json();
    } catch (e) {
      console.error('[sw] Failed to parse push data:', e);
      return;
    }

    // If it's a ping from the server (for checking 410 Gone), ignore it.
    // Note: Some browsers may still show a default notification if we don't call showNotification.
    if (data && data.data && data.data.type === 'ping') {
      console.log('[sw] Received ping');
      return;
    }

    try {
      // Push-server sends: { title, body, tag, silent, renotify, data }
      const title = data.title || 'かぐや';
      const options = {
        body: data.body || '',
        tag: data.tag || `kaguya-${Date.now()}`,
        silent: data.silent !== false,
        renotify: data.renotify === true,
        icon: '/favicon.ico',
        data: data.data || {},
      };

      await self.registration.showNotification(title, options);
    } catch (e) {
      console.error('[sw] Failed to show notification:', e);
    }
  })();

  event.waitUntil(notificationPromise);
});

// ============================================================
// Notification Click Handler
// ============================================================

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const url = event.notification.data?.url || '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus();
          if (url !== '/') {
            client.navigate(url);
          }
          return;
        }
      }
      return self.clients.openWindow(url);
    })
  );
});

// ============================================================
// Lifecycle Events
// ============================================================

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
