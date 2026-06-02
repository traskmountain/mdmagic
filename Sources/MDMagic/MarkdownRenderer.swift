import Foundation

/// A lightweight, dependency-free GitHub-Flavored Markdown -> HTML converter.
/// Handles headings, bold/italic/strike, inline & fenced code, links, images,
/// blockquotes, ordered/unordered/task lists, tables, hr, and paragraphs.
enum MarkdownRenderer {

    static func html(from markdown: String) -> String {
        let body = convert(markdown)
        return wrap(body: body)
    }

    // MARK: - Block-level conversion

    private static func convert(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var out = ""
        var i = 0

        func peek() -> String? { i < lines.count ? lines[i] : nil }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let fence = String(trimmed.prefix(3))
                let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                i += 1
                var code = ""
                while i < lines.count {
                    let l = lines[i]
                    if l.trimmingCharacters(in: .whitespaces).hasPrefix(fence) { i += 1; break }
                    code += escape(l) + "\n"
                    i += 1
                }
                let langClass = lang.isEmpty ? "" : " class=\"language-\(escape(lang))\""
                let langLabel = lang.isEmpty ? "" : "<span class=\"code-lang\">\(escape(lang))</span>"
                out += "<div class=\"code-wrap\">\(langLabel)<pre><code\(langClass)>\(code)</code></pre></div>\n"
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                out += "<hr>\n"; i += 1; continue
            }

            // ATX Heading
            if let h = headingMatch(trimmed) {
                out += "<h\(h.level)>\(inline(h.text))</h\(h.level)>\n"
                i += 1; continue
            }

