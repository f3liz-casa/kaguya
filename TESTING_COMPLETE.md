# Testing Complete: rescript-valibot

**Date**: 2024
**Status**: ✅ **COMPLETE**

## Summary

Successfully added comprehensive test coverage to the `rescript-valibot` package using Vitest. All tests compile cleanly and pass.

## What Was Done

### 1. Test Infrastructure Setup ✅

- **Added dependencies**: `vitest@^4.0.18` as dev dependency
- **Created vitest config**: `vitest.config.js` with globals and ESM support
- **Updated rescript config**: Added `test` directory to sources
- **Added npm scripts**:
  - `pnpm test` - Run tests once
  - `pnpm test:watch` - Run tests in watch mode

### 2. Test Files Created ✅

#### `/packages/rescript-valibot/test/Primitives.test.res` (21 tests)

Tests for basic schema types:
- ✅ String schema (valid/invalid)
- ✅ Number schema (valid/invalid)
- ✅ Boolean schema (true/false/invalid)
- ✅ Int schema (valid)
- ✅ Optional schemas (with value/undefined/null)
- ✅ Array schemas (strings/numbers/empty/invalid elements)
- ✅ Pipe and actions (nonEmpty, email, trim, min, max, combined)

#### `/packages/rescript-valibot/test/Objects.test.res` (11 tests)

Tests for object schemas:
- ✅ Simple objects (valid/missing field/wrong type)
- ✅ Objects with 3+ fields
- ✅ Objects with optional fields (present/absent)
- ✅ Nested object schemas
- ✅ Objects with array fields
- ✅ Objects with extra fields (open objects)
- ✅ parseOrThrow function (valid/invalid)

### 3. Critical Bug Fixes ✅

#### WeakMap → Map Migration

**Problem**: Cache used `WeakMap` which requires object keys, but GADT primitive constructors (`String`, `Number`, `Bool`, `Int`) are not objects.

**Error**: 
```
TypeError: Invalid value used as weak map key
```

**Solution**: Changed cache from `WeakMap` to `Map` in `src/Parse.res`:

```rescript
// Before
let cache: weakMap<Obj.t, V.schema> = makeWeakMap()

// After  
let cache: map<Obj.t, V.schema> = makeMap()
```

This allows all schema types (primitives and complex) to be cached correctly.

#### ReScript 12 Array Access

**Problem**: Array indexing returns `option<'a>` in ReScript 12.

**Solution**: Changed all array access patterns:

```rescript
// Before
arr[0]  // Returns option<string>

// After
arr[0]->Option.getOrThrow  // Unwraps to string
```

#### Null vs Undefined in Optional Schemas

**Problem**: Test expected `null` to be treated the same as `undefined` for `optional(string)`.

**Reality**: In Valibot (and JavaScript):
- `optional` accepts `undefined` → maps to ReScript's `None`
- `null` is a distinct value and should fail validation for `optional(string)`

**Solution**: Fixed test to expect validation failure for `null`.

### 4. Migration to ReScript 12 Deprecations ✅

Changed deprecated functions:
- `Option.getExn` → `Option.getOrThrow`

## Test Results

```
✓ test/Primitives.test.res.mjs (21 tests) 9ms
✓ test/Objects.test.res.mjs (11 tests) 6ms

Test Files  2 passed (2)
     Tests  32 passed (32)
```

**All 32 tests pass! 🎉**

## Build Status

- ✅ `rescript-valibot` builds with no errors
- ✅ Full monorepo builds with no errors
- ✅ All tests compile and pass
- ⚠️ Only warning: Unknown field 'version' in rescript.json (cosmetic, can be ignored)

## Test Coverage

The test suite covers:

| Category | Coverage |
|----------|----------|
| **Primitives** | ✅ string, number, int, bool |
| **Containers** | ✅ array, optional, object |
| **Validation** | ✅ Success and Failure paths |
| **Actions** | ✅ nonEmpty, email, trim, min, max, combined |
| **Nested structures** | ✅ Nested objects, arrays in objects |
| **Error handling** | ✅ parseOrThrow, invalid inputs |
| **Edge cases** | ✅ Empty arrays, optional fields, extra fields |

## Files Modified

1. `/packages/rescript-valibot/package.json` - Added vitest dependency and scripts
2. `/packages/rescript-valibot/rescript.json` - Added test directory
3. `/packages/rescript-valibot/vitest.config.js` - Created vitest configuration
4. `/packages/rescript-valibot/src/Parse.res` - Fixed cache to use Map instead of WeakMap
5. `/packages/rescript-valibot/test/Primitives.test.res` - Created comprehensive primitive tests
6. `/packages/rescript-valibot/test/Objects.test.res` - Created comprehensive object tests

## Running Tests

```bash
# Navigate to package
cd /Users/nyanrus/repos/kaguya/packages/rescript-valibot

# Run tests once
pnpm test

# Run tests in watch mode
pnpm test:watch

# Build and test
pnpm build && pnpm test

# Full monorepo build (includes valibot tests)
cd /Users/nyanrus/repos/kaguya
pnpm -r build
```

## API Verification

Tests verify the actual rescript-valibot API:

```rescript
// Schema definition - primitives are VALUES
let schema = string  // NOT string()

// Objects use generic `object` with field array
let userSchema = object([
  field("name", string),
  field("age", number),
])

// Parsing uses labeled argument ~schema
let result = Parse.parse(input, ~schema)

// Result type
switch result {
| Parse.Success({output}) => // validated output
| Parse.Failure({issues}) => // validation errors
}

// Throws on failure
let output = Parse.parseOrThrow(input, ~schema)
```

## Future Enhancements

Potential areas for additional testing (not critical):
- [ ] Custom error messages in actions
- [ ] Schema caching verification (reusing same schema)
- [ ] Transform action with complex transformations
- [ ] Check action with custom predicates
- [ ] Edge cases: empty strings, zero, negative numbers
- [ ] Unicode in string validation
- [ ] Large arrays performance
- [ ] Deep nesting (5+ levels)
- [ ] Circular reference handling (if supported)

## Notes

- **Test pattern**: Uses Vitest globals (`describe`, `test`, `expect`)
- **Type safety**: All tests use proper ReScript types and patterns
- **No Obj.magic in tests**: Uses proper external bindings for helper functions
- **Clean warnings**: Only cosmetic 'version' warning in rescript.json

---

**Conclusion**: The `rescript-valibot` package now has a solid foundation of tests covering all major functionality. The cache bug fix ensures proper schema handling for both primitive and complex types.
