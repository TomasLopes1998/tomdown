# Remove tomdown and its file association from the current Windows user.
# Per-user, no admin needed. Does not touch uv's cached venv.
#
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\tomdown'
$ProgId = 'tomdown.markdown'
$classesRoot = 'HKCU:\Software\Classes'
$progIdKey = Join-Path $classesRoot $ProgId
$mdKey = Join-Path $classesRoot '.md'
$mdOpenWithKey = Join-Path $mdKey 'OpenWithProgids'

# 1. If .md is currently pointing at our ProgID, clear it.
if (Test-Path $mdKey) {
    $current = (Get-ItemProperty -Path $mdKey -Name '(Default)' -ErrorAction SilentlyContinue).'(default)'
    if ($current -eq $ProgId) {
        Set-ItemProperty -Path $mdKey -Name '(Default)' -Value ''
    }
}
if (Test-Path $mdOpenWithKey) {
    Remove-ItemProperty -Path $mdOpenWithKey -Name $ProgId -ErrorAction SilentlyContinue
}

# 2. Drop the ProgID itself.
if (Test-Path $progIdKey) {
    Remove-Item -Path $progIdKey -Recurse -Force
}

# 3. Strip install dir from user PATH.
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath) {
    $entries = $userPath -split ';' | Where-Object { $_ -ne '' -and $_ -ne $InstallDir }
    $newPath = $entries -join ';'
    if ($newPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        Write-Host "removed from user PATH: $InstallDir"
    }
}

# 4. Remove the install dir.
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
}

# 5. Notify shell of the association change.
$signature = @'
[System.Runtime.InteropServices.DllImport("Shell32.dll")]
public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
'@
$shell = Add-Type -MemberDefinition $signature -Name 'NativeMethods' -Namespace 'TomdownUninstall' -PassThru
$shell::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)  # SHCNE_ASSOCCHANGED

Write-Host "removed tomdown and .md association"
