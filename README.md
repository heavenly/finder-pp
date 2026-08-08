# Explorer

Explorer is a native macOS file browser with a Windows Explorer-style path bar.
It is an alternative file browser. It does not replace the protected Finder
process.

## Current features

- Clickable breadcrumb path.
- Click the path bar to type or paste a path.
- Back, Forward, Up, and Refresh actions.
- Independent windows with **Command-E**.
- File details and native file icons.
- Double-click to open folders and files.
- Drag files between Explorer windows to move them.
- Drag files onto a folder row to move them into that folder.
- Create folders with **Command-Shift-N**.
- Rename one selected item with **Return**.
- Copy, Cut, and Paste with the standard macOS shortcuts.
- Move selected items to the Trash with **Command-Delete**.
- Right-click items for file-management actions.

Explorer hides hidden files in this first release. A move stops if the target
already contains an item with the same name. The app does not overwrite files.

## Run

Requirements: macOS 14 or later and Xcode 16 or later.

```sh
swift run Explorer
```

## Build

```sh
swift build -c release
```

The executable is at `.build/release/Explorer`. An Xcode app target, signing,
sandbox permissions, and DMG packaging are separate distribution steps.

## Roadmap

1. Add collision prompts and a file-operation progress queue.
2. Add tabs, configurable columns, sorting, and hidden-file controls.
3. Add Quick Look, search, network shares, and mounted-volume navigation.
4. Add state restoration and saved favorites.
5. Add an Xcode distribution target, app icon, signing, notarization, and DMG.
