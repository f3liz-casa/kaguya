// Module for fetching available custom timelines (antennas, lists, channels)

open MisskeyJS_Common

module Client = MisskeyJS_Client

// Fetch all available antennas for the user
let fetchAntennas = async (client: Client.t): result<
  array<JSON.t>,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let emptyParams = Dict.make()->JSON.Encode.object
    let result = await Client.request(client, ~endpoint="antennas/list", ~params=emptyParams)
    Ok(result->Obj.magic)
  } catch {
  | error =>
    switch isAPIError(error) {
    | Some(apiErr) => Error(#APIError(apiErr))
    | None => Error(#UnknownError(error))
    }
  }
}

// Fetch all user lists for the user
let fetchUserLists = async (client: Client.t): result<
  array<JSON.t>,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let emptyParams = Dict.make()->JSON.Encode.object
    let result = await Client.request(
      client,
      ~endpoint="users/lists/list",
      ~params=emptyParams,
    )
    Ok(result->Obj.magic)
  } catch {
  | error =>
    switch isAPIError(error) {
    | Some(apiErr) => Error(#APIError(apiErr))
    | None => Error(#UnknownError(error))
    }
  }
}

// Fetch all followed channels for the user
let fetchChannels = async (client: Client.t): result<
  array<JSON.t>,
  [> #APIError(apiError) | #UnknownError(exn)],
> => {
  try {
    let emptyParams = Dict.make()->JSON.Encode.object
    let result = await Client.request(client, ~endpoint="channels/followed", ~params=emptyParams)
    Ok(result->Obj.magic)
  } catch {
  | error =>
    switch isAPIError(error) {
    | Some(apiErr) => Error(#APIError(apiErr))
    | None => Error(#UnknownError(error))
    }
  }
}

// Helper to extract ID and name from timeline item
let extractIdAndName = (item: JSON.t): option<(string, string)> => {
  item
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let id = obj->Dict.get("id")->Option.flatMap(JSON.Decode.string)
    let name = obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)
    switch (id, name) {
    | (Some(id), Some(name)) => Some((id, name))
    | _ => None
    }
  })
}
