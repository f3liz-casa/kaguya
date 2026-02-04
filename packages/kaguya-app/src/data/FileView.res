// SPDX-License-Identifier: MPL-2.0
// FileView.res - File/attachment data for display

// ============================================================
// Types
// ============================================================

type t = {
  id: string,
  name: string,
  url: string,
  thumbnailUrl: option<string>,
  @as("type") type_: string, // MIME type
  isSensitive: bool,
  width: option<int>,
  height: option<int>,
}

// ============================================================
// Computed Properties
// ============================================================

// Check if file is an image
let isImage = (file: t): bool => {
  UrlUtils.isImageMimeType(file.type_)
}

// Check if file is a video
let isVideo = (file: t): bool => {
  UrlUtils.isVideoMimeType(file.type_)
}

// Get aspect ratio for proper display
let aspectRatio = (file: t): option<float> => {
  switch (file.width, file.height) {
  | (Some(w), Some(h)) if h > 0 => Some(Float.fromInt(w) /. Float.fromInt(h))
  | _ => None
  }
}

// Get display URL (thumbnail if available, otherwise full URL)
let displayUrl = (file: t): string => {
  file.thumbnailUrl->Option.getOr(file.url)
}

// ============================================================
// Sury Schema
// ============================================================

// Raw types from JSON
type properties = {
  width: Js.nullable<float>,
  height: Js.nullable<float>,
}

type raw = {
  id: string,
  name: string,
  url: string,
  thumbnailUrl: Js.nullable<string>,
  @as("type") type_: string,
  isSensitive: bool,
  properties: Js.nullable<properties>,
}

// Sury schema for properties
let propertiesSchema = S.object(s => {
  width: s.field("width", S.nullable(S.float)),
  height: s.field("height", S.nullable(S.float)),
})

// Sury schema for file
let schema = S.object(s => {
  id: s.field("id", S.string),
  name: s.field("name", S.string),
  url: s.field("url", S.string),
  thumbnailUrl: s.field("thumbnailUrl", S.nullable(S.string)),
  type_: s.field("type", S.string),
  isSensitive: s.fieldOr("isSensitive", S.bool, false),
  properties: s.field("properties", S.nullable(propertiesSchema)),
})

// Transform raw validated data to our type
let fromRaw = (raw: raw): t => {
  let width = raw.properties
    ->Js.Nullable.toOption
    ->Option.flatMap(p => p.width->Js.Nullable.toOption->Option.map(Float.toInt))
  
  let height = raw.properties
    ->Js.Nullable.toOption
    ->Option.flatMap(p => p.height->Js.Nullable.toOption->Option.map(Float.toInt))

  {
    id: raw.id,
    name: raw.name,
    url: raw.url,
    thumbnailUrl: raw.thumbnailUrl->Js.Nullable.toOption,
    type_: raw.type_,
    isSensitive: raw.isSensitive,
    width,
    height,
  }
}

// Parse from JSON using Sury
let parse = (json: JSON.t): result<t, S.error> => {
  try {
    let raw = json->S.parseOrThrow(schema)
    Ok(fromRaw(raw))
  } catch {
  | S.Error(e) => Error(e)
  }
}

// Convenient decode that returns option
let decode = (json: JSON.t): option<t> => {
  switch parse(json) {
  | Ok(file) => Some(file)
  | Error(_) => None
  }
}
