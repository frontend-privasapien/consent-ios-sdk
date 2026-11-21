import ConsentCore
import SwiftUI

/// `ConsentTheme` as SwiftUI colours. Core has already decided every one of them (a notice's colours, the tints on a
/// coloured background, what stays readable), so nothing here is worked out: it is converted once and handed down.
struct Colours {
    let surface: Color
    let accent: Color
    let headerText: Color
    let buttonText: Color
    let text: Color
    let authored: Color
    let muted: Color
    let border: Color
    let unselected: Color
    let partial: Color
    let selected: Color
    let onSelected: Color
    let onPartial: Color
    let hint: Color
    let error: Color
    let link: Color
    let autoTag: Color
    let headerFill: Color
    let headerRule: Color
    let headerRuleWidth: CGFloat

    init(_ theme: ConsentTheme) {
        surface = Color(argb: theme.surface)
        accent = Color(argb: theme.accent)
        headerText = Color(argb: theme.headerText)
        buttonText = Color(argb: theme.buttonText)
        text = Color(argb: theme.text)
        authored = Color(argb: theme.authored)
        muted = Color(argb: theme.muted)
        border = Color(argb: theme.border)
        unselected = Color(argb: theme.unselected)
        partial = Color(argb: theme.partial)
        selected = Color(argb: theme.selected)
        onSelected = Color(argb: theme.onSelected)
        onPartial = Color(argb: theme.onPartial)
        hint = Color(argb: theme.hint)
        error = Color(argb: theme.error)
        link = Color(argb: theme.link)
        autoTag = Color(argb: theme.autoTag)
        headerFill = Color(argb: theme.headerFill)
        headerRule = Color(argb: theme.headerRule)
        headerRuleWidth = CGFloat(theme.headerRuleWidth)
    }
}

// The Compose sheet's sizes (sheet/src/commonMain/.../ConsentSheet.kt), so both platforms look alike. Every colour
// comes from the notice's theme (`state.theme`, worked out in core), as `Colours`.

/// How faded a switch or box is that takes no taps: below the notice's actionable level, or granted already (the web's 0.75).
private let inertOpacity: Double = 0.75

/// How faded a disabled Submit is. It keeps the notice's colours, as on the web, and does not turn grey.
private let disabledOpacity: Double = 0.6

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
        let colours = Colours(state.theme)
        let canClose = !(state.isLocked || state.status == .submitting)
        VStack(spacing: 0) {
            TitleBar(state: state, canClose: canClose, colours: colours, controller: controller)
                // The title bar is the handle: dragging the scrolling content scrolls it instead.
                .gesture(
                    DragGesture()
                        .onChanged { onDrag(max(0, $0.translation.height)) }
                        .onEnded { onDragEnd($0.translation.height) }
                )
            content(colours: colours)
        }
        .padding(.bottom, bottomInset)
        .background(colours.surface)
        .clipShape(TopRounded(radius: 16))
        .frame(maxHeight: maxHeight + bottomInset, alignment: .bottom)
        // Urdu, Kashmiri and Sindhi read right to left, so the whole sheet mirrors, whatever the app's own direction.
        .environment(\.layoutDirection, state.isRtl ? .rightToLeft : .leftToRight)
        // The sheet ignores the phone's dark mode, as on Android. A notice with a dark surface asks for dark controls
        // instead: the scroll indicators and the language menu, which the sheet cannot colour itself.
        .environment(\.colorScheme, state.theme.isDark ? .dark : .light)
    }

    @ViewBuilder
    private func content(colours: Colours) -> some View {
        let status = state.status
        if status == .loading {
            Message(text: state.labels.loading, colours: colours)
        } else if status == .error {
            ErrorCard(state: state, colours: colours) { controller.open(force: false) }
        } else if status == .confirmed {
            Message(text: state.labels.saved, colours: colours)
        } else if state.screen == .policy {
            PolicyContent(state: state, colours: colours, controller: controller)
        } else if state.screen == .detail {
            DetailContent(state: state, colours: colours, controller: controller)
        } else if state.screen == .consented {
            ConsentedContent(state: state, colours: colours, controller: controller)
        } else {
            ConsentContent(state: state, colours: colours, controller: controller)
        }
    }
}

