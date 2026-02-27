// SPDX-License-Identifier: MPL-2.0

// Style Type

type t = JsxDOM.style

// Style Creation

@obj
external empty: unit => t = ""

@obj
external make: (
  ~display: string=?,
  ~flexWrap: string=?,
  ~flexDirection: string=?,
  ~gap: string=?,
  ~alignItems: string=?,
  ~justifyContent: string=?,
  ~marginTop: string=?,
  ~marginBottom: string=?,
  ~marginLeft: string=?,
  ~marginRight: string=?,
  ~height: string=?,
  ~width: string=?,
  ~minWidth: string=?,
  ~maxWidth: string=?,
  ~minHeight: string=?,
  ~maxHeight: string=?,
  ~position: string=?,
  ~top: string=?,
  ~bottom: string=?,
  ~left: string=?,
  ~right: string=?,
  ~zIndex: string=?,
  ~transform: string=?,
  ~background: string=?,
  ~backgroundColor: string=?,
  ~color: string=?,
  ~padding: string=?,
  ~paddingTop: string=?,
  ~paddingBottom: string=?,
  ~paddingLeft: string=?,
  ~paddingRight: string=?,
  ~margin: string=?,
  ~border: string=?,
  ~borderRadius: string=?,
  ~cursor: string=?,
  ~transition: string=?,
  ~fontSize: string=?,
  ~fontWeight: string=?,
  ~lineHeight: string=?,
  ~userSelect: string=?,
  ~whiteSpace: string=?,
  ~overflow: string=?,
  ~overflowX: string=?,
  ~overflowY: string=?,
  ~textOverflow: string=?,
  ~flex: string=?,
  ~flexShrink: string=?,
  ~flexGrow: string=?,
  ~flexBasis: string=?,
  ~objectFit: string=?,
  ~aspectRatio: string=?,
  ~opacity: string=?,
  ~boxShadow: string=?,
  ~animation: string=?,
  ~pointerEvents: string=?,
  ~wordBreak: string=?,
  unit,
) => t = ""
