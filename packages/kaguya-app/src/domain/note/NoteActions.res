// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = (~noteId: string, ~noteHost: string, ~reactionAcceptance: option<SharedTypes.reactionAcceptance>=?) => {
  let (_, navigate) = Wouter.useLocation()
  let (isRenoting, setIsRenoting) = PreactHooks.useState(() => false)
  let (showEmojiPicker, setShowEmojiPicker) = PreactHooks.useState(() => false)
  let isLoggedIn = PreactSignals.value(AppState.isLoggedIn)
  let isReadOnly = AppState.isReadOnlyMode()

  let handleReply = (_: JsxEvent.Mouse.t) => {
    navigate("/notes/" ++ noteId ++ "/" ++ noteHost)
  }

  let handleRenote = (_: JsxEvent.Mouse.t) => {
    if isLoggedIn && !isReadOnly && !isRenoting {
      let _ = (async () => {
        setIsRenoting(_ => true)
        switch PreactSignals.value(AppState.client) {
        | Some(client) =>
          let result = await client->Misskey.Notes.create("", ~renoteId=noteId, ())
          switch result {
          | Ok(_) => ToastState.showSuccess("リノートしました")
          | Error(msg) => ToastState.showError("リノートに失敗しました: " ++ msg)
          }
        | None => ToastState.showError("接続されていません")
        }
        setIsRenoting(_ => false)
      })()
    }
  }

  let handleEmojiSelect = (emoji: string) => {
    setShowEmojiPicker(_ => false)
    let _ = (async () => {
      switch PreactSignals.value(AppState.client) {
      | Some(client) =>
        let result = await client->Misskey.Notes.react(noteId, emoji)
        switch result {
        | Ok(_) => ()
        | Error(msg) => ToastState.showError("リアクションに失敗しました: " ++ msg)
        }
      | None => ()
      }
    })()
  }

  <div className="note-actions">
    <button
      className="note-action-btn"
      onClick={handleReply}
      title="返信"
      type_="button"
      ariaLabel="返信"
    >
      <iconify-icon icon="tabler:arrow-back-up" />
    </button>
    <button
      className={"note-action-btn" ++ (if isRenoting { " loading" } else { "" })}
      onClick={handleRenote}
      title="リノート"
      type_="button"
      ariaLabel="リノート"
      disabled={isRenoting || !isLoggedIn || isReadOnly}
    >
      <iconify-icon icon="tabler:repeat" />
    </button>
    {if isLoggedIn && !isReadOnly {
      <>
        <button
          className="note-action-btn"
          onClick={_ => setShowEmojiPicker(_ => true)}
          title="リアクション"
          type_="button"
          ariaLabel="リアクションを追加"
        >
          <iconify-icon icon="tabler:plus" />
        </button>
        {if showEmojiPicker {
          <EmojiPicker
            onSelect={handleEmojiSelect}
            onClose={() => setShowEmojiPicker(_ => false)}
            reactionAcceptance=?{reactionAcceptance}
          />
        } else {
          Preact.null
        }}
      </>
    } else {
      Preact.null
    }}
    <button
      className="note-action-btn note-action-more"
      title="その他"
      type_="button"
      ariaLabel="その他"
    >
      <iconify-icon icon="tabler:dots" />
    </button>
  </div>
}
