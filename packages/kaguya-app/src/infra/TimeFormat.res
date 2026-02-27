// SPDX-License-Identifier: MPL-2.0

// Relative Time Formatting

// Returns "now" for < 1 minute, or formatted time unit for longer periods
let formatRelativeTime = (dateStr: string): string => {
  try {
    let date = Date.fromString(dateStr)
    let now = Date.now()
    let diffMs = now -. Date.getTime(date)
    let diffSec = diffMs /. 1000.0
    let diffMin = diffSec /. 60.0
    let diffHour = diffMin /. 60.0
    let diffDay = diffHour /. 24.0

    if diffSec < 60.0 {
      "now"
    } else if diffMin < 60.0 {
      Int.toString(Float.toInt(diffMin)) ++ "m"
    } else if diffHour < 24.0 {
      Int.toString(Float.toInt(diffHour)) ++ "h"
    } else if diffDay < 7.0 {
      Int.toString(Float.toInt(diffDay)) ++ "d"
    } else {
      let month = Date.getMonth(date) + 1
      let day = Date.getDate(date)
      Int.toString(month) ++ "/" ++ Int.toString(day)
    }
  } catch {
  | _ => ""
  }
}

// Absolute Time Formatting

let formatFullDate = (dateStr: string): string => {
  try {
    let date = Date.fromString(dateStr)
    let year = Date.getFullYear(date)
    let month = Date.getMonth(date) + 1
    let day = Date.getDate(date)

    Int.toString(year) ++ "/" ++ Int.toString(month) ++ "/" ++ Int.toString(day)
  } catch {
  | _ => dateStr
  }
}

let formatDateTime = (dateStr: string): string => {
  try {
    let date = Date.fromString(dateStr)
    let year = Date.getFullYear(date)
    let month = Date.getMonth(date) + 1
    let day = Date.getDate(date)
    let hours = Date.getHours(date)
    let minutes = Date.getMinutes(date)

    // Pad single digits
    let padZero = (num: int): string => {
      if num < 10 {
        "0" ++ Int.toString(num)
      } else {
        Int.toString(num)
      }
    }

    Int.toString(year) ++
    "/" ++
    Int.toString(month) ++
    "/" ++
    Int.toString(day) ++
    " " ++
    padZero(hours) ++
    ":" ++
    padZero(minutes)
  } catch {
  | _ => dateStr
  }
}
