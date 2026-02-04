# rescript-valibot

A ReScript binding layer for Valibot. GADT type witnesses on the ReScript side
define schemas at compile time. Those witness values are walked at runtime and
translated into Valibot schema objects. Valibot does the actual validation.

No codegen. No ppx. The witness is the schema.

---

## Structure

```
┌─────────────────────────────────────────────────────────┐
│  User code                                              │
│                                                         │
│    let schema = object([                                │
│      field("name",  pipe(string, [nonEmpty])),          │
│      field("age",   pipe(int, [min(0)])),               │
│      field("email", pipe(string, [nonEmpty, email])),   │
│    ])                                                   │
│                                                         │
│    data->parse(~schema)                                 │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│  Schema.res                                             │
│  GADT schema<'a> + action<'a>                           │
│  field — existential wrapper for heterogeneous fields   │
│  Constructors survive at runtime as variant values      │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│  Bridge.res                                             │
│  Valibot.res — opaque externals, matched to actual API  │
│  toValibot — recursive walk: variant values → v.* calls │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│  Parse.res                                              │
│  parse, parseOrThrow — public API, pipe-first           │
│  Decodes safeParse's { success, output, issues } shape  │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│  Valibot (JS, npm)                                      │
│  Runtime validation engine. Not reimplemented here.     │
└─────────────────────────────────────────────────────────┘
```

---

## Schema.res

### schema<'a>

GADT. Each constructor is a type witness — it carries `'a` at compile time
and survives as a variant value at runtime.

`Pipe` mirrors Valibot's mental model directly: a base schema followed by
actions. A `Pipe` can itself be the base of another `Pipe` — this is how
Valibot composes schemas.

```rescript
type rec schema<'a> =
  | String: schema<string>
  | Number: schema<float>
  | Int: schema<int>
  | Bool: schema<bool>
  | Array(schema<'a>): schema<'a array>
  | Optional(schema<'a>): schema<'a option>
  | Object(field array): schema<obj>
  | Pipe(schema<'a>, action<'a> array): schema<'a>
```

What these become in JS at runtime:

```
String              →  0
Number              →  1
Int                 →  2
Bool                →  3
Array(String)       →  { TAG: 4, _0: 0 }
Optional(Number)    →  { TAG: 5, _0: 1 }
Object([...])       →  { TAG: 6, _0: [...] }
Pipe(String, [...]) →  { TAG: 7, _0: 0, _1: [...] }
```

The type parameter `'a` disappears. The variant structure does not.

### action<'a>

Each constructor mirrors one Valibot action. Message placement matches
Valibot's convention exactly: actions that take a constraint value have
message as the second argument. Actions that take only a message have it
as the first.

```rescript
and action<'a> =
  | NonEmpty(string option): action<string>
  | Email(string option): action<string>
  | MinLength(int, string option): action<string>
  | MaxLength(int, string option): action<string>
  | Min(float, string option): action<float>
  | Max(float, string option): action<float>
  | Integer(string option): action<int>
  | Trim: action<string>
  | Check(('a -> bool), string): action<'a>
  | Transform('a -> 'b): action<'a>
```

Common actions without a message are exposed as plain values for readability:

```rescript
let nonEmpty  = NonEmpty(None)
let email     = Email(None)
let trim      = Trim
let integer   = Integer(None)

// With message — call the constructor directly:
// NonEmpty(Some("Required"))
// MinLength(8, Some("Too short"))
```

### field — existential wrapper

`Object` holds an array of fields. Each field has a different `'a`.
ReScript cannot put heterogeneous `schema<'a>` values in one array directly.

`field` is an opaque type. The constructor hides `'a`. The bridge knows
the internal layout and reads it back. This is the single use of `Obj.magic`
in the entire library — justified because the layout is controlled here.

```rescript
type field

let field : <'a>(string, schema<'a>) -> field =
  <'a>(name, schema) => Obj.magic({ name, schema })
```

Usage from the user side is clean:

```rescript
let schema = object([
  field("name",  string),
  field("age",   int),
  field("email", pipe(string, [nonEmpty, email])),
])
```

### Convenience constructors

These are thin wrappers so the user doesn't write constructors with empty
action arrays for simple schemas:

```rescript
let string   = String
let number   = Number
let int      = Int
let bool     = Bool
let array    = (s) => Array(s)
let optional = (s) => Optional(s)
let object   = (fields) => Object(fields)
let pipe     = (base, actions) => Pipe(base, actions)
```

---

## Valibot.res

Opaque bindings to Valibot's JS API. Every signature here matches what
Valibot actually exports. Nothing invented.

### Opaque types

```rescript
// A Valibot schema object. Opaque — ReScript never inspects its internals.
type schema

// The raw object returned by safeParse. Decoded in Parse.res.
type parseResult
```

### Schema constructors

Valibot schemas accept an optional message as their first argument.
In ReScript, this is a trailing optional labeled arg.

