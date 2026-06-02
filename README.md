# MDMagic ✨

A **lightweight**, native macOS Markdown viewer **and rich-text editor** that renders content in rich color and text — no Electron, no network, no third-party dependencies. Just Swift + the built-in WebKit.

## Features

- **Tabbed interface** with a top nav bar (**New**, **Open**, **Save As**, **Export PDF**, dark-mode toggle)
- **WYSIWYG rich-text editor** — click **＋ New** (⌘N) for a new tab with a formatting toolbar (headings, bold/italic/underline/strike, text color, highlight, lists, indent, alignment, links). No Markdown markup — you see styled text directly.
- **GitHub-flavored Markdown viewer** — headings, **bold**/*italic*/~~strikethrough~~, inline & fenced code, links, images, blockquotes, tables (with alignment), ordered/unordered/task lists, horizontal rules
- **Syntax-highlighted code blocks** — keywords, strings, numbers, comments, function names
- **Light / dark mode** — follows the system, or toggle in-app with **⇧⌘D**
- **Drag & drop** a `.md` file onto a viewer tab, press **⌘O** to open, or double-click `.md` files in Finder
- **Save As** — **⌘S** saves the current tab as an HTML document (rich-text editor content is preserved)
- **Export to PDF** — **⌘E**; always exports with light styling for clean printing
- **Zoom** — **⌘+** / **⌘-** to zoom in/out, **⌘0** for actual size
- **⌘R** reloads the current file

## Build & Run

Requires the Swift toolchain (Xcode or Command Line Tools).

```sh
./make_app.sh          # builds and bundles MDMagic.app
open MDMagic.app       # launch it
```

Or run directly via SwiftPM:

```sh
swift run -c release
```

## Project layout

```
Package.swift                 # SwiftPM, zero external dependencies
make_app.sh                   # builds + bundles into MDMagic.app
Sources/MDMagic/
├── App.swift                 # SwiftUI app: tabs, top nav bar, save/export/zoom/theme
├── MarkdownRenderer.swift    # pure-Swift GFM → HTML converter
├── HTMLTemplate.swift        # rich CSS theme + JS syntax highlighter (viewer)
└── EditorTemplate.swift      # WYSIWYG contenteditable rich-text editor
```

## Notes

- The bundled `.app` is **ad-hoc signed** for local use. Running it on another Mac requires proper signing/notarization.
- No custom app icon yet (uses the generic icon).
