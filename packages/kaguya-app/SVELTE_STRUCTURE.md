# kaguya-app Svelte 5 構造ドキュメント

mount swap 完結時点（`1ce47d8`）の svelte tree 構造。ミオの「構造組み直し」検討用の叩き台。

## Top-level dir

| dir | 役割 |
|---|---|
| `pages/` | ルート単位の page component（15 種類） |
| `ui/` | UI primitive + router + signal bridge + content renderer pipeline + a11y helper |
| `domain/` | business logic 層（auth / account / emoji / note / timeline / notification / user / file） |
| `infra/` | 横断 utility（i18n / storage / fetch queue / media proxy / time format / URL utility） |
| `lib/` | backend SDK ラッパー（misskey / bluesky / mastodon / backend abstraction） |
| `types/` | global 型定義 |
| `bindings/` | 外部 lib 用の型 binding |

## エントリポイント連鎖

```
main.ts  →  mount(App, { target: root })
            ↓
         App.svelte
            ↓ (currentPath signal を svelteSignal で consume)
         {#if currentPath ...} branches
            ↓
         各 page.svelte  →  Layout.svelte でラップ
```

`App.svelte` は authState routing（LoggedOut/LoginFailed → LoginPage、LoggedIn → 通常）と callback path 強制 routing（`/miauth-callback` / `/oauth-callback*`）を持つ。

## Routing

- `ui/svelteRouter.ts` — `currentPath` signal（`@preact/signals-core` の ReadonlySignal）+ `navigate(path, replace?)` + popstate listener、SSR safe (`window` guard)
- `ui/Link.svelte` — `<a>` + onclick → `navigate(href)`、modified-key / middle-click / right-click は native fall through
- `App.svelte` 内の `{#if r.value === '/'}` / `{#if r.value.startsWith('/notes/')}` の分岐方式。`<Router>` component は置かず、template 側で explicit に分岐

## Signal bridge

`ui/svelteSignal.svelte.ts` の API：

```ts
function svelteSignal<T>(source: ReadonlySignal<T>): { readonly value: T }
```

`$state` で local snapshot を持って `$effect` で source signal の effect 購読、`get value()` で常に最新を返す。

例：
```ts
const authStateR = svelteSignal(authState)
const userName = $derived(authStateR.value.type === 'LoggedIn' ? authStateR.value.account.username : null)
```

`@preact/signals-core` は framework-agnostic で、domain 層は preact 時代から同じ signal を持ち続けてる。Svelte 側はこの bridge 1 つで読む。

## ui/ component 分類

### Layout / Container
- `Layout.svelte` — sidebar nav + header + main content + compose modal（focusTrap + ESC + scroll lock）
- `LoadingBar.svelte` — page transition indicator
- `Toast.svelte` — toast overlay（severity 別 icon + close button、aria-live polite）

### Interactive Primitive
- `Link.svelte` — SPA navigation 統合
- `ReactionBar.svelte` / `ReactionButton.svelte` — emoji reaction UI（optimistic + race guard）
- `PostForm.svelte` + `Composer` class（`postFormFactory.svelte.ts`）— note composition、attachment 4 個 cap + paste/picker 両 path
- `EmojiPicker.svelte` — emoji selector dropdown
- `PushNotificationToggle.svelte` — permission + subscription control
- `AccountSwitcher.svelte` — account switch popup
- `ImageAttachment.svelte` / `ImageGallery.svelte` / `ImageLightbox.svelte` — image display + sensitive flag + zoom modal

### Content Renderer Pipeline (`ui/content/`)
- `emojiHelpers.ts` — toTwemojiUrl / hasJapanese / hasKorean（TS only、framework-agnostic）
- `EmojiImg.svelte` — observeImage + $effect cleanup で lazy load
- `EmojiCode.svelte` — getEmoji → EmojiImg or `:name:` span fallback
- `SocialInline.svelte` — 15 inline variants（self-import で children 再帰）
- `SocialBlock.svelte` — 6 block variants（blockquote 再帰）
- `SocialRenderer.svelte` — top-level `{#each}`、SocialNode[] を render
- `ContentRenderer.svelte` — `{ text, contentType?, parseSimple?, contextHost?, facets? }` full surface、parseSimple subset と full の両方を host

### a11y / patterns
- `focusTrap.ts` — `Action<HTMLElement>`、modal 内 Tab cycle + 初期 textarea focus + prev focus restore

## domain/ sub-package

