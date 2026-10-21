import ConsentCore
import SwiftUI

// The Compose sheet's colours and sizes (sheet/src/commonMain/.../ConsentSheet.kt), so both platforms look alike.
let textColour = Color(argb: 0xFF1F2937)
private let errorColour = Color(argb: 0xFFB42318)
private let mutedColour = Color(argb: 0xFF6B7280)
private let dividerColour = Color(argb: 0xFFE5E7EB)

// The control colours are the web SDK's (`styles/branding.ts`), fixed whatever the accent, so they always stand
// apart from it. Partly on is amber; on only because the notice turned it on is violet, with a dashed outline so
// the cue never rests on colour alone.
private let partialColour = Color(argb: 0xFFF59E0B)
private let autoColour = Color(argb: 0xFF7C3AED)
private let offBorderColour = Color(argb: 0xFF9CA3AF)
private let offTrackColour = Color(argb: 0xFFE5E7EB)
// The consent screen's hint is amber, as on the web; the detailed notice's is muted.
private let blockedHintColour = Color(argb: 0xFFB45309)

/// The sheet fits its content, up to this share of the window.
private let maxHeightFraction: CGFloat = 0.75

/// The sheet over a dimmed app: it slides up, and slides away once the state is hidden, then calls `onGone`.
/// Swiping it down or tapping outside asks the controller to close it, which refuses while it is locked.
struct SheetHost: View {
    @ObservedObject var model: SheetModel
    let onGone: () -> Void
    @State private var shown = false
    @State private var drag: CGFloat = 0

    var body: some View {
        let state = model.state
        // Nobody can close the sheet while it is locked, or while a save is in flight. The gestures are refused here,
        // not only in the controller, so the sheet never slides away while the state still says it is open.
        let cannotClose = state.isLocked || state.status == .submitting
        GeometryReader { window in
            ZStack(alignment: .bottom) {
                Color.black.opacity(shown ? 0.32 : 0)
                    .onTapGesture { if !cannotClose { model.controller.dismiss() } }
                if shown {
                    ConsentSheetView(
                        state: state,
                        controller: model.controller,
                        maxHeight: window.size.height * maxHeightFraction,
                        bottomInset: window.safeAreaInsets.bottom,
                        onDrag: { distance in drag = cannotClose ? distance * 0.1 : distance },
                        onDragEnd: { distance in
                            if !cannotClose && distance > 100 { model.controller.dismiss() }
                            withAnimation(.spring()) { drag = 0 }
                        }
                    )
                    .offset(y: drag)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeOut(duration: 0.25)) { shown = state.visible } }
        .onChange(of: state.visible) { visible in
            guard !visible else { return }
            // Finish whatever happens, or an invisible screen is left on top, swallowing taps.
            withAnimation(.easeIn(duration: 0.2)) { shown = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onGone() }
        }
    }
}

/// The consent sheet. It draws `state` and forwards every tap to `controller`; it decides nothing.
struct ConsentSheetView: View {
    let state: ConsentState
    let controller: ConsentController
    let maxHeight: CGFloat
    let bottomInset: CGFloat
    var onDrag: (CGFloat) -> Void = { _ in }
    var onDragEnd: (CGFloat) -> Void = { _ in }

