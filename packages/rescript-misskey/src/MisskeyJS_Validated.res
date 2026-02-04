// SPDX-License-Identifier: MPL-2.0
// MisskeyJS_Validated.res - Validated API wrapper with runtime type checking
//
// This module provides validated versions of API functions that parse and validate
// responses using Sury schemas, ensuring type safety at runtime.

open MisskeyJS_Common
open MisskeyJS_Schemas

// Result type for validated responses
type parseError = {
  message: string,
  path: option<string>,
  raw: JSON.t,
}

type validationResult<'a> = result<'a, [#ValidationError(parseError) | #APIError(apiError) | #UnknownError(exn)]>

// Helper: Convert S.Error to our error type
let parseErrorFromSuryError = (error: S.error, raw: JSON.t): parseError => {
  {
    message: error.message,
    path: Some(error.path->S.Path.toString),
    raw: raw,
  }
}

// Parse and validate a single response
let parseOne = (json: JSON.t, schema: S.t<'a>): result<'a, parseError> => {
  try {
    Ok(S.parseOrThrow(json, schema))
  } catch {
  | S.Error(error) => Error(parseErrorFromSuryError(error, json))
  }
}

// Parse and validate an array response
let parseArray = (json: JSON.t, itemSchema: S.t<'a>): result<array<'a>, parseError> => {
  try {
    // Validate it's an array first
    let arr = json->Obj.magic
    if !Array.isArray(arr) {
      Error({
        message: "Expected an array",
        path: None,
        raw: json,
      })
    } else {
      // Parse each item
      let arraySchema = S.array(itemSchema)
      Ok(S.parseOrThrow(json, arraySchema))
    }
  } catch {
  | S.Error(error) => Error(parseErrorFromSuryError(error, json))
  }
}

// ============================================================
// Validated API Functions
// ============================================================

module Timeline = {
  open MisskeyJS_Timeline

  // Validated fetch - returns validated note array
  let fetch = async (
    client: MisskeyJS_Client.t,
    ~type_: timelineType,
    ~params: fetchParams={},
    (),
  ): validationResult<array<note>> => {
    let result = await MisskeyJS_Timeline.fetch(client, ~type_, ~params, ())
    
    switch result {
    | Ok(jsonArray) => {
        // Parse each note in the array
        switch parseArray(jsonArray->Obj.magic, noteSchema) {
        | Ok(notes) => Ok(notes)
        | Error(err) => Error(#ValidationError(err))
        }
      }
    | Error(#APIError(err)) => Error(#APIError(err))
    | Error(#UnknownError(err)) => Error(#UnknownError(err))
    }
  }
}

module Notes = {
  open MisskeyJS_Notes

  // Validated show - returns validated note
  let show = async (
    client: MisskeyJS_Client.t,
    ~noteId: id,
  ): validationResult<note> => {
    let result = await MisskeyJS_Notes.show(client, ~noteId)
    
    switch result {
    | Ok(json) => {
        switch parseOne(json, noteSchema) {
        | Ok(note) => Ok(note)
        | Error(err) => Error(#ValidationError(err))
        }
      }
    | Error(#APIError(err)) => Error(#APIError(err))
    | Error(#UnknownError(err)) => Error(#UnknownError(err))
    }
  }

  // Create note - returns validated note
  let create = async (
    client: MisskeyJS_Client.t,
    ~text: option<string>=?,
    ~visibility: visibility=#public,
    ~cw: option<string>=?,
    ~localOnly: option<bool>=?,
    ~reactionAcceptance: option<reactionAcceptance>=?,
    ~fileIds: option<array<id>>=?,
    ~poll: option<poll>=?,
    ~replyId: option<id>=?,
    ~renoteId: option<id>=?,
    ~channelId: option<id>=?,
    ~visibleUserIds: option<array<id>>=?,
    (),
  ): validationResult<note> => {
    let result = await MisskeyJS_Notes.create(
      client,
      ~text?,
      ~visibility,
      ~cw?,
      ~localOnly?,
      ~reactionAcceptance?,
      ~fileIds?,
      ~poll?,
      ~replyId?,
      ~renoteId?,
      ~channelId?,
      ~visibleUserIds?,
      (),
    )
    
    switch result {
    | Ok(json) => {
        // Misskey returns { createdNote: Note }
        let obj = json->Obj.magic
        switch obj->Dict.get("createdNote") {
        | Some(noteJson) => {
            switch parseOne(noteJson, noteSchema) {
            | Ok(note) => Ok(note)
            | Error(err) => Error(#ValidationError(err))
            }
          }
        | None => {
            // Fallback: try parsing the whole response as a note
            switch parseOne(json, noteSchema) {
            | Ok(note) => Ok(note)
            | Error(err) => Error(#ValidationError(err))
            }
          }
        }
      }
    | Error(#APIError(err)) => Error(#APIError(err))
    | Error(#UnknownError(err)) => Error(#UnknownError(err))
    }
  }
}

module Notifications = {
  open MisskeyJS_Notifications

  // Validated fetch - returns validated notification array
  let fetch = async (
    client: MisskeyJS_Client.t,
    ~params: fetchParams={},
    (),
  ): validationResult<array<notification>> => {
    let result = await MisskeyJS_Notifications.fetch(client, ~params, ())
    
    switch result {
    | Ok(jsonArray) => {
        switch parseArray(jsonArray->Obj.magic, notificationSchema) {
        | Ok(notifications) => Ok(notifications)
        | Error(err) => Error(#ValidationError(err))
        }
      }
    | Error(#APIError(err)) => Error(#APIError(err))
    | Error(#UnknownError(err)) => Error(#UnknownError(err))
    }
  }
}

// ============================================================
// Utility functions for working with validation errors
// ============================================================

// Format a validation error for display
let formatValidationError = (err: parseError): string => {
  let pathStr = switch err.path {
  | Some(p) => ` at path: ${p}`
  | None => ""
  }
  `Validation error${pathStr}: ${err.message}`
}

// Log validation error with details
let logValidationError = (err: parseError): unit => {
  Console.error("❌ API Response Validation Failed:")
  Console.error(`   ${err.message}`)
  switch err.path {
  | Some(path) => Console.error(`   Path: ${path}`)
  | None => ()
  }
  Console.error("   Raw response:")
  Console.error(err.raw)
}
