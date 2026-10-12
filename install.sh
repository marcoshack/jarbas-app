#!/bin/sh
# Installs jarbas-app on Linux or macOS from a Jarbas deployment.
#
#   curl -fsSL https://raw.githubusercontent.com/marcoshack/jarbas-app/main/install.sh | sh
#
# Linux:  ~/.local/opt/jarbas-app/versions/<version>, with a `current` link to
#         the installed one, links in ~/.local/bin and an application menu entry.
# macOS:  Jarbas.app in /Applications (~/Applications when that is not
#         writable), and jarbas-cli linked in ~/.local/bin.
#
# JARBAS_URL names another Jarbas deployment. Nothing is installed without a
# SHA-256 the deployment publishes and the download matches.

set -eu

JARBAS_URL="${JARBAS_URL:-https://jarbas.just4fun.games}"
JARBAS_URL="${JARBAS_URL%/}"
ASSETS_URL="https://raw.githubusercontent.com/marcoshack/jarbas-app/main/assets"

LINUX_HOME="$HOME/.local/opt/jarbas-app"
BIN_DIR="$HOME/.local/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_FILE="$DATA_HOME/applications/jarbas-app.desktop"
ICON_FILE="$DATA_HOME/icons/hicolor/scalable/apps/jarbas-app.svg"
MAC_APP="Jarbas.app"

say() { printf '%s\n' "$*"; }
# Success lines are green when stdout is a terminal and NO_COLOR is unset.
ok() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then printf '\033[32m%s\033[0m\n' "$*"; else say "$*"; fi
}
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is required but was not found"; }

usage() {
    say "Usage: install.sh"
    say ""
    say "Installs the latest jarbas-app published on $JARBAS_URL; uninstall.sh removes it."
}

detect_os() {
    case "$(uname -s)" in
        Linux) echo linux ;;
        Darwin) echo macos ;;
        *) die "unsupported operating system $(uname -s); on Windows use install.ps1" ;;
    esac
}

detect_arch() {
    arch="$(uname -m)"
    # A shell running under Rosetta reports x86_64 on an Apple silicon Mac.
    if [ "$arch" = x86_64 ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
        arch=arm64
    fi
    case "$arch" in
        x86_64 | amd64) echo x86_64 ;;
        aarch64 | arm64) echo aarch64 ;;
        *) die "unsupported processor $arch" ;;
    esac
}

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        die "sha256sum or shasum is required but neither was found"
    fi
}

# One string field of the feed's JSON; the fields read here never hold a quote.
json_field() {
    tr -d '\n' <"$1" | sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

# Fetches the feed for this platform and sets VERSION and SHA256.
read_feed() {
    feed="$TMP/feed.json"
    status="$(curl -sSL -o "$feed" -w '%{http_code}' "$JARBAS_URL/api/v1/downloads/j5modman/latest?os=$OS&arch=$ARCH")" ||
        die "could not reach $JARBAS_URL"
    case "$status" in
        200) ;;
        404) die "$JARBAS_URL has published no build for $OS/$ARCH" ;;
        *) die "$JARBAS_URL answered HTTP $status for the version feed" ;;
    esac
    VERSION="$(json_field "$feed" version)"
    SHA256="$(json_field "$feed" sha256 | tr 'A-F' 'a-f')"
    feed_os="$(json_field "$feed" os)"
    feed_arch="$(json_field "$feed" arch)"
    # A deployment that predates platforms names none and serves Windows x86_64.
    [ "${feed_os:-windows}/${feed_arch:-x86_64}" = "$OS/$ARCH" ] ||
        die "$JARBAS_URL has published no build for $OS/$ARCH"
    [ -n "$VERSION" ] || die "the version feed names no version"
    case "$SHA256" in
        *[!0-9a-f]* | "") die "build $VERSION has no SHA-256 to verify it against; not installing" ;;
    esac
    [ "${#SHA256}" -eq 64 ] || die "build $VERSION has a malformed SHA-256; not installing"
}

# Downloads the build into $1 and checks it against the feed's digest.
download() {
    say "Downloading jarbas-app $VERSION for $OS/$ARCH..."
    curl -fSL --progress-bar -o "$1" "$JARBAS_URL/downloads/j5modman?os=$OS&arch=$ARCH" ||
        die "the download failed"
    actual="$(sha256_of "$1")"
    [ "$actual" = "$SHA256" ] ||
        die "the download does not match the published SHA-256 (a new build may have been published meanwhile; run the installer again)"
}

# The version as a directory name: the deployment's version is free text.
version_dir() {
    v="$(printf '%s' "$VERSION" | sed 's/[^A-Za-z0-9._-]/_/g' | cut -c1-64)"
    case "$v" in "" | . | ..) v=build ;; esac
    echo "$v"
}

# Points $2 at $1 unless $2 is a file this installer did not make.
link() {
    if [ -e "$2" ] && [ ! -L "$2" ]; then
        say "warning: $2 exists and is not a link; leaving it alone"
        return
    fi
    ln -sfn "$1" "$2"
}

path_hint() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) say "Add $BIN_DIR to your PATH to run jarbas-cli from a terminal." ;;
    esac
}

