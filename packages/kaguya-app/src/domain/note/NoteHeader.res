// SPDX-License-Identifier: MPL-2.0

@jsx.component
let make = (~user: UserView.t, ~createdAt: string, ~noteId: option<string>=?, ~contextHost: option<string>=?) => {
  let relativeTime = TimeFormat.formatRelativeTime(createdAt)
  let localHost = PreactSignals.value(AppState.instanceName)

  // Resolve context: the instance this note was fetched from
  let ctxHost = switch contextHost {
  | Some(h) => h
  | None => localHost
  }

  // Resolve user's actual host (null = local to the fetching instance)
  let userHost = switch user.host {
  | Some(h) => h
  | None => ctxHost
  }

  // URL: always full @username@host
  let userPath = "/@" ++ user.username ++ "@" ++ userHost

  // UI display: short handle if user is local to context, full if remote
  let displayHandle = if userHost == ctxHost {
    "@" ++ user.username
  } else {
    "@" ++ user.username ++ "@" ++ userHost
  }

  // Note URL: /notes/:noteId/:host
  let noteHref = switch noteId {
  | Some(id) => Some("/notes/" ++ id ++ "/" ++ ctxHost)
  | None => None
  }

  <div className="note-header">
    <Wouter.Link href={userPath} className="note-avatar-link">
      {if user.avatarUrl != "" {
        <img
          className="avatar"
          src={user.avatarUrl}
          alt={user.username ++ "'s avatar"}
          loading=#lazy
          onError={event => {
            let target: Dom.element = event->JsxEvent.Media.target->Obj.magic
            HtmlElement.setDisplay(target, "none")
          }}
          role="img"
        />
      } else {
        <div className="avatar-placeholder" ariaLabel={user.username ++ "'s avatar"} role="img" />
      }}
    </Wouter.Link>
    <div className="note-author">
      <Wouter.Link href={userPath} className="display-name-link">
        <span className="display-name"> <MfmRenderer text={user.name} parseSimple=true /> </span>
      </Wouter.Link>
      <span className="username"> {Preact.string(displayHandle)} </span>
    </div>
    {switch noteHref {
    | Some(href) =>
      <Wouter.Link href className="note-time-link">
        <time className="note-time" dateTime={createdAt}> {Preact.string(relativeTime)} </time>
      </Wouter.Link>
    | None =>
      <time className="note-time" dateTime={createdAt}> {Preact.string(relativeTime)} </time>
    }}
  </div>
}
