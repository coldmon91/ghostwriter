import SwiftUI

struct StatusBarView: View {
    @ObservedObject var editorVM: EditorViewModel

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            Divider().frame(height: 12)
            Text("\(editorVM.content.count)자")
                .font(.caption)
            Spacer()
            Text("UTF-8")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            switch editorVM.aiStatus {
            case .idle:
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("AI 준비됨").font(.caption)
            case .requesting:
                ProgressView().controlSize(.mini)
                Text("호출 중…").font(.caption)
            case .error(let message):
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text("오류").font(.caption).foregroundStyle(.red)
                    .help(message)
            }
        }
    }
}
