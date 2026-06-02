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
            :root {
                --bg: #0d1117; --fg: #e6edf3; --muted: #8b949e;
                --border: #30363d; --link: #4493f8;
                --code-bg: #161b22; --code-fg: #e6edf3;
                --quote-border: #3d444d; --quote-fg: #9198a1;
                --th-bg: #161b22; --hr: #30363d;
                --kw:#ff7b72; --str:#a5d6ff; --num:#79c0ff; --com:#8b949e; --fn:#d2a8ff;
            }
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
        </style>
        </head>
        <body>
        \(body)
        <script>
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
