// SPDX-License-Identifier: MPL-2.0
// AppInitializer.res - Parallel initialization of app data

type initData = {
  notifications: result<JSON.t, string>,
  antennas: result<array<JSON.t>, string>,
  lists: result<array<JSON.t>, string>,
  channels: result<array<JSON.t>, string>,
  homeTimeline: option<result<JSON.t, string>>,
}

let cache: ref<option<initData>> = ref(None)

// Set cached data
let setCache = (data: initData): unit => {
  cache := Some(data)
}

// Batch fetch all initialization data in parallel
let initializeAppData = async (client: Misskey.t): unit => {
  Console.log("AppInitializer: Starting parallel initialization...")
  
  try {
    let notifParams = Dict.make()
    notifParams->Dict.set("limit", JSON.Encode.int(30))
    
    // Fetch all in parallel
    let notificationsPromise = client->Misskey.request(
      "i/notifications",
      ~params=JSON.Encode.object(notifParams),
      (),
    )
    let antennasPromise = client->Misskey.CustomTimelines.antennas
    let listsPromise = client->Misskey.CustomTimelines.lists
    let channelsPromise = client->Misskey.CustomTimelines.channels
    
    // Wait for all promises to resolve
    let notificationsResult = await notificationsPromise
    let antennasResult = await antennasPromise
    let listsResult = await listsPromise
    let channelsResult = await channelsPromise
    
    setCache({
      notifications: notificationsResult,
      antennas: antennasResult,
      lists: listsResult,
      channels: channelsResult,
      homeTimeline: None,
    })
    
    Console.log("AppInitializer: Parallel initialization complete")
  } catch {
  | exn => {
      Console.error2("AppInitializer: Parallel initialization failed", exn)
      cache := None
    }
  }
}

// Check if cached data exists and is still valid
let hasCachedData = (): bool => {
  cache.contents->Option.isSome
}

// Get cached notifications
let getCachedNotifications = (): option<result<JSON.t, string>> => {
  cache.contents->Option.map(data => data.notifications)
}

// Get cached antennas
let getCachedAntennas = (): option<result<array<JSON.t>, string>> => {
  cache.contents->Option.map(data => data.antennas)
}

// Get cached lists
let getCachedLists = (): option<result<array<JSON.t>, string>> => {
  cache.contents->Option.map(data => data.lists)
}

// Get cached channels
let getCachedChannels = (): option<result<array<JSON.t>, string>> => {
  cache.contents->Option.map(data => data.channels)
}

// Get cached home timeline
let getCachedHomeTimeline = (): option<result<JSON.t, string>> => {
  cache.contents->Option.flatMap(data => data.homeTimeline)
}

// Clear cached data (call on logout)
let clearCache = (): unit => {
  cache := None
}
