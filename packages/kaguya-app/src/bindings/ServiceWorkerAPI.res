// SPDX-License-Identifier: MPL-2.0

type serviceWorkerRegistration

type pushSubscription

type pushSubscriptionKeys = {
  p256dh: string,
  auth: string,
}

type pushSubscriptionJSON = {
  endpoint: string,
  keys: pushSubscriptionKeys,
}

type pushManager

type notificationPermission = [#default | #granted | #denied]

type subscribeOptions

@warning("-27")
let makeSubscribeOptions = (vapidKey: string): subscribeOptions => {
  %raw(`
    (function() {
      var padding = '='.repeat((4 - vapidKey.length % 4) % 4);
      var base64 = (vapidKey + padding).replace(/\-/g, '+').replace(/_/g, '/');
      var rawData = atob(base64);
      var outputArray = new Uint8Array(rawData.length);
      for (var i = 0; i < rawData.length; ++i) {
        outputArray[i] = rawData.charCodeAt(i);
      }
      return { userVisibleOnly: true, applicationServerKey: outputArray };
    })()
  `)
}

// Service Worker Container

@val @scope(("navigator", "serviceWorker"))
external register: string => promise<serviceWorkerRegistration> = "register"

@val @scope("navigator")
external serviceWorker: Nullable.t<{..}> = "serviceWorker"

let isSupported = (): bool => {
  Nullable.isNullable(serviceWorker) == false
}

// Push Manager

@get external pushManager: serviceWorkerRegistration => pushManager = "pushManager"

@send external subscribe: (pushManager, subscribeOptions) => promise<pushSubscription> = "subscribe"

@send external getSubscription: pushManager => promise<Nullable.t<pushSubscription>> = "getSubscription"

// Push Subscription

@get external endpoint: pushSubscription => string = "endpoint"

@send external toJSON: pushSubscription => pushSubscriptionJSON = "toJSON"

@send external unsubscribe: pushSubscription => promise<bool> = "unsubscribe"

// getKey returns raw ArrayBuffer
@send @return(nullable)
external getKey: (pushSubscription, string) => option<Js.TypedArray2.ArrayBuffer.t> = "getKey"

// Encode ArrayBuffer to base64url without padding (required by Misskey sw/register)
@warning("-27")
let encodeKeyBase64Url = (buffer: option<Js.TypedArray2.ArrayBuffer.t>): string => {
  %raw(`
    (function() {
      if (!buffer) return '';
      var bytes = new Uint8Array(buffer);
      var b64 = btoa(String.fromCharCode.apply(null, bytes));
      return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    })()
  `)
}

// Notification Permission

@val @scope("Notification")
external permission: notificationPermission = "permission"

@val @scope("Notification")
external requestPermission: unit => promise<notificationPermission> = "requestPermission"

let isNotificationSupported = (): bool => {
  %raw(`typeof Notification !== "undefined"`)
}
