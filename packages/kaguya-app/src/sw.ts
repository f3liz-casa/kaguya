// SPDX-License-Identifier: MPL-2.0
// sw.ts - Service Worker for kaguya
//
// Handles:
//  1. Precaching + runtime caching via serwist (for PWA offline support)
//  2. Web Push notifications from push-server (push-server.f3liz.casa)
//
// Build-time: vite-plugin-pwa injects the precache manifest into self.__SW_MANIFEST.

import type { PrecacheEntry, SerwistGlobalConfig } from "serwist";
import {
  CacheFirst,
  ExpirationPlugin,
  NetworkFirst,
  Serwist,
  StaleWhileRevalidate,
} from "serwist";

declare const self: ServiceWorkerGlobalScope & SerwistGlobalConfig;

const SW_VERSION = "2.0.0";

// ============================================================
// Serwist setup (precaching + runtime caching)
// ============================================================

const serwist = new Serwist({
  precacheEntries: self.__SW_MANIFEST,
  skipWaiting: true,
  clientsClaim: true,
  navigationPreload: false,
  runtimeCaching: [
    // Cache CDN resources (Iconify icons etc.) for 7 days
    {
      matcher: /^https:\/\/cdn\.jsdelivr\.net\/.*/i,
      handler: new CacheFirst({
        cacheName: "cdn-cache",
        plugins: [
          new ExpirationPlugin({
            maxEntries: 200,
            maxAgeSeconds: 7 * 24 * 60 * 60,
          }),
        ],
      }),
    },
    // Cache API requests with network-first (stale-while-revalidate for speed)
    {
      matcher: ({ url }) => url.pathname.startsWith("/api/"),
      handler: new StaleWhileRevalidate({
        cacheName: "api-cache",
        plugins: [
          new ExpirationPlugin({
            maxEntries: 50,
            maxAgeSeconds: 5 * 60, // 5 min
          }),
        ],
      }),
    },
    // Cache images from any Misskey instance
    {
      matcher: ({ request }) =>
        request.destination === "image" && !request.url.includes("localhost"),
      handler: new CacheFirst({
        cacheName: "image-cache",
        plugins: [
          new ExpirationPlugin({
            maxEntries: 300,
            maxAgeSeconds: 30 * 24 * 60 * 60, // 30 days
          }),
        ],
      }),
    },
  ],
});

serwist.addEventListeners();

// ============================================================
// Push Event Handler
// ============================================================

self.addEventListener("push", (event) => {
  if (!event.data) {
    return;
  }

  const notificationPromise = (async () => {
    let data;
    try {
      data = event.data.json();
    } catch (e) {
      console.error("[sw] Failed to parse push data:", e);
      return;
    }

    try {
      // Native Misskey push payload: { title, body, icon, tag, url }
      // Legacy push-server payload: { title, body, tag, silent, renotify, data }
      const title = data.title || "かぐや";
      const notifUrl = data.url || data?.data?.url || "/";
      const options: NotificationOptions = {
        body: data.body || "",
        tag: data.tag || `kaguya-${Date.now()}`,
        icon: data.icon || "/icons/icon-192.png",
        badge: "/icons/icon-192.png",
        silent: data.silent !== false,
        renotify: data.renotify === true,
        data: { url: notifUrl },
      };

      await self.registration.showNotification(title, options);
    } catch (e) {
      console.error("[sw] Failed to show notification:", e);
    }
  })();

  event.waitUntil(notificationPromise);
});

// ============================================================
// Notification Click Handler
// ============================================================

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const url = event.notification.data?.url || "/";

  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((clients) => {
        for (const client of clients) {
          if (
            client.url.includes(self.location.origin) &&
            "focus" in client
          ) {
            client.focus();
            if (url !== "/") {
              client.navigate(url);
            }
            return;
          }
        }
        return self.clients.openWindow(url);
      })
  );
});
