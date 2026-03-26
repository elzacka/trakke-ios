import SwiftUI

/// Renders simple markdown content (headers, bullets, numbered lists, bold/italic, paragraphs)
/// into native SwiftUI views. Avoids third-party dependencies.
struct MarkdownBodyView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.md) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: - Block Types

    private enum Block {
        case heading2(String)
        case heading3(String)
        case paragraph(String)
        case bulletList([String])
        case numberedList([String])
    }

    // MARK: - Parsing

    private func parseBlocks() -> [Block] {
        let sections = markdown.components(separatedBy: "\n\n")
        var blocks: [Block] = []

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lines = trimmed.components(separatedBy: "\n")

            // Check if the entire section is a list
            var bulletItems: [String] = []
            var numberedItems: [String] = []

            for line in lines {
                let stripped = line.trimmingCharacters(in: .whitespaces)
                if stripped.hasPrefix("## ") || stripped.hasPrefix("### ") {
                    if !bulletItems.isEmpty {
                        blocks.append(.bulletList(bulletItems))
                        bulletItems = []
                    }
                    if !numberedItems.isEmpty {
                        blocks.append(.numberedList(numberedItems))
                        numberedItems = []
                    }
                    if stripped.hasPrefix("### ") {
                        blocks.append(.heading3(String(stripped.dropFirst(4))))
                    } else {
                        blocks.append(.heading2(String(stripped.dropFirst(3))))
                    }
                } else if stripped.hasPrefix("- ") {
                    bulletItems.append(String(stripped.dropFirst(2)))
                } else if let match = stripped.firstMatch(of: /^(\d+)\.\s+(.+)/) {
                    numberedItems.append(String(match.2))
                } else if !stripped.isEmpty {
                    if !bulletItems.isEmpty {
                        blocks.append(.bulletList(bulletItems))
                        bulletItems = []
                    }
                    if !numberedItems.isEmpty {
                        blocks.append(.numberedList(numberedItems))
                        numberedItems = []
                    }
                    blocks.append(.paragraph(stripped))
                }
            }

            if !bulletItems.isEmpty {
                blocks.append(.bulletList(bulletItems))
            }
            if !numberedItems.isEmpty {
                blocks.append(.numberedList(numberedItems))
            }
        }

        return blocks
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading2(let text):
            inlineText(text)
                .font(Font.Trakke.bodyMedium)
                .padding(.top, .Trakke.sm)

        case .heading3(let text):
            inlineText(text)
                .font(Font.Trakke.caption)
                .fontWeight(.semibold)
                .padding(.top, .Trakke.xs)

        case .paragraph(let text):
            inlineText(text)
                .font(Font.Trakke.bodyRegular)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\u{2022}")
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.textTertiary)
                        inlineText(item)
                            .font(Font.Trakke.bodyRegular)
                    }
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: .Trakke.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: .Trakke.sm) {
                        Text("\(index + 1).")
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.textTertiary)
                            .frame(minWidth: 20, alignment: .trailing)
                        inlineText(item)
                            .font(Font.Trakke.bodyRegular)
                    }
                }
            }
        }
    }

    // MARK: - Inline Formatting

    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }
}
