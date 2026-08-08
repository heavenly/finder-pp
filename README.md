# ExplorerPP

ExplorerPP is a native macOS file browser with a Windows Explorer-style path bar.
It is an alternative file browser. It does not replace the protected Finder
process.

## Current features

- Clickable breadcrumb path.
- Click the path bar to type or paste a path.
- Back, Forward, Up, and Refresh actions.
- Independent windows with **Command-E**.
- File details and native file icons.
- Double-click to open folders and files.
- Drag files between ExplorerPP windows to move them.
- Drag files and folders from ExplorerPP into other macOS applications.
- Drag files onto a folder row to move them into that folder.
- Create folders with **Command-Shift-N**.
- Rename one selected item with **Return**.
- Copy, Cut, and Paste with the standard macOS shortcuts.
- Move selected items to the Trash with **Command-Delete**.
- Right-click items for file-management actions.
- Use the right-click **Open With** submenu to choose a compatible application.
- Press **Command-F** to filter the current folder by file name.
- Right-click a file or folder to add it to the persistent Favorites section.
- Follow the current macOS light or dark appearance automatically.
- Calculate folder sizes in the background and cache them between launches.
- Right-click a folder and select **Recalculate Folder Size** to refresh its cached value.
- Click Name, Date modified, Type, or Size to sort in ascending or descending order.
- Show small image, video, and audio previews in file rows when Quick Look supports them.

ExplorerPP hides hidden files in this first release. A move stops if the target
already contains an item with the same name. The app does not overwrite files.

## Run

Requirements: macOS 14 or later and Xcode 16 or later.

```sh
swift run ExplorerPP
```

## Build

```sh
swift build -c release
```

The executable is at `.build/release/ExplorerPP`.

## Package

Create a signed local application bundle and DMG:

```sh
./Scripts/package-app.sh
```

Outputs:

- `dist/ExplorerPP.app`
- `dist/ExplorerPP.dmg`

The default signature is ad hoc and is suitable for local use. To use an
installed Developer ID certificate, provide its exact identity:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/package-app.sh
```

Developer ID distribution also requires Apple notarization. The packaging
script does not store or request signing credentials.

ExplorerPP remains running after its last window closes. It hides its Dock icon
while it has no visible windows. Open ExplorerPP again to create or restore a
window.

## Roadmap

1. Add collision prompts and a file-operation progress queue.
2. Add tabs, configurable columns, sorting, and hidden-file controls.
3. Add Quick Look, search, network shares, and mounted-volume navigation.
4. Add state restoration and saved favorites.
5. Add Developer ID notarization and automatic updates.
