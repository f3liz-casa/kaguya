// SPDX-License-Identifier: MPL-2.0

type JsonObj = Record<string, unknown>

export function getString(obj: JsonObj, key: string): string | undefined {
  const v = obj[key]
  if (v === null || v === undefined) return undefined
  return typeof v === 'string' ? v : undefined
}

export function getStringOr(obj: JsonObj, key: string, def: string): string {
  return getString(obj, key) ?? def
}

export function getBool(obj: JsonObj, key: string): boolean | undefined {
  const v = obj[key]
  return typeof v === 'boolean' ? v : undefined
}

export function getFloat(obj: JsonObj, key: string): number | undefined {
  const v = obj[key]
  return typeof v === 'number' ? v : undefined
}

export function getInt(obj: JsonObj, key: string): number | undefined {
  const v = getFloat(obj, key)
  return v !== undefined ? Math.floor(v) : undefined
}

export function getObj(obj: JsonObj, key: string): JsonObj | undefined {
  const v = obj[key]
  return v && typeof v === 'object' && !Array.isArray(v) ? v as JsonObj : undefined
}

export function getArray(obj: JsonObj, key: string): unknown[] | undefined {
  const v = obj[key]
  return Array.isArray(v) ? v : undefined
}

export function asObj(v: unknown): JsonObj | undefined {
  return v && typeof v === 'object' && !Array.isArray(v) ? v as JsonObj : undefined
}
