import AppKit
import SwiftUI

struct BrowserView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(FolderSizeIndex.self) private var folderSizeIndex
    @State private var model = BrowserModel()
    @State private var isCurrentFolderTargeted = false
    @State private var selectionAnchor: URL?
    @FocusState private var searchFieldIsFocused: Bool

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model, favorites: favorites)
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
        .alert("ExplorerPP", isPresented: errorIsPresented) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .explorerFilesDidMove)) { _ in
            model.reload()
        }
        .onChange(of: model.entries) {
            folderSizeIndex.index(model.entries)
        }
        .onAppear {
            folderSizeIndex.index(model.entries)
        }
        .onChange(of: model.isFindPresented) {
            searchFieldIsFocused = model.isFindPresented
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            ExplorerToolbarButton(
                symbol: "chevron.left",
                help: "Back",
                isDisabled: !model.canGoBack,
                action: model.goBack
            )

            ExplorerToolbarButton(
                symbol: "chevron.right",
                help: "Forward",
                isDisabled: !model.canGoForward,
                action: model.goForward
            )

            ExplorerToolbarButton(
                symbol: "arrow.up",
                help: "Up one folder",
                isDisabled: !model.canGoUp,
                action: model.goUp
            )

            PathBar(
                url: model.currentURL,
                onNavigate: model.navigate,
                onSubmit: model.navigate(toPath:)
            )

            ExplorerToolbarButton(
                symbol: "arrow.clockwise",
                help: "Refresh",
                action: model.reload
            )

            if model.isFindPresented {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Find in this folder", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFieldIsFocused)
                        .onExitCommand(perform: closeFind)
                    Button(action: closeFind) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 7)
                .frame(width: 210, height: 28)
                .background(.background, in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.separator, lineWidth: 1)
                }
            }

            ToolbarSeparator()

            ExplorerToolbarButton(
                symbol: "folder.badge.plus",
                help: "New Folder",
                action: createFolder
            )

            ExplorerToolbarButton(
                symbol: "pencil",
                help: "Rename",
                isDisabled: !model.canRename,
                action: renameSelectedItem
            )

            ExplorerToolbarButton(
                symbol: "doc.on.doc",
                help: "Copy",
                isDisabled: !model.hasSelection,
                action: model.copySelectedItems
            )

            ExplorerToolbarButton(
                symbol: "scissors",
                help: "Cut",
                isDisabled: !model.hasSelection,
                action: model.cutSelectedItems
            )

            ExplorerToolbarButton(
                symbol: "clipboard",
                help: "Paste",
                action: { model.pasteItems() }
            )

            ExplorerToolbarButton(
                symbol: "trash",
                help: "Move to Trash",
                isDisabled: !model.hasSelection,
                action: model.moveSelectedItemsToTrash
            )
        }
        .padding(10)
        .background(.bar)
    }

    private var fileHeader: some View {
        HStack(spacing: 12) {
            SortHeader(
                title: "Name",
                column: .name,
                selectedColumn: model.sortColumn,
                ascending: model.sortAscending,
                action: model.selectSortColumn
            )
                .frame(maxWidth: .infinity, alignment: .leading)
            SortHeader(
                title: "Date modified",
                column: .modificationDate,
                selectedColumn: model.sortColumn,
                ascending: model.sortAscending,
                action: model.selectSortColumn
            )
                .frame(width: 150, alignment: .leading)
            SortHeader(
                title: "Type",
                column: .kind,
                selectedColumn: model.sortColumn,
                ascending: model.sortAscending,
                action: model.selectSortColumn
            )
                .frame(width: 110, alignment: .leading)
            SortHeader(
                title: "Size",
                column: .size,
                selectedColumn: model.sortColumn,
                ascending: model.sortAscending,
                alignment: .trailing,
                action: model.selectSortColumn
            )
                .frame(width: 90, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var fileList: some View {
        List(displayedEntries, selection: $model.selectedURLs) { entry in
            FileRow(entry: entry, sizeText: folderSizeIndex.formattedSize(for: entry))
                .tag(entry.url)
                .contentShape(Rectangle())
                .listRowBackground(
                    model.selectedURLs.contains(entry.url)
                        ? Color.accentColor.opacity(0.28)
                        : Color.clear
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            select(entry.url, modifiers: NSEvent.modifierFlags)
                        }
                )
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

                    Menu("Open With") {
                        let applications = openWithApplications(for: entry.url)
                        if applications.isEmpty {
                            Text("No Applications Found")
                        } else {
                            ForEach(applications, id: \.self) { applicationURL in
                                Button {
                                    model.open(entry.url, with: applicationURL)
                                } label: {
                                    Label {
                                        Text(applicationURL.deletingPathExtension().lastPathComponent)
                                    } icon: {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                                    }
                                }
                            }
                        }
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

                    Divider()

                    Button(favorites.contains(entry.url) ? "Remove from Favorites" : "Add to Favorites") {
                        favorites.toggle(entry.url)
                    }

                    if entry.isDirectory {
                        Button("Recalculate Folder Size") {
                            folderSizeIndex.recalculate(entry)
                        }
                    }
                }
                .onDrag {
                    NSItemProvider(object: entry.url as NSURL)
                } preview: {
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
            } else if displayedEntries.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
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
            Button(favorites.contains(model.currentURL) ? "Remove Current Folder from Favorites" : "Add Current Folder to Favorites") {
                favorites.toggle(model.currentURL)
            }
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

    private func select(_ url: URL, modifiers: NSEvent.ModifierFlags) {
        let entries = displayedEntries
        if modifiers.contains(.shift),
           let selectionAnchor,
           let anchorIndex = entries.firstIndex(where: { $0.url == selectionAnchor }),
           let selectedIndex = entries.firstIndex(where: { $0.url == url }) {
            let range = min(anchorIndex, selectedIndex)...max(anchorIndex, selectedIndex)
            model.selectedURLs = Set(range.map { entries[$0].url })
        } else if modifiers.contains(.command) {
            if model.selectedURLs.contains(url) {
                model.selectedURLs.remove(url)
            } else {
                model.selectedURLs.insert(url)
            }
            selectionAnchor = url
        } else {
            model.selectedURLs = [url]
            selectionAnchor = url
        }
    }

    private func openWithApplications(for url: URL) -> [URL] {
        let applications = NSWorkspace.shared.urlsForApplications(toOpen: url)
        return Array(Set(applications)).sorted {
            $0.deletingPathExtension().lastPathComponent.localizedStandardCompare(
                $1.deletingPathExtension().lastPathComponent
            ) == .orderedAscending
        }
    }

    private func closeFind() {
        model.searchText = ""
        model.isFindPresented = false
        searchFieldIsFocused = false
    }

    private var displayedEntries: [FileEntry] {
        model.visibleEntries(folderSizes: folderSizeIndex.sizesByPath)
    }
}

private struct FileRow: View {
    let entry: FileEntry
    let sizeText: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                FileIcon(entry: entry)
                Text(entry.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.formattedDate)
                .frame(width: 150, alignment: .leading)
            Text(entry.kind)
                .frame(width: 110, alignment: .leading)
            Text(sizeText)
                .frame(width: 90, alignment: .trailing)
        }
        .font(.callout)
        .padding(.vertical, 2)
    }
}

private struct FileIcon: View {
    @Environment(MediaThumbnailStore.self) private var mediaThumbnails
    let entry: FileEntry

    var body: some View {
        Group {
            if let thumbnail = mediaThumbnails.thumbnail(for: entry) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path))
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 20, height: 20)
        .task(id: entry) {
            await mediaThumbnails.loadThumbnail(for: entry)
        }
    }
}

