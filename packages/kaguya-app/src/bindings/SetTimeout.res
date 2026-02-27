// SPDX-License-Identifier: MPL-2.0

// setTimeout / clearTimeout

type timeoutId

@val
external make: (unit => unit, int) => timeoutId = "setTimeout"

@val
external clear: timeoutId => unit = "clearTimeout"
