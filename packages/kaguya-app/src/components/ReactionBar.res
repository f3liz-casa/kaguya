// SPDX-License-Identifier: MPL-2.0
// ReactionBar.res - Container for reaction buttons and add button

// ============================================================
// Types
// ============================================================

type reactionAcceptance = [
  | #likeOnly
  | #likeOnlyForRemote
  | #nonSensitiveOnly
  | #nonSensitiveOnlyForLocalLikeOnlyForRemote
]

// ============================================================
// Component
// ============================================================

@jsx.component
let make = (
  ~noteId: string,
  ~reactions: Dict.t<int>,
  ~reactionEmojis: Dict.t<string>,
  ~myReaction: option<string>,
  ~reactionAcceptance: option<reactionAcceptance>,
) => {
  let (isLoading, setIsLoading) = PreactHooks.useState(() => false)
  let (showEmojiPicker, setShowEmojiPicker) = PreactHooks.useState(() => false)
  let (optimisticReactions, setOptimisticReactions) = PreactHooks.useState(() => reactions)
  let (optimisticMyReaction, setOptimisticMyReaction) = PreactHooks.useState(() => myReaction)
  
  // Sync props with state when they change
  PreactHooks.useEffect2(() => {
    setOptimisticReactions(_ => reactions)
    None
  }, (reactions, noteId))
  
  PreactHooks.useEffect2(() => {
    setOptimisticMyReaction(_ => myReaction)
    None
  }, (myReaction, noteId))
  
  // Handle reaction click (toggle)
  let handleReactionClick = async (reaction: string) => {
    let client = PreactSignals.value(AppState.client)
    let isLoggedIn = PreactSignals.value(AppState.isLoggedIn)
    let isReadOnly = AppState.isReadOnlyMode()
    
    // Check if user can perform write operations
    if isReadOnly {
      ToastState.showError("Cannot react: You're in read-only mode")
      ()
    } else if isLoading || !isLoggedIn {
      ()
    } else {
      switch client {
      | None => ()
      | Some(c) => {
          setIsLoading(_ => true)
          
          // Determine action: if clicking current reaction, remove it; otherwise add new
          let shouldRemove = optimisticMyReaction->Option.getOr("") == reaction
          
          // Optimistic update
          if shouldRemove {
            // Remove reaction
            setOptimisticMyReaction(_ => None)
            setOptimisticReactions(prev => {
              let newDict = Dict.make()
              prev->Dict.toArray->Array.forEach(((r, count)) => {
                if r == reaction {
                  let newCount = count - 1
                  if newCount > 0 {
                    newDict->Dict.set(r, newCount)
                  }
                } else {
                  newDict->Dict.set(r, count)
                }
              })
              newDict
            })
            
            // API call
            let result = await MisskeyJS.Notes.unreact(c, ~noteId)
            
            switch result {
            | Ok() => {
                // Success - optimistic update was correct
                setIsLoading(_ => false)
              }
            | Error(#APIError(err)) => {
                // Check if it's a permission error
                if MisskeyJS.Common.isPermissionDenied(err) {
                  ToastState.showError("Permission denied: You're in read-only mode")
                } else {
                  ToastState.showError("Failed to remove reaction: " ++ err.message)
                }
                // Revert optimistic update
                setOptimisticMyReaction(_ => myReaction)
                setOptimisticReactions(_ => reactions)
                setIsLoading(_ => false)
              }
            | Error(#UnknownError(_)) => {
                ToastState.showError("Failed to remove reaction")
                // Revert optimistic update
                setOptimisticMyReaction(_ => myReaction)
                setOptimisticReactions(_ => reactions)
                setIsLoading(_ => false)
              }
            }
          } else {
            // Add/change reaction
            let oldReaction = optimisticMyReaction
            setOptimisticMyReaction(_ => Some(reaction))
            setOptimisticReactions(prev => {
              let newDict = Dict.make()
              prev->Dict.toArray->Array.forEach(((r, count)) => {
                if r == reaction {
                  newDict->Dict.set(r, count + 1)
                } else if Some(r) == oldReaction {
                  // Decrement old reaction if we had one
                  let newCount = count - 1
                  if newCount > 0 {
                    newDict->Dict.set(r, newCount)
                  }
                } else {
                  newDict->Dict.set(r, count)
                }
              })
              // If reaction didn't exist, add it
              if prev->Dict.get(reaction)->Option.isNone {
                newDict->Dict.set(reaction, 1)
              }
              newDict
            })
            
            // API call
            let result = await MisskeyJS.Notes.react(c, ~noteId, ~reaction)
            
            switch result {
            | Ok() => {
                // Success
                setIsLoading(_ => false)
              }
            | Error(#APIError(err)) => {
                // Check if it's a permission error
                if MisskeyJS.Common.isPermissionDenied(err) {
                  ToastState.showError("Permission denied: You're in read-only mode")
                } else {
                  ToastState.showError("Failed to add reaction: " ++ err.message)
                }
                // Revert optimistic update
                setOptimisticMyReaction(_ => myReaction)
                setOptimisticReactions(_ => reactions)
                setIsLoading(_ => false)
              }
            | Error(#UnknownError(_)) => {
                ToastState.showError("Failed to add reaction")
                // Revert optimistic update
                setOptimisticMyReaction(_ => myReaction)
                setOptimisticReactions(_ => reactions)
                setIsLoading(_ => false)
              }
            }
          }
        }
      }
    }
  }
  
  // Handle emoji selection from picker
  let handleEmojiSelect = (emoji: string) => {
    let _ = handleReactionClick(emoji)
  }
  
  // Convert reactions dict to array for rendering
  let reactionArray = optimisticReactions
    ->Dict.toArray
    ->Array.toSorted(((_, countA), (_, countB)) => {
      // Sort by count descending
      Float.fromInt(countB) -. Float.fromInt(countA)
    })
  
  // Check if user is logged in and permission mode
  let isLoggedIn = PreactSignals.value(AppState.isLoggedIn)
  let isReadOnly = AppState.isReadOnlyMode()
  
  // Don't render if no reactions and not logged in
  if reactionArray->Array.length == 0 && !isLoggedIn {
    Preact.null
   } else {
     let containerStyle = Style.make(
       ~display="flex",
       ~flexWrap="wrap",
       ~gap="6px",
       ~alignItems="center",
       ~marginTop="8px",
       (),
     )
     
     <div style={containerStyle} role="group" ariaLabel="Reactions">
       {reactionArray->Array.map(((reaction, count)) => {
         let isActive = optimisticMyReaction->Option.getOr("") == reaction
         
         let buttonStyle = Style.make(
           ~display="flex",
           ~alignItems="center",
           ~justifyContent="center",
           ~gap="3px",
           ~border="none",
           ~background=isActive ? "rgba(51, 153, 255, 0.2)" : "rgba(127, 127, 127, 0.1)",
           ~color=isActive ? "#3399ff" : "inherit",
           ~padding="4px 8px",
           ~borderRadius="12px",
           ~cursor=isReadOnly ? "not-allowed" : "pointer",
           ~transition="all 0.2s ease",
           ~fontSize="13px",
           ~fontWeight="500",
           ~userSelect="none",
           ~whiteSpace="nowrap",
           ~overflow="hidden",
           ~textOverflow="ellipsis",
           ~maxWidth="80px",
           ~height="28px",
           ~lineHeight="1",
           ~flex="0 0 auto",
           ~opacity=isReadOnly && isActive ? "0.7" : "1",
           (),
         )
        
        <button
          key={reaction}
          style={buttonStyle}
          onMouseEnter={e => {
            if !isReadOnly {
              let target = JsxEvent.Mouse.currentTarget(e)
              let isActive = HtmlElement.getComputedColor(target) == "rgb(51, 153, 255)" || 
                            HtmlElement.getComputedColor(target) == "#3399ff"
              HtmlElement.setBackground(
                target,
                isActive ? "rgba(51, 153, 255, 0.3)" : "rgba(127, 127, 127, 0.2)"
              )
            }
          }}
          onMouseLeave={e => {
            if !isReadOnly {
              let target = JsxEvent.Mouse.currentTarget(e)
              let isActive = HtmlElement.getComputedColor(target) == "rgb(51, 153, 255)" || 
                            HtmlElement.getComputedColor(target) == "#3399ff"
              HtmlElement.setBackground(
                target,
                isActive ? "rgba(51, 153, 255, 0.2)" : "rgba(127, 127, 127, 0.1)"
              )
            }
          }}
          onClick={_ => {
            if isLoggedIn && !isReadOnly {
              let _ = handleReactionClick(reaction)
            }
          }}
          disabled={isLoading || isReadOnly}
          title={
            if isReadOnly {
              "Read-only mode: Cannot react"
            } else if isActive {
              "Remove your reaction"
            } else {
              "React with " ++ reaction
            }
          }
          ariaLabel={
            if isReadOnly {
              "Read-only mode: Cannot react"
            } else if isActive {
              "Remove your " ++ reaction ++ " reaction"
            } else {
              "React with " ++ reaction
            }
          }
          ariaPressed={isActive ? #"true" : #"false"}
          type_="button"
        >
            <ReactionButton
              reaction={reaction}
              count={count}
              reactionEmojis={reactionEmojis}
            />
         </button>
       })->Preact.array}
      
       {if isLoggedIn && !isReadOnly {
          let addButtonStyle = Style.make(
            ~display="flex",
            ~alignItems="center",
            ~justifyContent="center",
            ~width="28px",
            ~height="28px",
            ~border="none",
            ~background="rgba(127, 127, 127, 0.1)",
            ~borderRadius="12px",
            ~cursor="pointer",
            ~transition="all 0.2s ease",
            ~fontSize="14px",
            ~fontWeight="bold",
            ~userSelect="none",
            ~padding="0",
            ~lineHeight="1",
            (),
          )
         
         <button
           style={addButtonStyle}
           onMouseEnter={e => {
             let target = JsxEvent.Mouse.currentTarget(e)
             HtmlElement.setBackground(target, "rgba(127, 127, 127, 0.2)")
           }}
           onMouseLeave={e => {
             let target = JsxEvent.Mouse.currentTarget(e)
             HtmlElement.setBackground(target, "rgba(127, 127, 127, 0.1)")
           }}
           onClick={_ => setShowEmojiPicker(_ => true)}
           disabled={isLoading}
           title="Add reaction"
           ariaLabel="Add reaction"
           type_="button"
         >
           {Preact.string("+")}
         </button>
      } else {
        Preact.null
      }}
      
      {if showEmojiPicker {
        switch reactionAcceptance {
        | Some(acceptance) =>
          <EmojiPicker
            onSelect={handleEmojiSelect}
            onClose={() => setShowEmojiPicker(_ => false)}
            reactionAcceptance={acceptance}
          />
        | None =>
          <EmojiPicker
            onSelect={handleEmojiSelect}
            onClose={() => setShowEmojiPicker(_ => false)}
          />
        }
      } else {
        Preact.null
      }}
    </div>
  }
}