private struct Sidebar: View {
    let model: BrowserModel
    let favorites: FavoritesStore

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
                        HStack(spacing: 8) {
                            Image(systemName: location.symbol)
                                .frame(width: 18, height: 18)
                            Text(location.name)
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Favorites") {
                if favorites.urls.isEmpty {
                    Text("Right-click an item to add it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(favorites.urls, id: \.self) { url in
                        Button {
                            model.open(url)
                        } label: {
                            Label {
                                Text(url.lastPathComponent.isEmpty ? "Mac" : url.lastPathComponent)
                                    .lineLimit(1)
                            } icon: {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Open") {
                                model.open(url)
                            }
                            Divider()
                            Button("Remove from Favorites") {
                                favorites.remove(url)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 190)
    }
}

private struct ExplorerToolbarButton: View {
    let symbol: String
    let help: String
    var isDisabled = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovering && !isDisabled ? Color.primary.opacity(0.08) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(isDisabled)
        .foregroundStyle(isDisabled ? .tertiary : .secondary)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

private struct ToolbarSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }
}

private struct SortHeader: View {
    let title: String
    let column: FileSortColumn
    let selectedColumn: FileSortColumn
    let ascending: Bool
    var alignment: Alignment = .leading
    let action: (FileSortColumn) -> Void

    var body: some View {
        Button {
            action(column)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if selectedColumn == column {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Sort by \(title)")
    }
}
