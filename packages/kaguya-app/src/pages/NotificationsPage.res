// SPDX-License-Identifier: MPL-2.0
// NotificationsPage.res - Notifications page

@jsx.component
let make = () => {
  let notifs = PreactSignals.value(NotificationStore.notifications)

  // Mark as read when viewing
  PreactHooks.useEffect0(() => {
    NotificationStore.markAllRead()
    None
  })

  <Layout>
    <div className="notifications-container">
      <div className="notifications-header">
        <h2> {Preact.string("通知")} </h2>
      </div>
      {if notifs->Array.length == 0 {
        <div className="notifications-empty">
          <p> {Preact.string("通知はまだありません")} </p>
        </div>
      } else {
        <div className="notifications-list">
          {notifs
          ->Array.map(notif => {
            <article key={notif.id} className="notification-item">
              <div className="notification-icon">
                {Preact.string(NotificationView.typeIcon(notif.type_))}
              </div>
              <div className="notification-body">
                <div className="notification-meta">
                  {switch notif.userName {
                  | Some(name) =>
                    <span className="notification-user">
                      <MfmRenderer text={name} parseSimple=true />
                      <small className="notification-handle">
                        {Preact.string(" " ++ NotificationView.fullHandle(notif))}
                      </small>
                    </span>
                  | None => Preact.null
                  }}
                  <span className="notification-type">
                    {Preact.string(NotificationView.typeLabel(notif.type_))}
                  </span>
                  <time className="notification-time" dateTime={notif.createdAt}>
                    {Preact.string(TimeFormat.formatRelativeTime(notif.createdAt))}
                  </time>
                </div>
                {switch (notif.reaction, notif.reactionUrl) {
                | (Some(reaction), Some(url)) =>
                  <span className="notification-reaction">
                    <img
                      className="mfm-emoji-image"
                      src={url}
                      alt={reaction}
                      loading=#lazy
                      style={Style.make(~height="1.5em", ())}
                    />
                  </span>
                | (Some(reaction), None) =>
                  <span className="notification-reaction"> {Preact.string(reaction)} </span>
                | _ => Preact.null
                }}
                {switch notif.noteText {
                | Some(text) =>
                  <div className="notification-note-text">
                    <MfmRenderer text={text} />
                  </div>
                | None =>
                  switch notif.body {
                  | Some(body) =>
                    <p className="notification-body-text"> {Preact.string(body)} </p>
                  | None => Preact.null
                  }
                }}
              </div>
            </article>
          })
          ->Preact.array}
        </div>
      }}
    </div>
  </Layout>
}
