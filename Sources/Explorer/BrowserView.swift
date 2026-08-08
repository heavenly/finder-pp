import AppKit
import SwiftUI

struct BrowserView: View {
    @State private var model = BrowserModel()
    @State private var isCurrentFolderTargeted = false

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
        } detail: {
            VStack(spacing: 0) {
                navigationBar
                Divider()
                fileHeader
                Divider()
                fileList
            }
        }
        .navigationTitle(model.currentURL.lastPathComponent.isEmpty ? "Mac" : model.currentURL.lastPathComponent)
        .alert("Explorer", isPresented: errorIsPresented) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .explorerFilesDidMove)) { _ in
            model.reload()
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            Button(action: model.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canGoBack)
            .help("Back")

            Button(action: model.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canGoForward)
            .help("Forward")

            Button(action: model.goUp) {
                Image(systemName: "arrow.up")
            }
            .disabled(!model.canGoUp)
            .help("Up one folder")

            PathBar(
                url: model.currentURL,
                onNavigate: model.navigate,
                onSubmit: model.navigate(toPath:)
            )

            Button(action: model.reload) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .buttonStyle(.borderless)
        .padding(10)
        .background(.bar)
    }

    private var fileHeader: some View {
        HStack(spacing: 12) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Date modified")
                .frame(width: 150, alignment: .leading)
            Text("Type")
                .frame(width: 110, alignment: .leading)
            Text("Size")
                .frame(width: 90, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var fileList: some View {
        List(model.entries, selection: $model.selectedURLs) { entry in
            FileRow(entry: entry)
                .tag(entry.url)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    model.open(entry.url)
                }
                .draggable(entry.url) {
                    Label(entry.name, systemImage: entry.isDirectory ? "folder.fill" : "doc")
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .dropDestination(for: URL.self) { urls, _ in
                    guard entry.isDirectory else { return false }
                    return model.move(urls, to: entry.url)
                }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if model.entries.isEmpty {
                ContentUnavailableView(
                    "This folder is empty",
                    systemImage: "folder",
                    description: Text("Drag files here to move them into this folder.")
                )
            }
        }
        .background(isCurrentFolderTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        .dropDestination(for: URL.self) { urls, _ in
            model.move(urls, to: model.currentURL)
        } isTargeted: { isTargeted in
            isCurrentFolderTargeted = isTargeted
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

private struct FileRow: View {
    let entry: FileEntry

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(entry.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.formattedDate)
                .frame(width: 150, alignment: .leading)
            Text(entry.kind)
                .frame(width: 110, alignment: .leading)
            Text(entry.formattedSize)
                .frame(width: 90, alignment: .trailing)
        }
        .font(.callout)
        .padding(.vertical, 2)
    }
}

private struct Sidebar: View {
    let model: BrowserModel

    private struct Location: Identifiable {
        let name: String
        let symbol: String
        let url: URL

        var id: URL { url }
    }

    private var locations: [Location] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Location(name: "Home", symbol: "house", url: home),
            Location(name: "Desktop", symbol: "desktopcomputer", url: home.appendingPathComponent("Desktop", isDirectory: true)),
            Location(name: "Documents", symbol: "doc", url: home.appendingPathComponent("Documents", isDirectory: true)),
            Location(name: "Downloads", symbol: "arrow.down.circle", url: home.appendingPathComponent("Downloads", isDirectory: true)),
            Location(name: "Applications", symbol: "square.grid.2x2", url: URL(fileURLWithPath: "/Applications", isDirectory: true))
        ]
    }

    var body: some View {
        List {
            Section("Quick access") {
                ForEach(locations) { location in
                    Button {
                        model.navigate(to: location.url)
                    } label: {
                        Label(location.name, systemImage: location.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 190)
    }
}