```rescript
@module("valibot") external string:  (~message: string=?) -> schema = "string"
@module("valibot") external number:  (~message: string=?) -> schema = "number"
@module("valibot") external boolean: (~message: string=?) -> schema = "boolean"

@module("valibot") external array:
  (schema, ~message: string=?) -> schema = "array"

@module("valibot") external optional:
  (schema) -> schema = "optional"
```

### object — built dynamically

`v.object()` takes a plain JS object `{ key: schema, ... }`.
The shape is not known at compile time, so we build it with `set_index`.

```rescript
// Opaque JS object we build field by field
type obj

@val external createObj: unit -> obj = "{}"

@set_index external setField: (obj, string, schema) -> unit = ""

@module("valibot") external object_: obj -> schema = "object"
```

Usage in the bridge:

```rescript
let obj = createObj()
fields->Array.iter(~f=(name, s) => setField(obj, name, s))
object_(obj)
```

### pipe — variadic

`v.pipe(schema, action1, action2, ...)` is variadic. All arguments share
the same internal JS type. `@variadic` works here.

```rescript
@module("valibot") @variadic external pipe:
  (schema array) -> schema = "pipe"
```

Called as: `pipe([| baseSchema; action1; action2 |])`
The first element must be a schema. The rest are actions.
Both are `schema` on the JS side — Valibot does not distinguish them at runtime.

### Actions

Message placement matches Valibot's actual signatures.

```rescript
// message only
@module("valibot") external nonEmpty:  (~message: string=?) -> schema = "nonEmpty"
@module("valibot") external email:     (~message: string=?) -> schema = "email"
@module("valibot") external integer:   (~message: string=?) -> schema = "integer"
@module("valibot") external trim:      unit -> schema = "trim"

// constraint + message
@module("valibot") external minLength: (int, ~message: string=?) -> schema = "minLength"
@module("valibot") external maxLength: (int, ~message: string=?) -> schema = "maxLength"
@module("valibot") external minValue:  (float, ~message: string=?) -> schema = "minValue"
@module("valibot") external maxValue:  (float, ~message: string=?) -> schema = "maxValue"

// custom
@module("valibot") external check:     (('a -> bool), string) -> schema = "check"
@module("valibot") external transform: ('a -> 'b) -> schema = "transform"
```

### Parsing

```rescript
// Throws ValiError on failure. Returns output directly.
@module("valibot") external parse:     (schema, unknown) -> 'a = "parse"

// Never throws. Returns { success, output, issues }.
@module("valibot") external safeParse: (schema, unknown) -> parseResult = "safeParse"
```

---

## Bridge.res

Walks the GADT variant tree. Produces Valibot schema objects.
This is the only file that touches both sides.

```rescript
open Schema
open Valibot

let rec toValibot : <'a>(schema<'a>) -> schema = <'a>(s) =>
  switch s {
  | String   => string()
  | Number   => number()
  | Int      => pipe([| number(); integer() |])
  | Bool     => boolean()
  | Array(inner) => array(toValibot(inner))
  | Optional(inner) => optional(toValibot(inner))
  | Object(fields) =>
      let obj = createObj()
      fields->Array.iter(~f=(f => {
        // field is opaque. We know the layout: { name, schema }.
        let { name, schema } : { name: string, schema: schema<unknown> } = Obj.magic(f)
        setField(obj, name, toValibot(schema))
      }))
      object_(obj)
  | Pipe(base, actions) =>
      let baseSchema = toValibot(base)
      let actionSchemas = actions->Array.map(~f=toValibotAction)
      pipe(Array.append([| baseSchema |], actionSchemas))
  }

and toValibotAction : <'a>(action<'a>) -> schema = <'a>(a) =>
  switch a {
  | NonEmpty(msg)         => nonEmpty(?message=msg)
  | Email(msg)            => email(?message=msg)
  | MinLength(n, msg)     => minLength(n, ?message=msg)
  | MaxLength(n, msg)     => maxLength(n, ?message=msg)
  | Min(n, msg)           => minValue(n, ?message=msg)
  | Max(n, msg)           => maxValue(n, ?message=msg)
  | Integer(msg)          => integer(?message=msg)
  | Trim                  => trim()
  | Check(fn, msg)        => check(fn, msg)
  | Transform(fn)         => transform(fn)
  }
```

---

## Issue.res

Mirrors Valibot's actual issue shape. Pulled directly from the docs,
not invented.

```rescript
type kind = [ #schema | #validation | #transformation ]

type path_item = {
  type: string,
  origin: [ #key | #value ],
  input: unknown,
  key: unknown option,
  value: unknown,
}

type issue = {
  kind: kind,
  type: string,
  input: unknown,
  expected: string option,
  received: string,
  message: string,
  path: path_item array option,
}
```

`path` tells you where in the data the issue occurred.
`issue.message` is what you show the user.
`issue.expected` / `issue.received` are language-neutral — useful for i18n.

---

## Parse.res

Public API. Two entry points. Pipe-first for ReScript's `->`.

### Result type

Mirrors safeParse's actual discriminated shape: `{ success: true, output }`
or `{ success: false, issues }`. Not mapped to `Result.t` — that would
hide what's actually happening at runtime.

