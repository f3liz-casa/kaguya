# Kaguya Push Notification Guide

This guide explains how Kaguya's push notification system works and how to troubleshoot or set it up manually.

## How it Works

Kaguya uses an external **push-server** (`push-server.f3liz.casa`) to bridge Misskey webhooks to your browser's Web Push API. This is necessary because Misskey's native push registration is restricted to first-party apps.

1. **Browser Subscription:** Your browser generates a push subscription (endpoint and keys) using Kaguya's VAPID public key.
2. **Misskey Webhook:** Kaguya creates a webhook on your Misskey instance.
3. **Push-Server Registration:** Kaguya registers your browser subscription and the webhook secret with the push-server.
4. **Delivery:** Misskey -> Webhook -> Push-Server -> Browser.

**Privacy Note:** Your Misskey access token is **never** sent to the push-server. Only the webhook secret (generated randomly by your browser) and your push subscription are stored.

## Automatic Setup (Recommended)

Simply click the **"Enable Push Notifications"** button in Kaguya's settings or sidebar.
If prompted, allow notification permissions in your browser.

## Manual Setup / Troubleshooting

If the automatic setup fails, you can manually verify or register for push notifications.

### 1. Verify Webhook on Misskey

Go to your Misskey instance:
`Settings` -> `API` -> `Webhooks`

You should see a webhook named **"kaguya push"**.
- **URL:** `https://push-server.f3liz.casa/webhook/<your_user_id>`
- **Secret:** A random string (stored in your browser).
- **Events:** `mention`, `reply`, `renote`, `reaction`, `follow`, `receiveFollowRequest`, `pollEnded`.

### 2. Manual Registration via API

If you need to manually register your subscription with the push-server (advanced), you can send a POST request to `https://push-server.f3liz.casa/register`:

```json
{
  "id": "<your_user_id>",
  "misskey_origin": "https://your.misskey.instance",
  "webhook_user_id": "<your_user_id>",
  "webhook_secret": "<random_secret>",
  "push_subscription": {
    "endpoint": "...",
    "keys": { "p256dh": "...", "auth": "..." }
  },
  "notification_preference": "quiet",
  "delay_minutes": 1
}
```

### 3. Finding Your User ID

If you need your User ID for manual registration:
- **Developer Tools:** Open your browser's Developer Tools (`F12`), go to the **Network** tab, refresh, and look for the `i` request. Your ID is the `"id"` field in the response.
- **URL (sometimes):** On some instances, your ID is part of the URL when viewing your own profile settings.
- **Kaguya:** Your ID is stored in the app state once you are logged in.

### 4. Common Issues

- **Permission Denied:** Check your browser settings and ensure you haven't blocked notifications for the Kaguya domain.
- **Service Worker Error:** Try clearing your browser cache and registering the service worker again by toggling the push button.
- **No Notifications:** Verify that the "kaguya push" webhook exists on your Misskey instance and has the correct URL.
