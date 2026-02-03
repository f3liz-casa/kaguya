// SPDX-License-Identifier: MPL-2.0
// URLSearchParams.res - URLSearchParams bindings

type t

@new
external make: string => t = "URLSearchParams"

@send
external get: (t, string) => Nullable.t<string> = "get"

let get = (params: t, key: string): option<string> => {
  params->get(key)->Nullable.toOption
}