```rescript
type result<'a> =
  | Success of { output: 'a }
  | Failure of { issues: Issue.issue array }
```

### Decoding safeParse's raw output

safeParse returns an opaque JS object. We read its fields with `@get`.

```rescript
@get external getSuccess: Valibot.parseResult -> bool = "success"
@get external getOutput:  Valibot.parseResult -> 'a   = "output"
@get external getIssues:  Valibot.parseResult -> Issue.issue array = "issues"

let decodeSafeParseResult : <'a>(Valibot.parseResult) -> result<'a> = <'a>(raw) =>
  if getSuccess(raw) then
    Success({ output: getOutput(raw) })
  else
    Failure({ issues: getIssues(raw) })
```

### Cache

`toValibot` walks the GADT and produces a Valibot schema object.
That walk should happen once per schema definition, not on every parse call.
Schemas are typically defined at module top level, so this is a safety net.

```rescript
let cache : (Obj.t, Valibot.schema) Hashtbl.t = Hashtbl.create(16)

let getOrBuild : <'a>(Schema.schema<'a>) -> Valibot.schema = <'a>(schema) => {
  let key = Obj.repr(schema)
  switch Hashtbl.find_opt(cache, key) {
  | Some(v) => v
  | None =>
    let v = Bridge.toValibot(schema)
    Hashtbl.replace(cache, key, v)
    v
  }
}
```

### Public functions

Data-first. Designed for `->` pipe.

```rescript
// Safe. Returns Success | Failure. Never throws.
let parse : <'a>(unknown, ~schema: Schema.schema<'a>) -> result<'a> = <'a>(data, ~schema) => {
  let vSchema = getOrBuild(schema)
  let raw = Valibot.safeParse(vSchema, data)
  decodeSafeParseResult(raw)
}

// Unsafe. Throws on failure. Returns 'a directly.
let parseOrThrow : <'a>(unknown, ~schema: Schema.schema<'a>) -> 'a = <'a>(data, ~schema) => {
  let vSchema = getOrBuild(schema)
  Valibot.parse(vSchema, data)
}
```

---

## Usage

```rescript
open ReScript_valibot

// Reusable, composable schemas.
let emailSchema  = pipe(string, [nonEmpty, email])
let nameSchema   = pipe(string, [nonEmpty, MinLength(1, None), MaxLength(50, None)])
let ageSchema    = pipe(int, [Min(0.0, None), Max(150.0, None)])

// Compose into an object.
let userSchema = object([
  field("name",  nameSchema),
  field("age",   ageSchema),
  field("email", emailSchema),
])

// Parse. Pipe-first.
let json : unknown = JSON.parse(rawString)

switch json->parse(~schema=userSchema) {
| Success({ output }) =>
    // output is typed. Compiler knows the shape from userSchema.
    Console.log(output.name)
| Failure({ issues }) =>
    issues->Array.iter(~f=(issue =>
      Console.log(issue.message)
    ))
}

// Or if you're okay with throwing:
let user = json->parseOrThrow(~schema=userSchema)
```

Pipe nesting — same composability as Valibot:

```rescript
let gmailSchema = pipe(emailSchema, [Check(
  (email => email->String.endsWith("@gmail.com")),
  "Must be a Gmail address"
)])
```

---

## File structure

```
rescript-valibot/
├── src/
│   ├── Schema.res       — schema<'a>, action<'a>, field, convenience constructors
│   ├── Issue.res        — issue, path_item (mirrors Valibot's shape)
│   ├── Valibot.res      — opaque externals for Valibot's JS API
│   ├── Bridge.res       — toValibot, toValibotAction
│   └── Parse.res        — result<'a>, parse, parseOrThrow, cache
├── test/
│   ├── Schema_test.res
│   ├── Bridge_test.res
│   └── Parse_test.res
└── package.json
```

---

## Boundaries and known constraints

`Obj.magic` appears in two places only. First, inside `field`, to erase
the existential `'a` when storing heterogeneous schemas in one array.
Second, inside `Bridge.toValibot` when reading the field back. Both are
in controlled code that owns the layout. Nowhere else.

`pipe` is bound with `@variadic`. All arguments are the same opaque
`schema` type on the JS side. Valibot does not distinguish base schemas
from actions at runtime — they share the same internal type. The first
element must be a base schema; the rest must be actions. This is a
runtime convention, same as in Valibot itself.

`Int` does not exist in JavaScript. It compiles to `pipe([| number(); integer() |])`.
`integer()` is a built-in Valibot action that checks `Number.isInteger`.

`Transform` changes the output type mid-pipe. The GADT models this as
`action<'a>` where the transform function is `'a -> 'b`. The type after
the transform becomes the new `'a` for subsequent actions. This is
supported in Valibot. The full type-flow through a pipe containing a
transform is the one edge case that needs careful testing — the compiler
may need a type annotation at the pipe call site.

Async validation (`pipeAsync`, `parseAsync`) is not covered. It has the
same shape as the sync version — the additions would be parallel async
variants of `pipe` in Valibot.res and `parse` in Parse.res.
