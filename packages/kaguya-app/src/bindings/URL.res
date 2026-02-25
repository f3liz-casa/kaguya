// SPDX-License-Identifier: MPL-2.0
// URL.res - Minimal URL API bindings

type t

@new external make: string => t = "URL"
@new external makeWithBase: (string, string) => t = "URL"

@get external href: t => string = "href"
@get external origin: t => string = "origin"
@get external hostname: t => string = "hostname"
@get external pathname: t => string = "pathname"
@get external search: t => string = "search"
@get external searchParams: t => URLSearchParams.t = "searchParams"

@send external toString: t => string = "toString"