install_linux() {
    need tar
    mkdir -p "$LINUX_HOME/versions" "$BIN_DIR"
    # Staged beside the versions so the final move is a rename.
    stage="$(mktemp -d "$LINUX_HOME/.install.XXXXXX")"
    STAGE="$stage"
    download "$stage/download"

    unpacked="$stage/unpacked"
    mkdir "$unpacked"
    magic="$(head -c 4 "$stage/download" | od -An -tx1 | tr -d ' \n')"
    case "$magic" in
        7f454c46)
            # A shelf still holding the bare executable rather than the archive.
            mv "$stage/download" "$unpacked/jarbas-app"
            chmod 755 "$unpacked/jarbas-app"
            ;;
        1f8b* | 425a68* | fd377a58*)
            tar -xf "$stage/download" -C "$unpacked" || die "could not unpack the archive"
            ;;
        *) die "the download is neither an archive nor a Linux executable" ;;
    esac

    # The release archive holds one top folder; install its contents.
    src="$unpacked"
    set -- "$unpacked"/*
    if [ "$#" -eq 1 ] && [ -d "$1" ]; then src="$1"; fi
    [ -x "$src/jarbas-app" ] || die "the download holds no jarbas-app executable"

    dir="$(version_dir)"
    rm -rf "$LINUX_HOME/versions/$dir"
    mv "$src" "$LINUX_HOME/versions/$dir"
    # The archive's own timestamp is the build's; pruning orders by install.
    touch "$LINUX_HOME/versions/$dir"
    ln -s "versions/$dir" "$stage/current"
    mv -T "$stage/current" "$LINUX_HOME/current"
    rm -rf "$stage"
    STAGE=""

    for bin in jarbas-app jarbas-cli; do
        if [ -e "$LINUX_HOME/current/$bin" ]; then
            link "$LINUX_HOME/current/$bin" "$BIN_DIR/$bin"
        fi
    done

    mkdir -p "$(dirname "$DESKTOP_FILE")" "$(dirname "$ICON_FILE")"
    curl -fsSL -o "$ICON_FILE" "$ASSETS_URL/jarbas-app.svg" || say "warning: could not fetch the icon"
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Jarbas
GenericName=Mod manager
Comment=Keep your mods in step with your Jarbas game servers, and talk in voice rooms
Exec="$LINUX_HOME/current/jarbas-app"
Icon=jarbas-app
Terminal=false
Categories=Game;Utility;
StartupWMClass=jarbas-app
EOF
    command -v update-desktop-database >/dev/null 2>&1 &&
        update-desktop-database -q "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true

    prune_versions "$dir"

    ok "Installed jarbas-app $VERSION in $LINUX_HOME/versions/$dir"
    ok "Start it from your application menu, or run jarbas-app."
    path_hint
    if [ -f /opt/jarbas-app/packaged-by ]; then
        say "note: the Arch package is installed too; remove it with 'sudo pacman -R jarbas-app' to keep one copy."
    fi
}

# Keeps the installed version and the newest other one, for a rollback.
prune_versions() {
    kept=""
    for v in $(ls -1t "$LINUX_HOME/versions"); do
        [ "$v" = "$1" ] && continue
        if [ -z "$kept" ]; then kept="$v"; continue; fi
        rm -rf "$LINUX_HOME/versions/$v"
    done
}

mac_app_dir() {
    if [ -w /Applications ]; then echo /Applications; else echo "$HOME/Applications"; fi
}

# The bundle was staged under a hidden name, which Spotlight skips, and macOS
# only registers an app on its first launch. Register and index it now so it
# shows up in Spotlight and Launchpad straight away. Best effort.
register_mac_app() {
    lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    [ -x "$lsregister" ] && "$lsregister" -f "$1" >/dev/null 2>&1 || true
    command -v mdimport >/dev/null 2>&1 && mdimport "$1" >/dev/null 2>&1 || true
}

install_macos() {
    need hdiutil
    need ditto
    download "$TMP/jarbas-app.dmg"

    MOUNT="$TMP/mount"
    mkdir "$MOUNT"
    # Newer macOS deprecates `hdiutil attach` in favour of `diskutil image`;
    # older releases only have hdiutil.
    if diskutil image attach --help >/dev/null 2>&1; then
        diskutil image attach --readOnly --nobrowse --mountPoint "$MOUNT" "$TMP/jarbas-app.dmg" >/dev/null
    else
        hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$TMP/jarbas-app.dmg" >/dev/null
    fi || die "could not open the disk image"
    [ -d "$MOUNT/$MAC_APP" ] || die "the disk image holds no $MAC_APP"

    apps="$(mac_app_dir)"
    mkdir -p "$apps"
    rm -rf "$apps/.$MAC_APP.new"
    ditto "$MOUNT/$MAC_APP" "$apps/.$MAC_APP.new"
    hdiutil detach -quiet "$MOUNT" || true
    MOUNT=""
    rm -rf "$apps/$MAC_APP"
    mv "$apps/.$MAC_APP.new" "$apps/$MAC_APP"
    register_mac_app "$apps/$MAC_APP"

    cli="$apps/$MAC_APP/Contents/MacOS/jarbas-cli"
    if [ -x "$cli" ]; then
        mkdir -p "$BIN_DIR"
        link "$cli" "$BIN_DIR/jarbas-cli"
    fi

    ok "Installed jarbas-app $VERSION in $apps/$MAC_APP"
    ok "Start it from Launchpad or Spotlight."
    [ -x "$cli" ] && path_hint
    return 0
}

cleanup() {
    if [ -n "${MOUNT:-}" ]; then hdiutil detach -quiet "$MOUNT" 2>/dev/null || true; fi
    if [ -n "${STAGE:-}" ]; then rm -rf "$STAGE"; fi
    if [ -n "${TMP:-}" ]; then rm -rf "$TMP"; fi
}

main() {
    for arg in "$@"; do
        case "$arg" in
            -h | --help) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
    done

    OS="$(detect_os)"

    need curl
    ARCH="$(detect_arch)"
    TMP="$(mktemp -d)"
    STAGE=""
    MOUNT=""
    trap cleanup EXIT
    trap 'exit 130' INT TERM
    read_feed
    "install_$OS"
}

# Everything runs from here, so a download cut short runs nothing.
main "$@"
