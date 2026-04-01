import Foundation

/// Parsed markdown block types shared across MarkdownBodyView and UserGuideBodyView.
enum MarkdownBlock: Sendable {
    case heading2(String, String?)  // text, optional anchor ID
    case heading3(String)
    case paragraph(String)
    case bulletList([String])
    case numberedList([String])
    case table(headers: [String], rows: [[String]])
    case image(name: String, caption: String)
    case speciesImage(scientificName: String, caption: String)
}

/// Configuration for the markdown parser.
struct MarkdownParserOptions: Sendable {
    /// Skip h1 headings (title shown in navigation bar instead).
    var skipH1 = false
    /// Skip ToC section (## Innhold ... ---).
    var skipTableOfContents = false
    /// Parse {#anchor} suffixes on h2 headings.
    var parseAnchors = false
    /// Parse ![caption](name) image syntax.
    var parseImages = false
}

/// Lightweight markdown parser that converts a markdown string into an array of blocks.
/// Shared by MarkdownBodyView (articles) and UserGuideBodyView (user guide).
enum MarkdownParser {
    static func parse(_ markdown: String, options: MarkdownParserOptions = MarkdownParserOptions()) -> [MarkdownBlock] {
        let sections = markdown.components(separatedBy: "\n\n")
        var blocks: [MarkdownBlock] = []
        var skipUntilDivider = false

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lines = trimmed.components(separatedBy: "\n")
            var bulletItems: [String] = []
            var numberedItems: [String] = []

            for line in lines {
                let stripped = line.trimmingCharacters(in: .whitespaces)

                // ToC skipping
                if options.skipTableOfContents && stripped == "## Innhold" {
                    skipUntilDivider = true
                    continue
                }
                if stripped == "---" {
                    if skipUntilDivider { skipUntilDivider = false }
                    continue
                }
                if skipUntilDivider { continue }

                // h1 skipping
                if options.skipH1 && stripped.hasPrefix("# ") && !stripped.hasPrefix("## ") {
                    continue
                }

                if stripped.hasPrefix("### ") {
                    flushLists(&bulletItems, &numberedItems, into: &blocks)
                    var h3Text = String(stripped.dropFirst(4))
                    if options.parseAnchors, let match = h3Text.firstMatch(of: /^(.+?)\s*\{#([^}]+)\}$/) {
                        h3Text = String(match.1)
                    }
                    blocks.append(.heading3(h3Text))
                } else if stripped.hasPrefix("## ") {
                    flushLists(&bulletItems, &numberedItems, into: &blocks)
                    let h2Text = String(stripped.dropFirst(3))
                    if options.parseAnchors, let match = h2Text.firstMatch(of: /^(.+?)\s*\{#([^}]+)\}$/) {
                        blocks.append(.heading2(String(match.1), String(match.2)))
                    } else {
                        blocks.append(.heading2(h2Text, nil))
                    }
                } else if options.parseImages, let imageMatch = stripped.firstMatch(of: /^!\[([^\]]*)\]\(([^)]+)\)$/) {
                    flushLists(&bulletItems, &numberedItems, into: &blocks)
                    let name = String(imageMatch.2)
                    let caption = String(imageMatch.1)
                    if name.hasPrefix("species:") {
                        let scientificName = String(name.dropFirst("species:".count))
                        blocks.append(.speciesImage(scientificName: scientificName, caption: caption))
                    } else {
                        blocks.append(.image(name: name, caption: caption))
                    }
                } else if stripped.hasPrefix("|") && stripped.hasSuffix("|") {
                    flushLists(&bulletItems, &numberedItems, into: &blocks)
                    // Collect all table lines from this point in the section
                    var tableLines: [String] = [stripped]
                    // The remaining lines in this section that are table rows
                    // will be handled below; for now just collect this one.
                    // We handle multi-line tables by checking subsequent lines in a second pass.
                    // For simplicity, parse the entire section as a table block.
                    let remainingLines = lines.suffix(from: lines.firstIndex(of: line)!.advanced(by: 1))
                    for nextLine in remainingLines {
                        let nextStripped = nextLine.trimmingCharacters(in: .whitespaces)
                        if nextStripped.hasPrefix("|") && nextStripped.hasSuffix("|") {
                            tableLines.append(nextStripped)
                        } else {
                            break
                        }
                    }
                    if let table = parseTable(tableLines) {
                        blocks.append(table)
                    }
                    // Skip the rest of this section since we consumed the table lines
                    break
                } else if stripped.hasPrefix("- ") {
                    if !numberedItems.isEmpty { blocks.append(.numberedList(numberedItems)); numberedItems = [] }
                    bulletItems.append(String(stripped.dropFirst(2)))
                } else if let match = stripped.firstMatch(of: /^(\d+)\.\s+(.+)/) {
                    if !bulletItems.isEmpty { blocks.append(.bulletList(bulletItems)); bulletItems = [] }
                    numberedItems.append(String(match.2))
                } else if !stripped.isEmpty {
                    flushLists(&bulletItems, &numberedItems, into: &blocks)
                    blocks.append(.paragraph(stripped))
                }
            }

            flushLists(&bulletItems, &numberedItems, into: &blocks)
        }

        return blocks
    }

    private static func flushLists(_ bullets: inout [String], _ numbered: inout [String], into blocks: inout [MarkdownBlock]) {
        if !bullets.isEmpty { blocks.append(.bulletList(bullets)); bullets = [] }
        if !numbered.isEmpty { blocks.append(.numberedList(numbered)); numbered = [] }
    }

    /// Parse markdown table lines into a .table block.
    /// Expects lines like: | Col1 | Col2 | ... with a separator row (|---|---|).
    private static func parseTable(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }

        func splitRow(_ line: String) -> [String] {
            line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        let headers = splitRow(lines[0])
        guard !headers.isEmpty else { return nil }

        // Skip separator row (|---|---|)
        let startIndex = lines.count > 2 && lines[1].contains("---") ? 2 : 1

        var rows: [[String]] = []
        for i in startIndex..<lines.count {
            let cells = splitRow(lines[i])
            guard !cells.allSatisfy({ $0.allSatisfy { $0 == "-" } }) else { continue }
            rows.append(cells)
        }

        return .table(headers: headers, rows: rows)
    }
}
