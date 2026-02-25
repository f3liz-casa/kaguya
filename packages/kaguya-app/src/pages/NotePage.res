// SPDX-License-Identifier: MPL-2.0
// NotePage.res - Note detail page with conversation context

type notePageState =
  | Loading
  | Loaded({
      note: NoteView.t,
      conversation: array<NoteView.t>,
      replies: array<NoteView.t>,
    })
  | Error(string)

// Resolve a note: if host matches local, fetch directly; if remote, use ap/show to cast URI to local
let resolveNote = async (client: Misskey.t, noteId: string, host: string, localHost: string): result<(string, JSON.t), string> => {
  if host == localHost {
    // Local note — fetch directly
    let result = await client->Misskey.Notes.show(noteId)
    switch result {
    | Ok(json) => Ok((noteId, json))
    | Error(msg) => Error(msg)
    }
  } else {
    // Remote note — use ap/show to cast the remote URI to a local object
    let remoteUri = "https://" ++ host ++ "/notes/" ++ noteId
    let params = Dict.make()
    params->Dict.set("uri", remoteUri->JSON.Encode.string)
    let apResult = await client->Misskey.request("ap/show", ~params=params->JSON.Encode.object, ())
    switch apResult {
    | Ok(json) =>
      switch json->JSON.Decode.object {
      | Some(obj) =>
        let type_ = obj->Dict.get("type")->Option.flatMap(JSON.Decode.string)
        let object = obj->Dict.get("object")
        switch (type_, object) {
        | (Some("Note"), Some(noteJson)) =>
          // Extract the local note ID from the resolved object
          let localNoteId = switch noteJson->JSON.Decode.object {
          | Some(noteObj) => noteObj->Dict.get("id")->Option.flatMap(JSON.Decode.string)->Option.getOr(noteId)
          | None => noteId
          }
          Ok((localNoteId, noteJson))
        | _ => Error("リモートURIがノートとして解決できませんでした")
        }
      | None => Error("ap/show の応答形式が不正です")
      }
    | Error(msg) => Error("リモートノートの取得に失敗: " ++ msg)
    }
  }
}

@jsx.component
let make = (~noteId: string, ~host: string) => {
  let (state, setState) = PreactHooks.useState(() => Loading)
  let localHost = PreactSignals.value(AppState.instanceName)
  let (_, navigate) = Wouter.useLocation()

  PreactHooks.useEffect2(() => {
    setState(_ => Loading)

    let fetchNote = async () => {
      switch PreactSignals.value(AppState.client) {
      | Some(client) => {
          let resolved = await resolveNote(client, noteId, host, localHost)

          switch resolved {
          | Ok((localNoteId, _noteJson)) if host != localHost =>
            // Remote note resolved via ap/show — redirect to local canonical URL
            navigate("/notes/" ++ localNoteId ++ "/" ++ localHost)
          | Ok((localNoteId, noteJson)) =>
            switch NoteDecoder.decode(noteJson) {
            | Some(note) => {
                let (convResult, repliesResult) = await Promise.all2((
                  client->Misskey.Notes.conversation(localNoteId, ()),
                  client->Misskey.Notes.children(localNoteId, ()),
                ))

                let conversation = switch convResult {
                | Ok(json) => NoteDecoder.decodeManyFromJson(json)->Array.toReversed
                | Error(_) => []
                }

                let replies = switch repliesResult {
                | Ok(json) => NoteDecoder.decodeManyFromJson(json)
                | Error(_) => []
                }

                setState(_ => Loaded({note, conversation, replies}))
              }
            | None => setState(_ => Error("ノートの解析に失敗しました"))
            }
          | Error(msg) => setState(_ => Error(msg))
          }
        }
      | None => setState(_ => Error("接続されていません"))
      }
    }

    let _ = fetchNote()
    None
  }, (noteId, host))

  <Layout>
    {switch state {
    | Loading =>
      <div className="loading-container">
        <p> {Preact.string("読み込み中...")} </p>
      </div>
    | Error(msg) =>
      <div className="note-page-error">
        <p> {Preact.string("エラー: " ++ msg)} </p>
      </div>
    | Loaded({note, conversation, replies}) =>
      <div className="note-page-container">
        // Federated note warning — shown when note has a uri (originated on another instance)
        {switch note.uri {
        | Some(uri) =>
          <div className="note-remote-warning" role="status">
            <p>
              {Preact.string("⚠ このノートは連合先から取得されたコピーです。元のノートより情報が不完全な場合があります。")}
            </p>
            <a
              href={uri}
              target="_blank"
              rel="noopener noreferrer"
              className="note-original-link"
            >
              {Preact.string("元のノートを見る →")}
            </a>
          </div>
        | None => Preact.null
        }}

        // Conversation context (parent notes)
        {if Array.length(conversation) > 0 {
          <div className="note-conversation">
            <div className="timeline-notes">
              {conversation
              ->Array.map(n => {
                <Note.NoteView key={n.id} note=n />
              })
              ->Preact.array}
            </div>
            <div className="note-thread-connector" />
          </div>
        } else {
          Preact.null
        }}

        // Main note (highlighted)
        <div className="note-page-main">
          <Note.NoteView note />
        </div>

        // Reply form
        <PostForm replyTo=note placeholder="返信を書き込む..." />

        // Replies
        {if Array.length(replies) > 0 {
          <div className="note-replies">
            <h3 className="note-replies-title"> {Preact.string("返信")} </h3>
            <div className="timeline-notes">
              {replies
              ->Array.map(n => {
                <Note.NoteView key={n.id} note=n />
              })
              ->Preact.array}
            </div>
          </div>
        } else {
          Preact.null
        }}
      </div>
    }}
  </Layout>
}
