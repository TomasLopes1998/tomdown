# Install tomdown as the default Markdown viewer for the current Windows user.
# Per-user, no admin/UAC needed. Idempotent — safe to re-run.
#
# Run from the repo root (in PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\install.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\tomdown'
$Source = Join-Path $ScriptDir 'tomdown'
$Shim = Join-Path $ScriptDir 'tomdown.cmd'
$ProgId = 'tomdown.markdown'

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Error "'uv' is required (https://docs.astral.sh/uv/). Install it first (e.g. 'winget install astral-sh.uv')."
}
if (-not (Test-Path $Source)) {
    Write-Error "Source script not found: $Source"
}
if (-not (Test-Path $Shim)) {
    Write-Error "Shim not found: $Shim"
}

# 1. Copy script + shim into the install dir.
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$TargetPy = Join-Path $InstallDir 'tomdown.py'
$TargetCmd = Join-Path $InstallDir 'tomdown.cmd'

# Strip the unix shebang line if present; uv reads the inline PEP 723 block either way.
$content = Get-Content -Raw -LiteralPath $Source
if ($content.StartsWith('#!')) {
    $content = $content -replace '^#![^\r\n]*\r?\n', ''
}
Set-Content -LiteralPath $TargetPy -Value $content -Encoding UTF8 -NoNewline
Copy-Item -LiteralPath $Shim -Destination $TargetCmd -Force

# 2. Add install dir to user PATH (idempotent).
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (-not $userPath) { $userPath = '' }
$pathEntries = $userPath -split ';' | Where-Object { $_ -ne '' }
if ($pathEntries -notcontains $InstallDir) {
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "added to user PATH: $InstallDir"
}

# 3. Register a per-user ProgID for .md files.
$classesRoot = 'HKCU:\Software\Classes'
$progIdKey = Join-Path $classesRoot $ProgId
$shellOpenCmdKey = Join-Path $progIdKey 'shell\open\command'
$mdKey = Join-Path $classesRoot '.md'
$mdOpenWithKey = Join-Path $mdKey 'OpenWithProgids'

New-Item -Path $progIdKey -Force | Out-Null
Set-ItemProperty -Path $progIdKey -Name '(Default)' -Value 'Markdown File (tomdown)'
Set-ItemProperty -Path $progIdKey -Name 'FriendlyTypeName' -Value 'Markdown File'

New-Item -Path $shellOpenCmdKey -Force | Out-Null
Set-ItemProperty -Path $shellOpenCmdKey -Name '(Default)' -Value "`"$TargetCmd`" `"%1`""

# Register tomdown as a candidate handler and set as default for .md (per-user).
New-Item -Path $mdKey -Force | Out-Null
Set-ItemProperty -Path $mdKey -Name '(Default)' -Value $ProgId
Set-ItemProperty -Path $mdKey -Name 'Content Type' -Value 'text/markdown'
Set-ItemProperty -Path $mdKey -Name 'PerceivedType' -Value 'text'
New-Item -Path $mdOpenWithKey -Force | Out-Null
Set-ItemProperty -Path $mdOpenWithKey -Name $ProgId -Value ''

# 4. Notify shell of the association change.
$signature = @'
[System.Runtime.InteropServices.DllImport("Shell32.dll")]
public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
'@
$shell = Add-Type -MemberDefinition $signature -Name 'NativeMethods' -Namespace 'TomdownInstall' -PassThru
$shell::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)  # SHCNE_ASSOCCHANGED

Write-Host ""
Write-Host "installed: $TargetPy"
Write-Host "shim:      $TargetCmd"
Write-Host "ProgID:    $ProgId  (HKCU\Software\Classes)"
Write-Host ""
Write-Host "Open a Markdown file with:"
Write-Host "  tomdown path\to\file.md"
Write-Host "or double-click any .md file in Explorer."
Write-Host ""
Write-Host "Note: open a NEW shell to pick up the updated PATH."
Write-Host "Note: the first time you double-click an .md file, Windows may ask"
Write-Host "      'How do you want to open this?' — pick tomdown and tick 'Always use'."
