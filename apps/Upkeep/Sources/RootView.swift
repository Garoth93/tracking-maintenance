import SwiftUI
import UpkeepCore

enum Route: Hashable {
    case asset(String)
    case assetTypes
    case operationTypes
}

struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .asset(let id): AssetDetailView(assetID: id)
        case .assetTypes: AssetTypesView()
        case .operationTypes: OperationTypesView()
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3
    @State private var paths: [AppTab: [Route]] = [:]

    var body: some View {
        // The navigation bar is stacked below the content (not inset over it), so every
        // screen — and its floating "+" button — ends exactly above the bar.
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    let active = store.selectedTab == tab
                    NavigationStack(path: pathBinding(tab)) {
                        tabRoot(tab)
                            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
                    }
                    .opacity(active ? 1 : 0)
                    .allowsHitTesting(active)
                    .accessibilityHidden(!active)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Snackbar above the floating button of the current screen.
            .overlay(alignment: .bottom) { ToastView().padding(.bottom, 88) }

            M3NavigationBar(selection: Binding(
                get: { store.selectedTab },
                set: { tab in
                    if tab == store.selectedTab {
                        paths[tab] = []
                    } else {
                        store.selectedTab = tab
                    }
                }
            ), badges: [.deadlines: urgentCount])
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(duration: 0.35), value: store.toast?.id)
        .sensoryFeedback(.success, trigger: store.successCount)
        .alert(
            "Attenzione",
            isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .background(m3.surface.ignoresSafeArea())
    }

    private var urgentCount: Int {
        store.data.deadlines(today: store.today).filter { $0.status != .ok }.count
    }

    private func pathBinding(_ tab: AppTab) -> Binding<[Route]> {
        Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 })
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .objects: HomeView()
        case .deadlines: DeadlinesView()
        case .expenses: ExpensesView()
        case .settings: SettingsView()
        }
    }
}

/// Material 3 navigation bar with the pill indicator.
struct M3NavigationBar: View {
    @Environment(\.m3) private var m3
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let selected = selection == tab
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.25)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selected {
                                Capsule()
                                    .fill(m3.secondaryContainer)
                                    .matchedGeometryEffect(id: "pill", in: indicator)
                            }
                            Image(systemName: selected ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 19, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? m3.onSecondaryContainer : m3.onSurfaceVariant)
                                .symbolEffect(.bounce, value: selected)
                        }
                        .frame(width: 60, height: 32)
                        .overlay(alignment: .topTrailing) {
                            if let n = badges[tab], n > 0 {
                                Text("\(n)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(m3.onPrimary)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(m3.error, in: Capsule())
                                    .offset(x: -6, y: -2)
                            }
                        }
                        Text(tab.title)
                            .font(.m3LabelMedium)
                            .foregroundStyle(selected ? m3.onSurface : m3.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(m3.surfaceContainer.ignoresSafeArea(edges: .bottom))
    }
}

/// Material snackbar.
struct ToastView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.m3) private var m3

    var body: some View {
        if let toast = store.toast {
            HStack(spacing: 12) {
                Text(toast.text)
                    .font(.m3BodyMedium)
                    .foregroundStyle(m3.surface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if toast.undo != nil {
                    Button("Annulla") { store.performUndo() }
                        .font(.m3LabelLarge)
                        .foregroundStyle(m3.inversePrimary)
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(m3.onSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
            .onTapGesture { store.dismissToast(id: toast.id) }
        }
    }
}
