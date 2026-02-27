// SPDX-License-Identifier: MPL-2.0

// Signal Type

type signal<'a>
type computed<'a> = signal<'a>
type readonlySignal<'a> = signal<'a>

// Core Signal Functions

@module("@preact/signals")
external make: 'a => signal<'a> = "signal"

@module("@preact/signals")
external computed: (unit => 'a) => computed<'a> = "computed"

// Run a side effect when signals change
// Returns a cleanup function
@module("@preact/signals")
external effect: (unit => option<unit => unit>) => unit => unit = "effect"

// Batch multiple signal updates
@module("@preact/signals")
external batch: (unit => unit) => unit = "batch"

// Untracked read - read a signal without subscribing
@module("@preact/signals")
external untracked: (unit => 'a) => 'a = "untracked"

// Signal Value Access

@get external value: signal<'a> => 'a = "value"

@set external setValue: (signal<'a>, 'a) => unit = "value"

// Peek at the current value without subscribing
@send external peek: signal<'a> => 'a = "peek"

// Preact Integration Hook

// useSignal creates a signal that persists across renders
@module("@preact/signals")
external useSignal: 'a => signal<'a> = "useSignal"

// useComputed creates a computed signal that persists across renders
@module("@preact/signals")
external useComputed: (unit => 'a) => computed<'a> = "useComputed"

// useSignalEffect runs an effect synchronized with component lifecycle
@module("@preact/signals")
external useSignalEffect: (unit => option<unit => unit>) => unit = "useSignalEffect"

// Helper Functions

let update = (signal: signal<'a>, fn: 'a => 'a): unit => {
  setValue(signal, fn(value(signal)))
}

// Map a signal to a new computed signal
let map = (signal: signal<'a>, fn: 'a => 'b): computed<'b> => {
  computed(() => fn(value(signal)))
}
