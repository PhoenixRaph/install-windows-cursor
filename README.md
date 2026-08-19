# install-windows-cursor

Convert Windows cursor packs (`.cur` / `.ani`) into Linux X11 cursor themes.
Supports direct install with auto-activation, or convert-only mode for manual setup.

## Quick Start

### Install directly

```bash
./install-windows-cursor.sh my-theme.zip
```

Detects the theme name from the filename, converts all cursors, installs to your icon directories, and activates the theme automatically.

### Convert only

```bash
./install-windows-cursor.sh --convert my-theme.zip
```

Saves the converted theme to `converted cursors/<Theme Name>/` with a `README.md` inside containing manual install instructions. No system dirs are touched.

## Usage

```bash
# Install with auto-detected name
./install-windows-cursor.sh my-theme.zip

# Install with a custom name
./install-windows-cursor.sh my-theme.zip "My Theme"

# Convert only — no install, no activation
./install-windows-cursor.sh --convert my-theme.zip

# List installed cursor themes
./install-windows-cursor.sh --list

# Apply an installed theme
./install-windows-cursor.sh --apply "My Theme"

# Uninstall a theme
./install-windows-cursor.sh --uninstall "My Theme"

# Preview actions without making changes
./install-windows-cursor.sh --dry-run my-theme.zip
```

## Options

| Flag | Description |
|------|-------------|
| `-h`, `--help` | Show help message |
| `-c`, `--convert` | Convert only — saves to `converted cursors/` without installing |
| `-l`, `--list` | List installed cursor themes |
| `-u`, `--uninstall` | Remove an installed cursor theme |
| `-a`, `--apply` | Set a cursor theme as the active one |
| `-n`, `--dry-run` | Preview actions without making changes |
| `-v`, `--version` | Show version |

## What the Script Does

1. Extracts the Windows cursor ZIP
2. Converts `.cur` and `.ani` files to X11 format using `win2xcur`
3. Maps Windows cursor names to standard X11 names (e.g., "Normal Select" → `left_ptr`)
4. Generates an `index.theme` file with the correct `Inherits` chain
5. In `--convert` mode: saves to `converted cursors/` with a per-theme `README.md`
6. In install mode: copies to `~/.local/share/icons/` and `~/.icons/`
7. Auto-activates the theme via KDE Plasma, GNOME, or Xresources
8. Detects your distro and offers to install missing dependencies

## Dependencies

- **unzip** — extract ZIP archives
- **win2xcur** — convert Windows cursors to X11 format

The script detects your distro and offers to install missing dependencies automatically.

## Supported Distros

Arch, Ubuntu/Debian, Fedora, openSUSE, NixOS, Void, Alpine, Gentoo, RHEL/CentOS.

## Cursor Mapping

The script maps Windows cursor names to standard X11 cursor names:

| Windows name | X11 names |
|---|---|
| Normal Select | `left_ptr`, `default`, `arrow`, `top_left_arrow` |
| Help Select | `help`, `question_arrow`, `whats_this` |
| Working in Background | `left_ptr_watch`, `progress`, `half-busy` |
| Busy | `wait`, `watch` |
| Precision Select | `crosshair`, `cross`, `tcross` |
| Text Select | `xterm`, `ibeam`, `text` |
| Handwriting | `pencil`, `draft` |
| Unavailable | `not-allowed`, `forbidden`, `circle` |
| Vertical Resize | `ns-resize`, `v_double_arrow`, `size_ver` |
| Horizontal Resize | `ew-resize`, `h_double_arrow`, `size_hor` |
| Diagonal Resize 1 | `nwse-resize`, `fd_double_arrow`, `size_fdiag` |
| Diagonal Resize 2 | `nesw-resize`, `bd_double_arrow`, `size_bdiag` |
| Move | `move`, `size_all`, `fleur` |
| Link Select | `pointer`, `hand2`, `hand1`, `pointing_hand` |
