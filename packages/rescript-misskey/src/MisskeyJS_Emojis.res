// Emojis module - Custom emoji operations

open MisskeyJS_Common

module API_Bindings = MisskeyJS_API_Bindings
module Client = MisskeyJS_Client

// Internal: Error handler
let handleError = (error: exn): result<'a, [> #APIError(apiError) | #UnknownError(exn)]> => {
  switch isAPIError(error) {
  | Some(apiErr) => Error(#APIError(apiErr))
  | None => Error(#UnknownError(error))
  }
}

// Custom emoji type (extended from common emoji type)
type customEmoji = {
  name: string,
  url: string,
  category: option<string>,
  aliases: array<string>,
}

// Decode custom emoji from JSON
let decodeCustomEmoji = (json: JSON.t): option<customEmoji> => {
  switch json->JSON.Decode.object {
  | Some(obj) =>
    switch (
      obj->Dict.get("name")->Option.flatMap(JSON.Decode.string),
      obj->Dict.get("url")->Option.flatMap(JSON.Decode.string),
    ) {
    | (Some(name), Some(url)) =>
      let category = obj->Dict.get("category")->Option.flatMap(JSON.Decode.string)
      let aliases = switch obj->Dict.get("aliases")->Option.flatMap(JSON.Decode.array) {
      | Some(arr) => arr->Array.filterMap(JSON.Decode.string)->Array.filter(s => s != "")
      | None => []
      }
      Some({
        name,
        url,
        category,
        aliases,
      })
    | _ => None
    }
  | None => None
  }
}

// Get all custom emojis from the instance
let list = async (
  client: Client.t,
): result<array<customEmoji>, [> #APIError(apiError) | #UnknownError(exn)]> => {
  try {
    let result = await Client.request(
      client,
      ~endpoint="emojis",
      ~params=JSON.Encode.object(Dict.make()),
    )
    
    // Parse response
    switch result->JSON.Decode.object {
    | Some(obj) =>
      switch obj->Dict.get("emojis")->Option.flatMap(JSON.Decode.array) {
      | Some(emojisArray) => {
          let decoded = emojisArray->Array.filterMap(decodeCustomEmoji)
          Ok(decoded)
        }
      | None => Ok([]) // No emojis or invalid structure
      }
    | None => Ok([]) // Invalid response
    }
  } catch {
  | error => handleError(error)
  }
}