| sub-package | 主要 export |
|---|---|
| `auth/` | `appState.ts`（authState / client / accessToken / instanceOrigin signal）+ `authService.ts`（restore / login）+ `authTypes.ts`（discriminated union: LoggedOut / LoggingIn / LoggedIn / LoginFailed、LoginError に SessionExpired variant 含む）+ `miAuthFlow.ts` / `oauth2Flow.ts` |
| `account/` | `account.ts`（Account 型）+ `AccountSwitcher.svelte` |
| `emoji/` | `emojiStore.ts`（emojis map + loadState signal）+ `emojiOps.ts`（extract / normalize）+ EmojiPicker.svelte |
| `note/` | `noteDecoder.ts`（JSON → NoteView）+ `Note.svelte`（discriminated decode/raw mode）+ NoteCard / NoteHeader / NoteContent / NoteActions / NotePoll |
| `timeline/` | `timelineStore.ts`（streaming + filter cache + last-seen divider）+ Timeline.svelte（HomePageTimeline 含む、`<script module>` で TimelineItem / TimelineSelector export）|
| `notification/` | `notificationStore.ts` + `pushNotificationStore.ts`（subscription state） |
| `user/` | `userProfileView.ts` decoder + filter store |

各 sub-package は `@preact/signals-core` の signal + decoder + domain-specific svelte component を export。

## infra/ 層

| file | 責務 |
|---|---|
| `i18n.ts` + `locales/{ja,en}.ts` | `currentLocale` signal + `t(key)` 関数、`Record<keyof typeof ja, string>` で en に parity 強制 |
| `storage.ts` | localStorage wrapper（accounts / auth / preferences） |
| `fetchQueue.ts` | QoS-aware fetch queue（priority + dedup） |
| `mediaProxy.ts` | avatar / image URL proxy rewrite |
| `timeFormat.ts` | relative time formatting |
| `urlUtils.ts` | URL parse / hostname extract / query build |
| `jsonUtils.ts` | safe JSON walk（`asObj` / `getString` / `getArray`） |
| `notePrefetch.ts` | startup 時の emoji / note prefetch |
| `sharedTypes.ts` | shared enum / constant |

## 依存関係グラフ（ざっくり）

```
pages → Layout + domain/* + ui/
domain/note → domain/{emoji,user,file} + infra/
domain/timeline → domain/note + ui/
domain/auth → infra/storage + domain/account
domain/emoji → infra/fetchQueue
ui/content/* → ui/{svelteSignal, content/} + domain/emoji + infra/
ui/svelteRouter → (standalone)
ui/svelteSignal → (standalone bridge)
```

## 観察（構造組み直し検討の叩き台）

実装は機能してる前提で、構造的に気になる点：

1. **domain 内の direct cross-coupling**：Timeline / NoteCard が `instanceName`（auth 由来）+ `currentLocale`（i18n 由来）の signal を直接読む。global signal で動作するが、後に i18n module split や instance per-window が出てくると refactor 難。
2. **content renderer の parser と i18n の層境界**：`fromMfm` 内部に regex match があり、多言語対応で parser と i18n の境界が曖昧化する余地。
3. **signal bridge の thin さ**：`svelteSignal` は snapshot utility 止まり、computed / batch 操作が UI 側に露出してない。domain 側で `computed` chain がある場合の cache miss 余地。
4. **`<script module>` 経由 export の混在**：Timeline.svelte が `<script module>` で TimelineItem / TimelineSelector / itemKey 等を export してる。Svelte 5 の慣用句だが、純 .ts util ファイル化と混ぜる線引きが暗黙。
5. **ui/ と domain/ の責務 fuzziness**：`AccountSwitcher.svelte` は `domain/account/` 配下、`PostForm.svelte` は `ui/` 配下。両方 domain-aware だが配置が分散。
6. **focusTrap の selector が hardcode**：modal pattern 複数で再利用するなら option 化（or focus-visible 等の組み込み属性に置き換え）の余地。

## 移行 chain（参考）

```
fix/kaguya-bugs (4 commit、main にすでに merge 済)
  - 52b48d8 compose modal a11y + attachment cleanup
  - 79378ed MiAuth callback exception + sw cache scope
  - e41807a SessionExpired variant
  - 52ed16e i18n ja/en key parity (PR-0)

feat/svelte (28 commit、PR #2 で main 取り込み待ち)
  - M1 (7): svelte build pipeline alongside Preact / router / bridge / Toast / LoadingBar / Layout / focusTrap
  - M2 (15): 12 pages + Note chain + Timeline + ContentRenderer full
  - M5 (1): mount swap + Preact deps drop
```

`@preact/signals-core` のみ retain（framework-agnostic な signal layer）、他 Preact 系 deps は全 drop。

---

このドキュメントは「現状」の写し、改善提案ではない。ミオが「構造組み直し」を検討するときの土台として観察 1-6 を pin。
