// SPDX-License-Identifier: MPL-2.0

// Configuration object (opaque)
type configuration

// Token endpoint response
type tokenEndpointResponse = {
  access_token: string,
  token_type: string,
  scope: option<string>,
  expires_in: option<int>,
  refresh_token: option<string>,
}

// ClientAuth type (opaque)
type clientAuth

// None client auth (public client — no client_secret, for IndieAuth/Misskey OAuth2)
@module("openid-client")
external clientAuthNone: unit => clientAuth = "None"

// Custom fetch response (opaque — openid-client handles it internally)
type fetchResponse

// Custom fetch function type
type customFetchFn = (string, JSON.t) => promise<fetchResponse>

// Helper functions that use the customFetch symbol from openid-client
// Delegated to kaguya-network TypeScript layer (ReScript can't use Symbol property keys)
let makeDiscoveryOptions = (fetchFn: customFetchFn): JSON.t => {
  KaguyaNetwork.makeDiscoveryOptions(fetchFn->Obj.magic)->Obj.magic
}

let setCustomFetch = (config: configuration, fetchFn: customFetchFn): unit => {
  KaguyaNetwork.setCustomFetchOnConfig(config->Obj.magic, fetchFn->Obj.magic)
}

let clearCustomFetch = (config: configuration): unit => {
  KaguyaNetwork.clearCustomFetchOnConfig(config->Obj.magic)
}

// Discovery with options (5th arg is DiscoveryRequestOptions object)
@module("openid-client")
external discovery: (
  URL.t,
  string,
  Nullable.t<string>,
  clientAuth,
  JSON.t,
) => promise<configuration> = "discovery"

@module("openid-client")
external buildAuthorizationUrl: (
  configuration,
  Dict.t<string>,
) => URL.t = "buildAuthorizationUrl"

// PKCE helpers
@module("openid-client")
external randomPKCECodeVerifier: unit => string = "randomPKCECodeVerifier"

@module("openid-client")
external calculatePKCECodeChallenge: string => promise<string> = "calculatePKCECodeChallenge"

// State helper
@module("openid-client")
external randomState: unit => string = "randomState"

// Authorization code grant
// 4th arg: additional token endpoint parameters (Record<string, string>)
@module("openid-client")
external authorizationCodeGrant: (
  configuration,
  URL.t,
  {"pkceCodeVerifier": string, "expectedState": string},
  Dict.t<string>,
) => promise<tokenEndpointResponse> = "authorizationCodeGrant"
