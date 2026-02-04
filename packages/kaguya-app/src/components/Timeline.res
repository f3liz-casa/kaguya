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

  // Ref to store the streaming subscription
  let subscriptionRef = PreactHooks.useRef(None)

  // Ref to track if we've already started streaming for this timeline
  let hasStartedStreamingRef = PreactHooks.useRef(false)

  // Fetch timeline on mount and when timelineType changes
  PreactHooks.useEffect1(() => {
    // Reset to loading state when timeline changes
    setState(_ => Loading)
    hasStartedStreamingRef.current = false // Reset streaming flag

    let fetchTimeline = async () => {
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
                isStreaming: false,
              }))
            }
          | Error(msg) => setState(_ => Error(msg))
          }
        }
      | None => setState(_ => Error("Not connected"))
      }
    }

    let _ = fetchTimeline()
    None
  }, [timelineType])

  // Subscribe to realtime streaming updates after initial load
  PreactHooks.useEffect(() => {
    // Only subscribe if:
    // 1. We have a client
    // 2. State is Loaded
    // 3. We haven't already started streaming for this timeline
    let shouldSubscribe = switch (
      PreactSignals.value(AppState.client),
      state,
      hasStartedStreamingRef.current,
    ) {
    | (Some(_), Loaded(_), false) => true
    | _ => false
    }

    if shouldSubscribe {
      switch PreactSignals.value(AppState.client) {
      | Some(client) => {
          Console.log("Starting streaming subscription...")
          hasStartedStreamingRef.current = true

          // Update state to indicate streaming is active FIRST
          setState(prev => {
            switch prev {
            | Loaded(data) => {
                Console.log("Setting isStreaming to true")
                Loaded({...data, isStreaming: true})
              }
            | _ => prev
            }
          })

          // Subscribe to timeline updates
          let subscription = client->Misskey.Stream.timeline(timelineType, newNote => {
            Console.log("Received new note via stream")
            // Decode note at the boundary
            let decodedNote = NoteDecoder.decode(newNote)

            // Add new note to timeline with deduplication
            setState(
              prev => {
                switch (prev, decodedNote) {
                | (Loaded(data), Some(noteData)) => {
                    // Check if note already exists (deduplication)
                    let shouldAdd = !noteExists(data.notes, noteData.id)

                    if shouldAdd {
                      // Prepend new note to the beginning of the timeline
                      Loaded({
                        ...data,
                        notes: [noteData]->Array.concat(data.notes),
                      })
                    } else {
                      // Note already exists, no update needed
                      prev
                    }
                  }
                | _ => prev // If decoding failed or not in Loaded state, no update
                }
              },
            )
          })

          // Store subscription ref
          subscriptionRef.current = Some(subscription)
          Console.log("Subscription created and stored")
        }
      | None => Console.log("No client available for streaming")
      }
    }

    None // No cleanup here - handled by separate effect
  })

  // Cleanup subscription on unmount or timeline change
  PreactHooks.useEffect1(() => {
    Some(
      () => {
        Console.log("Timeline unmounting or changing - cleaning up subscription...")
        subscriptionRef.current->Option.forEach(sub => {
          sub.dispose()
          Console.log("Subscription disposed")
        })
        subscriptionRef.current = None
        hasStartedStreamingRef.current = false
      },
    )
  }, [timelineType])

  // Handle refresh
  let handleRefresh = async () => {
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
              isStreaming: false,
            }))
          }
        | Error(msg) => setState(_ => Error(msg))
        }
      }
    | None => setState(_ => Error("Not connected"))
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
            | #home => "Home"
            | #local => "Local"
            | #global => "Global"
            | #hybrid => "Social"
            | #antenna(_) => "Antenna"
            | #list(_) => "List"
            | #channel(_) => "Channel"
            }
          },
        )}
      </h2>
      {switch state {
      | Loaded({isStreaming: true}) =>
        <span
          className="streaming-indicator"
          title="Live updates active"
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
          {Preact.string("Live")}
        </span>
      | _ => Preact.null
      }}
      <button className="secondary outline" onClick={onRefreshClick}>
        {Preact.string("Refresh")}
      </button>
    </div>
    {switch state {
    | Loading =>
      <div className="timeline-loading">
        <p> {Preact.string("Loading timeline...")} </p>
      </div>
    | Error(msg) =>
      <div className="timeline-error">
        <p> {Preact.string("Error: " ++ msg)} </p>
        <button onClick={onRefreshClick}> {Preact.string("Try again")} </button>
      </div>
    | Loaded({notes, isLoadingMore, hasMore, isStreaming: _}) =>
      if Array.length(notes) == 0 {
        <div className="timeline-empty">
          <p> {Preact.string("No notes yet")} </p>
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
                  <p> {Preact.string("Loading more...")} </p>
                </div>
              } else {
                Preact.null
              }}
            </>
          } else {
            <div className="timeline-end">
              <p> {Preact.string("No more posts")} </p>
            </div>
          }}
        </>
      }
    }}
  </div>
}
