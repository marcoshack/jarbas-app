# Installs jarbas-app on Windows from a Jarbas deployment.
#
#   irm https://raw.githubusercontent.com/marcoshack/jarbas-app/main/install.ps1 | iex
#
# Installs %LOCALAPPDATA%\Programs\Jarbas\jarbas-app.exe, a folder the user owns
# so the app can update itself, and a Start menu shortcut; uninstall.ps1
# removes them.
#
# JARBAS_URL names another Jarbas deployment. Nothing is installed without a
# SHA-256 the deployment publishes and the download matches.

function Install-JarbasApp {
    $ErrorActionPreference = 'Stop'
    # Invoke-WebRequest's progress bar slows a download to a crawl on Windows PowerShell.
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $base = if ($env:JARBAS_URL) { $env:JARBAS_URL.TrimEnd('/') } else { 'https://jarbas.just4fun.games' }
    $installDir = Join-Path $env:LOCALAPPDATA 'Programs\Jarbas'
    $exe = Join-Path $installDir 'jarbas-app.exe'
    $shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Jarbas.lnk'

    # PROCESSOR_ARCHITEW6432 is the machine's own when this shell is emulated.
    $machine = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $arch = switch ($machine) {
        'AMD64' { 'x86_64' }
        'ARM64' { 'aarch64' }
        default { throw "Unsupported processor $machine." }
    }

    try {
        $feed = Invoke-RestMethod -UseBasicParsing -Uri "$base/api/v1/downloads/j5modman/latest?os=windows&arch=$arch"
    } catch {
        $status = $_.Exception.Response.StatusCode
        if ($status -and [int]$status -eq 404) { throw "$base has published no build for windows/$arch." }
        throw "Could not read the version feed from ${base}: $($_.Exception.Message)"
    }
    $release = $feed.data
    # A deployment that predates platforms names none and serves Windows x86_64.
    $os = if ($release.os) { $release.os } else { 'windows' }
    $relArch = if ($release.arch) { $release.arch } else { 'x86_64' }
    if ("$os/$relArch" -ne "windows/$arch") { throw "$base has published no build for windows/$arch." }
    $version = $release.version
    if (-not $version) { throw 'The version feed names no version.' }
    if ($release.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Build $version has no SHA-256 to verify it against; not installing."
    }

    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    # Downloaded beside the install so the final move is a rename.
    $download = Join-Path $installDir 'jarbas-app.download'
    Write-Host "Downloading jarbas-app $version for windows/$arch..."
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$base/downloads/j5modman?os=windows&arch=$arch" -OutFile $download
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash
        if ($actual -ne $release.sha256) {
            throw 'The download does not match the published SHA-256 (a new build may have been published meanwhile; run the installer again).'
        }
        $header = [byte[]]::new(2)
        $stream = [IO.File]::OpenRead($download)
        try { [void]$stream.Read($header, 0, 2) } finally { $stream.Dispose() }
        if ([Text.Encoding]::ASCII.GetString($header) -ne 'MZ') { throw 'The download is not a Windows executable.' }

        $aside = $null
        if (Test-Path -LiteralPath $exe) {
            # A running image cannot be overwritten but can be renamed; the app
            # deletes a *.__relocated__.exe still held then at its next start.
            $aside = Join-Path $installDir ("jarbas-app-{0}.__relocated__.exe" -f [guid]::NewGuid().ToString('N'))
            Move-Item -LiteralPath $exe -Destination $aside
        }
        try {
            Move-Item -LiteralPath $download -Destination $exe
        } catch {
            if ($aside) { Move-Item -LiteralPath $aside -Destination $exe }
            throw
        }
        if ($aside) { Remove-Item -LiteralPath $aside -Force -ErrorAction SilentlyContinue }
    } finally {
        Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
    }

    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    $link.TargetPath = $exe
    $link.WorkingDirectory = $installDir
    $link.Description = 'Jarbas'
    $link.Save()

    Write-Host "Installed jarbas-app $version in $installDir"
    Write-Host 'Start it from the Start menu: Jarbas.'
}

# Errors are thrown, never `exit`, so a window that ran `irm | iex` stays open.
Install-JarbasApp
