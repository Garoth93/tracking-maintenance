import SwiftUI
import UpkeepCore

// MARK: - Surfaces

/// Material 3 card: tonal surface, large continuous corners.
struct M3Card<Content: View>: View {
    @Environment(\.m3) private var m3
    var color: Color?
    var padding: CGFloat
    var corner: CGFloat
    let content: Content

    init(color: Color? = nil, padding: CGFloat = 16, corner: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.color = color
        self.padding = padding
        self.corner = corner
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color ?? m3.surfaceContainerLow, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// Scalloped "cookie" shape from the Material 3 Expressive shape set.
struct CookieShape: Shape {
    var lobes: Int = 9
    var depth: CGFloat = 0.06

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2
        let r0 = base * (1 - depth)
        var p = Path()
        let steps = 240
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi - .pi / 2
            let r = r0 + base * depth * cos(Double(lobes) * a)
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Icon on a tonal rounded square.
struct IconBadge: View {
    let icon: String
    let tones: Tones
    var size: CGFloat = 44
    var cookie = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tones.onContainer)
            .frame(width: size, height: size)
            .background {
                if cookie {
                    CookieShape().fill(tones.container)
                } else {
                    RoundedRectangle(cornerRadius: size * 0.34, style: .continuous).fill(tones.container)
                }
            }
    }
}

struct SectionTitle: View {
    @Environment(\.m3) private var m3
    let title: String
    var trailing: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.m3TitleMedium)
                .foregroundStyle(m3.onSurface)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.m3LabelLarge)
                    .foregroundStyle(m3.primary)
            } else if let trailing {
                Text(trailing)
                    .font(.m3LabelLarge)
                    .foregroundStyle(m3.onSurfaceVariant)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }
}

struct EmptyStateView: View {
    @Environment(\.m3) private var m3
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(m3.onPrimaryContainer)
                .frame(width: 96, height: 96)
                .background(CookieShape().fill(m3.primaryContainer))
            Text(title)
                .font(.m3TitleLarge)
                .foregroundStyle(m3.onSurface)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.m3BodyMedium)
                .foregroundStyle(m3.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Buttons

struct M3ButtonStyle: ButtonStyle {
    enum Kind { case filled, tonal, outlined, text, danger }

    @Environment(\.m3) private var m3
    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .m3LabelMedium : .m3LabelLarge)
            .lineLimit(1)
            .padding(.horizontal, kind == .text ? 12 : (compact ? 14 : 22))
            .frame(minHeight: compact ? 34 : 46)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay {
                if kind == .outlined { Capsule().strokeBorder(m3.outlineVariant, lineWidth: 1) }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .filled: return m3.onPrimary
        case .tonal: return m3.onSecondaryContainer
        case .outlined, .text: return m3.primary
        case .danger: return m3.onErrorContainer
        }
    }

    private var background: Color {
        switch kind {
        case .filled: return m3.primary
        case .tonal: return m3.secondaryContainer
        case .outlined, .text: return .clear
        case .danger: return m3.errorContainer
        }
    }
}

extension ButtonStyle where Self == M3ButtonStyle {
    static var m3Filled: M3ButtonStyle { M3ButtonStyle(kind: .filled) }
    static var m3Tonal: M3ButtonStyle { M3ButtonStyle(kind: .tonal) }
    static var m3Outlined: M3ButtonStyle { M3ButtonStyle(kind: .outlined) }
    static var m3Text: M3ButtonStyle { M3ButtonStyle(kind: .text) }
    static var m3Danger: M3ButtonStyle { M3ButtonStyle(kind: .danger) }
    static var m3TonalSmall: M3ButtonStyle { M3ButtonStyle(kind: .tonal, compact: true) }
    static var m3FilledSmall: M3ButtonStyle { M3ButtonStyle(kind: .filled, compact: true) }
}

/// Plain press feedback for custom tappable surfaces.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }
}

/// Floating action button (extended when it has a label).
struct FAB: View {
    @Environment(\.m3) private var m3
    let icon: String
    var label: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                if let label {
                    Text(label).font(.m3LabelLarge)
                }
            }
            .padding(.horizontal, label == nil ? 0 : 20)
            .frame(minWidth: 60, minHeight: 60)
            .foregroundStyle(m3.onPrimaryContainer)
            .background(m3.primaryContainer, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(m3.dark ? 0.4 : 0.16), radius: 10, y: 5)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label ?? "Aggiungi")
    }
}

// MARK: - Chips

struct FilterChip: View {
    @Environment(\.m3) private var m3
    let label: String
    var icon: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(label).font(.m3LabelLarge).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundStyle(selected ? m3.onSecondaryContainer : m3.onSurfaceVariant)
            .background(selected ? m3.secondaryContainer : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.clear : m3.outlineVariant, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(duration: 0.25), value: selected)
    }
}

struct StatusPill: View {
    @Environment(\.m3) private var m3
    let status: DueStatus
    var text: String?

    var body: some View {
        let t = m3.tones(for: status)
        HStack(spacing: 5) {
            Circle().fill(t.accent).frame(width: 7, height: 7)
            Text(text ?? status.label)
        }
        .font(.m3LabelMedium)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .foregroundStyle(t.onContainer)
        .background(t.container, in: Capsule())
    }
}

