# Removes what install.ps1 installed on Windows.
#
#   irm https://raw.githubusercontent.com/marcoshack/jarbas-app/main/uninstall.ps1 | iex
#
# Your settings and profiles are kept.

function Uninstall-JarbasApp {
    $ErrorActionPreference = 'Stop'

    $installDir = Join-Path $env:LOCALAPPDATA 'Programs\Jarbas'
    $shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Jarbas.lnk'

    if (Get-Process -Name 'jarbas-app' -ErrorAction SilentlyContinue) {
        throw 'Close Jarbas before removing it.'
    }
    Remove-Item -LiteralPath $shortcut -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $installDir) { Remove-Item -LiteralPath $installDir -Recurse -Force }
    Write-Host 'Removed jarbas-app. Your settings and profiles are kept.' -ForegroundColor Green
}

# Errors are thrown, never `exit`, so a window that ran `irm | iex` stays open.
Uninstall-JarbasApp
