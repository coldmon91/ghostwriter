import SwiftUI

struct TabBarView: View {
    @ObservedObject var tabsVM: TabsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabsVM.documents) { doc in
                    TabChip(
                        title: doc.displayTitle,
                        isSelected: doc.id == tabsVM.selectedID,
                        canClose: tabsVM.documents.count > 1,
                        onSelect: { tabsVM.select(id: doc.id) },
                        onClose: { tabsVM.closeTab(id: doc.id) }
                    )
                }
                Button {
                    tabsVM.newTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderless)
                .help("새 탭")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TabChip: View {
    let title: String
    let isSelected: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: 160, alignment: .leading)
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.borderless)
                .opacity(0.6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