    var body: some View {
        let accent = Color(argb: state.accentColor)
        let onAccent = Color(argb: state.onAccentColor)
        let canClose = !(state.isLocked || state.status == .submitting)
        VStack(spacing: 0) {
            TitleBar(state: state, canClose: canClose, accent: accent, onAccent: onAccent, controller: controller)
                // The title bar is the handle: dragging the scrolling content scrolls it instead.
                .gesture(
                    DragGesture()
                        .onChanged { onDrag(max(0, $0.translation.height)) }
                        .onEnded { onDragEnd($0.translation.height) }
                )
            content(accent: accent, onAccent: onAccent)
        }
        .padding(.bottom, bottomInset)
        .background(Color.white)
        .clipShape(TopRounded(radius: 16))
        .frame(maxHeight: maxHeight + bottomInset, alignment: .bottom)
        // Urdu, Kashmiri and Sindhi read right to left, so the whole sheet mirrors, whatever the app's own direction.
        .environment(\.layoutDirection, state.isRtl ? .rightToLeft : .leftToRight)
        // The sheet stays light in dark mode, as on Android.
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func content(accent: Color, onAccent: Color) -> some View {
        let status = state.status
        if status == .loading {
            Message(text: state.labels.loading)
        } else if status == .error {
            ErrorCard(state: state, accent: accent, onAccent: onAccent) { controller.open(force: false) }
        } else if status == .confirmed {
            Message(text: state.labels.saved)
        } else if state.screen == .policy {
            PolicyContent(state: state, accent: accent, controller: controller)
        } else if state.screen == .detail {
            DetailContent(state: state, accent: accent, onAccent: onAccent, controller: controller)
        } else {
            ConsentContent(state: state, accent: accent, onAccent: onAccent, controller: controller)
        }
    }
}

/// The title on the accent colour, the language chip when there is a choice, and a close button only when nothing is owed.
private struct TitleBar: View {
    let state: ConsentState
    let canClose: Bool
    let accent: Color
    let onAccent: Color
    let controller: ConsentController

    var body: some View {
        HStack(spacing: 0) {
            let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(title.isEmpty ? state.labels.titleFallback : state.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(onAccent)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !state.languages.isEmpty {
                LanguageChip(state: state, accent: accent, onAccent: onAccent) { controller.setLanguage(code: $0) }
            }
            if canClose {
                Button(action: controller.dismiss) {
                    Text("✕").font(.system(size: 18)).foregroundColor(onAccent).padding(8)
                }
                .accessibilityLabel(state.labels.close)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(accent)
    }
}

/// The language on screen, as a chip that opens the list of languages the notice is published in.
private struct LanguageChip: View {
    let state: ConsentState
    let accent: Color
    let onAccent: Color
    let onPick: (String) -> Void

    var body: some View {
        Menu {
            ForEach(state.languages, id: \.code) { language in
                Button { onPick(language.code) } label: {
                    if language.isSelected {
                        Label(language.name, systemImage: "checkmark")
                    } else {
                        Text(language.name)
                    }
                }
            }
        } label: {
            Text(state.language.uppercased() + " ▾")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(onAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(onAccent, lineWidth: 1))
        }
        .accessibilityLabel(state.labels.currentLanguage)
    }
}

private struct Message: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundColor(textColour)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(32)
    }
}

private struct ErrorCard: View {
    let state: ConsentState
    let accent: Color
    let onAccent: Color
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(state.errorMessage ?? "").foregroundColor(textColour).multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(state.labels.retry)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(onAccent)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(accent))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

/// The notice text, the two boxes, the words under them and the two links scroll; Submit stays pinned at the bottom.
private struct ConsentContent: View {
    let state: ConsentState
    let accent: Color
    let onAccent: Color
    let controller: ConsentController

    var body: some View {
        VStack(spacing: 0) {
            FittingScroll {
                VStack(alignment: .leading, spacing: 8) {
                    if !state.noticeText.isEmpty {
                        RichText(blocks: state.noticeText, accent: accent).padding(.bottom, 8)
                    }
                    ForEach(state.checkboxes, id: \.side) { box in
                        CheckboxRow(box: box, accent: accent, onAccent: onAccent) { controller.toggleGroup(side: box.side) }
                    }
                    if !state.consentText.isEmpty {
                        RichText(blocks: state.consentText, accent: accent).padding(.top, 8)
                    }
                    HStack(spacing: 16) {
                        LinkText(text: state.labels.detailedNoticeLink, accent: accent) { controller.show(screen: .detail) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LinkText(text: state.labels.privacyPolicyLink + " " + forward(state), accent: accent) { controller.show(screen: .policy) }
                    }
                }
                .padding(16)
            }
            SubmitFooter(
                state: state, accent: accent, onAccent: onAccent, controller: controller,
                blockedHint: state.labels.blockedHint, hintColour: blockedHintColour
            )
        }
    }
}

/// Submit, pinned under both consent screens, with a failed save's message above it. `blockedHint` shows under it
/// while a required purpose is still off.
private struct SubmitFooter: View {
    let state: ConsentState
    let accent: Color
    let onAccent: Color
    let controller: ConsentController
    let blockedHint: String
    let hintColour: Color