            // Blockquote (collapse consecutive >)
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while let l = peek(), l.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    var q = l.trimmingCharacters(in: .whitespaces)
                    q.removeFirst()
                    if q.hasPrefix(" ") { q.removeFirst() }
                    quoteLines.append(q)
                    i += 1
                }
                out += "<blockquote>\n\(convert(quoteLines.joined(separator: "\n")))</blockquote>\n"
                continue
            }

            // Table (line with | followed by a separator row)
            if line.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                var tableLines = [line]
                i += 1 // separator
                let sep = lines[i]
                i += 1
                while let l = peek(), l.contains("|"), !l.trimmingCharacters(in: .whitespaces).isEmpty {
                    tableLines.append(l); i += 1
                }
                out += renderTable(header: tableLines[0], separator: sep, rows: Array(tableLines.dropFirst()))
                continue
            }

            // Lists (unordered, ordered, task)
            if isListItem(trimmed) {
                let (htmlList, consumed) = renderList(lines, start: i)
                out += htmlList
                i += consumed
                continue
            }

            // Blank line
            if trimmed.isEmpty { i += 1; continue }

            // Paragraph: gather consecutive non-blank, non-block lines
            var para: [String] = []
            while let l = peek() {
                let t = l.trimmingCharacters(in: .whitespaces)
                if t.isEmpty || headingMatch(t) != nil || t.hasPrefix("```") || t.hasPrefix("~~~")
                    || t.hasPrefix(">") || t == "---" || t == "***" || isListItem(t) { break }
                para.append(t)
                i += 1
            }
            if !para.isEmpty {
                out += "<p>\(inline(para.joined(separator: "\n")))</p>\n"
            }
        }
        return out
    }

    // MARK: - Lists

    private static func isListItem(_ s: String) -> Bool {
        if s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ") { return true }
        return orderedMarker(s) != nil
    }

    private static func orderedMarker(_ s: String) -> Int? {
        var num = ""
        for ch in s {
            if ch.isNumber { num.append(ch) } else { break }
        }
        guard !num.isEmpty else { return nil }
        let rest = s.dropFirst(num.count)
        if rest.hasPrefix(". ") || rest.hasPrefix(") ") { return num.count }
        return nil
    }

    private static func indentLevel(_ line: String) -> Int {
        var spaces = 0
        for ch in line {
            if ch == " " { spaces += 1 }
            else if ch == "\t" { spaces += 4 }
            else { break }
        }
        return spaces / 2
    }

    /// Renders a (possibly nested) list starting at `start`. Returns html + lines consumed.
    private static func renderList(_ lines: [String], start: Int) -> (String, Int) {
        var i = start
        let baseIndent = indentLevel(lines[i])
        let firstTrim = lines[i].trimmingCharacters(in: .whitespaces)
        let ordered = orderedMarker(firstTrim) != nil
        var items = ""

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { i += 1; continue }
            let indent = indentLevel(line)
            if indent < baseIndent || !isListItem(trimmed) { break }
            if indent > baseIndent {
                // nested list belongs to previous item — handled below, shouldn't reach
                break
            }

            // strip marker
            var content = trimmed
            if let n = orderedMarker(trimmed) {
                content = String(trimmed.dropFirst(n + 2))
            } else {
                content = String(trimmed.dropFirst(2))
            }

            // task list checkbox
            var checkbox = ""
            if content.hasPrefix("[ ]") {
                checkbox = "<input type=\"checkbox\" disabled> "
                content = String(content.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if content.lowercased().hasPrefix("[x]") {
                checkbox = "<input type=\"checkbox\" checked disabled> "
                content = String(content.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }

            i += 1
            // gather nested list lines
            var nested = ""
            if i < lines.count {
                let nextIndent = indentLevel(lines[i])
                let nextTrim = lines[i].trimmingCharacters(in: .whitespaces)
                if nextIndent > baseIndent, isListItem(nextTrim) {
                    let (sub, consumed) = renderList(lines, start: i)
                    nested = sub
                    i += consumed
                }
            }
            let cls = checkbox.isEmpty ? "" : " class=\"task-item\""
            items += "<li\(cls)>\(checkbox)\(inline(content))\(nested)</li>\n"
        }

        let tag = ordered ? "ol" : "ul"
        return ("<\(tag)>\n\(items)</\(tag)>\n", i - start)
    }

    // MARK: - Tables

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.contains("-") else { return false }
        let cells = t.split(separator: "|", omittingEmptySubsequences: true)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func splitRow(_ row: String) -> [String] {
        var s = row.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func renderTable(header: String, separator: String, rows: [String]) -> String {
        let aligns = splitRow(separator).map { spec -> String in
            let l = spec.hasPrefix(":"), r = spec.hasSuffix(":")
            if l && r { return "center" }
            if r { return "right" }
            if l { return "left" }
            return ""
        }
        func cellStyle(_ idx: Int) -> String {
            guard idx < aligns.count, !aligns[idx].isEmpty else { return "" }
            return " style=\"text-align:\(aligns[idx])\""
        }

        var out = "<table>\n<thead>\n<tr>"
        for (idx, h) in splitRow(header).enumerated() {
            out += "<th\(cellStyle(idx))>\(inline(h))</th>"
        }
        out += "</tr>\n</thead>\n<tbody>\n"
        for row in rows {
            out += "<tr>"
            for (idx, c) in splitRow(row).enumerated() {
                out += "<td\(cellStyle(idx))>\(inline(c))</td>"
            }
            out += "</tr>\n"
        }
        out += "</tbody>\n</table>\n"
        return out
    }

    // MARK: - Headings

    private static func headingMatch(_ s: String) -> (level: Int, text: String)? {
        guard s.hasPrefix("#") else { return nil }
        var level = 0
        for ch in s { if ch == "#" { level += 1 } else { break } }
        guard level >= 1, level <= 6 else { return nil }
        let rest = s.dropFirst(level)
        guard rest.hasPrefix(" ") || rest.isEmpty else { return nil }
        return (level, rest.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Inline conversion

    /// Inline parsing. Code spans are protected first, then other emphasis is applied.
    private static func inline(_ text: String) -> String {
        // Protect inline code spans with placeholders so their content isn't escaped/parsed.
        var placeholders: [String] = []
        var working = ""
        var idx = text.startIndex
        while idx < text.endIndex {
            if text[idx] == "`" {
                // find closing backtick run
                var tickCount = 0
                var j = idx
                while j < text.endIndex, text[j] == "`" { tickCount += 1; j = text.index(after: j) }
                let fence = String(repeating: "`", count: tickCount)
                if let closeRange = text.range(of: fence, range: j..<text.endIndex) {
                    let code = String(text[j..<closeRange.lowerBound])
                    let token = "\u{0}CODE\(placeholders.count)\u{0}"
                    placeholders.append("<code>\(escape(code))</code>")
                    working += token
                    idx = closeRange.upperBound
                    continue
                }
            }
            working.append(text[idx])
            idx = text.index(after: idx)
        }

        var s = escape(working)

        // Images: ![alt](url)
        s = regexReplace(s, #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#) { m in
            "<img alt=\"\(m[1])\" src=\"\(m[2])\">"
        }
        // Links: [text](url)
        s = regexReplace(s, #"\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#) { m in
            "<a href=\"\(m[2])\">\(m[1])</a>"
        }
        // Bold+italic ***
        s = regexReplace(s, #"\*\*\*([^*]+)\*\*\*"#) { m in "<strong><em>\(m[1])</em></strong>" }
        // Bold **
        s = regexReplace(s, #"\*\*([^*]+)\*\*"#) { m in "<strong>\(m[1])</strong>" }
        s = regexReplace(s, #"__([^_]+)__"#) { m in "<strong>\(m[1])</strong>" }
        // Italic *
        s = regexReplace(s, #"\*([^*]+)\*"#) { m in "<em>\(m[1])</em>" }
        s = regexReplace(s, #"(?<![A-Za-z0-9])_([^_]+)_(?![A-Za-z0-9])"#) { m in "<em>\(m[1])</em>" }
        // Strikethrough ~~
        s = regexReplace(s, #"~~([^~]+)~~"#) { m in "<del>\(m[1])</del>" }
        // Autolink bare URLs
        s = regexReplace(s, #"(?<!["=>])(https?://[^\s<]+)"#) { m in "<a href=\"\(m[1])\">\(m[1])</a>" }

        // line breaks within paragraph
        s = s.replacingOccurrences(of: "\n", with: "<br>\n")

        // restore code spans
        for (n, repl) in placeholders.enumerated() {
            s = s.replacingOccurrences(of: "\u{0}CODE\(n)\u{0}", with: repl)
        }
        return s
    }

    // MARK: - Helpers

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func regexReplace(_ input: String, _ pattern: String,
                                     _ transform: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return input }
        let ns = input as NSString
        var result = ""
        var last = 0
        re.enumerateMatches(in: input, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match = match else { return }
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            var groups: [String] = []
            for g in 0..<match.numberOfRanges {
                let r = match.range(at: g)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += transform(groups)
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}
