import { customFetch } from "openid-client";

export function makeProxiedFetch(proxyBase: string): typeof fetch {
  return (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    if (url.includes("/.well-known/")) {
      return fetch(proxyBase + encodeURIComponent(url), init);
    }
    return fetch(url, init);
  };
}

export function makeDiscoveryOptions(fetchFn: typeof fetch): Record<string, unknown> {
  return { [customFetch]: fetchFn, algorithm: "oauth2" };
}

export function setCustomFetchOnConfig(config: Record<string, unknown>, fetchFn: typeof fetch): void {
  (config as any)[customFetch] = fetchFn;
}

export function clearCustomFetchOnConfig(config: Record<string, unknown>): void {
  (config as any)[customFetch] = undefined;
}

export function locationHref(): string {
  return window.location.href;
}

export function locationSearch(): string {
  return window.location.search;
}

export function locationOrigin(): string {
  return window.location.origin;
}

export function navigateTo(url: string): void {
  window.location.href = url;
}

export function replaceState(url: string): void {
  window.history.replaceState({}, "", url);
}

export function searchParams(): URLSearchParams {
  return new URLSearchParams(window.location.search);
}

export function getSearchParam(key: string): string | null {
  return new URLSearchParams(window.location.search).get(key);
}

const preconnectedOrigins = new Set<string>();
const prefetchedDomains = new Set<string>();

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

export function addDnsPrefetch(origin: string): boolean {
  if (prefetchedDomains.has(origin)) return false;
  prefetchedDomains.add(origin);

  const link = document.createElement("link");
  link.rel = "dns-prefetch";
  link.href = origin;
  document.head.appendChild(link);

  return true;
}

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

export function extractOrigin(url: string): string | null {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
}

export function extractHostname(url: string): string | null {
  try {
    return new URL(url).hostname;
  } catch {
    return null;
  }
}

export function supportsIdleCallback(): boolean {
  return typeof requestIdleCallback !== "undefined";
}
