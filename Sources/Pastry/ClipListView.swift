import SwiftUI

final class PanelState: ObservableObject {
    @Published var selected = 0
    /// Last mouse position seen by a hover. Rows sliding under a still cursor
    /// (keyboard scrolling) fire hovers too; those must not steal the selection.
    var lastMouse = NSEvent.mouseLocation
}

struct ClipListView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var state: PanelState
    let onPick: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pastry").font(.system(size: 13, weight: .semibold))
                Spacer()
                if !store.items.isEmpty {
                    Button("Clear all") { store.clear() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(nsImage: PancakeGlyph.image(points: 40))
                        .renderingMode(.template)
                    Text("Nothing on the plate yet")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Copy something to start a stack")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                ClipRow(item: item, selected: index == state.selected)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onPick(item) }
                                    .onHover { inside in
                                        let mouse = NSEvent.mouseLocation
                                        guard inside, mouse != state.lastMouse else { return }
                                        state.lastMouse = mouse
                                        state.selected = index
                                    }
                                    .contextMenu {
                                        Button("Paste") { onPick(item) }
                                        Button("Delete") { store.remove(item) }
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: state.selected) { index in
                        guard store.items.indices.contains(index) else { return }
                        withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(store.items[index].id) }
                    }
                }
            }
        }
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let selected: Bool

    var body: some View {
        Group {
            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06))
        )
    }
}
