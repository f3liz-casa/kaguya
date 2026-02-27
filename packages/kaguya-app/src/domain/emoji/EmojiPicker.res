// SPDX-License-Identifier: MPL-2.0

// Use shared types
type reactionAcceptance = SharedTypes.reactionAcceptance

@jsx.component
let make = (
  ~onSelect: string => unit,
  ~onClose: unit => unit,
  ~reactionAcceptance: option<reactionAcceptance>=?,
) => {
  let (searchQuery, setSearchQuery) = PreactHooks.useState(() => "")
  let (selectedCategory, setSelectedCategory) = PreactHooks.useState(() => None)
  let (scrollTop, setScrollTop) = PreactHooks.useState(() => 0)

  // Eagerly load emojis if not already loaded
  // This ensures the picker shows emojis immediately
  PreactHooks.useEffect0(() => {
    let client = PreactSignals.value(AppState.client)
    switch client {
    | Some(c) => {
        // Try to load emojis if not already loaded
        // This will be instant if they were prefetched during idle time
        let _ = EmojiStore.lazyLoadGlobal(c)
      }
    | None => ()
    }
    None
  })

  let allEmojis = EmojiStore.getAllEmojis()
  let categories = EmojiStore.getCategories()

  // Virtual scrolling configuration
  let itemSize = 44 // Size of each emoji item in pixels (2.75rem = 44px)
  let containerHeight = 400 // Height of the scrollable area
  let itemsPerRow = 8 // Approximate items per row (will adjust based on grid)
  let overscanRows = 2 // Render extra rows above and below viewport

  let isLikeOnly = switch reactionAcceptance {
  | Some(#likeOnly) => true
  | _ => false
  }

  // Filter emojis based on search query and selected category
  let filteredEmojis = allEmojis->Array.filter(emoji => {
    // If likeOnly mode, only show heart emoji
    if isLikeOnly {
      emoji.name->String.includes("heart") || emoji.name->String.includes("like")
    } else {
      // Category filter
      let matchesCategory = switch selectedCategory {
      | None => true
      | Some(cat) => emoji.category->Option.getOr("Other") == cat
      }

      // Search filter
      let matchesSearch = if searchQuery == "" {
        true
      } else {
        let query = searchQuery->String.toLowerCase
        let nameMatches = emoji.name->String.toLowerCase->String.includes(query)
        let aliasMatches =
          emoji.aliases->Array.some(alias => alias->String.toLowerCase->String.includes(query))
        nameMatches || aliasMatches
      }

      matchesCategory && matchesSearch
    }
  })

  // Calculate virtual scrolling parameters
  let totalItems = filteredEmojis->Array.length
  let totalRows = (totalItems + itemsPerRow - 1) / itemsPerRow

  // Calculate visible range
  let startRow = Math.Int.max(scrollTop / itemSize - overscanRows, 0)
  let endRow = Math.Int.min((scrollTop + containerHeight) / itemSize + overscanRows, totalRows)

  let startIndex = startRow * itemsPerRow
  let endIndex = Math.Int.min(endRow * itemsPerRow, totalItems)

  let visibleEmojis = filteredEmojis->Array.slice(~start=startIndex, ~end=endIndex)

  let contentStyle = Style.make(
    ~height=Int.toString(totalRows * itemSize) ++ "px",
    ~position="relative",
    (),
  )

  let itemsStyle = Style.make(
    ~transform="translateY(" ++ Int.toString(startRow * itemSize) ++ "px)",
    (),
  )

  PreactHooks.useEffect1(() => {
    let handleEscape = (e: JsxEvent.Keyboard.t) => {
      if JsxEvent.Keyboard.key(e) == "Escape" {
        onClose()
      }
    }

    Document.addEventListener("keydown", handleEscape)
    Some(() => Document.removeEventListener("keydown", handleEscape))
  }, [onClose])

  // Prevent body scroll when picker is open
  PreactHooks.useEffect0(() => {
    Document.setBodyOverflow("hidden")
    Some(() => Document.setBodyOverflow(""))
  })

  <div
    className="emoji-picker-overlay"
    onClick={_ => onClose()}
    role="dialog"
    ariaModal={true}
    ariaLabel="絵文字ピッカー"
  >
    <div className="emoji-picker-modal" onClick={e => e->JsxEvent.Mouse.stopPropagation}>
      <div className="emoji-picker-header">
        <input
          className="emoji-search"
          type_="text"
          placeholder="絵文字を検索..."
          value={searchQuery}
          onInput={e => {
            let target = JsxEvent.Form.target(e)
            let value = EventTarget.getValue(target)
            setSearchQuery(_ => value)
          }}
          ariaLabel="絵文字を検索"
        />
        <button
          className="emoji-close"
          onClick={_ => onClose()}
          ariaLabel="絵文字ピッカーを閉じる"
          type_="button"
        >
          {Preact.string("×")}
        </button>
      </div>

      {if !isLikeOnly && categories->Array.length > 1 {
        <div className="emoji-categories" role="tablist">
          <button
            className={selectedCategory->Option.isNone
              ? "emoji-category-tab active"
              : "emoji-category-tab"}
            onClick={_ => setSelectedCategory(_ => None)}
            role="tab"
            ariaSelected={selectedCategory->Option.isNone}
            type_="button"
          >
            {Preact.string("すべて")}
          </button>
          {categories
          ->Array.map(cat => {
            let isActive = selectedCategory->Option.getOr("") == cat
            <button
              key={cat}
              className={isActive ? "emoji-category-tab active" : "emoji-category-tab"}
              onClick={_ => setSelectedCategory(_ => Some(cat))}
              role="tab"
              ariaSelected={isActive}
              type_="button"
            >
              {Preact.string(cat)}
            </button>
          })
          ->Preact.array}
        </div>
      } else {
        Preact.null
      }}

      <div
        className="emoji-grid"
        role="grid"
        ariaLabel="絵文字一覧"
        onScroll={e => {
          let target = JsxEvent.UI.target(e)
          let scrollTop = EventTarget.getScrollTop(target)
          setScrollTop(_ => scrollTop)
        }}
      >
        {if filteredEmojis->Array.length == 0 {
          <div className="emoji-empty" role="status">
            <p> {Preact.string("絵文字が見つかりません")} </p>
          </div>
        } else {
          <div className="emoji-grid-content" style={contentStyle}>
            <div className="emoji-grid-items" style={itemsStyle}>
              {visibleEmojis
              ->Array.map(emoji => {
                <button
                  key={emoji.name}
                  className="emoji-item"
                  onClick={_ => {
                    onSelect(":" ++ emoji.name ++ ":")
                    onClose()
                  }}
                  title={emoji.name}
                  ariaLabel={emoji.name ++ " を選択"}
                  type_="button"
                >
                  <img src={emoji.url} alt={":" ++ emoji.name ++ ":"} />
                </button>
              })
              ->Preact.array}
            </div>
          </div>
        }}
      </div>
    </div>
  </div>
}
