// SPDX-License-Identifier: MPL-2.0
// Timeline.res - Timeline container component

type timelineState =
  | Loading
  | Loaded({
      notes: array<NoteView.t>,
      lastPostId: option<string>,
      hasMore: bool,
      isLoadingMore: bool,
      isStreaming: bool,
    })
  | Error(string)

// Helper to extract error message from exn
let getExnMessage = (exn: exn): string => {
  switch exn->JsExn.fromException {
  | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
  | None => "Unknown error"
  }
}

// Helper to get last note ID from notes array
let getLastNoteId = (notes: array<NoteView.t>): option<string> => {
  notes->Array.at(-1)->Option.map(note => note.id)
}

// Helper to check if a note already exists in the array (by ID)
let noteExists = (notes: array<NoteView.t>, noteId: string): bool => {
  notes->Array.some(note => note.id == noteId)
}

@jsx.component
let make = (~timelineType: Misskey.Stream.timelineType, ~name: string="") => {
  // Track render performance
  let _ = PerfMonitor.useRenderMetrics(~component="Timeline")

  let (state, setState) = PreactHooks.useState(() => Loading)

  // Keep a stable ref to the latest state so the visibilitychange handler
  // (mounted once in useEffect0) always sees up-to-date values.
  let stateRef = PreactHooks.useRef(state)
  stateRef.current = state
  let timelineTypeRef = PreactHooks.useRef(timelineType)
  timelineTypeRef.current = timelineType

  // Ref to store the streaming subscription
  let subscriptionRef = PreactHooks.useRef(None)

  // Fetch timeline when client becomes available or when timelineType changes
  // We need to watch both the client signal and the timelineType prop
  PreactHooks.useEffect2(() => {
    // Read the current client value from the signal
    let clientOpt = PreactSignals.value(AppState.client)
    
    // Cancellation token: set to true when this effect is cleaned up.
    // Prevents a stale async fetch from overwriting state after tab switch.
    let cancelled = ref(false)

    // Reset to loading state immediately so old notes are not shown
    setState(_ => Loading)

    let fetchTimeline = async () => {
      switch clientOpt {
      | Some(client) => {
          // Check if we have cached home timeline data (only for #home timeline)
          let cachedTimelineOpt = switch timelineType {
          | #home => AppInitializer.getCachedHomeTimeline()
          | _ => None
          }
          
          switch cachedTimelineOpt {
          | Some(cachedResult) => {
              if cancelled.contents { () } else {
              Console.log("Timeline: Using cached home timeline data")
              // Use cached data and setup stream subscription
              switch cachedResult {
              | Ok(rawJson) => {
                  let notes = NoteDecoder.decodeManyFromJson(rawJson)
                  let lastPostId = getLastNoteId(notes)
                  
                  // Prefetch image domains from cached notes
                  NetworkOptimizer.extractImageDomainsFromNotes([rawJson])
                  
                  setState(_ => Loaded({
                    notes,
                    lastPostId,
                    hasMore: Array.length(notes) >= 20,
                    isLoadingMore: false,
                    isStreaming: false,
                  }))

                  // Start streaming subscription after loading cached data
                  Console.log("Starting streaming subscription...")
                  let subscription = client->Misskey.Stream.timeline(timelineType, newNote => {
                    Console.log("Received new note via stream")
                    let decodedNote = NoteDecoder.decode(newNote)

                    // Prefetch images for better UX
                    decodedNote->Option.forEach(NoteOps.prefetchImages)

                    setState(
                      prev => {
                        switch (prev, decodedNote) {
                        | (Loaded(data), Some(noteData)) => {
                            let shouldAdd = !noteExists(data.notes, noteData.id)
                            if shouldAdd {
                              Loaded({
                                ...data,
                                notes: [noteData]->Array.concat(data.notes),
                              })
                            } else {
                              prev
                            }
                          }
                        | _ => prev
                        }
                      },
                    )
                  })
                  subscriptionRef.current = Some(subscription)
                  setState(prev => {
                    switch prev {
                    | Loaded(data) => Loaded({...data, isStreaming: true})
                    | _ => prev
                    }
                  })
                  Console.log("Using cached timeline and stream active")
                }
              | Error(msg) => setState(_ => Error(msg))
              }
              }
            }
          | None => {
              // No cache, fetch from API and setup stream in parallel
              let notesPromise = client->Misskey.Notes.fetch(
                timelineType,
                ~limit=20,
                (),
              )
              
              if !cancelled.contents {
              // Start stream subscription immediately (doesn't await the fetch)
              Console.log("Starting streaming subscription in parallel...")
              let subscription = client->Misskey.Stream.timeline(timelineType, newNote => {
                Console.log("Received new note via stream")
                let decodedNote = NoteDecoder.decode(newNote)

                // Prefetch images for better UX
                decodedNote->Option.forEach(NoteOps.prefetchImages)

                setState(
                  prev => {
                    switch (prev, decodedNote) {
                    | (Loaded(data), Some(noteData)) => {
                        let shouldAdd = !noteExists(data.notes, noteData.id)
                        if shouldAdd {
                          Loaded({
                            ...data,
                            notes: [noteData]->Array.concat(data.notes),
                          })
                        } else {
                          prev
                        }
                      }
                    | _ => prev
                    }
                  },
                )
              })
              subscriptionRef.current = Some(subscription)
              
              // Now await the notes fetch
              let result = await notesPromise

              if !cancelled.contents {
              switch result {
              | Ok(rawJson) => {
                  let notes = NoteDecoder.decodeManyFromJson(rawJson)
                  let lastPostId = getLastNoteId(notes)
                  
                  // Prefetch image domains from initial notes
                  NetworkOptimizer.extractImageDomainsFromNotes([rawJson])
                  
                  setState(_ => Loaded({
                    notes,
                    lastPostId,
                    hasMore: Array.length(notes) >= 20,
                    isLoadingMore: false,
                    isStreaming: true, // Already subscribed
                  }))

                  Console.log("Notes fetched and stream already active")
                }
              | Error(msg) => {
                  // If fetch failed, clean up the subscription
                  subscriptionRef.current->Option.forEach(sub => sub.dispose())
                  subscriptionRef.current = None
                  setState(_ => Error(msg))
                }
              }
              } // end if !cancelled (after await)
              } // end if !cancelled (before stream setup)
            }
          }
        }
      | None => setState(_ => Error("接続されていません"))
      }
    }

    let _ = fetchTimeline()

    // Cleanup: cancel pending fetch, dispose subscription when timeline changes or unmounts
    Some(() => {
      cancelled := true
      Console.log("Timeline unmounting or changing - cleaning up subscription...")
      subscriptionRef.current->Option.forEach(sub => {
        sub.dispose()
        Console.log("Subscription disposed")
      })
      subscriptionRef.current = None
    })
  }, (PreactSignals.value(AppState.client), timelineType))

  // Catch up on missed notes when the page becomes visible again (tab switch, screen wake)
  PreactHooks.useEffect0(() => {
    let handleVisibility = () => {
      let isVisible: bool = %raw(`document.visibilityState === "visible"`)
      if isVisible {
        switch (PreactSignals.value(AppState.client), stateRef.current) {
        | (Some(client), Loaded(data)) => {
            // Fetch notes newer than the newest note we have
            let newestId = data.notes->Array.at(0)->Option.map(n => n.id)
            let tt = timelineTypeRef.current
            let _ = (async () => {
              let result = await client->Misskey.Notes.fetch(
                tt,
                ~limit=20,
                ~sinceId=?newestId,
                (),
              )
              switch result {
              | Ok(rawJson) => {
                  let newNotes = NoteDecoder.decodeManyFromJson(rawJson)
                  if Array.length(newNotes) > 0 {
                    setState(prev => switch prev {
                    | Loaded(d) =>
                      let merged = Array.concat(newNotes, d.notes)
                      Loaded({...d, notes: merged})
                    | _ => prev
                    })
                  }
                }
              | Error(_) => () // silently ignore catch-up failures
              }
            })()
          }
        | _ => ()
        }
      }
    }
    %raw(`document.addEventListener("visibilitychange", handleVisibility)`)
    Some(() => {
      %raw(`document.removeEventListener("visibilitychange", handleVisibility)`)
    })
  })

  let handleRefresh = async () => {
    // Preserve streaming state during refresh
    let wasStreaming = subscriptionRef.current->Option.isSome
    setState(_ => Loading)

    switch PreactSignals.value(AppState.client) {
    | Some(client) => {
        let result = await client->Misskey.Notes.fetch(
          timelineType,
          ~limit=20,
          (),
        )

        switch result {
        | Ok(rawJson) => {
            let notes = NoteDecoder.decodeManyFromJson(rawJson)
            let lastPostId = getLastNoteId(notes)
            setState(_ => Loaded({
              notes,
              lastPostId,
              hasMore: Array.length(notes) >= 20,
              isLoadingMore: false,
              isStreaming: wasStreaming,
            }))
          }
        | Error(msg) => setState(_ => Error(msg))
        }
      }
    | None => setState(_ => Error("接続されていません"))
    }
  }

  let onRefreshClick = (_: JsxEvent.Mouse.t) => {
    let _ = handleRefresh()
  }

  // Handle loading more posts (infinite scroll)
  let loadMore = async () => {
    switch state {
    | Loaded({
        notes,
        lastPostId: Some(lastId),
        hasMore: true,
        isLoadingMore: false,
        isStreaming,
      }) => {
        // Set loading state
        setState(prev => {
          switch prev {
          | Loaded(data) => Loaded({...data, isLoadingMore: true})
          | _ => prev
          }
        })

        switch PreactSignals.value(AppState.client) {
        | Some(client) => {
            let result = await client->Misskey.Notes.fetch(
              timelineType,
              ~limit=20,
              ~untilId=lastId,
              (),
            )

            switch result {
            | Ok(newRawJson) => {
                let newNotes = NoteDecoder.decodeManyFromJson(newRawJson)
                
                // Prefetch image domains from new notes
                NetworkOptimizer.extractImageDomainsFromNotes([newRawJson])
                
                let allNotes = Array.concat(notes, newNotes)
                let newLastPostId = getLastNoteId(newNotes)
                setState(_ => Loaded({
                  notes: allNotes,
                  lastPostId: newLastPostId,
                  hasMore: Array.length(newNotes) >= 20,
                  isLoadingMore: false,
                  isStreaming,
                }))
              }
            | Error(_) => // Reset loading state on error
              setState(prev => {
                switch prev {
                | Loaded(data) => Loaded({...data, isLoadingMore: false})
                | _ => prev
                }
              })
            }
          }
        | None => // Reset loading state if no client
          setState(prev => {
            switch prev {
            | Loaded(data) => Loaded({...data, isLoadingMore: false})
            | _ => prev
            }
          })
        }
      }
    | _ => () // Do nothing if not in the right state
    }
  }
  let _ = loadMore // Suppress unused warning - used in raw JS below

  // Ref for the sentinel element at the bottom of the timeline
  let sentinelRef = PreactHooks.useRef(Nullable.null)

  // Callback ref function to set the sentinel element
  let setSentinelRef = (element: Nullable.t<Dom.element>): unit => {
    sentinelRef.current = element
  }

  // Setup IntersectionObserver for infinite scroll
  PreactHooks.useEffect1(() => {
    let sentinel = sentinelRef.current

    // Create and setup observer only if sentinel exists
    if !Nullable.isNullable(sentinel) {
      let element = sentinel->Nullable.toOption->Option.getOrThrow
      let (_observer, cleanup) = IntersectionObserver.makeObserver(
        element,
        () => {
          let _ = loadMore()
        },
        ~threshold=0.1,
        (),
      )
      Some(cleanup)
    } else {
      None
    }
  }, [state])

  <div className="timeline">
    <div className="timeline-header">
      <h2>
        {Preact.string(
          if name != "" {
            name
          } else {
            switch timelineType {
            | #home => "ホーム"
            | #local => "ローカル"
            | #global => "グローバル"
            | #hybrid => "ソーシャル"
            | #antenna(_) => "アンテナ"
            | #list(_) => "リスト"
            | #channel(_) => "チャンネル"
            }
          },
        )}
      </h2>
      {switch state {
      | Loaded({isStreaming: true}) =>
        <span
          className="streaming-indicator"
          title="配信中"
          style={Style.make(
            ~display="inline-flex",
            ~alignItems="center",
            ~gap="0.3rem",
            ~fontSize="0.85rem",
            ~color="#10b981",
            ~fontWeight="600",
            (),
          )}
        >
          <span
            style={Style.make(
              ~width="8px",
              ~height="8px",
              ~borderRadius="50%",
              ~backgroundColor="#10b981",
              ~animation="pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite",
              (),
            )}
          />
          {Preact.string("配信中")}
        </span>
      | _ => Preact.null
      }}
      <button className="secondary outline" onClick={onRefreshClick}>
        {Preact.string("更新")}
      </button>
    </div>
    {switch state {
    | Loading =>
      <div className="timeline-skeleton">
        {Array.make(~length=6, ())
        ->Array.mapWithIndex((_, i) =>
          <div key={Int.toString(i)} className="skeleton-note">
            <div className="skeleton-avatar" />
            <div className="skeleton-content">
              <div className="skeleton-line skeleton-line-name" />
              <div className="skeleton-line skeleton-line-long" />
              <div className="skeleton-line skeleton-line-medium" />
            </div>
          </div>
        )
        ->Preact.array}
      </div>
    | Error(msg) =>
      <div className="timeline-error">
        <p> {Preact.string("エラー: " ++ msg)} </p>
        <button onClick={onRefreshClick}> {Preact.string("再試行")} </button>
      </div>
    | Loaded({notes, isLoadingMore, hasMore, isStreaming: _}) =>
      if Array.length(notes) == 0 {
        <div className="timeline-empty">
          <p> {Preact.string("ノートはまだありません")} </p>
        </div>
      } else {
        <>
          <div className="timeline-notes">
            {notes
            ->Array.map(note => {
              <Note.NoteView key={note.id} note />
            })
            ->Preact.array}
          </div>
          {if hasMore {
            <>
              <div ref={setSentinelRef->Obj.magic} className="timeline-sentinel" />
              {if isLoadingMore {
                <div className="timeline-loading-more">
                  <p> {Preact.string("読み込み中...")} </p>
                </div>
              } else {
                Preact.null
              }}
            </>
          } else {
            <div className="timeline-end">
              <p> {Preact.string("これ以上ありません")} </p>
            </div>
          }}
        </>
      }
    }}
  </div>
}
