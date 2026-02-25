// SPDX-License-Identifier: MPL-2.0
// PostForm.res - Simple, progressive disclosure post form

// FFI helpers for file handling
@val external _arrayFrom: {..} => array<{..}> = "Array.from"
@val external _createObjectURL: {..} => string = "URL.createObjectURL"
@val external _revokeObjectURL: string => unit = "URL.revokeObjectURL"

@jsx.component
let make = (~placeholder: string="今何してる？", ~replyTo: option<NoteView.t>=?, ~onPosted: option<unit => unit>=?) => {
  let (text, setText) = PreactHooks.useState(() => "")
  let (isExpanded, setIsExpanded) = PreactHooks.useState(() => true)
  let (isPosting, setIsPosting) = PreactHooks.useState(() => false)
  let (visibility, setVisibility) = PreactHooks.useState(() => #public)
  let (cw, setCw) = PreactHooks.useState(() => "")
  let (showCw, setShowCw) = PreactHooks.useState(() => false)
  let (showVisibilityMenu, setShowVisibilityMenu) = PreactHooks.useState(() => false)
  // Attached files: array of {file, preview} objects
  let (attachedFiles, setAttachedFiles) = PreactHooks.useState(() => [])
  // Number of files currently being uploaded (shows overlay spinner on previews)
  let (uploadingCount, setUploadingCount) = PreactHooks.useState(() => 0)

  let inputRef = PreactHooks.useRef(Nullable.null)
  let fileInputRef = PreactHooks.useRef(Nullable.null)

  let handleSubmit = (e: JsxEvent.Form.t) => {
    e->JsxEvent.Form.preventDefault
    
    if text == "" && Array.length(attachedFiles) == 0 {
      ()
    } else {
      let _ = (async () => {
        setIsPosting(_ => true)
        
        let clientOpt = PreactSignals.value(AppState.client)
        
        switch clientOpt {
        | Some(client) => {
            let cwOpt = if showCw && cw != "" { Some(cw) } else { None }
            let replyId = replyTo->Option.map(note => note.id)

            // Upload any attached images first
            let fileIds =
              if Array.length(attachedFiles) == 0 {
                None
              } else {
                setUploadingCount(_ => Array.length(attachedFiles))
                let uploadResults = await Promise.all(
                  attachedFiles->Array.map(item => Misskey.Drive.upload(client, ~file=item["file"], ()))
                )
                setUploadingCount(_ => 0)
                let ids = uploadResults->Array.filterMap(r => switch r {
                  | Ok(id) => Some(id)
                  | Error(msg) => {
                      ToastState.showError("画像アップロード失敗: " ++ msg)
                      None
                    }
                })
                if Array.length(ids) > 0 { Some(ids) } else { None }
              }
            
            let result = await client->Misskey.Notes.create(
              text,
              ~visibility=visibility,
              ~cw=?cwOpt,
              ~replyId=?replyId,
              ~fileIds=?fileIds,
              ()
            )
            
            switch result {
            | Ok(_) => {
                setText(_ => "")
                setCw(_ => "")
                setShowCw(_ => false)
                setIsExpanded(_ => false)
                setAttachedFiles(_ => [])
                ToastState.showSuccess("投稿しました")
                onPosted->Option.forEach(cb => cb())
              }
            | Error(msg) => {
                ToastState.showError("投稿に失敗しました: " ++ msg)
              }
            }
          }
        | None => ToastState.showError("接続されていません")
        }
        
        setIsPosting(_ => false)
      })()
    }
  }

  let handleFileChange = (e: JsxEvent.Form.t) => {
    let input = JsxEvent.Form.currentTarget(e)
    let fileList = input["files"]
    let files = _arrayFrom(fileList)
    let newItems = files->Array.map(file => {
      let preview = _createObjectURL(file)
      {"file": file, "preview": preview}
    })
    setAttachedFiles(prev => Array.concat(prev, newItems))
    input["value"] = ""
  }

  let removeAttachment = (idx: int) => {
    setAttachedFiles(prev => {
      let removed = prev->Array.getUnsafe(idx)
      _revokeObjectURL(removed["preview"])
      prev->Array.filterWithIndex((_, i) => i != idx)
    })
  }

  // Ctrl+V / paste — capture images from clipboard
  let handlePaste = (e: JsxEvent.Clipboard.t) => {
    let rawEvent: {..} = e->Obj.magic
    let clipboardData = rawEvent["clipboardData"]
    let items: array<{..}> = _arrayFrom(clipboardData["items"])
    let imageFiles = items->Array.filterMap(item => {
      if item["kind"] == "file" && String.startsWith(item["type"], "image/") {
        let file: option<{..}> = item["getAsFile"]()
        file
      } else {
        None
      }
    })
    if Array.length(imageFiles) > 0 {
      rawEvent["preventDefault"]()
      let newItems = imageFiles->Array.map(file => {
        let preview = _createObjectURL(file)
        {"file": file, "preview": preview}
      })
      setAttachedFiles(prev => Array.concat(prev, newItems))
    }
  }

  let containerClass = "post-form-container expanded"

  <div className={containerClass}>
    <form onSubmit={handleSubmit}>
      {if showCw {
        <div className="post-form-cw fade-in">
          <input
            type_="text"
            placeholder="閲覧注意（CW）の注釈"
            value={cw}
            onInput={e => {
              let val = JsxEvent.Form.currentTarget(e)["value"]
              setCw(_ => val)
            }}
            disabled={isPosting}
            className="cw-input"
          />
        </div>
      } else {
        Preact.null
      }}

      <div className="post-form-main">
        <textarea
          ref={inputRef->Obj.magic}
          className="post-form-textarea"
          placeholder={placeholder}
          value={text}
          onInput={e => {
            let val = JsxEvent.Form.currentTarget(e)["value"]
            setText(_ => val)
            let target = JsxEvent.Form.currentTarget(e)
            target["style"]["height"] = "auto"
            target["style"]["height"] = (Int.toString(target["scrollHeight"]) ++ "px")
          }}
          onPaste={handlePaste}
          disabled={isPosting}
          rows={3}
        />
      </div>

      {if Array.length(attachedFiles) > 0 {
        <div className="post-form-attachments fade-in">
          {attachedFiles
          ->Array.mapWithIndex((item, idx) =>
            <div className={"attachment-preview" ++ (if uploadingCount > 0 { " uploading" } else { "" })} key={Int.toString(idx)}>
              <img src={item["preview"]} className="attachment-img" alt="添付画像" />
              {if uploadingCount > 0 {
                <div className="attachment-upload-overlay">
                  <iconify-icon icon="tabler:loader-2" className="attachment-upload-spinner" />
                </div>
              } else {
                <button
                  type_="button"
                  className="attachment-remove"
                  onClick={_ => removeAttachment(idx)}
                  ariaLabel="削除"
                  disabled={isPosting}
                >
                  <iconify-icon icon="tabler:x" />
                </button>
              }}
            </div>
          )
          ->Preact.array}
        </div>
      } else {
        Preact.null
      }}

      <input
        ref={fileInputRef->Obj.magic}
        type_="file"
        accept="image/*"
        multiple={true}
        className="post-form-file-input"
        onChange={handleFileChange}
        disabled={isPosting}
      />

      {
        <div className="post-form-footer">
          <div className="post-form-tools">
            <button
              type_="button"
              className={"tool-btn" ++ (if showCw { " active" } else { "" })}
              onClick={_ => setShowCw(prev => !prev)}
              title="閲覧注意 (CW)"
            >
              <iconify-icon icon="tabler:eye" />
            </button>

            <button
              type_="button"
              className="tool-btn"
              onClick={_ => {
                let input = fileInputRef.current
                if !Nullable.isNullable(input) {
                  (input->Nullable.toOption->Option.getOrThrow)["click"]()
                }
              }}
              title="画像を添付"
              ariaLabel="画像を添付"
              disabled={isPosting || Array.length(attachedFiles) >= 4}
            >
              <iconify-icon icon="tabler:photo-plus" />
            </button>
            
            <div className="visibility-selector">
              <button
                type_="button"
                className="visibility-trigger tool-btn"
                onClick={_ => setShowVisibilityMenu(prev => !prev)}
                disabled={isPosting}
                title="公開範囲"
              >
                <iconify-icon icon={switch visibility {
                  | #public => "tabler:world"
                  | #home => "tabler:home"
                  | #followers => "tabler:lock"
                  | #specified => "tabler:mail"
                }} />
                <iconify-icon icon="tabler:chevron-down" className="vis-chevron" />
              </button>
              {if showVisibilityMenu {
                <ul className="visibility-menu">
                  <li>
                    <button type_="button" className={"visibility-option" ++ (if visibility == #public { " active" } else { "" })}
                      onClick={_ => { setVisibility(_ => #public); setShowVisibilityMenu(_ => false) }}>
                      <iconify-icon icon="tabler:world" />
                      {Preact.string("パブリック")}
                    </button>
                  </li>
                  <li>
                    <button type_="button" className={"visibility-option" ++ (if visibility == #home { " active" } else { "" })}
                      onClick={_ => { setVisibility(_ => #home); setShowVisibilityMenu(_ => false) }}>
                      <iconify-icon icon="tabler:home" />
                      {Preact.string("ホームのみ")}
                    </button>
                  </li>
                  <li>
                    <button type_="button" className={"visibility-option" ++ (if visibility == #followers { " active" } else { "" })}
                      onClick={_ => { setVisibility(_ => #followers); setShowVisibilityMenu(_ => false) }}>
                      <iconify-icon icon="tabler:lock" />
                      {Preact.string("フォロワー限定")}
                    </button>
                  </li>
                </ul>
              } else {
                Preact.null
              }}
            </div>
          </div>
          
          <div className="post-form-actions">
            <button
              type_="submit"
              disabled={isPosting || (text == "" && Array.length(attachedFiles) == 0)}
              className="post-btn"
            >
              {if isPosting {
                <> <iconify-icon icon="tabler:loader-2" className="spin" /> {Preact.string(" 送信中...")} </>
              } else {
                <> <iconify-icon icon="tabler:send" /> {Preact.string(" ノート")} </>
              }}
            </button>
          </div>
        </div>
      }
    </form>
  </div>
}
