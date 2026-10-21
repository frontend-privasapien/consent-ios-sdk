import ConsentCore
import SwiftUI

/// Each list level sits this far in, and its bullet or number gets a column this wide.
private let levelIndent: CGFloat = 16
private let markerWidth: CGFloat = 20
private let textSize: CGFloat = 14
/// Compose's 21 sp line height for 14 sp text, as extra space between lines.
private let extraLineSpacing: CGFloat = 4

/// Draws authored text. Core has already read the editor's format and worked out every bullet and number, so
/// this only draws: a list is a plain column of blocks, each with its marker and indent.
struct RichText: View {
    let blocks: [TextBlock]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.indent == 0 {
                    blockText(block)
                } else {
                    // The marker has a column of its own, so a wrapped line lines up under the text, not the bullet.
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(block.marker ?? "")
                            .font(.system(size: textSize))
                            .foregroundColor(textColour)
                            .frame(width: markerWidth, alignment: .leading)
                        blockText(block)
                    }
                    .padding(.leading, levelIndent * CGFloat(block.indent - 1))
                }
            }
        }
    }

    private func blockText(_ block: TextBlock) -> some View {
        Text(attributed(block.spans, accent: accent))
            .font(.system(size: textSize))
            .foregroundColor(textColour)
            .lineSpacing(extraLineSpacing)
            .multilineTextAlignment(block.alignment.textAlignment)
            .tint(accent)
            .frame(maxWidth: .infinity, alignment: block.alignment.frameAlignment)
    }
}

/// The spans as one attributed string. A link is drawn in the accent colour and underlined, so it reads as one on
/// any notice; tapping it opens it.
func attributed(_ spans: [TextSpan], accent: Color) -> AttributedString {
    spans.reduce(into: AttributedString()) { text, span in
        var piece = AttributedString(span.text)
        piece.font = fontOf(span)
        if span.underline { piece.underlineStyle = .single }
        if span.strike { piece.strikethroughStyle = .single }
        if let color = span.color { piece.foregroundColor = Color(argb: color.int64Value) }
        if let background = span.background { piece.backgroundColor = Color(argb: background.int64Value) }
        if let link = span.link, let url = URL(string: link) {
            piece.link = url
            piece.foregroundColor = accent
            piece.underlineStyle = .single
        }
        text.append(piece)
    }
}

private func fontOf(_ span: TextSpan) -> Font? {
    switch (span.bold, span.italic) {
    case (true, true): return .system(size: textSize, weight: .bold).italic()
    case (true, false): return .system(size: textSize, weight: .bold)
    case (false, true): return .system(size: textSize).italic()
    case (false, false): return nil
    }
}

private extension ConsentCore.TextAlignment {
    // SwiftUI has no justified text, so a justified block is laid out from the start.
    var textAlignment: SwiftUI.TextAlignment {
        if self == .center { return .center }
        return self == .end ? .trailing : .leading
    }

    var frameAlignment: Alignment {
        if self == .center { return .center }
        return self == .end ? .trailing : .leading
    }
}
