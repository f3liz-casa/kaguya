// SPDX-License-Identifier: MPL-2.0

let string = (obj: Dict.t<JSON.t>, key: string): option<string> => {
  obj->Dict.get(key)->Option.flatMap(v => {
    switch v {
    | JSON.Null => None
    | _ => JSON.Decode.string(v)
    }
  })
}

let stringOr = (obj: Dict.t<JSON.t>, key: string, default: string): string => {
  string(obj, key)->Option.getOr(default)
}

let bool = (obj: Dict.t<JSON.t>, key: string): option<bool> => {
  obj->Dict.get(key)->Option.flatMap(JSON.Decode.bool)
}

let float = (obj: Dict.t<JSON.t>, key: string): option<float> => {
  obj->Dict.get(key)->Option.flatMap(JSON.Decode.float)
}

let int = (obj: Dict.t<JSON.t>, key: string): option<int> => {
  float(obj, key)->Option.map(Float.toInt)
}

let obj = (obj: Dict.t<JSON.t>, key: string): option<Dict.t<JSON.t>> => {
  obj->Dict.get(key)->Option.flatMap(JSON.Decode.object)
}

let array = (obj: Dict.t<JSON.t>, key: string): option<array<JSON.t>> => {
  obj->Dict.get(key)->Option.flatMap(JSON.Decode.array)
}
