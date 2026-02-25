// kaguya-network - TypeScript networking utilities for Kaguya
// Provides clean APIs for browser features that are awkward in ReScript

import { customFetch } from "openid-client";

// ============================================================================
// Proxy Fetch (OAuth2 CORS bypass)
// ============================================================================

/**
 * Create a fetch function that proxies .well-known requests through the worker.
 * Other requests go directly to avoid unnecessary proxy overhead.
 */
export function makeProxiedFetch(proxyBase: string): typeof fetch {
  return (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    if (url.includes("/.well-known/")) {
      return fetch(proxyBase + encodeURIComponent(url), init);
    }
    return fetch(url, init);
  };
}

// ============================================================================
// OpenID Client Symbol Helpers
// ============================================================================

/**
 * Create discovery options with the customFetch Symbol.
 * ReScript can't use computed property keys (Symbols), so this must be in TS.
 */
export function makeDiscoveryOptions(fetchFn: typeof fetch): Record<string, unknown> {
  return { [customFetch]: fetchFn, algorithm: "oauth2" };
}

/** Set customFetch on a configuration object */
export function setCustomFetchOnConfig(config: Record<string, unknown>, fetchFn: typeof fetch): void {
  (config as any)[customFetch] = fetchFn;
}

/** Clear customFetch from a configuration object */
export function clearCustomFetchOnConfig(config: Record<string, unknown>): void {
  (config as any)[customFetch] = undefined;
}

// ============================================================================
// Window / Location / History Utilities
// ============================================================================

/** Get current window.location.href */
export function locationHref(): string {
  return window.location.href;
}

/** Get current window.location.search */
export function locationSearch(): string {
  return window.location.search;
}

/** Get current window.location.origin */
export function locationOrigin(): string {
  return window.location.origin;
}

/** Navigate by setting window.location.href */
export function navigateTo(url: string): void {
  window.location.href = url;
}

/** Replace current history state without navigation */
export function replaceState(url: string): void {
  window.history.replaceState({}, "", url);
}

/** Create URLSearchParams from current URL search string */
export function searchParams(): URLSearchParams {
  return new URLSearchParams(window.location.search);
}

/** Get a single param from current URL search string */
export function getSearchParam(key: string): string | null {
  return new URLSearchParams(window.location.search).get(key);
}

// ============================================================================
// Network Hints (Preconnect / DNS Prefetch)
// ============================================================================

const preconnectedOrigins = new Set<string>();
const prefetchedDomains = new Set<string>();

/** Add preconnect + dns-prefetch hints for an origin */
export function addPreconnect(origin: string): boolean {
  if (preconnectedOrigins.has(origin)) return false;
  preconnectedOrigins.add(origin);

  const link1 = document.createElement("link");
  link1.rel = "preconnect";
  link1.href = origin;
  link1.crossOrigin = "anonymous";
  document.head.appendChild(link1);

  const link2 = document.createElement("link");
  link2.rel = "dns-prefetch";
  link2.href = origin;
  document.head.appendChild(link2);

  return true;
}

/** Add dns-prefetch hint for a domain (deduplicates) */
export function addDnsPrefetch(origin: string): boolean {
  if (prefetchedDomains.has(origin)) return false;
  prefetchedDomains.add(origin);

  const link = document.createElement("link");
  link.rel = "dns-prefetch";
  link.href = origin;
  document.head.appendChild(link);

  return true;
}

/** Batch dns-prefetch using document fragment for performance */
export function batchDnsPrefetch(domains: string[]): void {
  const fragment = document.createDocumentFragment();
  for (const domain of domains) {
    const link = document.createElement("link");
    link.rel = "dns-prefetch";
    link.href = domain;
    fragment.appendChild(link);
  }
  document.head.appendChild(fragment);
}

/** Extract origin from a URL string, returns null on invalid URLs */
export function extractOrigin(url: string): string | null {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}

/** Extract hostname from a URL string, returns null on invalid URLs */
export function extractHostname(url: string): string | null {
  try {
    return new URL(url).hostname;
  } catch {
    return null;
  }
}

// ============================================================================
// Browser Feature Detection
// ============================================================================

/** Check if requestIdleCallback is available */
export function supportsIdleCallback(): boolean {
  return typeof requestIdleCallback !== "undefined";
}
