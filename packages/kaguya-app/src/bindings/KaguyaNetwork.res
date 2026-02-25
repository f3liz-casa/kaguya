// KaguyaNetwork.res - ReScript bindings for kaguya-network
// Clean typed imports eliminating %raw for browser APIs

// ============================================================================
// Proxy Fetch
// ============================================================================

type fetchResponse
type customFetchFn = (string, JSON.t) => promise<fetchResponse>

@module("kaguya-network")
external makeProxiedFetch: string => customFetchFn = "makeProxiedFetch"

// ============================================================================
// OpenID Client Symbol Helpers
// ============================================================================

@module("kaguya-network")
external makeDiscoveryOptions: customFetchFn => JSON.t = "makeDiscoveryOptions"

@module("kaguya-network")
external setCustomFetchOnConfig: ({..}, customFetchFn) => unit = "setCustomFetchOnConfig"

@module("kaguya-network")
external clearCustomFetchOnConfig: {..} => unit = "clearCustomFetchOnConfig"

// ============================================================================
// Window / Location / History
// ============================================================================

@module("kaguya-network") external locationHref: unit => string = "locationHref"
@module("kaguya-network") external locationSearch: unit => string = "locationSearch"
@module("kaguya-network") external locationOrigin: unit => string = "locationOrigin"
@module("kaguya-network") external navigateTo: string => unit = "navigateTo"
@module("kaguya-network") external replaceState: string => unit = "replaceState"

type urlSearchParams
@module("kaguya-network") external searchParams: unit => urlSearchParams = "searchParams"
@module("kaguya-network") external getSearchParam: string => Nullable.t<string> = "getSearchParam"

// ============================================================================
// Network Hints
// ============================================================================

@module("kaguya-network") external addPreconnect: string => bool = "addPreconnect"
@module("kaguya-network") external addDnsPrefetch: string => bool = "addDnsPrefetch"
@module("kaguya-network") external batchDnsPrefetch: array<string> => unit = "batchDnsPrefetch"
@module("kaguya-network") external extractOrigin: string => Nullable.t<string> = "extractOrigin"
@module("kaguya-network") external extractHostname: string => Nullable.t<string> = "extractHostname"

// ============================================================================
// Feature Detection
// ============================================================================

@module("kaguya-network") external supportsIdleCallback: unit => bool = "supportsIdleCallback"
