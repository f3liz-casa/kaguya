# MFM Renderer for Kaguya

A Preact-based MFM (Misskey Flavored Markdown) renderer integrated into Kaguya.

## Location

`packages/kaguya-app/src/components/mfm/`

## Files

- **`MfmRenderer.res`** - Main renderer component
- **`mfm.css`** - Styles and animations for MFM effects

## Usage

### Basic Usage

```rescript
<MfmRenderer text="Hello **world**! :emoji:" />
```

### Simple Mode (Emoji + Text Only)

```rescript
<MfmRenderer text="Hello :wave:" parseSimple={true} />
```

### In Note Component

The renderer is already integrated into the Note component:

```rescript
<div className="note-text">
  <MfmRenderer text={noteText} />
</div>
```

## Supported MFM Features

### Text Formatting

- **Bold**: `**text**` → **text**
- **Italic**: `*text*` or `_text_` → *text*
- **Strikethrough**: `~~text~~` → ~~text~~
- **Small**: `<small>text</small>` → smaller text

### Code

- **Inline code**: `` `code` ``
- **Code blocks**:
  ```
  ```language
  code
  ```
  ```

### Blocks

- **Quote**: `> text`
- **Center**: `<center>content</center>`

### Links & Mentions

- **URLs**: `https://example.com`
- **Links**: `[label](url)`
- **Mentions**: `@username` or `@username@host.com`
- **Hashtags**: `#tag`

### Emoji

- **Unicode emoji**: 🎉
- **Custom emoji**: `:emoji_name:`

### Effects (MFM Functions)

All effects are rendered with CSS animations:

- **`$[tada text]`** - Bouncing celebration effect
- **`$[jelly text]`** - Jelly wobble effect
- **`$[bounce text]`** - Vertical bounce
- **`$[spin text]`** - Continuous rotation
- **`$[shake text]`** - Shaking effect
- **`$[twitch text]`** - Random twitching
- **`$[rainbow text]`** - Rainbow gradient animation
- **`$[flip text]`** - Horizontal flip
- **`$[x2 text]`** - Double size
- **`$[x3 text]`** - Triple size
- **`$[x4 text]`** - Quad size
- **`$[blur text]`** - Blur effect (clears on hover)
- **`$[rotate text]`** - 90° rotation
- **`$[font text]`** - Font family changes

### Math

- **Inline**: `\(formula\)`
- **Block**: `\[formula\]`

### Search

- `query [Search]` - Renders as a search box

## Customization

### CSS Variables

You can customize colors by setting CSS variables:

```css
:root {
  --link-color: #0066cc;
  --mention-color: #008000;
  --hashtag-color: #1e90ff;
  --mfm-code-bg: #f5f5f5;
  --mfm-code-border: #ddd;
  --mfm-quote-border: #ccc;
  --mfm-quote-color: #666;
  /* ... and more */
}
```

### Dark Mode

Dark mode colors are automatically applied via `prefers-color-scheme: dark`.

### Accessibility

- **Reduced motion**: Animations are disabled for users with `prefers-reduced-motion: reduce`
- **Responsive**: Font sizes adjust on mobile devices
- **Semantic HTML**: Uses proper tags (strong, em, del, blockquote, etc.)

## Implementation Details

### Architecture

```
MfmRenderer Component
  ├── Parse MFM text with rescript-mfm
  ├── Recursively render nodes
  │   ├── Text nodes → string
  │   ├── Formatting → HTML tags
  │   ├── Links → <a> tags
  │   ├── Effects → <span> with CSS classes
  │   └── Blocks → semantic HTML
  └── Return Preact elements
```

### Performance

- **Zero-cost wrapper**: Uses rescript-mfm which wraps mfm-js directly
- **CSS animations**: All effects use GPU-accelerated CSS
- **Lazy rendering**: Only parses and renders visible content

### Security

- **XSS Protection**: All text content is rendered through Preact.string
- **URL sanitization**: External links have `rel="noopener noreferrer"`
- **No dangerouslySetInnerHTML**: All rendering is done through Preact components

## Examples

### Rich Text Note

```rescript
let text = `
Hello **everyone**!

Check out this cool feature:
$[tada 🎉 New Release! 🎉]

Visit our site: https://example.com
Or mention me: @alice@example.com

#announcement #update
`

<MfmRenderer text />
```

### Code Snippet

```rescript
let text = `
Here's some code:

\`\`\`javascript
const hello = () => {
  console.log('Hello, world!');
};
\`\`\`
`

<MfmRenderer text />
```

### Quote and Effects

```rescript
let text = `
> This is a quote
> with multiple lines

And here's a $[rainbow rainbow text] effect!
`

<MfmRenderer text />
```

## Testing

You can test the renderer by creating notes with various MFM syntax:

1. Navigate to the timeline
2. View notes with different MFM formatting
3. Check that effects animate properly
4. Verify links and mentions work

## Future Enhancements

Potential improvements:

- [ ] Custom emoji rendering (fetch from instance)
- [ ] Math rendering with KaTeX
- [ ] Syntax highlighting for code blocks
- [ ] Link previews
- [ ] Media embeds
- [ ] Custom effect parameters
- [ ] Performance optimizations for long notes

## Dependencies

- **rescript-mfm**: MFM parser bindings
- **Preact**: UI framework
- **CSS**: Styling and animations

## License

MPL-2.0 (same as Kaguya)
