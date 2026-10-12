#!/bin/sh
# Removes what install.sh installed on Linux or macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/marcoshack/jarbas-app/main/uninstall.sh | sh
#
# Your settings and profiles are kept.

set -eu

LINUX_HOME="$HOME/.local/opt/jarbas-app"
BIN_DIR="$HOME/.local/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_FILE="$DATA_HOME/applications/jarbas-app.desktop"
ICON_FILE="$DATA_HOME/icons/hicolor/scalable/apps/jarbas-app.svg"
MAC_APP="Jarbas.app"

# Removes the link $1 only when it points at a path matching the pattern $2.
unlink_if() {
    if [ -L "$1" ]; then
        # shellcheck disable=SC2254
        case "$(readlink "$1")" in $2) rm -f "$1" ;; esac
    fi
}

uninstall_linux() {
    unlink_if "$BIN_DIR/jarbas-app" "$LINUX_HOME/*"
    unlink_if "$BIN_DIR/jarbas-cli" "$LINUX_HOME/*"
    rm -f "$DESKTOP_FILE" "$ICON_FILE"
    command -v update-desktop-database >/dev/null 2>&1 &&
        update-desktop-database -q "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
    rm -rf "$LINUX_HOME"
}

uninstall_macos() {
    unlink_if "$BIN_DIR/jarbas-cli" "*/$MAC_APP/*"
    rm -rf "/Applications/$MAC_APP" "$HOME/Applications/$MAC_APP"
}

main() {
    case "$(uname -s)" in
        Linux) uninstall_linux ;;
        Darwin) uninstall_macos ;;
        *) printf 'error: unsupported operating system %s; on Windows use uninstall.ps1\n' "$(uname -s)" >&2; exit 1 ;;
    esac
    msg="Removed jarbas-app. Your settings and profiles are kept."
    # Green when stdout is a terminal and NO_COLOR is unset, as in install.sh.
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[32m%s\033[0m\n' "$msg"
    else
        printf '%s\n' "$msg"
    fi
}

main "$@"
