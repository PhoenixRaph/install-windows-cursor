#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# install-windows-cursor.sh — Convert Windows cursor ZIP to Linux cursor theme
# =============================================================================
VERSION="1.0.0"

# ── Paths ────────────────────────────────────────────────────────────────────
XDG_ICON_DIR="$HOME/.local/share/icons"
LEGACY_ICON_DIR="$HOME/.icons"
ICON_DIRS=("$XDG_ICON_DIR" "$LEGACY_ICON_DIR")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTED_DIR="$SCRIPT_DIR/converted cursors"

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'    GREEN=$'\033[0;32m'  YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'   BOLD=$'\033[1m'      DIM=$'\033[2m'
    RESET=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' RESET=''
fi

# ── Output helpers ───────────────────────────────────────────────────────────
info()    { printf "${BLUE}==>${RESET} %s\n" "$*"; }
success() { printf "${GREEN}==>${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}WARN:${RESET} %s\n" "$*" >&2; }
error()   { printf "${RED}ERROR:${RESET} %s\n" "$*" >&2; }
die()     { error "$@"; exit 1; }
header()  { printf "\n${BOLD}── %s ──${RESET}\n" "$*"; }

# ── Dry-run support ──────────────────────────────────────────────────────────
DRY_RUN=false
run() { if $DRY_RUN; then info "[dry-run] $*"; else "$@"; fi; }

# ── Cleanup ──────────────────────────────────────────────────────────────────
CURSOR_TMP_DIR=""
_cleanup() { rm -rf "${CURSOR_TMP_DIR:-}"; }
trap _cleanup EXIT

# ── Distro detection ─────────────────────────────────────────────────────────
detect_distro() {
    local id="" id_like=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
        id_like="${ID_LIKE:-}"
    fi

    case "$id" in
        arch|manjaro|endeavouros|garuda|arco) echo "arch" ;;
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian) echo "debian" ;;
        fedora) echo "fedora" ;;
        opensuse*|sles) echo "suse" ;;
        nixos) echo "nixos" ;;
        void) echo "void" ;;
        alpine) echo "alpine" ;;
        gentoo|funtoo) echo "gentoo" ;;
        centos|rhel|rocky|alma) echo "rhel" ;;
        *)
            # Check ID_LIKE for nested distros
            case "$id_like" in
                *arch*)  echo "arch" ;;
                *debian*) echo "debian" ;;
                *fedora*|*rhel*) echo "fedora" ;;
                *) echo "unknown" ;;
            esac
            ;;
    esac
}

# ── Distro display name ──────────────────────────────────────────────────────
distro_display_name() {
    case "$(detect_distro)" in
        arch)    echo "Arch Linux" ;;
        debian)  echo "Debian/Ubuntu" ;;
        fedora)  echo "Fedora" ;;
        suse)    echo "openSUSE" ;;
        nixos)   echo "NixOS" ;;
        void)    echo "Void Linux" ;;
        alpine)  echo "Alpine Linux" ;;
        gentoo)  echo "Gentoo" ;;
        rhel)    echo "RHEL/CentOS" ;;
        *)       echo "Linux (unknown distro)" ;;
    esac
}

# ── Get distro-specific install command ──────────────────────────────────────
get_install_cmd() {
    local pkg="$1"
    local distro
    distro=$(detect_distro)

    case "$distro" in
        arch)
            case "$pkg" in
                unzip)    echo "sudo pacman -S --noconfirm unzip" ;;
                win2xcur)
                    if command -v yay &>/dev/null; then
                        echo "yay -S --noconfirm win2xcur"
                    elif command -v paru &>/dev/null; then
                        echo "paru -S --noconfirm win2xcur"
                    else
                        echo "pip install win2xcur"
                    fi
                    ;;
            esac
            ;;
        debian)
            case "$pkg" in
                unzip)    echo "sudo apt install -y unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        fedora)
            case "$pkg" in
                unzip)    echo "sudo dnf install -y unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        suse)
            case "$pkg" in
                unzip)    echo "sudo zypper install -y unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        nixos)
            case "$pkg" in
                unzip)    echo "nix-env -iA nixpkgs.unzip" ;;
                win2xcur) echo "nix-env -iA nixpkgs.win2xcur" ;;
            esac
            ;;
        void)
            case "$pkg" in
                unzip)    echo "sudo xbps-install -Sy unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        alpine)
            case "$pkg" in
                unzip)    echo "sudo apk add unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        gentoo)
            case "$pkg" in
                unzip)    echo "sudo emerge -av dev-libs/libunzip app-arch/unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        rhel)
            case "$pkg" in
                unzip)    echo "sudo yum install -y unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
        *)
            case "$pkg" in
                unzip)    echo "sudo <your-package-manager> install unzip" ;;
                win2xcur) echo "pip install win2xcur" ;;
            esac
            ;;
    esac
}

