# jarbas-app

Voice chat and screen sharing for your whole community, right next to your game servers. Jarbas also keeps your mods in sync, so everyone joins with the same setup.

More details in https://jarbas.just4fun.games/download


## Install

**Linux and macOS**, in a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/marcoshack/jarbas-app/main/install.sh | sh
```

**Windows**, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/marcoshack/jarbas-app/main/install.ps1 | iex
```

Run the same command again to install the newest build. The installers download the latest build from Jarbas and refuse one whose SHA-256 does not match what Jarbas publishes.

| | Installs to | Also adds |
|---|---|---|
| Linux | `~/.local/opt/jarbas-app/versions/<version>`, with `current` pointing at the one in use | `jarbas-app` and `jarbas-cli` in `~/.local/bin`, and an application menu entry |
| macOS | `/Applications/Jarbas.app`, or `~/Applications` when `/Applications` is not writable | `jarbas-cli` in `~/.local/bin` |
| Windows | `%LOCALAPPDATA%\Programs\Jarbas\jarbas-app.exe` | a Start menu shortcut |

On Linux, screen share needs PipeWire and the desktop portal, which every current desktop runs. On Arch you can install the `.pkg.tar.zst` with `sudo pacman -U` instead.

## Uninstall

Your settings and profiles are kept.

```sh
curl -fsSL https://raw.githubusercontent.com/marcoshack/jarbas-app/main/uninstall.sh | sh
```

```powershell
irm https://raw.githubusercontent.com/marcoshack/jarbas-app/main/uninstall.ps1 | iex
```