/// The title, the language chip when there is a choice, and a close button only when nothing is owed. The bar is the accent,
/// or the surface with a rule under it, as the notice's header style says (the web's `brandHeaderStyle`); core has worked out which.
private struct TitleBar: View {
    let state: ConsentState
    let canClose: Bool
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(title.isEmpty ? state.labels.titleFallback : state.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colours.headerText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !state.languages.isEmpty {
                    LanguageChip(state: state, colours: colours) { controller.setLanguage(code: $0) }
                }
                if canClose {
                    Button(action: controller.dismiss) {
                        Text("✕").font(.system(size: 18)).foregroundColor(colours.headerText).padding(8)
                    }
                    .accessibilityLabel(state.labels.close)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(colours.headerFill)
            if colours.headerRuleWidth > 0 { colours.headerRule.frame(height: colours.headerRuleWidth) }
        }
    }
}

/// The language on screen, as a chip that opens the list of languages the notice is published in.
private struct LanguageChip: View {
    let state: ConsentState
    let colours: Colours
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
                .foregroundColor(colours.headerText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(colours.headerText, lineWidth: 1))
        }
        .accessibilityLabel(state.labels.currentLanguage)
    }
}

private struct Message: View {
    let text: String
    let colours: Colours

    var body: some View {
        Text(text)
            .foregroundColor(colours.text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(32)
    }
}

private struct ErrorCard: View {
    let state: ConsentState
    let colours: Colours
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(state.errorMessage ?? "").foregroundColor(colours.text).multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(state.labels.retry)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colours.buttonText)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 40)
                    .background(Capsule().fill(colours.accent))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

/// The notice text, the two boxes, the words under them and the links scroll; Submit stays pinned at the bottom.
private struct ConsentContent: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackStrip(state: state, colours: colours, controller: controller)
            FittingScroll {
                VStack(alignment: .leading, spacing: 8) {
                    if !state.noticeText.isEmpty {
                        RichText(blocks: state.noticeText, colours: colours).padding(.bottom, 8)
                    }
                    ForEach(state.checkboxes, id: \.side) { box in
                        CheckboxRow(box: box, autoLabel: state.labels.autoOptIn, colours: colours) { controller.toggleGroup(side: box.side) }
                    }
                    if !state.consentText.isEmpty {
                        RichText(blocks: state.consentText, colours: colours).padding(.top, 8)
                    }
                    PageLinks(state: state, colours: colours, controller: controller)
                }
                .padding(16)
            }
            SubmitFooter(
                state: state, colours: colours, controller: controller,
                blockedHint: state.labels.blockedHint, hintColour: colours.hint
            )
        }
    }
}