# ── Dependency check with interactive install ────────────────────────────────
check_deps() {
    local -a missing=()
    local -A pkg_names=()

    command -v unzip &>/dev/null || { missing+=("unzip"); pkg_names[unzip]="unzip"; }
    command -v win2xcur &>/dev/null || { missing+=("win2xcur"); pkg_names[win2xcur]="win2xcur"; }

    [[ ${#missing[@]} -eq 0 ]] && return 0

    header "Missing dependencies"
    for pkg in "${missing[@]}"; do
        printf "  ${RED}✗${RESET} %-14s not found\n" "$pkg"
    done

    local distro_name
    distro_name=$(distro_display_name)

    printf "\n  ${BOLD}Detected:${RESET} %s\n\n" "$distro_name"
    printf "  ${BOLD}Install commands:${RESET}\n"
    for pkg in "${missing[@]}"; do
        local cmd
        cmd=$(get_install_cmd "${pkg_names[$pkg]}")
        printf "    ${BOLD}%-12s${RESET} %s\n" "$pkg:" "$cmd"
    done

    printf "\n"
    if $DRY_RUN; then
        info "[dry-run] Would install: ${missing[*]}"
        return 0
    fi

    read -r -p "  Install missing dependencies now? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        die "Aborted. Install manually and try again."
    fi

    # Install each missing dependency
    for pkg in "${missing[@]}"; do
        local cmd
        cmd=$(get_install_cmd "${pkg_names[$pkg]}")
        info "Installing $pkg..."
        if bash -c "$cmd"; then
            success "$pkg installed"
        else
            die "Failed to install $pkg.\n  Run manually: $cmd"
        fi
    done

    # Verify installation
    local still_missing=()
    for pkg in "${missing[@]}"; do
        command -v "$pkg" &>/dev/null || still_missing+=("$pkg")
    done

    if [[ ${#still_missing[@]} -gt 0 ]]; then
        die "Still missing after install: ${still_missing[*]}\n  Please install manually."
    fi

    success "All dependencies installed"
}

# ── ZIP validation ───────────────────────────────────────────────────────────
validate_zip() {
    local zip="$1"
    [[ -f "$zip" ]] || die "File not found: $zip"
    unzip -tq "$zip" &>/dev/null || die "Not a valid ZIP file: $zip"
}

# ── Smart theme name from ZIP filename ───────────────────────────────────────
derive_theme_name() {
    local basename="${1##*/}"
    local name="${basename%.zip}"
    name="${name%.ZIP}"
    # Strip common suffixes
    name="${name%-cursors}"
    name="${name%-cursor}"
    name="${name%_cursors}"
    name="${name%_cursor}"
    name="${name%-Cursors}"
    name="${name%-Cursor}"
    # Replace underscores and hyphens with spaces, title-case each word
    name="${name//[_-]/ }"
    # Collapse multiple spaces
    while [[ "$name" == *"  "* ]]; do name="${name//  / }"; done
    name="$(echo "$name" | sed 's/\b\(.\)/\u\1/g')"
    [[ -n "$name" ]] || name="Cursor Theme"
    echo "$name"
}

# ── Map cursor name to X11 standard name ─────────────────────────────────────
map_cursor() {
    local -n _mapped=$1 _unmapped=$2
    shift 2
    local pattern="$1"
    local target="$2"
    shift 2
    local links=("$@")

    local match
    match=$(find . -maxdepth 1 -iname "*$pattern*" ! -type l | head -n 1)

    if [[ -n "$match" ]] && [[ -f "$match" ]]; then
        mv "$match" "$target"
        for l in "${links[@]}"; do
            ln -sf "$target" "$l"
        done
        (( _mapped++ )) || true
    else
        (( _unmapped++ )) || true
    fi
}

# ── Map all cursor names ─────────────────────────────────────────────────────
map_cursors() {
    local cursor_dir="$1"
    local mapped_count=0 unmapped_count=0

    pushd "$cursor_dir" > /dev/null
    map_cursor mapped_count unmapped_count "Normal Select"         "left_ptr"        "default" "arrow" "top_left_arrow"
    map_cursor mapped_count unmapped_count "Help Select"           "help"            "question_arrow" "whats_this"
    map_cursor mapped_count unmapped_count "Working in Background" "left_ptr_watch"  "progress" "half-busy"
    map_cursor mapped_count unmapped_count "Busy"                  "wait"            "watch"
    map_cursor mapped_count unmapped_count "Precision Select"      "crosshair"       "cross" "tcross"
    map_cursor mapped_count unmapped_count "Text Select"           "xterm"           "ibeam" "text"
    map_cursor mapped_count unmapped_count "Handwriting"           "pencil"          "draft"
    map_cursor mapped_count unmapped_count "Unavailable"           "not-allowed"     "forbidden" "circle"
    map_cursor mapped_count unmapped_count "Vertical Resize"       "ns-resize"       "v_double_arrow" "size_ver"
    map_cursor mapped_count unmapped_count "Horizontal Resize"     "ew-resize"       "h_double_arrow" "size_hor"
    map_cursor mapped_count unmapped_count "Diagonal Resize 1"     "nwse-resize"     "fd_double_arrow" "size_fdiag"
    map_cursor mapped_count unmapped_count "Diagonal Resize 2"     "nesw-resize"     "bd_double_arrow" "size_bdiag"
    map_cursor mapped_count unmapped_count "Move"                  "move"            "size_all" "fleur"
    map_cursor mapped_count unmapped_count "Link Select"           "pointer"         "hand2" "hand1" "pointing_hand"
    popd > /dev/null

    echo "$mapped_count $unmapped_count"
}

# ── Refresh icon cache ──────────────────────────────────────────────────────
refresh_icon_cache() {
    info "Refreshing icon cache..."
    # Remove stale caches
    run rm -rf "$HOME"/.cache/ksycoca* "$HOME"/.cache/icon-cache* 2>/dev/null || true

    # KDE Plasma
    if command -v kbuildsycoca6 &>/dev/null; then
        run kbuildsycoca6 --noincremental
    fi
    # GNOME / GTK
    if command -v gtk-update-icon-cache &>/dev/null; then
        for dir in "${ICON_DIRS[@]}"; do
            [[ -d "$dir/$1" ]] && run gtk-update-icon-cache -f -t "$dir/$1" 2>/dev/null || true
        done
    fi
    # Generic: rebuild hicolor cache
    if command -v update-icon-caches &>/dev/null; then
        run update-icon-caches "$XDG_ICON_DIR" 2>/dev/null || true
    fi
}

# ── Check if a theme is currently active ─────────────────────────────────────
is_active_theme() {
    local name="$1"

    # Try KDE Plasma (kcminputrc)
    if command -v kreadconfig5 &>/dev/null; then
        local active
        active=$(kreadconfig5 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null || echo "")
        [[ "$active" == "$name" ]] && return 0
    elif [[ -f "$HOME/.config/kcminputrc" ]]; then
        local cursor_theme
        cursor_theme=$(sed -n '/^\[Mouse\]/,/^\[/{s/^cursorTheme[[:space:]]*=[[:space:]]*//p}' \
            "$HOME/.config/kcminputrc" 2>/dev/null | head -1)
        cursor_theme="${cursor_theme//\"/}"
        cursor_theme="${cursor_theme//\'/}"
        [[ "$cursor_theme" == "$name" ]] && return 0
    fi

    # Try GNOME/GTK (gsettings)
    if command -v gsettings &>/dev/null; then
        local active
        active=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null || echo "")
        active="${active//\'/}"
        [[ "$active" == "$name" ]] && return 0
    fi

    return 1
}

# ── Apply cursor theme via desktop environment ──────────────────────────────
# Returns 0 if a DE was found and the command was run, 1 otherwise.
apply_cursor_theme() {
    local theme_name="$1"

    if command -v plasma-apply-cursortheme &>/dev/null; then
        run plasma-apply-cursortheme "$theme_name"
        return 0
    fi

    if command -v gsettings &>/dev/null; then
        run gsettings set org.gnome.desktop.interface cursor-theme "$theme_name"
        return 0
    fi

    local xresources="$HOME/.Xresources"
    if [[ -f "$xresources" ]] && grep -q "Xcursor.theme" "$xresources"; then
        run sed -i "s/^Xcursor.theme:.*/Xcursor.theme: $theme_name/" "$xresources"
        return 0
    fi

    return 1
}

# ── Reset cursor theme to safe default ──────────────────────────────────────
reset_cursor_theme() {
    local default_theme=""

    if command -v plasma-apply-cursortheme &>/dev/null; then
        default_theme="breeze_cursors"
    elif command -v gsettings &>/dev/null; then
        default_theme="Adwaita"
    fi

    if [[ -n "$default_theme" ]]; then
        apply_cursor_theme "$default_theme"
        success "Reset cursor to '$default_theme'"
        return 0
    fi

    warn "Select a different cursor in your desktop settings"
    return 1
}

# =============================================================================
# INSTALL SUB-FUNCTIONS
# =============================================================================

# ── Extract ZIP to temp dir ──────────────────────────────────────────────────
extract_zip() {
    local zip_file="$1"
    local tmp_dir="$2"

    info "Extracting ZIP..." >&2
    run unzip -qo "$zip_file" -d "$tmp_dir"
    local file_count
    file_count=$(find "$tmp_dir" -type f | wc -l)
    info "Extracted $file_count files" >&2
}

# ── Convert .cur/.ani files to X11 cursors ───────────────────────────────────
convert_cursors() {
    local tmp_dir="$1"
    local cursors_dir="$2"

    run mkdir -p "$cursors_dir"
    local converted=0 failed=0

    info "Converting .cur and .ani files..." >&2
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        if run win2xcur "$file" -o "$cursors_dir/" 2>/dev/null; then
            ((converted++)) || true
        else
            ((failed++)) || true
        fi
    done < <(find "$tmp_dir" -type f \( -iname "*.cur" -o -iname "*.ani" \))

    echo "$converted $failed"
}

# ── Generate index.theme ─────────────────────────────────────────────────────
generate_index_theme() {
    local theme_dir="$1"
    local theme_name="$2"

    info "Generating index.theme..."
    run mkdir -p "$theme_dir"
    if ! $DRY_RUN; then
        cat > "$theme_dir/index.theme" <<EOF
[Icon Theme]
Name=$theme_name
Comment=$theme_name Cursor Theme
Inherits=breeze_cursors
EOF
    fi
}

# ── Generate README.md for converted theme ───────────────────────────────────
generate_theme_readme() {
    local theme_dir="$1"
    local theme_name="$2"

    if ! $DRY_RUN; then
        cat > "$theme_dir/README.md" <<EOF
# $theme_name

## Install

Copy this folder to one of these locations:

    cp -r "$theme_name" ~/.local/share/icons/

or (legacy):

    cp -r "$theme_name" ~/.icons/

## Activate

### KDE Plasma

    plasma-apply-cursortheme '$theme_name'

Or: System Settings > Appearance > Cursors > select '$theme_name'

### GNOME

    gsettings set org.gnome.desktop.interface cursor-theme '$theme_name'

### XFCE

    xfconf-query -c xsettings -p /Gtk/CursorThemeName -s '$theme_name'

### Xresources

Add this line to ~/.Xresources:

    Xcursor.theme: $theme_name

Then reload:

    xrdb -merge ~/.Xresources

### Environment variable

Add to ~/.profile or ~/.xinitrc:

    export XCURSOR_THEME='$theme_name'
EOF
    fi
}

# ── Generate index.theme and copy to system dirs ────────────────────────────
install_theme_files() {
    local theme_dir="$1"
    local theme_name="$2"

    generate_index_theme "$theme_dir" "$theme_name"

    info "Installing to system paths..."
    for dir in "${ICON_DIRS[@]}"; do
        run mkdir -p "$dir"
        run cp -r "$theme_dir" "$dir/"
        run chmod -R 755 "$dir/$theme_name"
    done

    refresh_icon_cache "$theme_name"
}

# =============================================================================
# COMMANDS
# =============================================================================

cmd_install() {
    local zip_file="${1:-}"
    local theme_name="${2:-}"

    [[ -n "$zip_file" ]] || die "No ZIP file specified.\nUsage: $0 <zip-file> [theme-name]\nRun '$0 --help' for more info."

    # Resolve to absolute path before anything changes directory
    zip_file="$(cd "$(dirname "$zip_file")" 2>/dev/null && echo "$(pwd)/$(basename "$zip_file")" || echo "$zip_file")"

    header "Installing cursor theme"
    validate_zip "$zip_file"

    # Determine theme name
    if [[ -z "$theme_name" ]]; then
        theme_name=$(derive_theme_name "$zip_file")
        info "Auto-detected theme name: $theme_name"
    fi

    local local_theme_dir="$SCRIPT_DIR/$theme_name"
    local local_cursors_dir="$local_theme_dir/cursors"

    # Create temp dir
    CURSOR_TMP_DIR=$(mktemp -d)

    # Extract ZIP
    extract_zip "$zip_file" "$CURSOR_TMP_DIR"

    # Count cursor files
    local cursor_count
    cursor_count=$(find "$CURSOR_TMP_DIR" -type f \( -iname "*.cur" -o -iname "*.ani" \) 2>/dev/null | wc -l)

    if [[ "$cursor_count" -eq 0 ]]; then
        die "No .cur or .ani files found in the ZIP.\nThis doesn't appear to be a Windows cursor theme."
    fi
    info "Found $cursor_count cursor file(s)"

    # Clean previous versions
    info "Cleaning previous versions..."
    run rm -rf "$local_theme_dir"
    for dir in "${ICON_DIRS[@]}"; do
        run rm -rf "$dir/$theme_name"
    done

    # Convert cursors
    local converted failed
    read -r converted failed <<< "$(convert_cursors "$CURSOR_TMP_DIR" "$local_cursors_dir")"

    if [[ "$converted" -eq 0 ]]; then
        die "win2xcur conversion failed for all $cursor_count file(s).\nCheck that win2xcur is working correctly."
    fi
    info "Converted: $converted success, $failed failed"

    # Map cursor names to X11 standard names
    info "Mapping cursor names..."
    local mapped_count unmapped_count
    read -r mapped_count unmapped_count <<< "$(map_cursors "$local_cursors_dir")"
    info "Mapped: $mapped_count standard name(s), $unmapped_count unmapped"

    # Generate index.theme and install
    install_theme_files "$local_theme_dir" "$theme_name"

    # Summary
    header "Installation complete"
    printf "  ${BOLD}Theme:${RESET}      %s\n" "$theme_name"
    printf "  ${BOLD}Cursors:${RESET}    %d converted, %d failed\n" "$converted" "$failed"
    printf "  ${BOLD}Mapped:${RESET}     %d standard X11 names\n" "$mapped_count"
    printf "  ${BOLD}Local copy:${RESET} %s/%s/\n" "$SCRIPT_DIR" "$theme_name"
    for dir in "${ICON_DIRS[@]}"; do
        [[ -d "$dir/$theme_name" ]] && printf "  ${BOLD}Installed:${RESET}  %s/%s/\n" "$dir" "$theme_name"
    done

    # Auto-apply the new cursor theme
    if ! $DRY_RUN; then
        printf "\n"
        if apply_cursor_theme "$theme_name"; then
            success "Cursor theme is now active"
        else
            printf "  ${DIM}Select '${BOLD}%s${RESET}${DIM}' in your desktop settings to activate.${RESET}\n" "$theme_name"
        fi
    fi
}

cmd_convert() {
    local zip_file="${1:-}"
    local theme_name="${2:-}"

    [[ -n "$zip_file" ]] || die "No ZIP file specified.\nUsage: $0 --convert <zip-file> [theme-name]\nRun '$0 --help' for more info."

    # Resolve to absolute path before anything changes directory
    zip_file="$(cd "$(dirname "$zip_file")" 2>/dev/null && echo "$(pwd)/$(basename "$zip_file")" || echo "$zip_file")"

    header "Converting cursor theme"
    validate_zip "$zip_file"

    # Determine theme name
    if [[ -z "$theme_name" ]]; then
        theme_name=$(derive_theme_name "$zip_file")
        info "Auto-detected theme name: $theme_name"
    fi

    local output_dir="$CONVERTED_DIR/$theme_name"
    local cursors_dir="$output_dir/cursors"

    # Create temp dir
    CURSOR_TMP_DIR=$(mktemp -d)

    # Extract ZIP
    extract_zip "$zip_file" "$CURSOR_TMP_DIR"

    # Count cursor files
    local cursor_count
    cursor_count=$(find "$CURSOR_TMP_DIR" -type f \( -iname "*.cur" -o -iname "*.ani" \) 2>/dev/null | wc -l)

    if [[ "$cursor_count" -eq 0 ]]; then
        die "No .cur or .ani files found in the ZIP.\nThis doesn't appear to be a Windows cursor theme."
    fi
    info "Found $cursor_count cursor file(s)"

    # Clean previous conversion
    info "Cleaning previous conversion..."
    run rm -rf "$output_dir"

    # Ensure output directory exists
    run mkdir -p "$CONVERTED_DIR"

    # Convert cursors
    local converted failed
    read -r converted failed <<< "$(convert_cursors "$CURSOR_TMP_DIR" "$cursors_dir")"

    if [[ "$converted" -eq 0 ]]; then
        die "win2xcur conversion failed for all $cursor_count file(s).\nCheck that win2xcur is working correctly."
    fi
    info "Converted: $converted success, $failed failed"

    # Map cursor names to X11 standard names
    info "Mapping cursor names..."
    local mapped_count unmapped_count
    read -r mapped_count unmapped_count <<< "$(map_cursors "$cursors_dir")"
    info "Mapped: $mapped_count standard name(s), $unmapped_count unmapped"

    # Generate index.theme
    generate_index_theme "$output_dir" "$theme_name"

    # Generate README with manual install instructions
    generate_theme_readme "$output_dir" "$theme_name"

    # Summary
    header "Conversion complete"
    printf "  ${BOLD}Theme:${RESET}    %s\n" "$theme_name"
    printf "  ${BOLD}Cursors:${RESET}  %d converted, %d failed\n" "$converted" "$failed"
    printf "  ${BOLD}Mapped:${RESET}   %d standard X11 names\n" "$mapped_count"
    printf "  ${BOLD}Output:${RESET}   %s/%s/\n" "$CONVERTED_DIR" "$theme_name"

    # Manual install instructions
    printf "\n"
    info "To install manually, copy the theme to one of:"
    for dir in "${ICON_DIRS[@]}"; do
        printf "    ${BOLD}%s/<theme-name>/${RESET}\n" "$dir"
    done
    printf "\n"
    info "Then activate it with your desktop environment:"
    printf "  ${BOLD}KDE Plasma:${RESET}   plasma-apply-cursortheme '%s'\n" "$theme_name"
    printf "  ${BOLD}GNOME:${RESET}        gsettings set org.gnome.desktop.interface cursor-theme '%s'\n" "$theme_name"
    printf "  ${BOLD}XFCE:${RESET}         xfconf-query -c xsettings -p /Gtk/CursorThemeName -s '%s'\n" "$theme_name"
    printf "\n"
}

cmd_list() {
    header "Installed cursor themes"
    local found=false
    local -A listed=()

    for dir in "${ICON_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r theme_dir; do
            [[ -f "$theme_dir/index.theme" ]] || continue
            [[ -d "$theme_dir/cursors" ]] || continue

            local name cursor_count
            name=$(basename "$theme_dir")
            # Skip if already listed from another icon dir
            [[ -n "${listed[$name]:-}" ]] && continue
            listed[$name]=1

            cursor_count=$(find "$theme_dir/cursors" -maxdepth 1 -type f -o -type l | wc -l)

            if is_active_theme "$name"; then
                printf "  ${GREEN}*${RESET} ${BOLD}%-30s${RESET} %s cursor(s)  ${GREEN}[active]${RESET}\n" "$name" "$cursor_count"
            else
                printf "  ${DIM} ${RESET} %-30s %s cursor(s)\n" "$name" "$cursor_count"
            fi
            found=true
        done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    done

    $found || printf "  ${DIM}No cursor themes found.${RESET}\n"
}

cmd_uninstall() {
    local theme_name="${1:-}"
    [[ -n "$theme_name" ]] || die "No theme name specified.\nUsage: $0 --uninstall <theme-name>"

    header "Uninstalling '$theme_name'"
    local found=false

    for dir in "${ICON_DIRS[@]}"; do
        if [[ -d "$dir/$theme_name" ]]; then
            printf "  Will remove: %s/%s/\n" "$dir" "$theme_name"
            found=true
        fi
    done

    # Also check local copy
    if [[ -d "$SCRIPT_DIR/$theme_name" ]]; then
        printf "  Will remove: %s/%s/ (local copy)\n" "$SCRIPT_DIR" "$theme_name"
        found=true
    fi

    # Check converted copy
    if [[ -d "$CONVERTED_DIR/$theme_name" ]]; then
        printf "  Will remove: %s/%s/ (converted)\n" "$CONVERTED_DIR" "$theme_name"
        found=true
    fi

    $found || die "Theme '$theme_name' not found."

    if ! $DRY_RUN; then
        printf "\n"
        read -r -p "  Remove? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
    fi

    for dir in "${ICON_DIRS[@]}"; do
        run rm -rf "$dir/$theme_name"
    done
    run rm -rf "$SCRIPT_DIR/$theme_name"
    run rm -rf "$CONVERTED_DIR/$theme_name"

    refresh_icon_cache "$theme_name"

    # If the uninstalled theme was active, reset to a safe default
    if is_active_theme "$theme_name"; then
        warn "Uninstalled theme was active — resetting cursor"
        reset_cursor_theme
    fi

    success "Uninstalled '$theme_name'"
}

cmd_apply() {
    local theme_name="${1:-}"
    [[ -n "$theme_name" ]] || die "No theme name specified.\nUsage: $0 --apply <theme-name>"

    # Verify theme is installed
    local found=false
    for dir in "${ICON_DIRS[@]}"; do
        [[ -d "$dir/$theme_name/cursors" ]] && found=true && break
    done
    $found || die "Theme '$theme_name' not found. Install it first."

    header "Applying '$theme_name'"

    if apply_cursor_theme "$theme_name"; then
        success "Applied '$theme_name'"
        return
    fi

    # Manual instructions
    warn "Could not auto-apply. Set the cursor theme manually:"
    printf "\n"
    printf "  ${BOLD}GNOME/GTK:${RESET}    gsettings set org.gnome.desktop.interface cursor-theme '%s'\n" "$theme_name"
    printf "  ${BOLD}KDE Plasma:${RESET}   System Settings > Appearance > Cursors > select '%s'\n" "$theme_name"
    printf "  ${BOLD}XFCE:${RESET}         xfconf-query -c xsettings -p /Gtk/CursorThemeName -s '%s'\n" "$theme_name"
    printf "  ${BOLD}Xresources:${RESET}   Add 'Xcursor.theme: %s' to ~/.Xresources\n" "$theme_name"
    printf "  ${BOLD}Environment:${RESET}  export XCURSOR_THEME='%s' in ~/.profile or ~/.xinitrc\n" "$theme_name"
    printf "\n"
}

cmd_help() {
    cat <<EOF
${BOLD}install-windows-cursor${RESET} v${VERSION} — Convert Windows cursors to Linux themes

${BOLD}USAGE:${RESET}
    $0 [OPTIONS] <zip-file> [theme-name]
    $0 [OPTIONS] --convert <zip-file> [theme-name]
    $0 [OPTIONS] --list
    $0 [OPTIONS] --uninstall <theme-name>
    $0 [OPTIONS] --apply <theme-name>

${BOLD}ARGUMENTS:${RESET}
    <zip-file>      Path to a Windows cursor ZIP file (.cur / .ani)
    [theme-name]    Name for the theme (default: auto-detected from filename)

${BOLD}OPTIONS:${RESET}
    -h, --help          Show this help message
    -c, --convert       Convert only — saves to 'converted cursors/' without installing
    -l, --list          List installed cursor themes
    -u, --uninstall     Remove an installed cursor theme
    -a, --apply         Set a cursor theme as the active one
    -n, --dry-run       Preview actions without making changes
    -v, --version       Show version

${BOLD}EXAMPLES:${RESET}
    $0 my-theme.zip                    # Install with auto-detected name
    $0 my-theme.zip "My Theme"         # Install with custom name
    $0 --convert my-theme.zip          # Convert only — no install, no apply
    $0 --convert my-theme.zip "My Theme"  # Convert with custom name
    $0 --list                          # List installed themes
    $0 --apply "My Theme"              # Set as active cursor
    $0 --uninstall "My Theme"          # Remove a theme
    $0 --dry-run my-theme.zip          # Preview without changes

${BOLD}DEPENDENCIES:${RESET}
    unzip       Extract ZIP archives (auto-installed if missing)
    win2xcur    Convert Windows cursors to X11 (auto-installed if missing)

    The script detects your distro and offers to install missing
    dependencies automatically. Supported: Arch, Ubuntu/Debian,
    Fedora, openSUSE, NixOS, Void, Alpine, Gentoo, RHEL/CentOS.

${BOLD}CURSOR MAPPING:${RESET}
    The script maps Windows cursor names to standard X11 cursor names:
      Normal Select       → left_ptr, default, arrow, top_left_arrow
      Help Select         → help, question_arrow, whats_this
      Working in Background → left_ptr_watch, progress, half-busy
      Busy                → wait, watch
      Precision Select    → crosshair, cross, tcross
      Text Select         → xterm, ibeam, text
      Handwriting         → pencil, draft
      Unavailable         → not-allowed, forbidden, circle
      Vertical Resize     → ns-resize, v_double_arrow, size_ver
      Horizontal Resize   → ew-resize, h_double_arrow, size_hor
      Diagonal Resize 1   → nwse-resize, fd_double_arrow, size_fdiag
      Diagonal Resize 2   → nesw-resize, bd_double_arrow, size_bdiag
      Move                → move, size_all, fleur
      Link Select         → pointer, hand2, hand1, pointing_hand
EOF
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    if [[ $# -eq 0 ]]; then
        cmd_help
        exit 0
    fi

    local action="install"
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     cmd_help; exit 0 ;;
            -v|--version)  echo "install-windows-cursor.sh v${VERSION}"; exit 0 ;;
            -n|--dry-run)  DRY_RUN=true; shift ;;
            -c|--convert)  action="convert"; shift ;;
            -l|--list)     action="list"; shift ;;
            -u|--uninstall) action="uninstall"; shift ;;
            -a|--apply)    action="apply"; shift ;;
            -*)            die "Unknown option: $1\nRun '$0 --help' for usage." ;;
            *)             args+=("$1"); shift ;;
        esac
    done

    case "$action" in
        install)   check_deps; cmd_install "${args[@]}" ;;
        convert)   check_deps; cmd_convert "${args[@]}" ;;
        list)      cmd_list ;;
        uninstall) cmd_uninstall "${args[@]}" ;;
        apply)     cmd_apply "${args[@]}" ;;
    esac
}

main "$@"
