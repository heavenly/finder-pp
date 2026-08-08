import SwiftUI

struct PathBar: View {
    let url: URL
    let onNavigate: (URL) -> Void
    let onSubmit: (String) -> Void

    @State private var isEditing = false
    @State private var pathText = ""
    @FocusState private var pathFieldIsFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("Path", text: $pathText)
                    .textFieldStyle(.plain)
                    .focused($pathFieldIsFocused)
                    .onSubmit {
                        onSubmit(pathText)
                        isEditing = false
                    }
                    .onExitCommand {
                        isEditing = false
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(ancestors.enumerated()), id: \.element) { index, ancestor in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Button(ancestor.path == "/" ? "Mac" : ancestor.lastPathComponent) {
                                onNavigate(ancestor)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    beginEditing()
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.separator, lineWidth: 1)
        }
        .onChange(of: url) {
            pathText = url.path
        }
        .onAppear {
            pathText = url.path
        }
    }

    private var ancestors: [URL] {
        let components = url.standardizedFileURL.pathComponents
        var result = [URL(fileURLWithPath: "/", isDirectory: true)]
        var current = result[0]

        for component in components.dropFirst() {
            current.appendPathComponent(component, isDirectory: true)
            result.append(current)
        }
        return result
    }

    private func beginEditing() {
        pathText = url.path
        isEditing = true
        pathFieldIsFocused = true
    }
}
