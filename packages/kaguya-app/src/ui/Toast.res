// SPDX-License-Identifier: MPL-2.0

// Single Toast Component

module ToastItem = {
  @jsx.component
  let make = (~toast: ToastState.toast, ~onDismiss: unit => unit) => {
    let (backgroundColor, borderColor, icon) = switch toast.type_ {
    | #error => ("rgba(220, 38, 38, 0.85)", "#dc2626", "❌")
    | #warning => ("rgba(234, 179, 8, 0.85)", "#eab308", "⚠️")
    | #info => ("rgba(37, 99, 235, 0.85)", "#3b82f6", "ℹ️")
    | #success => ("rgba(22, 163, 74, 0.85)", "#22c563", "✓")
    }

    let containerStyle = Style.make(
      ~position="relative",
      ~display="flex",
      ~alignItems="flex-start",
      ~gap="12px",
      ~padding="16px",
      ~marginBottom="12px",
      ~backgroundColor,
      ~border=`2px solid ${borderColor}`,
      ~borderRadius="8px",
      ~boxShadow="0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)",
      ~minWidth="300px",
      ~maxWidth="400px",
      ~animation="slideInRight 0.3s ease-out",
      (),
    )

    let iconStyle = Style.make(~fontSize="20px", ~flexShrink="0", ~marginTop="2px", ())

    let messageStyle = Style.make(
      ~flex="1",
      ~fontSize="14px",
      ~lineHeight="1.5",
      ~color="var(--color)",
      ~wordBreak="break-word",
      (),
    )

    let actionButtonStyle = Style.make(
      ~marginTop="8px",
      ~padding="4px 10px",
      ~fontSize="13px",
      ~fontWeight="600",
      ~background="transparent",
      ~border=`1px solid ${borderColor}`,
      ~borderRadius="4px",
      ~cursor="pointer",
      ~color="var(--color)",
      (),
    )

    let closeButtonStyle = Style.make(
      ~position="absolute",
      ~top="8px",
      ~right="8px",
      ~background="transparent",
      ~border="none",
      ~cursor="pointer",
      ~fontSize="20px",
      ~lineHeight="1",
      ~padding="4px",
      ~opacity="0.6",
      ~transition="opacity 0.2s",
      ~color="var(--color)",
      (),
    )

    <div style={containerStyle} role="alert" ariaLive=#assertive>
      <span style={iconStyle} ariaHidden={true}> {Preact.string(icon)} </span>
      <div style={messageStyle}>
        {Preact.string(toast.message)}
        {switch toast.action {
        | Some(action) =>
          <div>
            <button style={actionButtonStyle} onClick={_ => action.onClick()} type_="button">
              {Preact.string(action.label)}
            </button>
          </div>
        | None => Preact.null
        }}
      </div>
      <button
        style={closeButtonStyle}
        onClick={_ => onDismiss()}
        onMouseEnter={e => {
          let target = JsxEvent.Mouse.currentTarget(e)
          HtmlElement.setOpacity(target, "1")
        }}
        onMouseLeave={e => {
          let target = JsxEvent.Mouse.currentTarget(e)
          HtmlElement.setOpacity(target, "0.6")
        }}
        ariaLabel="通知を閉じる"
        type_="button"
      >
        {Preact.string("×")}
      </button>
    </div>
  }
}

// Toast Container Component

@jsx.component
let make = () => {
  let toasts = PreactSignals.value(ToastState.toasts)

  let containerStyle = Style.make(
    ~position="fixed",
    ~bottom="20px",
    ~right="20px",
    ~zIndex="9999",
    ~display="flex",
    ~flexDirection="column",
    ~alignItems="flex-end",
    ~pointerEvents="none",
    (),
  )

  let toastWrapperStyle = Style.make(~pointerEvents="auto", ())

  if Array.length(toasts) > 0 {
    <div style={containerStyle} ariaLive=#polite ariaAtomic={false}>
      <div style={toastWrapperStyle}>
        {toasts
        ->Array.map(toast => {
          <ToastItem
            key={toast.id} toast={toast} onDismiss={() => ToastState.dismissToast(toast.id)}
          />
        })
        ->Preact.array}
      </div>
    </div>
  } else {
    Preact.null
  }
}
