import Foundation

/// A self-contained WYSIWYG rich-text editor (contenteditable). No Markdown markup
/// is ever shown — the user formats with the toolbar / keyboard shortcuts and sees
/// the styled result directly.
enum EditorTemplate {
    static var html: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>
        :root {
            --bg:#ffffff; --fg:#1f2328; --muted:#59636e; --border:#d1d9e0;
            --link:#0969da; --bar-bg:#f6f8fa; --btn-hover:#eaeef2; --btn-active:#dde3ea;
        }
        @media (prefers-color-scheme: dark) {
            :root:not([data-theme="light"]) {
                --bg:#0d1117; --fg:#e6edf3; --muted:#8b949e; --border:#30363d;
                --link:#4493f8; --bar-bg:#161b22; --btn-hover:#21262d; --btn-active:#2d333b;
            }
        }
        /* Explicit in-app override (set via data-theme) */
        :root[data-theme="dark"] {
            --bg:#0d1117; --fg:#e6edf3; --muted:#8b949e; --border:#30363d;
            --link:#4493f8; --bar-bg:#161b22; --btn-hover:#21262d; --btn-active:#2d333b;
        }
        * { box-sizing: border-box; }
        html, body { height: 100%; margin: 0; }
        body {
            display: flex; flex-direction: column;
            font-family: -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif;
            color: var(--fg); background: var(--bg);
            -webkit-font-smoothing: antialiased;
        }
        #toolbar {
            display: flex; flex-wrap: wrap; gap: 2px; align-items: center;
            padding: 8px 14px; background: var(--bar-bg);
            border-bottom: 1px solid var(--border);
            position: sticky; top: 0; z-index: 10;
        }
        #toolbar button, #toolbar select {
            font-size: 14px; color: var(--fg); background: transparent;
            border: none; border-radius: 6px; padding: 6px 9px; cursor: pointer;
            min-width: 32px; height: 30px; line-height: 1;
        }
        #toolbar button:hover { background: var(--btn-hover); }
        #toolbar button:active { background: var(--btn-active); }
        #toolbar .sep { width: 1px; height: 20px; background: var(--border); margin: 0 6px; }
        #toolbar select { padding: 4px 6px; border: 1px solid var(--border); }
        #toolbar input[type=color] {
            width: 30px; height: 28px; padding: 0; border: none;
            background: transparent; cursor: pointer; border-radius: 6px;
        }
        #editor {
            flex: 1; overflow-y: auto; outline: none;
            padding: 40px 56px 120px; max-width: 860px; width: 100%;
            margin: 0 auto; font-size: 16px; line-height: 1.65;
        }
        #editor:empty:before {
            content: attr(data-placeholder); color: var(--muted);
        }
        #editor h1 { font-size: 2em; font-weight: 650; margin: .67em 0 .4em; }
        #editor h2 { font-size: 1.5em; font-weight: 650; margin: .7em 0 .4em; }
        #editor h3 { font-size: 1.25em; font-weight: 650; margin: .8em 0 .4em; }
        #editor p { margin: 0 0 1em; }
        #editor a { color: var(--link); }
        #editor blockquote {
            margin: 0 0 1em; padding: .2em 1em;
            border-left: .25em solid var(--border); color: var(--muted);
        }
        #editor ul, #editor ol { padding-left: 2em; margin: 0 0 1em; }
        #editor code, #editor pre {
            font-family: "SF Mono", Menlo, monospace;
            background: var(--bar-bg); border-radius: 6px;
        }
        #editor code { padding: .15em .4em; font-size: .9em; }
        #editor pre { padding: 14px 16px; overflow-x: auto; }
        #editor img { max-width: 100%; border-radius: 8px; }
        </style>
        </head>
        <body>
        <div id="toolbar">
            <select id="block" title="Paragraph style" onchange="block(this.value)">
                <option value="P">Normal text</option>
                <option value="H1">Heading 1</option>
                <option value="H2">Heading 2</option>
                <option value="H3">Heading 3</option>
                <option value="BLOCKQUOTE">Quote</option>
                <option value="PRE">Code block</option>
            </select>
            <span class="sep"></span>
            <button title="Bold (⌘B)" onclick="cmd('bold')"><b>B</b></button>
            <button title="Italic (⌘I)" onclick="cmd('italic')"><i>I</i></button>
            <button title="Underline (⌘U)" onclick="cmd('underline')"><u>U</u></button>
            <button title="Strikethrough" onclick="cmd('strikeThrough')"><s>S</s></button>
            <span class="sep"></span>
            <input type="color" id="fg" title="Text color" value="#1f6feb"
                   oninput="cmd('foreColor', this.value)">
            <button title="Highlight" onclick="cmd('hiliteColor','#fff3a3')">🖍️</button>
            <span class="sep"></span>
            <button title="Bulleted list" onclick="cmd('insertUnorderedList')">•&nbsp;—</button>
            <button title="Numbered list" onclick="cmd('insertOrderedList')">1.&nbsp;—</button>
            <button title="Outdent" onclick="cmd('outdent')">⇤</button>
            <button title="Indent" onclick="cmd('indent')">⇥</button>
            <span class="sep"></span>
            <button title="Align left" onclick="cmd('justifyLeft')">⬅</button>
            <button title="Align center" onclick="cmd('justifyCenter')">⬌</button>
            <button title="Align right" onclick="cmd('justifyRight')">➡</button>
            <span class="sep"></span>
            <button title="Insert link" onclick="addLink()">🔗</button>
            <button title="Horizontal rule" onclick="cmd('insertHorizontalRule')">―</button>
            <button title="Clear formatting" onclick="cmd('removeFormat')">⌫</button>
        </div>
        <div id="editor" contenteditable="true" spellcheck="true"
             data-placeholder="Start writing…"><h1>Untitled</h1><p><br></p></div>
        <script>
        const ed = document.getElementById('editor');
        document.execCommand('styleWithCSS', false, true);
        function cmd(c, v) { ed.focus(); document.execCommand(c, false, v || null); }
        function block(tag) { ed.focus(); document.execCommand('formatBlock', false, tag); }
        function addLink() {
            const url = prompt('Link URL:', 'https://');
            if (url) cmd('createLink', url);
        }
        // Keep the block-style dropdown in sync with the caret position.
        document.addEventListener('selectionchange', function () {
            let node = document.getSelection().anchorNode;
            while (node && node !== ed) {
                if (node.nodeType === 1) {
                    const t = node.tagName;
                    if (['H1','H2','H3','BLOCKQUOTE','PRE','P'].includes(t)) {
                        document.getElementById('block').value = t; return;
                    }
                }
                node = node.parentNode;
            }
        });
        ed.focus();

        // Serialize the editor's rich content back to Markdown. Exposed for the
        // native app to call via evaluateJavaScript when saving as .md.
        function toMarkdown() {
            function inline(node) {
                let out = "";
                node.childNodes.forEach(function (n) {
                    if (n.nodeType === 3) { out += n.textContent; return; }
                    if (n.nodeType !== 1) return;
                    const tag = n.tagName.toLowerCase();
                    const inner = inline(n);
                    switch (tag) {
                        case "b": case "strong": out += "**" + inner + "**"; break;
                        case "i": case "em": out += "*" + inner + "*"; break;
                        case "u": out += inner; break; // no MD underline
                        case "s": case "strike": case "del": out += "~~" + inner + "~~"; break;
                        case "code": out += "`" + inner + "`"; break;
                        case "a": out += "[" + inner + "](" + (n.getAttribute("href")||"") + ")"; break;
                        case "br": out += "  \\n"; break;
                        default: out += inner;
                    }
                });
                return out;
            }
            function listItems(list, ordered, depth) {
                let out = ""; let i = 1;
                list.childNodes.forEach(function (li) {
                    if (li.nodeType !== 1 || li.tagName.toLowerCase() !== "li") return;
                    const pad = "  ".repeat(depth);
                    const marker = ordered ? (i++ + ". ") : "- ";
                    // separate nested lists from inline content
                    let sub = "";
                    const clone = li.cloneNode(true);
                    clone.querySelectorAll("ul,ol").forEach(function (n) {
                        sub += listItems(n, n.tagName.toLowerCase() === "ol", depth + 1);
                        n.remove();
                    });
                    out += pad + marker + inline(clone).trim() + "\\n" + sub;
                });
                return out;
            }
            let md = "";
            ed.childNodes.forEach(function (n) {
                if (n.nodeType === 3) { const t = n.textContent.trim(); if (t) md += t + "\\n\\n"; return; }
                if (n.nodeType !== 1) return;
                const tag = n.tagName.toLowerCase();
                switch (tag) {
                    case "h1": md += "# " + inline(n).trim() + "\\n\\n"; break;
                    case "h2": md += "## " + inline(n).trim() + "\\n\\n"; break;
                    case "h3": md += "### " + inline(n).trim() + "\\n\\n"; break;
                    case "h4": md += "#### " + inline(n).trim() + "\\n\\n"; break;
                    case "blockquote": md += "> " + inline(n).trim().replace(/\\n/g, "\\n> ") + "\\n\\n"; break;
                    case "pre": md += "```\\n" + n.textContent.replace(/\\n$/, "") + "\\n```\\n\\n"; break;
                    case "ul": md += listItems(n, false, 0) + "\\n"; break;
                    case "ol": md += listItems(n, true, 0) + "\\n"; break;
                    case "hr": md += "---\\n\\n"; break;
                    default: { const t = inline(n).trim(); if (t) md += t + "\\n\\n"; }
                }
            });
            return md.replace(/\\n{3,}/g, "\\n\\n").trim() + "\\n";
        }
        </script>
        </body>
        </html>
        """
    }
}
