import SwiftUI
import UpkeepCore

/// Sheet with Annulla / Salva and a Material form body.
struct SheetScaffold<Content: View>: View {
    @Environment(\.m3) private var m3
    @Environment(\.dismiss) private var dismiss
    let title: String
    var saveTitle = "Salva"
    var canSave = true
    let onSave: () -> Void
    let content: Content

    init(_ title: String, saveTitle: String = "Salva", canSave: Bool = true, onSave: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.saveTitle = saveTitle
        self.canSave = canSave
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(m3.surfaceContainerLow.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) { onSave() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .m3Sheet(m3)
    }
}

/// Titled group inside a form.
struct FormSection<Content: View>: View {
    @Environment(\.m3) private var m3
    let title: String
    var footer: String?
    let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.m3LabelMedium)
                .tracking(0.8)
                .foregroundStyle(m3.primary)
                .padding(.horizontal, 4)
            content
            if let footer {
                Text(footer)
                    .font(.m3BodySmall)
                    .foregroundStyle(m3.onSurfaceVariant)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A card that groups toggles/rows on the sheet background.
struct FormCard<Content: View>: View {
    @Environment(\.m3) private var m3
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(m3.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Grid of SF Symbols.
struct IconPicker: View {
    @Environment(\.m3) private var m3
    @Binding var selection: String
    var tint: String

    var body: some View {
        let tones = m3.tones(tint)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(Palette.icons, id: \.self) { icon in
                let selected = icon == selection
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(selected ? tones.onContainer : m3.onSurfaceVariant)
                        .background(selected ? tones.container : m3.surfaceContainerHighest,
                                    in: RoundedRectangle(cornerRadius: selected ? 23 : 14, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .animation(.spring(duration: 0.3), value: selected)
                .accessibilityLabel(icon)
            }
        }
    }
}

/// Palette swatches plus a custom color picker.
struct ColorRow: View {
    @Environment(\.m3) private var m3
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Palette.colors, id: \.self) { hex in
                    let selected = hex.lowercased() == selection.lowercased()
                    Button {
                        selection = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 38, height: 38)
                            .overlay {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(3)
                            .overlay(Circle().strokeBorder(selected ? m3.onSurface : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(PressableStyle())
                }
                ColorPicker("Personalizzato", selection: Binding(
                    get: { Color(hex: selection) },
                    set: { if let hex = $0.hexString { selection = hex } }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 2)
        }
    }
}

/// Editor for the custom fields of a type.
struct FieldsEditor: View {
    @Environment(\.m3) private var m3
    @Binding var fields: [FieldDefinition]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(fields) { field in
                HStack(spacing: 8) {
                    TextField("Nome campo", text: nameBinding(field.id))
                        .font(.m3BodyLarge)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(m3.surfaceContainerHighest, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Menu {
                        ForEach(FieldKind.allCases, id: \.self) { kind in
                            Button(kind.label) { setKind(kind, id: field.id) }
                        }
                    } label: {
                        Text(field.kind.label)
                            .font(.m3LabelLarge)
                            .padding(.horizontal, 12)
                            .frame(height: 48)
                            .foregroundStyle(m3.onSecondaryContainer)
                            .background(m3.secondaryContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button {
                        let id = field.id
                        withAnimation(.snappy) { fields.removeAll { $0.id == id } }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(m3.error)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rimuovi campo")
                }
            }
            Button {
                withAnimation(.snappy) { fields.append(FieldDefinition(name: "")) }
            } label: {
                Label("Aggiungi campo", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.m3Outlined)
        }
    }

    private func nameBinding(_ id: String) -> Binding<String> {
        Binding(
            get: { fields.first { $0.id == id }?.name ?? "" },
            set: { value in
                if let i = fields.firstIndex(where: { $0.id == id }) { fields[i].name = value }
            }
        )
    }

    private func setKind(_ kind: FieldKind, id: String) {
        if let i = fields.firstIndex(where: { $0.id == id }) { fields[i].kind = kind }
    }
}

/// Text value of a custom field, with a numeric keyboard for number fields.
struct AttributeField: View {
    let field: FieldDefinition
    @Binding var values: [String: String]

    var body: some View {
        M3TextField(
            label: field.name.isEmpty ? "Campo" : field.name,
            text: Binding(
                get: { values[field.id] ?? "" },
                set: { values[field.id] = $0 }
            ),
            icon: field.kind == .number ? "number" : "text.alignleft",
            keyboard: field.kind == .number ? .decimalPad : .default
        )
    }
}
