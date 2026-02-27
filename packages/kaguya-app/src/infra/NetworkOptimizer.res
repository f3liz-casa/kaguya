// SPDX-License-Identifier: MPL-2.0

let addPreconnectForInstance = (instanceOrigin: option<string>): unit => {
  switch instanceOrigin {
  | Some(origin) => ignore(KaguyaNetwork.addPreconnect(origin))
  | None => ()
  }
}

// Prefetch common image domains after discovering them from API responses
let prefetchImageDomain = (imageUrl: string): unit => {
  switch KaguyaNetwork.extractOrigin(imageUrl)->Nullable.toOption {
  | Some(origin) => ignore(KaguyaNetwork.addDnsPrefetch(origin))
  | None => ()
  }
}

// Extract and prefetch image domains from notes
let extractImageDomainsFromNotes = (notes: array<JSON.t>): unit => {
  notes->Array.forEach(note => {
    switch note->JSON.Decode.object {
    | Some(obj) => {
        switch obj->Dict.get("files") {
        | Some(filesJson) =>
          switch filesJson->JSON.Decode.array {
          | Some(files) =>
            files->Array.forEach(file => {
              switch file->JSON.Decode.object {
              | Some(fileObj) => {
                  switch fileObj->Dict.get("thumbnailUrl") {
                  | Some(urlJson) =>
                    switch urlJson->JSON.Decode.string {
                    | Some(url) => prefetchImageDomain(url)
                    | None => ()
                    }
                  | None => ()
                  }
                  switch fileObj->Dict.get("url") {
                  | Some(urlJson) =>
                    switch urlJson->JSON.Decode.string {
                    | Some(url) => prefetchImageDomain(url)
                    | None => ()
                    }
                  | None => ()
                  }
                }
              | None => ()
              }
            })
          | None => ()
          }
        | None => ()
        }
        switch obj->Dict.get("user") {
        | Some(userJson) =>
          switch userJson->JSON.Decode.object {
          | Some(userObj) =>
            switch userObj->Dict.get("avatarUrl") {
            | Some(avatarJson) =>
              switch avatarJson->JSON.Decode.string {
              | Some(url) => prefetchImageDomain(url)
              | None => ()
              }
            | None => ()
            }
          | None => ()
          }
        | None => ()
        }
      }
    | None => ()
    }
  })
}

// Batch prefetch for common domains after initial load
let prefetchCommonDomains = (instanceOrigin: string): unit => {
  switch KaguyaNetwork.extractHostname(instanceOrigin)->Nullable.toOption {
  | Some(hostname) =>
    KaguyaNetwork.batchDnsPrefetch([
      "https://s3." ++ hostname,
      "https://media." ++ hostname,
      "https://files." ++ hostname,
      "https://cdn." ++ hostname,
      instanceOrigin ++ "/proxy",
    ])
  | None => ()
  }
}
