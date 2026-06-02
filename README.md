# MDMagic ✨

A **lightweight**, native macOS Markdown viewer that renders `.md` files in rich color and text — no Electron, no network, no third-party dependencies. Just Swift + the built-in WebKit.

## Features

- **GitHub-flavored Markdown** — headings, **bold**/*italic*/~~strikethrough~~, inline & fenced code, links, images, blockquotes, tables (with alignment), ordered/unordered/task lists, horizontal rules
- **Syntax-highlighted code blocks** — keywords, strings, numbers, comments, function names
- **Automatic light / dark mode** — follows the system appearance
- **Drag & drop** a `.md` file onto the window, press **⌘O** to open, or double-click `.md` files in Finder
- **Export to PDF** — **⌘E** (or the toolbar share button); always exports with light styling for clean printing
- **Zoom** — **⌘+** / **⌘-** to zoom in/out, **⌘0** for actual size
- **⌘R** reloads the current file
- Single ~187 KB native executable

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
├── App.swift                 # SwiftUI window, toolbar, drag-drop, ⌘O/⌘R
├── MarkdownRenderer.swift    # pure-Swift GFM → HTML converter
└── HTMLTemplate.swift        # rich CSS theme + JS syntax highlighter
```

## Notes

- The bundled `.app` is **ad-hoc signed** for local use. Running it on another Mac requires proper signing/notarization.
- No custom app icon yet (uses the generic icon).
