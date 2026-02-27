// SPDX-License-Identifier: MPL-2.0

let antennas: PreactSignals.signal<array<JSON.t>> = PreactSignals.make([])
let lists: PreactSignals.signal<array<JSON.t>> = PreactSignals.make([])
let channels: PreactSignals.signal<array<JSON.t>> = PreactSignals.make([])
let homeTimelineInitial: PreactSignals.signal<option<JSON.t>> = PreactSignals.make(None)

let clear = () => {
  PreactSignals.batch(() => {
    PreactSignals.setValue(antennas, [])
    PreactSignals.setValue(lists, [])
    PreactSignals.setValue(channels, [])
    PreactSignals.setValue(homeTimelineInitial, None)
  })
}

let setFromInitData = (
  ~antennasResult: result<array<JSON.t>, string>,
  ~listsResult: result<array<JSON.t>, string>,
  ~channelsResult: result<array<JSON.t>, string>,
  ~homeTimelineResult: option<result<JSON.t, string>>,
) => {
  PreactSignals.batch(() => {
    switch antennasResult {
    | Ok(items) => PreactSignals.setValue(antennas, items)
    | Error(_) => ()
    }
    switch listsResult {
    | Ok(items) => PreactSignals.setValue(lists, items)
    | Error(_) => ()
    }
    switch channelsResult {
    | Ok(items) => PreactSignals.setValue(channels, items)
    | Error(_) => ()
    }
    switch homeTimelineResult {
    | Some(Ok(json)) => PreactSignals.setValue(homeTimelineInitial, Some(json))
    | _ => ()
    }
  })
}
