// SPDX-License-Identifier: MPL-2.0
// HomePage.res - Home page with timeline selector

type timelineItem = {
  type_: Misskey.Stream.timelineType,
  name: string,
  category: [#standard | #antenna | #list | #channel],
}

type state =
  | Loading
  | Loaded({customTimelines: array<timelineItem>, selectedTimeline: timelineItem})
  | Error(string)

// Helper to extract error message from exn
let getExnMessage = (exn: exn): string => {
  switch exn->JsExn.fromException {
  | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
  | None => "Unknown error"
  }
}

@jsx.component
let make = () => {
  let (state, setState) = PreactHooks.useState(() => Loading)

  // Load all available timelines when client becomes available
  PreactSignals.useSignalEffect(() => {
    let loadTimelines = async () => {
      let clientOpt = PreactSignals.value(AppState.client)
      
      switch clientOpt {
      | Some(client) => {
          // Start with standard timelines
          let standardTimelines = [
            {type_: #home, name: "ホーム", category: #standard},
            {type_: #local, name: "ローカル", category: #standard},
            {type_: #global, name: "グローバル", category: #standard},
            {type_: #hybrid, name: "ソーシャル", category: #standard},
          ]

          // Fetch custom timelines
          let customItems = []

          // Try to use cached data first, otherwise fetch from API in parallel
          let (antennasResult, listsResult, channelsResult) = switch (
            AppInitializer.getCachedAntennas(),
            AppInitializer.getCachedLists(),
            AppInitializer.getCachedChannels(),
          ) {
          | (Some(cachedAntennas), Some(cachedLists), Some(cachedChannels)) => {
              Console.log("HomePage: Using cached timeline data")
              (cachedAntennas, cachedLists, cachedChannels)
            }
          | _ => {
              Console.log("HomePage: Fetching timeline data from API in parallel")
              // No cache available, fetch all in parallel using Promise.all3 for 3 promises
              let (antennasResult, listsResult, channelsResult) = await Promise.all3((
                client->Misskey.CustomTimelines.antennas,
                client->Misskey.CustomTimelines.lists,
                client->Misskey.CustomTimelines.channels,
              ))
              
              (antennasResult, listsResult, channelsResult)
            }
          }

          // Process antennas
          switch antennasResult {
          | Ok(antennas) =>
            antennas->Array.forEach(antenna => {
              switch Misskey.CustomTimelines.extractIdAndName(antenna) {
              | Some((id, name)) =>
                customItems->Array.push({
                  type_: #antenna(id),
                  name,
                  category: #antenna,
                })
              | None => ()
              }
            })
          | Error(_) => () // Silently ignore antenna fetch errors
          }

          // Process lists
          switch listsResult {
          | Ok(lists) =>
            lists->Array.forEach(list => {
              switch Misskey.CustomTimelines.extractIdAndName(list) {
              | Some((id, name)) =>
                customItems->Array.push({
                  type_: #list(id),
                  name,
                  category: #list,
                })
              | None => ()
              }
            })
          | Error(_) => () // Silently ignore list fetch errors
          }

          // Process channels
          switch channelsResult {
          | Ok(channels) =>
            channels->Array.forEach(channel => {
              switch Misskey.CustomTimelines.extractIdAndName(channel) {
              | Some((id, name)) =>
                customItems->Array.push({
                  type_: #channel(id),
                  name,
                  category: #channel,
                })
              | None => ()
              }
            })
          | Error(_) => () // Silently ignore channel fetch errors
          }

          let allTimelines = Array.concat(standardTimelines, customItems)
          setState(_ => Loaded({
            customTimelines: allTimelines,
            selectedTimeline: standardTimelines->Array.getUnsafe(0), // Default to Home
          }))
        }
      | None => setState(_ => Error("Not connected"))
      }
    }

    let _ = loadTimelines()
    None // No cleanup needed
  })

  let selectTimeline = (timeline: timelineItem) => {
    setState(prev => {
      switch prev {
      | Loaded(data) => Loaded({...data, selectedTimeline: timeline})
      | _ => prev
      }
    })
  }

  <Layout>
    {switch state {
    | Loading =>
      <div className="loading-container">
        <p> {Preact.string("Loading timelines...")} </p>
      </div>
    | Error(msg) =>
      <div className="timeline-error">
        <p> {Preact.string("Error: " ++ msg)} </p>
      </div>
    | Loaded({customTimelines, selectedTimeline}) =>
      <div className="timeline-selector-container">
        <div className="timeline-tabs">
          {customTimelines
          ->Array.map(timeline => {
            let isActive = timeline.type_ == selectedTimeline.type_
            let categoryIcon = switch timeline.category {
            | #standard => ""
            | #antenna => "📡 "
            | #list => "📋 "
            | #channel => "📺 "
            }
            <button
              key={timeline.name}
              className={isActive ? "timeline-tab active" : "timeline-tab"}
              onClick={_ => selectTimeline(timeline)}
            >
              {Preact.string(categoryIcon ++ timeline.name)}
            </button>
          })
          ->Preact.array}
        </div>
        <Timeline timelineType={selectedTimeline.type_} name={selectedTimeline.name} />
      </div>
    }}
  </Layout>
}
