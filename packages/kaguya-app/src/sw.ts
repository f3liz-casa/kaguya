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

declare global {
  interface WorkerGlobalScope extends SerwistGlobalConfig {
    __SW_MANIFEST: (PrecacheEntry | string)[] | undefined;
  }
}

declare const self: ServiceWorkerGlobalScope;

const SW_VERSION = "2.1.0";

const NOTE_PREFETCH_CACHE = "kaguya-note-prefetch";

// ============================================================
// Serwist setup (precaching + runtime caching)
// ============================================================

const serwist = new Serwist({
  precacheEntries: self.__SW_MANIFEST,
  skipWaiting: false,
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

// Misskey sw/register push payload types (from misskey/packages/sw/src/types.ts)
type PushNotificationData =
  | { type: "notification"; body: { type: string; user?: { name?: string | null; username: string; avatarUrl?: string | null }; note?: { id: string; text?: string | null }; [k: string]: unknown }; userId: string; dateTime: number }
  | { type: "unreadAntennaNote"; body: { antenna: { id: string; name: string }; note: { text?: string | null; user: { name?: string | null; username: string; avatarUrl?: string | null } } }; userId: string; dateTime: number }
  | { type: "newChatMessage"; body: { fromUser: { name?: string | null; username: string; avatarUrl?: string | null }; text: string; toRoom?: { name: string } | null; toRoomId?: string | null; fromUserId: string }; userId: string; dateTime: number }
  | { type: "readAllNotifications"; userId: string; dateTime: number };

function getUserName(user: { name?: string | null; username: string }): string {
  return user.name || user.username;
}

function composeNotification(data: PushNotificationData): [string, NotificationOptions] | null {
  switch (data.type) {
    case "notification": {
      const b = data.body;
      const user = b.user;
      const note = b.note;
      const icon = user?.avatarUrl ?? "/icons/icon-192.png";
      const notifData = { url: note ? `/push/notes/${note.id}?userId=${data.userId}` : "/", userId: data.userId, type: data.type, body: b };
      switch (b.type) {
        case "mention":
        case "reply":
        case "quote":
          return [`${getUserName(user!)} からの${b.type === "mention" ? "メンション" : b.type === "reply" ? "返信" : "引用"}`, { body: note?.text ?? "", icon, data: notifData }];
        case "renote":
          return [`${getUserName(user!)} がリノート`, { body: note?.text ?? "", icon, data: notifData }];
        case "reaction":
          return [`${b.reaction ?? "👍"} ${getUserName(user!)}`, { body: note?.text ?? "", icon, data: notifData }];
        case "follow":
          return [`${getUserName(user!)} にフォローされました`, { icon, data: notifData }];
        case "receiveFollowRequest":
          return [`${getUserName(user!)} からフォローリクエスト`, { icon, data: notifData }];
        case "followRequestAccepted":
          return [`${getUserName(user!)} がフォローリクエストを承認`, { icon, data: notifData }];
        case "app":
          return [(b.header as string) ?? (b.body as string) ?? "通知", { body: b.header ? (b.body as string) : "", icon: (b.icon as string) ?? icon, data: notifData }];
        default:
          return ["通知", { body: note?.text ?? "", icon, data: notifData }];
      }
    }
    case "unreadAntennaNote": {
      const { antenna, note } = data.body;
      return [`アンテナ: ${antenna.name}`, { body: `${getUserName(note.user)}: ${note.text ?? ""}`, icon: note.user.avatarUrl ?? "/icons/icon-192.png", tag: `antenna:${antenna.id}`, data: { url: "/", userId: data.userId, type: data.type, body: data.body }, renotify: true }];
    }
    case "newChatMessage": {
      const { fromUser, text, toRoom } = data.body;
      const title = toRoom ? `${toRoom.name}: ${getUserName(fromUser)}` : getUserName(fromUser);
      return [title, { body: text, icon: fromUser.avatarUrl ?? "/icons/icon-192.png", tag: toRoom ? `chat:room:${data.body.toRoomId}` : `chat:user:${data.body.fromUserId}`, data: { url: "/", userId: data.userId, type: data.type, body: data.body }, renotify: true }];
    }
    default:
      return null;
  }
}

self.addEventListener("push", (event) => {
  if (!event.data) return;

  event.waitUntil((async () => {
    let data: PushNotificationData;
    try {
      data = event.data!.json();
    } catch (e) {
      console.error("[sw] Failed to parse push data:", e);
      return;
    }

    // Ignore stale notifications (older than 1 day)
    if (Date.now() - data.dateTime > 1000 * 60 * 60 * 24) return;

    if (data.type === "readAllNotifications") {
      const notifications = await self.registration.getNotifications();
      notifications.forEach((n) => n.close());
      return;
    }

    const composed = composeNotification(data);
    if (!composed) return;
    const [title, options] = composed;
    await self.registration.showNotification(title, { badge: "/icons/icon-192.png", ...options });

    // Cache partial note data from the push payload for instant preview
    if (data.type === "notification" && data.body.note) {
      const note = data.body.note;
      const user = data.body.user;
      if (note.id && user) {
        try {
          const cache = await caches.open(NOTE_PREFETCH_CACHE);
          const preview = {
            text: note.text ?? "",
            userName: user.name ?? user.username,
            userUsername: user.username,
            avatarUrl: user.avatarUrl ?? "",
          };
          const key = `${self.location.origin}/_note-preview/${note.id}`;
          await cache.put(key, new Response(JSON.stringify(preview), {
            headers: { "Content-Type": "application/json" },
          }));
        } catch { /* best-effort */ }
      }
    }
  })());
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
