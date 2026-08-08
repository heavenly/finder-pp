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
        .focusedSceneValue(\.browserModel, model)
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

            Divider()
                .frame(height: 18)

            Button(action: createFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder")

            Button(action: renameSelectedItem) {
                Image(systemName: "pencil")
            }
            .disabled(!model.canRename)
            .help("Rename")

            Button(action: model.copySelectedItems) {
                Image(systemName: "doc.on.doc")
            }
            .disabled(!model.hasSelection)
            .help("Copy")

            Button(action: model.cutSelectedItems) {
                Image(systemName: "scissors")
            }
            .disabled(!model.hasSelection)
            .help("Cut")

            Button(action: { model.pasteItems() }) {
                Image(systemName: "clipboard")
            }
            .help("Paste")

            Button(action: model.moveSelectedItemsToTrash) {
                Image(systemName: "trash")
            }
            .disabled(!model.hasSelection)
            .help("Move to Trash")
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
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            model.open(entry.url)
                        }
                )
                .contextMenu {
                    Button("Open") {
                        model.open(entry.url)
                    }

                    Divider()

                    Button("Cut") {
                        selectForContextMenu(entry.url)
                        model.cutSelectedItems()
                    }
                    Button("Copy") {
                        selectForContextMenu(entry.url)
                        model.copySelectedItems()
                    }
                    Button("Paste") {
                        model.pasteItems(to: entry.isDirectory ? entry.url : model.currentURL)
                    }

                    Divider()

                    Button("Rename") {
                        selectForContextMenu(entry.url)
                        renameSelectedItem()
                    }
                    Button("Move to Trash") {
                        selectForContextMenu(entry.url)
                        model.moveSelectedItemsToTrash()
                    }
                }
                .draggable(entry.url) {
                    Label(entry.name, systemImage: entry.isDirectory ? "folder.fill" : "doc")
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .dropDestination(for: URL.self) { urls, _ in
                    moveDroppedItems(urls, onto: entry)
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
        .contextMenu {
            Button("New Folder", action: createFolder)
            Button("Paste", action: { model.pasteItems() })
            Divider()
            Button("Refresh", action: model.reload)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private func createFolder() {
        guard let name = FileNamePrompt.show(
            title: "New Folder",
            message: "Enter a name for the new folder.",
            defaultValue: "New Folder"
        ) else { return }
        model.createFolder(named: name)
    }

    private func renameSelectedItem() {
        guard let item = model.selectedURLs.first else { return }
        guard let name = FileNamePrompt.show(
            title: "Rename",
            message: "Enter a new name for “\(item.lastPathComponent)”.",
            defaultValue: item.lastPathComponent
        ) else { return }
        model.renameSelectedItem(to: name)
    }

    private func selectForContextMenu(_ url: URL) {
        if !model.selectedURLs.contains(url) {
            model.selectedURLs = [url]
        }
    }

    private func moveDroppedItems(_ urls: [URL], onto entry: FileEntry) -> Bool {
        guard entry.isDirectory else { return false }
        return model.move(urls, to: entry.url)
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
