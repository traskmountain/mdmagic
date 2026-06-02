import Foundation

extension MarkdownRenderer {
    /// Wraps rendered body HTML in a full document with rich, theme-aware styling.
    static func wrap(body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>
        :root {
            --bg: #ffffff; --fg: #1f2328; --muted: #59636e;
            --border: #d1d9e0; --link: #0969da;
            --code-bg: #f6f8fa; --code-fg: #1f2328;
            --quote-border: #d0d7de; --quote-fg: #59636e;
            --th-bg: #f6f8fa; --hr: #d1d9e0;
            --kw:#cf222e; --str:#0a3069; --num:#0550ae; --com:#59636e; --fn:#8250df;
        }
        @media (prefers-color-scheme: dark) {
            :root:not([data-theme="light"]) {
                --bg: #0d1117; --fg: #e6edf3; --muted: #8b949e;
                --border: #30363d; --link: #4493f8;
                --code-bg: #161b22; --code-fg: #e6edf3;
                --quote-border: #3d444d; --quote-fg: #9198a1;
                --th-bg: #161b22; --hr: #30363d;
                --kw:#ff7b72; --str:#a5d6ff; --num:#79c0ff; --com:#8b949e; --fn:#d2a8ff;
            }
        }
        /* Explicit in-app override (set via data-theme) */
        :root[data-theme="dark"] {
            --bg: #0d1117; --fg: #e6edf3; --muted: #8b949e;
            --border: #30363d; --link: #4493f8;
            --code-bg: #161b22; --code-fg: #e6edf3;
            --quote-border: #3d444d; --quote-fg: #9198a1;
            --th-bg: #161b22; --hr: #30363d;
            --kw:#ff7b72; --str:#a5d6ff; --num:#79c0ff; --com:#8b949e; --fn:#d2a8ff;
        }
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif;
            font-size: 16px; line-height: 1.65;
            color: var(--fg); background: var(--bg);
            margin: 0; padding: 44px 56px 120px;
            max-width: 900px; margin-left: auto; margin-right: auto;
            -webkit-font-smoothing: antialiased;
        }
        h1,h2,h3,h4,h5,h6 { font-weight: 650; line-height: 1.3; margin: 1.6em 0 0.6em; }
        h1 { font-size: 2em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
        h3 { font-size: 1.25em; } h4 { font-size: 1em; }
        h5 { font-size: .9em; } h6 { font-size: .85em; color: var(--muted); }
        p { margin: 0 0 1em; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { font-weight: 650; }
        del { color: var(--muted); }
        hr { border: none; border-top: 1px solid var(--hr); margin: 2em 0; }
        blockquote {
            margin: 0 0 1em; padding: .2em 1em;
            border-left: .25em solid var(--quote-border); color: var(--quote-fg);
        }
        blockquote p:last-child { margin-bottom: 0; }
        ul, ol { margin: 0 0 1em; padding-left: 2em; }
        li { margin: .25em 0; }
        li.task-item { list-style: none; margin-left: -1.4em; }
        li.task-item input { margin-right: .5em; }
        code {
            font-family: "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
            font-size: .88em; background: var(--code-bg);
            padding: .2em .4em; border-radius: 6px;
        }
        .code-wrap { position: relative; margin: 0 0 1em; }
        .code-lang {
            position: absolute; top: 0; right: 0;
            font-family: "SF Mono", Menlo, monospace; font-size: .7em;
            color: var(--muted); padding: 6px 12px; text-transform: uppercase;
            letter-spacing: .05em;
        }
        pre {
            background: var(--code-bg); border: 1px solid var(--border);
            border-radius: 10px; padding: 16px; overflow-x: auto; margin: 0;
        }
        pre code { background: none; padding: 0; font-size: .85em; line-height: 1.5;
                   color: var(--code-fg); }
        table {
            border-collapse: collapse; margin: 0 0 1em; width: 100%;
            display: block; overflow-x: auto;
        }
        th, td { border: 1px solid var(--border); padding: 7px 13px; }
        th { background: var(--th-bg); font-weight: 650; }
        tr:nth-child(even) td { background: var(--code-bg); }
        img { max-width: 100%; border-radius: 8px; }
        /* lightweight syntax highlight (applied via JS) */
        .tok-kw { color: var(--kw); } .tok-str { color: var(--str); }
        .tok-num { color: var(--num); } .tok-com { color: var(--com); font-style: italic; }
        .tok-fn { color: var(--fn); }
        /* inline editing toolbar */
        #edit-toolbar {
            display: none; position: sticky; top: 0; z-index: 100;
            background: var(--bar-bg, #f6f8fa); border-bottom: 1px solid var(--border);
            padding: 6px 10px; flex-wrap: wrap; gap: 2px; align-items: center;
            margin: -44px -56px 32px; /* bleed to page edges */
        }
        @media (prefers-color-scheme: dark) {
            :root:not([data-theme="light"]) { --bar-bg: #161b22; }
        }
        :root[data-theme="dark"] { --bar-bg: #161b22; }
        :root[data-theme="light"] { --bar-bg: #f6f8fa; }
        #edit-toolbar button, #edit-toolbar select {
            font-size: 13px; color: var(--fg); background: transparent;
            border: none; border-radius: 6px; padding: 5px 8px; cursor: pointer;
            min-width: 28px; height: 28px; line-height: 1;
        }
        #edit-toolbar button:hover { background: var(--border); }
        #edit-toolbar .sep { width: 1px; height: 18px; background: var(--border); margin: 0 4px; }
        #edit-toolbar .btn-save {
            background: #0969da; color: #fff; font-weight: 600; padding: 5px 12px; border-radius: 6px;
        }
        #edit-toolbar .btn-save:hover { background: #0550ae; }
        #edit-toolbar .btn-cancel { color: var(--muted); }
        #article { outline: none; }
        body.editing #article { cursor: text; padding-top: 12px; }
        body.editing #article > *:hover { outline: 1px dashed var(--link); outline-offset: 3px; border-radius: 3px; }
        body.editing #article > *:focus { outline: 2px solid var(--link); outline-offset: 3px; border-radius: 3px; }
        </style>
        </head>
        <body>
        <div id="edit-toolbar">
            <select title="Block style" onchange="applyBlock(this.value); this.blur();">
                <option value="p">Normal</option>
                <option value="h1">H1</option>
                <option value="h2">H2</option>
                <option value="h3">H3</option>
                <option value="blockquote">Quote</option>
            </select>
            <span class="sep"></span>
            <button title="Bold (⌘B)" onclick="fmt('bold')"><b>B</b></button>
            <button title="Italic (⌘I)" onclick="fmt('italic')"><i>I</i></button>
            <button title="Inline code" onclick="wrapCode()"><code style="font-size:11px">&lt;/&gt;</code></button>
            <span class="sep"></span>
            <button title="Bulleted list" onclick="fmt('insertUnorderedList')">• —</button>
            <button title="Numbered list" onclick="fmt('insertOrderedList')">1. —</button>
            <button title="Outdent" onclick="fmt('outdent')">⇤</button>
            <button title="Indent" onclick="fmt('indent')">⇥</button>
            <span class="sep"></span>
            <button title="Insert link" onclick="addLink()" id="btn-link">🔗 Link</button>
            <span id="link-row" style="display:none;align-items:center;gap:4px;">
                <input id="link-url" type="url" placeholder="https://" autocomplete="off" spellcheck="false"
                       style="font-size:13px;height:26px;padding:0 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--fg);width:180px;"
                       onkeydown="if(event.key==='Enter'){event.preventDefault();confirmLink();}else if(event.key==='Escape'){cancelLink();}">
                <button onclick="confirmLink()" title="Apply link" style="padding:4px 8px;">→</button>
                <button onclick="cancelLink()" title="Cancel" style="padding:4px 8px;">✕</button>
            </span>
            <span class="sep"></span>
            <button class="btn-save" onclick="saveEdit()">💾 Save</button>
            <button class="btn-cancel" onclick="cancelEdit()">✕ Cancel</button>
        </div>
        <div id="article">
        \(body)
        </div>
        <script>
        // ── Inline editing ──────────────────────────────────────────────────
        var _snapshot = null;
        function enableEditing() {
            var art = document.getElementById('article');
            _snapshot = art.innerHTML;
            document.getElementById('edit-toolbar').style.display = 'flex';
            document.body.classList.add('editing');
            art.setAttribute('contenteditable', 'true');
            art.setAttribute('spellcheck', 'true');
            document.execCommand('styleWithCSS', false, true);
            art.focus();
        }
        function disableEditing() {
            var art = document.getElementById('article');
            document.getElementById('edit-toolbar').style.display = 'none';
            document.body.classList.remove('editing');
            art.removeAttribute('contenteditable');
            art.removeAttribute('spellcheck');
        }
        function cancelEdit() {
            var art = document.getElementById('article');
            if (_snapshot !== null) art.innerHTML = _snapshot;
            disableEditing();
            if (window.webkit) window.webkit.messageHandlers.mdmagic.postMessage({action:'cancel'});
        }
        function saveEdit() {
            var md = articleToMarkdown();
            disableEditing();
            if (window.webkit) window.webkit.messageHandlers.mdmagic.postMessage({action:'save', content: md});
        }
        function getMarkdown() { return articleToMarkdown(); }
        function fmt(cmd, val) { document.execCommand(cmd, false, val || null); }
        function applyBlock(tag) { document.execCommand('formatBlock', false, tag); }
        function wrapCode() {
            var sel = window.getSelection();
            if (!sel.rangeCount) return;
            var r = sel.getRangeAt(0), code = document.createElement('code');
            r.surroundContents(code);
        }
        var _savedRange = null;
        function addLink() {
            var sel = window.getSelection();
            _savedRange = (sel && sel.rangeCount) ? sel.getRangeAt(0).cloneRange() : null;
            document.getElementById('btn-link').style.display = 'none';
            var row = document.getElementById('link-row');
            row.style.display = 'inline-flex';
            var input = document.getElementById('link-url');
            input.value = '';
            input.focus();
        }
        function confirmLink() {
            var url = document.getElementById('link-url').value.trim();
            if (url) {
                if (_savedRange) {
                    var sel = window.getSelection();
                    sel.removeAllRanges();
                    sel.addRange(_savedRange);
                }
                document.execCommand('createLink', false, url);
            }
            cancelLink();
        }
        function cancelLink() {
            document.getElementById('link-row').style.display = 'none';
            document.getElementById('btn-link').style.display = '';
            document.getElementById('link-url').value = '';
            _savedRange = null;
            document.getElementById('article').focus();
        }

        // ── Markdown serialiser (rendered HTML → Markdown) ──────────────────
        function articleToMarkdown() {
            var art = document.getElementById('article');
            var out = [];
            function collect(node) {
                node.childNodes.forEach(function(n) {
                    if (n.nodeType === 3) {
                        var t = n.textContent.trim();
                        if (t) out.push(t);
                        return;
                    }
                    if (n.nodeType !== 1) return;
                    var md = nodeToMd(n);
                    if (md !== null) out.push(md);
                });
            }
            collect(art);
            return out.join('\\n\\n').trim() + '\\n';
        }
        function inlineToMd(node) {
            var out = '';
            node.childNodes.forEach(function(n) {
                if (n.nodeType === 3) { out += n.textContent; return; }
                if (n.nodeType !== 1) return;
                var tag = n.tagName.toLowerCase();
                var inner = inlineToMd(n);
                if (tag === 'span') { out += n.textContent; return; }
                switch (tag) {
                    case 'strong': case 'b': out += '**' + inner + '**'; break;
                    case 'em': case 'i': out += '*' + inner + '*'; break;
                    case 'del': case 's': out += '~~' + inner + '~~'; break;
                    case 'code': out += '`' + n.textContent + '`'; break;
                    case 'a': out += '[' + inner + '](' + (n.getAttribute('href') || '') + ')'; break;
                    case 'br': out += '  \\n'; break;
                    case 'img': out += '![' + (n.getAttribute('alt') || '') + '](' + (n.getAttribute('src') || '') + ')'; break;
                    case 'input': break;
                    // block wrappers contenteditable inserts
                    case 'div': case 'p':
                        if (out && !out.endsWith('\\n')) out += '\\n';
                        out += inner;
                        break;
                    // list inside inline context (shouldn't happen, but be defensive)
                    case 'ul': case 'ol': {
                        var ord = tag === 'ol'; var li_i = 1;
                        n.querySelectorAll('li').forEach(function(li) {
                            var m = ord ? (li_i++ + '. ') : '- ';
                            if (out && !out.endsWith('\\n')) out += '\\n';
                            out += m + inlineToMd(li).trim();
                        });
                        break;
                    }
                    default: out += inner;
                }
            });
            return out;
        }
        function listToMd(list, ordered, depth) {
            var out = ''; var idx = 1;
            var pad = '  '.repeat(depth);
            list.childNodes.forEach(function(li) {
                if (li.nodeType !== 1 || li.tagName.toLowerCase() !== 'li') return;
                var marker = ordered ? (idx++ + '. ') : '- ';
                var clone = li.cloneNode(true);
                var nested = '';
                clone.querySelectorAll('ul,ol').forEach(function(sub) {
                    nested += '\\n' + listToMd(sub, sub.tagName.toLowerCase() === 'ol', depth + 1);
                    sub.remove();
                });
                var cb = clone.querySelector('input[type=checkbox]');
                var task = '';
                if (cb) { task = cb.checked ? '[x] ' : '[ ] '; cb.remove(); }
                out += pad + marker + task + inlineToMd(clone).trim() + nested + '\\n';
            });
            return out.trimEnd();
        }
        function tableToMd(table) {
            var rows = [];
            table.querySelectorAll('tr').forEach(function(tr) {
                var cells = [];
                tr.querySelectorAll('th,td').forEach(function(c) { cells.push(inlineToMd(c).trim()); });
                rows.push(cells);
            });
            if (!rows.length) return '';
            var hdr = '| ' + rows[0].join(' | ') + ' |';
            var sep = '| ' + rows[0].map(function() { return '---'; }).join(' | ') + ' |';
            var body = rows.slice(1).map(function(r) { return '| ' + r.join(' | ') + ' |'; }).join('\\n');
            return hdr + '\\n' + sep + (body ? '\\n' + body : '');
        }
        function nodeToMd(n) {
            var tag = n.tagName ? n.tagName.toLowerCase() : '';
            switch (tag) {
                case 'h1': return '# ' + inlineToMd(n).trim();
                case 'h2': return '## ' + inlineToMd(n).trim();
                case 'h3': return '### ' + inlineToMd(n).trim();
                case 'h4': return '#### ' + inlineToMd(n).trim();
                case 'h5': return '##### ' + inlineToMd(n).trim();
                case 'h6': return '###### ' + inlineToMd(n).trim();
                case 'p': { var t = inlineToMd(n).trim(); return t || null; }
                case 'hr': return '---';
                case 'blockquote': {
                    var bqParts = [];
                    n.childNodes.forEach(function(c) {
                        if (c.nodeType === 3) { var t = c.textContent.trim(); if (t) bqParts.push(t); return; }
                        if (c.nodeType !== 1) return;
                        var m = nodeToMd(c); if (m) bqParts.push(m);
                    });
                    return bqParts.join('\\n\\n').split('\\n').map(function(l) { return '> ' + l; }).join('\\n');
                }
                case 'ul': return listToMd(n, false, 0);
                case 'ol': return listToMd(n, true, 0);
                case 'div': {
                    if (n.classList.contains('code-wrap')) {
                        var code = n.querySelector('code');
                        var lang = '';
                        if (code) code.classList.forEach(function(c) { if (c.startsWith('language-')) lang = c.slice(9); });
                        return '```' + lang + '\\n' + (code ? code.textContent : n.textContent).replace(/\\n$/, '') + '\\n```';
                    }
                    // Generic wrapper div (WebKit creates these during editing) — recurse
                    var divParts = [];
                    n.childNodes.forEach(function(c) {
                        if (c.nodeType === 3) { var t = c.textContent.trim(); if (t) divParts.push(t); return; }
                        if (c.nodeType !== 1) return;
                        var m = nodeToMd(c); if (m !== null) divParts.push(m);
                    });
                    return divParts.length ? divParts.join('\\n\\n') : null;
                }
                case 'table': return tableToMd(n);
                default: { var txt = inlineToMd(n).trim(); return txt || null; }
            }
        }
        // ── Syntax highlighting ─────────────────────────────────────────────
        (function () {
          const KW = new Set(("func var let const function return if else for while do switch case break " +
            "continue class struct enum protocol extension import from def lambda public private static " +
            "void int float double bool string true false null nil None True False self this new try catch " +
            "throw throws async await guard in is as where typeof instanceof export default print").split(" "));
          document.querySelectorAll("pre code").forEach(function (block) {
            const text = block.textContent;
            let out = "", i = 0;
            function esc(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}
            while (i < text.length) {
              const c = text[i];
              // comments
              if (c === "/" && text[i+1] === "/") { let j=text.indexOf("\\n",i); if(j<0)j=text.length;
                out += "<span class='tok-com'>"+esc(text.slice(i,j))+"</span>"; i=j; continue; }
              if (c === "#") { let j=text.indexOf("\\n",i); if(j<0)j=text.length;
                out += "<span class='tok-com'>"+esc(text.slice(i,j))+"</span>"; i=j; continue; }
              // strings
              if (c === '"' || c === "'" || c === "`") {
                let j=i+1; while(j<text.length && text[j]!==c){ if(text[j]==="\\\\")j++; j++; }
                out += "<span class='tok-str'>"+esc(text.slice(i,j+1))+"</span>"; i=j+1; continue;
              }
              // numbers
              if (/[0-9]/.test(c)) { let j=i; while(j<text.length && /[0-9.xa-fA-F]/.test(text[j]))j++;
                out += "<span class='tok-num'>"+esc(text.slice(i,j))+"</span>"; i=j; continue; }
              // identifiers / keywords
              if (/[A-Za-z_$]/.test(c)) { let j=i; while(j<text.length && /[A-Za-z0-9_$]/.test(text[j]))j++;
                const word=text.slice(i,j);
                if (KW.has(word)) out += "<span class='tok-kw'>"+esc(word)+"</span>";
                else if (text[j]==="(") out += "<span class='tok-fn'>"+esc(word)+"</span>";
                else out += esc(word);
                i=j; continue;
              }
              out += esc(c); i++;
            }
            block.innerHTML = out;
          });
        })();
        </script>
        </body>
        </html>
        """
    }
}
