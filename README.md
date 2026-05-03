# MacExplorer

A Windows-style file explorer for macOS. If you've always preferred the PC's File Explorer over Finder, MacExplorer brings that familiar experience to your Mac — built natively with SwiftUI.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🗂️ Folder Tree Sidebar
- Expandable folder tree on the left with lazy-loading directories
- **Auto-expands** to track the current navigation path (stays in sync)
- Active folder highlighted with bold text and filled icon
- Quick-access favorites: Home, Desktop, Documents, Downloads, Applications
- Mounted volumes section
- Right-click any folder to **open in a new tab**, **create a new folder**, or **move to trash**

### 📋 File List
- Sortable table with columns: **Name**, **Size**, **Date Modified**, **Kind**
- **Folders always sorted on top**, separately from files
- File type icons from the system (`.app` bundles correctly shown as files)
- Single and multi-select support
- Double-click a folder to navigate into it
- Double-click a file to open it with the default app

### 🔀 Breadcrumb Navigation
- Clickable path components at the top to jump to any parent directory
- Back / Forward buttons with full history
- Small triangle separators for a clean look

### 📑 Tabs
- Open multiple folders in tabs within a single window — no separate windows
- Each tab has its own independent navigation history
- Add, close, and switch tabs
- **Drag tabs between windows** to merge them into one
- Right-click sidebar folders to open in a new tab

### 👁️ Preview Pane
- Toggleable preview panel on the right side
- **QuickLook** integration for images, PDFs, videos, documents, and more
- File metadata display: name, kind, size, modified date, full path
- Multi-selection shows item count, file/folder breakdown, and total size

### ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘T` | New tab |
| `⌘W` | Close tab |
| `⌘[` | Navigate back |
| `⌘]` | Navigate forward |
| `⌘⇧P` | Toggle preview pane |
| `Delete` | Move selected items to Trash |
| `⌘⌫` | Move selected items to Trash |

### 📁 File Operations
- **Open** files and folders from context menu
- **Open in New Tab** for folders
- **Rename** files and folders inline via popover
- **New Folder** from context menu (file list background, on folders, or sidebar)
  - Auto-scrolls to the new folder and opens rename popover
- **Show in Finder** to reveal in native Finder
- **Move to Trash** — works with multiple selected files
  - Confirmation prompt when trashing non-empty folders
- All context menu actions respect multi-selection

### 🖥️ Default Folder Handler
- Can replace Finder as the default folder handler
- Makes `open .` and other folder-opening commands use MacExplorer
- Use `./set-default.sh set` to enable, `./set-default.sh unset` to revert

### 🔍 Search
- Filter current directory contents by name in real time

### 📊 Status Bar
- Bottom bar showing total item count, selection count, and total file size

## Installation

### Homebrew (Recommended)

```bash
brew tap ronhash10/macexplorer https://github.com/ronhash10/MacExplorer
brew install --cask macexplorer
```

### DMG Download

1. Go to [Releases](https://github.com/ronhash10/MacExplorer/releases)
2. Download `MacExplorer-x.x.x.dmg`
3. Open the DMG and drag **MacExplorer** to **Applications**

### Build from Source

Requires Xcode 15+ and macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/ronhash10/MacExplorer.git
cd MacExplorer
./run.sh
```

## Setup

### Full Disk Access

On first launch, MacExplorer will prompt you to grant **Full Disk Access** so it can browse all directories without repeated permission dialogs.

1. The app will offer to open **System Settings** for you
2. In **Privacy & Security → Full Disk Access**, click the **+** button
3. Select **MacExplorer.app** from the Finder window that opens
4. Restart MacExplorer

### Settings

Open **MacExplorer → Settings** (or `⌘,`) to configure:
- **Show Hidden Files** — toggle visibility of dotfiles and hidden folders
- **Show Preview Pane** — toggle the right-side preview panel

## Development

### Project Structure

```
MacExplorer/
├── MacExplorerApp.swift          # App entry point, commands, FDA check
├── Services/
│   ├── FileSystemService.swift   # FileManager wrapper
│   └── TrashHelper.swift         # Trash with confirmation for non-empty folders
├── Models/
│   ├── AppState.swift            # Per-window state: tabs, preferences
│   ├── FileItem.swift            # File/folder data model
│   ├── TabState.swift            # Per-tab navigation state
│   ├── WindowManager.swift       # Cross-window tab transfer
│   └── TabTransferData.swift     # Transferable data for tab drag
├── Views/
│   ├── ContentView.swift         # Main layout (sidebar + content)
│   ├── SidebarView.swift         # Folder tree sidebar
│   ├── SettingsView.swift        # Preferences window
│   └── Components/
│       ├── BreadcrumbBar.swift   # Path breadcrumb navigation
│       ├── FileListView.swift    # Sortable file table
│       ├── PreviewPane.swift     # QuickLook + file info
│       ├── StatusBar.swift       # Bottom status bar
│       └── TabBarView.swift      # Tab bar
├── Package.swift
├── run.sh                        # Build, sign & launch (dev)
├── build-dmg.sh                  # Build release DMG
└── release.sh                    # Publish GitHub release
```

### Scripts

| Script | Purpose |
|--------|---------|
| `./run.sh` | Build debug, code-sign, deploy to /Applications, and launch |
| `./build-dmg.sh [version]` | Build release binary and create a DMG |
| `./release.sh [version]` | Build DMG, create GitHub release, update Homebrew cask |
| `./set-default.sh set\|unset\|status` | Manage default folder handler |
| `./setup-cert.sh` | Create self-signed certificate for persistent code signing |

## Tech Stack

- **SwiftUI** with `@Observable` (Observation framework)
- **macOS 14+** (Sonoma)
- **QuickLook** (`QLPreviewView`) for file previews
- **NSTableView** introspection for double-click handling and scroll-to-item
- **Self-signed certificate** for persistent Full Disk Access across builds
- **Cross-window tab drag** via `Transferable` protocol

## License

MIT