/// An open that found nothing owed: the consent is on record, for these purposes. The words scroll; the note and the
/// two buttons, side by side, stay pinned at the bottom. Redirect to DSR portal closes the sheet, then opens
/// `continueUrl` when the app gave one (the web's `continueAway`).
private struct ConsentedContent: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController
    @Environment(\.openURL) private var openURL

    var body: some View {
        let labels = state.labels
        VStack(spacing: 0) {
            FittingScroll {
                VStack(spacing: 8) {
                    CheckCircle(colours: colours).padding(.bottom, 8)
                    Text(labels.consentedTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colours.text)
                        .multilineTextAlignment(.center)
                    Text(labels.consentedMessage)
                        .font(.system(size: 14))
                        .foregroundColor(colours.muted)
                        .multilineTextAlignment(.center)
                    if !state.recordedPurposes.isEmpty {
                        Text(labels.recordedFor.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundColor(colours.muted)
                            .padding(.top, 8)
                        Text(state.recordedPurposesText)
                            .font(.system(size: 14))
                            .foregroundColor(colours.link)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            colours.border.frame(height: 1)
            VStack(spacing: 8) {
                if state.hasLocked { LockedNote(labels: labels, colours: colours) }
                // Side by side, as on the web (src/styles/consentedPage.styles.ts, `actions`): neither is a consent
                // signal, so neither needs the full width. A long label wraps inside its own half, and the shorter
                // button grows to match (`fixedSize` below), so the pair stays one row of equal buttons.
                HStack(spacing: 10) {
                    Button { controller.showLanding() } label: {
                        Text(labels.updateConsent)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colours.buttonText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
                            .background(Capsule().fill(colours.accent))
                            .contentShape(Capsule())
                    }
                    Button {
                        controller.dismiss()
                        if let link = state.continueUrl, let url = URL(string: link) { openURL(url) }
                    } label: {
                        Text(labels.redirectToDsr)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colours.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
                            .overlay(Capsule().strokeBorder(colours.unselected, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }
}

/// Why a padlocked control cannot be turned off. Muted, not amber: nothing is wrong, and Submit still works.
private struct LockedNote: View {
    let labels: ConsentLabels
    let colours: Colours

    var body: some View {
        Text(labels.lockedNote)
            .font(.system(size: 12))
            .foregroundColor(colours.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// The padlock beside a control that holds a grant on record (the web's `LockIcon`).
private struct LockMark: View {
    // Muted, so the padlock reads on a dark surface as well as a light one.
    let colours: Colours

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.2).stroke(colours.muted, lineWidth: 1.2)
                .frame(width: 9.4, height: 5.8).offset(y: 2.9)
            Path { path in
                path.move(to: CGPoint(x: 4.7, y: 6.4))
                path.addLine(to: CGPoint(x: 4.7, y: 4.1))
                path.addArc(center: CGPoint(x: 7, y: 4.1), radius: 2.3, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: CGPoint(x: 9.3, y: 6.4))
            }
            .stroke(colours.muted, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}

/// A tick in a circle, in the link colour: the accent where it reads on the surface.
private struct CheckCircle: View {
    let colours: Colours

    var body: some View {
        ZStack {
            Circle().stroke(colours.link, lineWidth: 2.5).padding(1.25)
            Path { path in
                path.move(to: CGPoint(x: 12, y: 20.8))
                path.addLine(to: CGPoint(x: 17.6, y: 26.4))
                path.addLine(to: CGPoint(x: 28.8, y: 14.4))
            }
            .stroke(colours.link, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 40, height: 40)
    }
}

/// Submit, pinned under both consent screens, with a failed save's message above it. `blockedHint` shows under it
/// while a required purpose is still off.
private struct SubmitFooter: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController
    let blockedHint: String
    let hintColour: Color
    /// Under Submit only where a control can carry a padlock: not on the policy screen.
    var lockedNote = true

    var body: some View {
        let saving = state.status == .submitting
        let enabled = !state.isSubmitBlocked && !saving
        VStack(spacing: 8) {
            // A save that failed: the form is as the user left it, and Submit again is the retry.
            if let message = state.errorMessage {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(colours.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            Button(action: controller.submit) {
                ZStack {
                    if saving {
                        ProgressView().progressViewStyle(.circular).tint(colours.buttonText)
                    } else {
                        Text(state.submitLabel ?? state.labels.submitFallback).font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundColor(colours.buttonText)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(colours.accent))
                // Disabled is the same button, faded, as on the web: grey would be nobody's choice.
                .opacity(enabled ? 1 : disabledOpacity)
            }
            .buttonStyle(SubmitButtonStyle())
            .disabled(!enabled)
            if lockedNote && state.hasLocked { LockedNote(labels: state.labels, colours: colours) }
            if state.isSubmitBlocked && !blockedHint.isEmpty {
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

/// Draws the label as it is. The built-in button styles dim a disabled button on their own, on top of the fade above.
private struct SubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct CheckboxRow: View {
    let box: ConsentCheckbox
    let autoLabel: String
    let colours: Colours
    let onToggle: () -> Void

    var body: some View {
        // The row carries the tap and the accessibility state, so the box only draws. A tap on a link in the text
        // opens the link instead.
        HStack(alignment: .top, spacing: 12) {
            CheckMark(state: box.state, isAuto: box.isAuto, colours: colours).padding(.top, 2)
                .opacity(box.isLocked ? inertOpacity : 1)
            RichText(blocks: box.text, colours: colours).frame(maxWidth: .infinity, alignment: .leading)
            if box.isAuto { AutoOptInTag(text: autoLabel, colours: colours).padding(.top, 2) }
            if box.isLocked { LockMark(colours: colours).padding(.top, 4) }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // A locked box takes no taps: every purpose behind it is granted already.
        .onTapGesture { if !box.isLocked { onToggle() } }
        .toggleAccessibility(box.state, locked: box.isLocked, action: onToggle)
    }
}

/// The privacy policy and the purposes the notice covers. The way back stays pinned at the top; the rest scrolls. When
/// the notice shows only this page, Submit is pinned at the bottom, and it grants every purpose.
private struct PolicyContent: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        let labels = state.labels
        VStack(alignment: .leading, spacing: 0) {
            BackStrip(state: state, colours: colours, controller: controller)
            FittingScroll {
                VStack(alignment: .leading, spacing: 8) {
                    Text(labels.policyTitle).font(.system(size: 16, weight: .bold)).foregroundColor(colours.text)
                    if state.policy.text.isEmpty {
                        Text(labels.policyEmpty).font(.system(size: 14)).foregroundColor(colours.muted)
                    } else {
                        RichText(blocks: state.policy.text, colours: colours)
                    }
                    Text(labels.purposesTitle).font(.system(size: 16, weight: .bold)).foregroundColor(colours.text).padding(.top, 8)
                    if state.policy.purposes.isEmpty {
                        Text(labels.purposesEmpty).font(.system(size: 14)).foregroundColor(colours.muted)
                    }
                    if !state.policy.purposes.isEmpty {
                        PurposeLegend(state: state, colours: colours)
                        PurposeList(state: state, colours: colours, controller: controller)
                    }
                    PageLinks(state: state, colours: colours, controller: controller)
                }
                .padding(.horizontal, 16)
                // The way back gives the space above when there is one.
                .padding(.top, state.backLabel == nil ? 16 : 0)
                .padding(.bottom, 16)
            }
            // No hint: nothing on this screen can be left off.
            if state.policyHasSubmit {
                SubmitFooter(
                    state: state, colours: colours, controller: controller,
                    blockedHint: "", hintColour: colours.muted, lockedNote: false
                )
            }
        }
    }
}

/// The same question purpose by purpose: a Required and an Optional block, each with a master switch and a switch per
/// category and purpose. The way back stays pinned at the top and Submit at the bottom; the rest scrolls.
private struct DetailContent: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        let labels = state.labels
        VStack(alignment: .leading, spacing: 0) {
            BackStrip(state: state, colours: colours, controller: controller)
            FittingScroll {
                VStack(alignment: .leading, spacing: 16) {
                    if !state.noticeText.isEmpty { RichText(blocks: state.noticeText, colours: colours) }
                    ForEach(state.blocks, id: \.side) { block in
                        DetailBlock(
                            block: block, state: state, colours: colours,
                            onToggleAll: { controller.toggleGroup(side: block.side) },
                            onToggle: { controller.togglePurpose(side: block.side, id: $0) },
                            onFold: { controller.toggleDetailCategory(side: block.side, id: $0) }
                        )
                    }
                    if !state.consentText.isEmpty { RichText(blocks: state.consentText, colours: colours) }
                    PageLinks(state: state, colours: colours, controller: controller)
                }
                .padding(.horizontal, 16)
                .padding(.top, state.backLabel == nil ? 16 : 0)
            }
            SubmitFooter(
                state: state, colours: colours, controller: controller,
                blockedHint: labels.requiredHint, hintColour: colours.muted
            )
        }
    }
}

private struct DetailBlock: View {
    let block: ConsentBlock
    let state: ConsentState
    let colours: Colours
    let onToggleAll: () -> Void
    let onToggle: (String) -> Void
    let onFold: (String) -> Void

    var body: some View {
        let labels = state.labels
        VStack(alignment: .leading, spacing: 8) {
            let heading = block.side == .required ? labels.required : labels.optional
            SwitchRow(state: block.state, isAuto: block.isAuto, isLocked: block.isLocked, isEnabled: true, colours: colours, onToggle: onToggleAll) {
                HStack(spacing: 8) {
                    Text(heading.uppercased()).font(.system(size: 12, weight: .bold)).tracking(1).foregroundColor(colours.text)
                    if block.isAuto { AutoOptInTag(text: labels.autoOptIn, colours: colours) }
                }
            }
            if !block.text.isEmpty { RichText(blocks: block.text, colours: colours) }
            if block.switches.isEmpty {
                Text(labels.detailEmpty).font(.system(size: 14)).foregroundColor(colours.muted)
            }
            VStack(spacing: 0) {
                ForEach(block.switches, id: \.id) { purpose in
                    colours.border.frame(height: 1)
                    HStack(spacing: 0) {
                        // The arrow sits beside the switch, not in it, so a tap on it folds and does not switch anything.
                        if purpose.hasChildren {
                            Button { onFold(purpose.id) } label: {
                                Text(purpose.isCollapsed ? foldedArrow(state) : "▾")
                                    .font(.system(size: 12)).foregroundColor(colours.muted).frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(state.foldDescription(purpose: purpose))
                        } else {
                            Spacer().frame(width: 28)
                        }
                        SwitchRow(state: purpose.state, isAuto: purpose.isAuto, isLocked: purpose.isLocked, isEnabled: purpose.isEnabled, colours: colours, onToggle: { onToggle(purpose.id) }) {
                            HStack(spacing: 6) {
                                Text(purpose.name)
                                    .font(.system(size: 14, weight: purpose.isCategory ? .semibold : .regular))
                                    .foregroundColor(colours.text)
                                if purpose.showsAutoTag { AutoOptInTag(text: labels.autoOptIn, colours: colours) }
                            }
                            if let description = purpose.description_ {
                                Text(description).font(.system(size: 12)).foregroundColor(colours.muted)
                            }
                        }
                    }
                    .padding(.leading, 16 * CGFloat(purpose.depth))
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

/// A row that is one tri-state switch: the whole row takes the tap and carries the state for screen readers. A
/// locked switch takes no taps and has a padlock before it, and so does one that is not enabled (below the notice's
/// actionable level); both are drawn faded.
private struct SwitchRow<Label: View>: View {
    let state: ToggleState
    let isAuto: Bool
    let isLocked: Bool
    let isEnabled: Bool
    let colours: Colours
    let onToggle: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        let inert = isLocked || !isEnabled
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) { label() }.frame(maxWidth: .infinity, alignment: .leading)
            if isLocked { LockMark(colours: colours) }
            SwitchMark(state: state, isAuto: isAuto, colours: colours).opacity(inert ? inertOpacity : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !inert { onToggle() } }
        .toggleAccessibility(state, locked: inert, action: onToggle)
    }
}

/// How strongly the legend and a category row tint the surface: the border colour, which the theme already tints.
private let tintOpacity: Double = 0.4

/// The key to the purpose list: the bases of processing by number behind a toggle (they are only numbers on the rows),
/// and what the filled and hollow dots mean. Folded until asked for, so it does not take the screen (the web's `AnnexLegend`).
private struct PurposeLegend: View {
    let state: ConsentState
    let colours: Colours
    @State private var open = false

    var body: some View {
        let labels = state.labels
        let bases = state.policy.bases
        let title = "\(labels.basisHeading) (\(bases.count))"
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                if !bases.isEmpty {
                    Button { open.toggle() } label: {
                        Text((open ? "▾ " : foldedArrow(state) + " ") + title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colours.text)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title)
                }
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    SideKey(required: true, text: labels.required, colours: colours)
                    SideKey(required: false, text: labels.optional, colours: colours)
                }
                .fixedSize()
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(labels.consentKey): \(labels.required), \(labels.optional)")
            }
            if open {
                colours.border.frame(height: 1)
                ForEach(Array(bases.enumerated()), id: \.offset) { index, basis in
                    HStack(spacing: 8) {
                        BasisBadge(number: index + 1, colours: colours)
                        Text(basis).font(.system(size: 13)).foregroundColor(colours.text)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(colours.border.opacity(tintOpacity)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colours.border, lineWidth: 1))
    }
}

/// The arrow of a folded category: it points the way the text reads.
private func foldedArrow(_ state: ConsentState) -> String { state.isRtl ? "◂" : "▸" }

private struct SideKey: View {
    let required: Bool
    let text: String
    let colours: Colours

    var body: some View {
        HStack(spacing: 5) {
            SideDot(required: required, colours: colours)
            Text(text).font(.system(size: 12)).foregroundColor(colours.muted)
        }
    }
}

/// Filled for a required purpose, hollow for an optional one: the shape carries the meaning, not the colour.
private struct SideDot: View {
    let required: Bool
    let colours: Colours

    var body: some View {
        // The link colour is the accent where it reads on the surface, so a pale accent never leaves an invisible dot.
        Group {
            if required { Circle().fill(colours.link) } else { Circle().strokeBorder(colours.link, lineWidth: 2) }
        }
        .frame(width: 10, height: 10)
    }
}

/// A purpose's basis of processing as its number in the legend.
private struct BasisBadge: View {
    let number: Int
    let colours: Colours

    var body: some View {
        Text(String(number))
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(colours.text)
            .frame(width: 18, height: 18)
            .background(Circle().fill(colours.link.opacity(0.12)))
            .overlay(Circle().strokeBorder(colours.border, lineWidth: 1))
    }
}

/// The purposes the notice covers, one bordered list. A category is a tinted heading you can fold; a purpose shows its
/// basis number and Required or Optional dot, and under its name what it collects and how it reaches the person
/// (the web's `PurposeCards`).
private struct PurposeList: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.policy.purposes.enumerated()), id: \.offset) { index, row in
                if index > 0 { colours.border.frame(height: 1) }
                if row.side == nil {
                    CategoryRow(row: row, state: state, colours: colours, controller: controller)
                } else {
                    PurposeCard(row: row, state: state, colours: colours)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(colours.border, lineWidth: 1))
    }
}

private struct CategoryRow: View {
    let row: PurposeRow
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        Button { controller.togglePolicyCategory(id: row.id) } label: {
            HStack(spacing: 0) {
                Text(row.isCollapsed ? foldedArrow(state) : "▾")
                    .font(.system(size: 12)).foregroundColor(colours.muted).frame(width: 18, alignment: .leading)
                NameWithConnector(row: row, state: state, weight: .semibold, colours: colours)
                Spacer(minLength: 0)
            }
            .padding(.leading, 10 + 14 * CGFloat(row.depth))
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colours.border.opacity(tintOpacity))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.foldDescription(row: row))
    }
}

private struct PurposeCard: View {
    let row: PurposeRow
    let state: ConsentState
    let colours: Colours

    var body: some View {
        let labels = state.labels
        let required = row.side == .required
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Spacer().frame(width: 10)
                NameWithConnector(row: row, state: state, weight: .regular, colours: colours)
                Spacer(minLength: 0)
                if row.basisNumber > 0 {
                    BasisBadge(number: Int(row.basisNumber), colours: colours)
                        .accessibilityLabel(state.basisDescription(row: row))
                }
                SideDot(required: required, colours: colours)
                    .accessibilityLabel(required ? labels.required : labels.optional)
            }
            VStack(alignment: .leading, spacing: 4) {
                PurposeDetail(label: labels.dataElements, values: row.dataElements, none: labels.noDataElements, colours: colours)
                PurposeDetail(label: labels.channels, values: row.channels, none: labels.noChannels, colours: colours)
            }
            .padding(.leading, 18)
        }
        .padding(.leading, 10 + 14 * CGFloat(row.depth))
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A name set in under its category, with the connector that shows how deep it is.
private struct NameWithConnector: View {
    let row: PurposeRow
    let state: ConsentState
    let weight: Font.Weight
    let colours: Colours

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if row.depth > 0 {
                Text(state.isRtl ? "┘" : "└").font(.system(size: 14)).foregroundColor(colours.muted)
            }
            Text(row.name).font(.system(size: 14, weight: weight)).foregroundColor(colours.text)
        }
    }
}

/// A label and the chips beside it, which wrap onto more lines and are never cut to "+n more": the data elements are what
/// the notice must list. A purpose with none says so in a dashed chip, so an empty space is never read as "not told".
private struct PurposeDetail: View {
    let label: String
    let values: [String]
    let none: String
    let colours: Colours

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).font(.system(size: 11)).foregroundColor(colours.muted)
                .frame(maxWidth: 110, alignment: .leading).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            if values.isEmpty {
                Chip(text: none, empty: true, colours: colours)
                Spacer(minLength: 0)
            } else {
                Chips(values: values, colours: colours)
            }
        }
    }
}

/// "Auto opt-in", beside the topmost control the notice turned on. Dashed like the control it describes, so the two read
/// as one cue; the dashes alone mark the controls beneath it (the web's `AutoOptInTag`).
private struct AutoOptInTag: View {
    let text: String
    let colours: Colours

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(colours.autoTag)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(colours.selected, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .fixedSize()
    }
}

private struct Chip: View {
    let text: String
    let empty: Bool
    let colours: Colours

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(empty ? colours.muted : colours.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(empty ? nil : Capsule().fill(colours.border))
            .overlay(empty ? Capsule().strokeBorder(colours.muted, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) : nil)
    }
}

/// Chips that wrap onto as many lines as they need. SwiftUI's own wrapping layout needs iOS 16 and this package supports
/// 15, so each chip is placed with alignment guides and the container takes the height the lines add up to.
private struct Chips: View {
    let values: [String]
    let colours: Colours
    @State private var height: CGFloat = 0

    var body: some View {
        var width: CGFloat = 0
        var rowTop: CGFloat = 0
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Chip(text: value, empty: false, colours: colours)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                        .alignmentGuide(.leading) { dimensions in
                            if abs(width - dimensions.width) > geometry.size.width {
                                width = 0
                                rowTop -= dimensions.height
                            }
                            let place = width
                            width = index == values.count - 1 ? 0 : width - dimensions.width
                            return place
                        }
                        .alignmentGuide(.top) { _ in
                            let place = rowTop
                            if index == values.count - 1 { rowTop = 0 }
                            return place
                        }
                }
            }
            .background(GeometryReader { Color.clear.preference(key: ChipsHeight.self, value: $0.size.height) })
        }
        .frame(height: height)
        .onPreferenceChange(ChipsHeight.self) { height = $0 }
    }
}

private struct ChipsHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// The arrow on the way back points the way the sheet reads. Compose's text engine mirrors it in a right-to-left
// language; iOS draws it as written, so it is swapped here.
private func back(_ state: ConsentState) -> String { state.isRtl ? "›" : "‹" }

private struct BackStrip: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        if let label = state.backLabel {
            LinkText(text: back(state) + " " + label, colours: colours) { controller.showLanding() }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
        }
    }
}

/// The links to the notice's other pages, by name. Nothing when there is none to go to.
private struct PageLinks: View {
    let state: ConsentState
    let colours: Colours
    let controller: ConsentController

    var body: some View {
        if !state.pageLinks.isEmpty {
            HStack(spacing: 16) {
                ForEach(state.pageLinks, id: \.screen) { link in
                    LinkText(text: link.label, colours: colours) { controller.show(screen: link.screen) }
                }
            }
        }
    }
}

/// Text in the link colour that moves between screens.
private struct LinkText: View {
    let text: String
    let colours: Colours
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundColor(colours.link).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// What an on or partly on control is filled with, and the tick, dash or knob on it (the web's `fillFor`, `markerOn`).
// A control the notice turned on by auto opt-in is filled like any other on control: the dashed outline is its cue.
private func fillOf(_ state: ToggleState, _ colours: Colours) -> Color {
    state == .partial ? colours.partial : colours.selected
}

private func markerOf(_ state: ToggleState, _ colours: Colours) -> Color {
    state == .partial ? colours.onPartial : colours.onSelected
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
    let colours: Colours

    var body: some View {
        let on = state != .off
        let fill = fillOf(state, colours)
        let marker = markerOf(state, colours)
        ZStack {
            Outlined(shape: RoundedRectangle(cornerRadius: 4), fill: on ? fill : nil, border: on ? fill : colours.unselected, isAuto: isAuto && on)
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
    let colours: Colours

    var body: some View {
        let on = state != .off
        let fill = fillOf(state, colours)
        let marker = markerOf(state, colours)
        ZStack(alignment: on ? .trailing : .leading) {
            Outlined(shape: Capsule(), fill: on ? fill : colours.border, border: on ? fill : colours.unselected, isAuto: isAuto && on)
            Circle().fill(on ? marker : .white).frame(width: 14, height: 14).padding(3)
        }
        .frame(width: 36, height: 20)
    }
}

private extension View {
    /// The tri-state toggle for screen readers: a button that is selected when on or partly on. A locked one does
    /// nothing; it is not `.disabled`, which would also stop the links in a box's text.
    func toggleAccessibility(_ state: ToggleState, locked: Bool, action: @escaping () -> Void) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityAddTraits(state == .off ? .isButton : [.isButton, .isSelected])
            .accessibilityAction(.default) { if !locked { action() } }
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