// MARK: - Progress

struct M3Progress: View {
    let value: Double
    let color: Color
    let track: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { g in
            let v = min(1, max(0, value))
            HStack(spacing: v > 0 && v < 1 ? 4 : 0) {
                if v > 0 {
                    Capsule().fill(color).frame(width: max(height, (g.size.width - 4) * v))
                }
                if v < 1 {
                    Capsule().fill(track)
                }
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.5), value: value)
    }
}

// MARK: - Inputs

/// Filled text-field container with a small label (Material 3 style).
struct M3FieldBox<Content: View>: View {
    @Environment(\.m3) private var m3
    let label: String
    var icon: String?
    var focused = false
    let content: Content

    init(_ label: String, icon: String? = nil, focused: Bool = false, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.focused = focused
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(focused ? m3.primary : m3.onSurfaceVariant)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.m3LabelMedium)
                    .foregroundStyle(focused ? m3.primary : m3.onSurfaceVariant)
                content
                    .font(.m3BodyLarge)
                    .foregroundStyle(m3.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .background(m3.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focused ? m3.primary : Color.clear, lineWidth: 2)
        }
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

struct M3TextField: View {
    @Environment(\.m3) private var m3
    let label: String
    @Binding var text: String
    var icon: String?
    var placeholder = ""
    var suffix: String?
    var keyboard: UIKeyboardType = .default
    var multiline = false
    @FocusState private var focused: Bool

    var body: some View {
        M3FieldBox(label, icon: icon, focused: focused) {
            HStack(spacing: 6) {
                Group {
                    if multiline {
                        TextField(placeholder, text: $text, axis: .vertical)
                            .lineLimit(2...6)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboard)
                .focused($focused)
                .tint(m3.primary)
                if let suffix, !suffix.isEmpty {
                    Text(suffix)
                        .font(.m3BodyMedium)
                        .foregroundStyle(m3.onSurfaceVariant)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

struct M3DateField: View {
    let label: String
    @Binding var day: DayDate
    var icon = "calendar"

    var body: some View {
        M3FieldBox(label, icon: icon) {
            DatePicker(label, selection: DayDate.binding($day), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "it_IT"))
        }
    }
}

/// Material 3 switch.
struct M3SwitchStyle: ToggleStyle {
    @Environment(\.m3) private var m3

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? m3.primary : m3.surfaceContainerHighest)
                        .overlay {
                            Capsule().strokeBorder(configuration.isOn ? Color.clear : m3.outline, lineWidth: 2)
                        }
                        .frame(width: 52, height: 32)
                    Circle()
                        .fill(configuration.isOn ? m3.onPrimary : m3.outline)
                        .frame(width: configuration.isOn ? 24 : 16, height: configuration.isOn ? 24 : 16)
                        .overlay {
                            if configuration.isOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(m3.primary)
                            }
                        }
                        .padding(configuration.isOn ? 4 : 8)
                }
                .animation(.spring(duration: 0.28, bounce: 0.3), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == M3SwitchStyle {
    static var m3: M3SwitchStyle { M3SwitchStyle() }
}

/// A row with title/subtitle and a trailing view, used in setting cards.
struct M3Row<Trailing: View>: View {
    @Environment(\.m3) private var m3
    let title: String
    var subtitle: String?
    var icon: String?
    let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, icon: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(m3.onSurfaceVariant)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.m3BodyLarge).foregroundStyle(m3.onSurface)
                if let subtitle {
                    Text(subtitle).font(.m3BodySmall).foregroundStyle(m3.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// − value + control.
struct M3Stepper: View {
    @Environment(\.m3) private var m3
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var format: (Int) -> String = { String($0) }

    var body: some View {
        HStack(spacing: 4) {
            button("minus", enabled: value - step >= range.lowerBound) { value = max(range.lowerBound, value - step) }
            Text(format(value))
                .font(.m3LabelLarge.monospacedDigit())
                .foregroundStyle(m3.onSurface)
                .frame(minWidth: 54)
                .contentTransition(.numericText())
            button("plus", enabled: value + step <= range.upperBound) { value = min(range.upperBound, value + step) }
        }
        .animation(.snappy, value: value)
    }

    private func button(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .foregroundStyle(m3.onSecondaryContainer)
                .background(m3.secondaryContainer, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Layout

/// Wrapping horizontal layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Screen scaffolding

/// Large Material headline used at the top of each tab.
struct ScreenHeader: View {
    @Environment(\.m3) private var m3
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.m3HeadlineLarge)
                .foregroundStyle(m3.onSurface)
            if let subtitle {
                Text(subtitle)
                    .font(.m3BodyMedium)
                    .foregroundStyle(m3.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.horizontal, 4)
    }
}

extension View {
    /// Standard background of every screen.
    func m3Screen(_ m3: M3Theme) -> some View {
        background(m3.surface.ignoresSafeArea())
    }

    /// Material-styled sheet content background.
    func m3Sheet(_ m3: M3Theme) -> some View {
        presentationBackground(m3.surfaceContainerLow)
            .presentationCornerRadius(32)
            .presentationDragIndicator(.visible)
    }
}