    var body: some View {
        let saving = state.status == .submitting
        let enabled = !state.isSubmitBlocked && !saving
        VStack(spacing: 8) {
            // A save that failed: the form is as the user left it, and Submit again is the retry.
            if let message = state.errorMessage {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(errorColour)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            Button(action: controller.submit) {
                ZStack {
                    if saving {
                        ProgressView().progressViewStyle(.circular).tint(onAccent)
                    } else {
                        Text(state.submitLabel ?? state.labels.submitFallback).font(.system(size: 14, weight: .medium))
                    }
                }
                // Material's disabled button: a faint grey with faded words.
                .foregroundColor(enabled ? onAccent : Color.black.opacity(0.38))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(enabled ? accent : Color.black.opacity(0.12)))
            }
            .disabled(!enabled)
            if state.isSubmitBlocked {
                Text(blockedHint)
                    .font(.system(size: 12))
                    .foregroundColor(hintColour)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
    }
}

private struct CheckboxRow: View {
    let box: ConsentCheckbox
    let accent: Color
    let onAccent: Color
    let onToggle: () -> Void

    var body: some View {
        // The row carries the tap and the accessibility state, so the box only draws. A tap on a link in the text
        // opens the link instead.
        HStack(alignment: .top, spacing: 12) {
            CheckMark(state: box.state, isAuto: box.isAuto, accent: accent, onAccent: onAccent).padding(.top, 2)
            RichText(blocks: box.text, accent: accent).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .toggleAccessibility(box.state, action: onToggle)
    }
}

/// The privacy policy and the purposes the notice covers. The way back stays pinned at the top; the rest scrolls.
private struct PolicyContent: View {
    let state: ConsentState
    let accent: Color
    let controller: ConsentController

    var body: some View {
        let labels = state.labels
        VStack(alignment: .leading, spacing: 0) {
            LinkText(text: back(state) + " " + labels.backToNotice, accent: accent) { controller.show(screen: .consent) }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            FittingScroll {
                VStack(alignment: .leading, spacing: 8) {
                    Text(labels.policyTitle).font(.system(size: 16, weight: .bold)).foregroundColor(textColour)
                    if state.policyText.isEmpty {
                        Text(labels.policyEmpty).font(.system(size: 14)).foregroundColor(mutedColour)
                    } else {
                        RichText(blocks: state.policyText, accent: accent)
                    }
                    Text(labels.purposesTitle).font(.system(size: 16, weight: .bold)).foregroundColor(textColour).padding(.top, 8)
                    if state.purposes.isEmpty {
                        Text(labels.purposesEmpty).font(.system(size: 14)).foregroundColor(mutedColour)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(state.purposes.enumerated()), id: \.offset) { _, row in
                            PurposeLine(row: row, labels: labels)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

/// The same question purpose by purpose: a Required and an Optional block, each with a master switch and a switch per
/// category and purpose. The way back stays pinned at the top and Submit at the bottom; the rest scrolls.
private struct DetailContent: View {
    let state: ConsentState
    let accent: Color
    let onAccent: Color
    let controller: ConsentController

    var body: some View {
        let labels = state.labels
        VStack(alignment: .leading, spacing: 0) {
            LinkText(text: back(state) + " " + labels.backToNotice, accent: accent) { controller.show(screen: .consent) }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            FittingScroll {
                VStack(alignment: .leading, spacing: 16) {
                    if !state.noticeText.isEmpty { RichText(blocks: state.noticeText, accent: accent) }
                    ForEach(state.blocks, id: \.side) { block in
                        DetailBlock(
                            block: block, labels: labels, accent: accent, onAccent: onAccent,
                            onToggleAll: { controller.toggleGroup(side: block.side) },
                            onToggle: { controller.togglePurpose(side: block.side, id: $0) }
                        )
                    }
                    if !state.consentText.isEmpty { RichText(blocks: state.consentText, accent: accent) }
                }
                .padding(.horizontal, 16)
            }
            SubmitFooter(
                state: state, accent: accent, onAccent: onAccent, controller: controller,
                blockedHint: labels.requiredHint, hintColour: mutedColour
            )
        }
    }
}

private struct DetailBlock: View {
    let block: ConsentBlock
    let labels: ConsentLabels
    let accent: Color
    let onAccent: Color
    let onToggleAll: () -> Void
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let heading = block.side == .required ? labels.required : labels.optional
            SwitchRow(state: block.state, isAuto: block.isAuto, accent: accent, onAccent: onAccent, onToggle: onToggleAll) {
                Text(heading.uppercased()).font(.system(size: 12, weight: .bold)).tracking(1).foregroundColor(textColour)
            }
            if !block.text.isEmpty { RichText(blocks: block.text, accent: accent) }
            if block.switches.isEmpty {
                Text(labels.detailEmpty).font(.system(size: 14)).foregroundColor(mutedColour)
            }
            VStack(spacing: 0) {
                ForEach(block.switches, id: \.id) { purpose in
                    dividerColour.frame(height: 1)
                    SwitchRow(state: purpose.state, isAuto: purpose.isAuto, accent: accent, onAccent: onAccent, onToggle: { onToggle(purpose.id) }) {
                        Text(purpose.name)
                            .font(.system(size: 14, weight: purpose.isCategory ? .semibold : .regular))
                            .foregroundColor(textColour)
                        if let description = purpose.description_ {
                            Text(description).font(.system(size: 12)).foregroundColor(mutedColour)
                        }
                    }
                    .padding(.leading, 16 * CGFloat(purpose.depth))
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

/// A row that is one tri-state switch: the whole row takes the tap and carries the state for screen readers.
private struct SwitchRow<Label: View>: View {
    let state: ToggleState
    let isAuto: Bool
    let accent: Color
    let onAccent: Color
    let onToggle: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) { label() }.frame(maxWidth: .infinity, alignment: .leading)
            SwitchMark(state: state, isAuto: isAuto, accent: accent, onAccent: onAccent)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .toggleAccessibility(state, action: onToggle)
    }
}

/// One line of the purpose list: a category is a heading; a purpose shows its basis and whether it is required.
private struct PurposeLine: View {
    let row: PurposeRow
    let labels: ConsentLabels

    var body: some View {
        VStack(spacing: 0) {
            dividerColour.frame(height: 1)
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.name)
                        .font(.system(size: 14, weight: row.side == nil ? .semibold : .regular))
                        .foregroundColor(textColour)
                    if let basis = row.basis { Text(basis).font(.system(size: 12)).foregroundColor(mutedColour) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let side = row.side {
                    Text((side == .required ? labels.required : labels.optional).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(mutedColour)
                }
            }
            .padding(.leading, 16 * CGFloat(row.depth))
            .padding(.vertical, 8)
        }
    }
}

// The arrows on the links point the way the sheet reads. Compose's text engine mirrors them in a right-to-left
// language; iOS draws them as written, so the pair is swapped here.
private func forward(_ state: ConsentState) -> String { state.isRtl ? "‹" : "›" }
private func back(_ state: ConsentState) -> String { state.isRtl ? "›" : "‹" }

/// Text in the accent colour that moves between screens.
private struct LinkText: View {
    let text: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundColor(accent).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// What an on or partly on control is filled with, and the tick, dash or knob on it. Partly on wins over auto,
// as on the web (`fillFor`, `markerOn`): "some of these are on" is the more urgent of the two.
private func fillOf(_ state: ToggleState, _ isAuto: Bool, _ accent: Color) -> Color {
    if state == .partial { return partialColour }
    return isAuto ? autoColour : accent
}

private func markerOf(_ state: ToggleState, _ isAuto: Bool, _ onAccent: Color) -> Color {
    state == .partial || isAuto ? .white : onAccent
}

/// The outline of a control. Auto is dashed, with the fill drawn inside it rather than under it, so the gaps
/// show and the cue does not depend on colour.
private struct Outlined<S: InsettableShape>: View {
    let shape: S
    let fill: Color?
    let border: Color
    let isAuto: Bool

    var body: some View {
        ZStack {
            if let fill { shape.fill(fill).padding(isAuto ? 3 : 0) }
            shape.strokeBorder(border, style: StrokeStyle(lineWidth: 1.5, dash: isAuto ? [3, 2] : []))
        }
    }
}

/// The checkbox, drawn by hand so an auto box can carry the dashed outline. A tick when on, a dash when partly on.
private struct CheckMark: View {
    let state: ToggleState
    let isAuto: Bool
    let accent: Color
    let onAccent: Color

    var body: some View {
        let on = state != .off
        let fill = fillOf(state, isAuto, accent)
        let marker = markerOf(state, isAuto, onAccent)
        ZStack {
            Outlined(shape: RoundedRectangle(cornerRadius: 4), fill: on ? fill : nil, border: on ? fill : offBorderColour, isAuto: isAuto && on)
            if state == .on {
                Path { path in
                    path.move(to: CGPoint(x: 5.4, y: 10.4))
                    path.addLine(to: CGPoint(x: 8.8, y: 13.6))
                    path.addLine(to: CGPoint(x: 14.8, y: 6.8))
                }
                .stroke(marker, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else if state == .partial {
                Path { path in
                    path.move(to: CGPoint(x: 5.6, y: 10))
                    path.addLine(to: CGPoint(x: 14.4, y: 10))
                }
                .stroke(marker, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        .frame(width: 20, height: 20)
    }
}

/// The switch, drawn by hand for the same reason. Partly on sits in the on position, in amber: a knob left halfway
/// reads as a broken control. The knob sits at the trailing end when on, so it mirrors in a right-to-left language.
private struct SwitchMark: View {
    let state: ToggleState
    let isAuto: Bool
    let accent: Color
    let onAccent: Color

    var body: some View {
        let on = state != .off
        let fill = fillOf(state, isAuto, accent)
        let marker = markerOf(state, isAuto, onAccent)
        ZStack(alignment: on ? .trailing : .leading) {
            Outlined(shape: Capsule(), fill: on ? fill : offTrackColour, border: on ? fill : offBorderColour, isAuto: isAuto && on)
            Circle().fill(on ? marker : .white).frame(width: 14, height: 14).padding(3)
        }
        .frame(width: 36, height: 20)
    }
}

private extension View {
    /// The tri-state toggle for screen readers: a button that is selected when on or partly on.
    func toggleAccessibility(_ state: ToggleState, action: @escaping () -> Void) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityAddTraits(state == .off ? .isButton : [.isButton, .isSelected])
            .accessibilityAction(.default, action)
    }
}

/// A scroll view as tall as its content, up to the room the sheet leaves it: a short notice makes a short sheet.
private struct FittingScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content().background(GeometryReader { Color.clear.preference(key: ContentHeight.self, value: $0.size.height) })
        }
        .frame(maxHeight: height)
        .onPreferenceChange(ContentHeight.self) { height = $0 }
    }
}

private struct ContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The sheet's shape: rounded at the top, square where it meets the bottom of the screen.
private struct TopRounded: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

extension Color {
    /// A colour from core's ARGB (0xAARRGGBB).
    init(argb: Int64) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
