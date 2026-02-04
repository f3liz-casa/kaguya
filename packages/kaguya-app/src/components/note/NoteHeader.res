// SPDX-License-Identifier: MPL-2.0
// NoteHeader.res - Note header component (avatar, username, timestamp)

@jsx.component
let make = (~user: UserView.t, ~createdAt: string) => {
  let relativeTime = TimeFormat.formatRelativeTime(createdAt)

  <div className="note-header">
    {if user.avatarUrl != "" {
      <img
        className="avatar"
        src={user.avatarUrl}
        alt={user.username ++ "'s avatar"}
        onError={_ => {
          let target: Dom.element = %raw(`event.target`)
          HtmlElement.setDisplay(target, "none")
        }}
        role="img"
      />
    } else {
      <div className="avatar-placeholder" ariaLabel={user.username ++ "'s avatar"} role="img" />
    }}
    <div className="note-author">
      <span className="display-name"> {Preact.string(user.name)} </span>
      <span className="username"> {Preact.string("@" ++ user.username)} </span>
    </div>
    <time className="note-time" dateTime={createdAt}> {Preact.string(relativeTime)} </time>
  </div>
}
