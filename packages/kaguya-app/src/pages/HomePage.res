// SPDX-License-Identifier: MPL-2.0
// HomePage.res - Home page with timeline selector

type timelineItem = {
  type_: MisskeyJS.Timeline.timelineType,
  name: string,
  category: [#standard | #antenna | #list | #channel],
}

type state =
  | Loading
  | Loaded({
      customTimelines: array<timelineItem>,
      selectedTimeline: timelineItem,
    })
  | Error(string)

// Helper to extract error message from exn
let getExnMessage = (exn: exn): string => {
  switch exn->Exn.asJsExn {
  | Some(jsExn) => Exn.message(jsExn)->Option.getOr("Unknown error")
  | None => "Unknown error"
  }
}

@jsx.component
let make = () => {
  let (state, setState) = PreactHooks.useState(() => Loading)

  // Load all available timelines on mount
  PreactHooks.useEffect0(() => {
    let loadTimelines = async () => {
      switch PreactSignals.value(AppState.client) {
      | Some(client) => {
          // Start with standard timelines
          let standardTimelines = [
            {type_: #home, name: "Home", category: #standard},
            {type_: #local, name: "Local", category: #standard},
            {type_: #global, name: "Global", category: #standard},
            {type_: #hybrid, name: "Social", category: #standard},
          ]

          // Fetch custom timelines
          let customItems = []

          // Fetch antennas
          let antennasResult = await MisskeyJS.CustomTimelines.fetchAntennas(client)
          switch antennasResult {
          | Ok(antennas) => {
              antennas->Array.forEach(antenna => {
                switch MisskeyJS.CustomTimelines.extractIdAndName(antenna) {
                | Some((id, name)) =>
                  customItems->Array.push({
                    type_: #antenna(id),
                    name: name,
                    category: #antenna,
                  })
                | None => ()
                }
              })
            }
          | Error(_) => () // Silently ignore antenna fetch errors
          }

          // Fetch user lists
          let listsResult = await MisskeyJS.CustomTimelines.fetchUserLists(client)
          switch listsResult {
          | Ok(lists) => {
              lists->Array.forEach(list => {
                switch MisskeyJS.CustomTimelines.extractIdAndName(list) {
                | Some((id, name)) =>
                  customItems->Array.push({
                    type_: #userList(id),
                    name: name,
                    category: #list,
                  })
                | None => ()
                }
              })
            }
          | Error(_) => () // Silently ignore list fetch errors
          }

          // Fetch channels
          let channelsResult = await MisskeyJS.CustomTimelines.fetchChannels(client)
          switch channelsResult {
          | Ok(channels) => {
              channels->Array.forEach(channel => {
                switch MisskeyJS.CustomTimelines.extractIdAndName(channel) {
                | Some((id, name)) =>
                  customItems->Array.push({
                    type_: #channel(id),
                    name: name,
                    category: #channel,
                  })
                | None => ()
                }
              })
            }
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
    None
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
              onClick={_ => selectTimeline(timeline)}>
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
