[CmdletBinding()]
param(
  [string]$InstallRoot = $env:ROS2_LYRICAL_INSTALL_ROOT,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$payloadRoot = $PSScriptRoot
$versionFile = Join-Path $payloadRoot 'INSTALLER_VERSION.txt'
$version = if (Test-Path -LiteralPath $versionFile) { (Get-Content -Raw -LiteralPath $versionFile).Trim() } else { 'lyrical-unknown' }
$logPath = Join-Path $env:TEMP 'ROS2-Lyrical-install.log'
try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }

function Write-Step([string]$Message) { Write-Host "[ROS2] $Message" -ForegroundColor Cyan }
function Fail([string]$Message) { throw $Message }

function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Robocopy([string]$Source, [string]$Destination) {
  if (-not (Test-Path -LiteralPath $Source)) { Fail "Missing payload directory: $Source" }
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  & "$env:SystemRoot\System32\robocopy.exe" $Source $Destination /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:8 /NFL /NDL /NJH /NJS /NP
  $code = $LASTEXITCODE
  if ($code -ge 8) { Fail "robocopy failed with exit code $code while copying $Source" }
}

function Repair-PythonShebangs([string]$BasePath, [string]$PythonPath) {
  if (-not (Test-Path -LiteralPath $BasePath)) { return }
  $files = Get-ChildItem -LiteralPath $BasePath -Recurse -File -Filter '*-script.py' -ErrorAction SilentlyContinue
  foreach ($file in $files) {
    $lines = [IO.File]::ReadAllLines($file.FullName)
    if ($lines.Length -gt 0 -and $lines[0].StartsWith('#!')) {
      $lines[0] = '#!' + $PythonPath
      [IO.File]::WriteAllLines($file.FullName, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }
  }
}

try {
  Write-Step "Checking system dependencies..."
  if (-not [Environment]::Is64BitOperatingSystem) { Fail 'ROS 2 Lyrical requires 64-bit Windows.' }
  if ([Environment]::OSVersion.Version.Build -lt 17763) { Fail 'ROS 2 Lyrical requires Windows 10 build 17763 or newer.' }

  $payloadItems = @('ros', 'runtime', 'ros2.cmd', 'ros2_env.cmd', 'ros2_shell.cmd', 'README.md', 'uninstall.ps1')
  foreach ($item in $payloadItems) {
    if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot $item))) { Fail "Installer payload is incomplete: $item" }
  }
  $requiredRuntimeFiles = @(
    'runtime\python.exe',
    'runtime\vcruntime140.dll',
    'runtime\msvcp140.dll',
    'runtime\Library\bin\Qt6Core.dll'
  )
  foreach ($relative in $requiredRuntimeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot $relative))) { Fail "Runtime dependency is missing: $relative" }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'ros\local_setup.bat'))) { Fail 'ROS 2 install tree is incomplete: local_setup.bat' }
  if (-not (Test-Path -LiteralPath (Join-Path $payloadRoot 'ros\Scripts\ros2-script.py'))) { Fail 'ROS 2 install tree is incomplete: ros2-script.py' }

  if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $env:LOCALAPPDATA 'ROS2\Lyrical'
  }
  $InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
  if ($InstallRoot.Length -gt 120) { Write-Warning 'The selected install path is long. Enable Windows long paths before use.' }

  $driveRoot = [IO.Path]::GetPathRoot($InstallRoot)
  $drive = New-Object System.IO.DriveInfo($driveRoot)
  $requiredBytes = 10GB
  if ($drive.AvailableFreeSpace -lt $requiredBytes) {
    Fail ("Not enough free disk space on {0}. Required at least 10 GB, available {1:N2} GB." -f $driveRoot, ($drive.AvailableFreeSpace / 1GB))
  }

  $longPathsEnabled = $false
  try {
    $longPathsEnabled = [int](Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction Stop).LongPathsEnabled -eq 1
  } catch { $longPathsEnabled = $false }
  if (-not $longPathsEnabled) {
    if (Test-Admin) {
      try {
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -PropertyType DWord -Force | Out-Null
        $longPathsEnabled = $true
        Write-Step 'Enabled Windows long path support.'
      } catch { Write-Warning 'Windows long paths are disabled and could not be enabled automatically.' }
    } else {
      Write-Warning 'Windows long paths are disabled. The installer will continue, but development tools may require long paths.'
    }
  }

  $marker = Join-Path $InstallRoot '.ros2_lyrical_install'
  if (Test-Path -LiteralPath $InstallRoot) {
    $existing = @(Get-ChildItem -Force -LiteralPath $InstallRoot -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0 -and -not (Test-Path -LiteralPath $marker) -and -not $Force) {
      Fail "Install directory is not empty and is not managed by this installer: $InstallRoot"
    }
  }

  Write-Step "Installing ROS 2 Lyrical to $InstallRoot"
  New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
  Invoke-Robocopy (Join-Path $payloadRoot 'ros') (Join-Path $InstallRoot 'ros')
  Invoke-Robocopy (Join-Path $payloadRoot 'runtime') (Join-Path $InstallRoot 'runtime')
  foreach ($name in @('ros2.cmd', 'ros2_env.cmd', 'ros2_shell.cmd', 'README.md', 'uninstall.ps1')) {
    Copy-Item -LiteralPath (Join-Path $payloadRoot $name) -Destination (Join-Path $InstallRoot $name) -Force
  }

  Write-Step 'Repairing Python launcher paths for the portable runtime...'
  $portablePython = Join-Path $InstallRoot 'runtime\python.exe'
  Repair-PythonShebangs (Join-Path $InstallRoot 'ros\Scripts') $portablePython
  Repair-PythonShebangs (Join-Path $InstallRoot 'ros\lib') $portablePython
  Repair-PythonShebangs (Join-Path $InstallRoot 'runtime\Scripts') $portablePython

  @{
    Distribution = 'lyrical'
    Version = $version
    InstalledAt = (Get-Date).ToString('o')
    InstallRoot = $InstallRoot
  } | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8

  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $pathEntries = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() })
  if (-not ($pathEntries | Where-Object { $_.TrimEnd('\') -ieq $InstallRoot.TrimEnd('\') })) {
    $newPath = (@($pathEntries) + $InstallRoot) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  }
  [Environment]::SetEnvironmentVariable('ROS2_LYRICAL_HOME', $InstallRoot, 'User')

  $shell = New-Object -ComObject WScript.Shell
  $startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\ROS 2 Lyrical'
  New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
  $shellLinkPath = Join-Path $startMenuDir 'ROS 2 Lyrical Shell.lnk'
  $shellLink = $shell.CreateShortcut($shellLinkPath)
  $shellLink.TargetPath = $env:ComSpec
  $shellLink.Arguments = '/k call "' + (Join-Path $InstallRoot 'ros2_env.cmd') + '"'
  $shellLink.WorkingDirectory = $InstallRoot
  $shellLink.IconLocation = (Join-Path $InstallRoot 'runtime\python.exe') + ',0'
  $shellLink.Save()

  $uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ROS2Lyrical'
  New-Item -Path $uninstallKey -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name DisplayName -Value 'ROS 2 Lyrical' -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name DisplayVersion -Value $version -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name Publisher -Value 'Open Robotics / local build' -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name UninstallString -Value ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $InstallRoot 'uninstall.ps1')) -PropertyType String -Force | Out-Null

  Write-Step 'Running installation smoke test...'
  $helpOutput = & (Join-Path $InstallRoot 'ros2.cmd') --help 2>&1
  if ($LASTEXITCODE -ne 0) { Fail 'Installed ros2 command failed its help smoke test.' }
  $packageOutput = & (Join-Path $InstallRoot 'ros2.cmd') pkg list 2>&1
  $packageCount = @($packageOutput | Where-Object { $_ -match '^[A-Za-z0-9_]+$' }).Count
  if ($packageCount -lt 300) { Fail "Installed package index is incomplete: only $packageCount packages found." }

  Write-Host ''
  Write-Host 'ROS 2 Lyrical installation completed successfully.' -ForegroundColor Green
  Write-Host "Install path: $InstallRoot"
  Write-Host "Package count: $packageCount"
  Write-Host "Open a new terminal, or run: $InstallRoot\ros2_shell.cmd"
  Write-Host 'Try:'
  Write-Host '  ros2 run demo_nodes_cpp talker'
  Write-Host '  ros2 run demo_nodes_py listener'
  try { Stop-Transcript | Out-Null } catch { }
  if ($env:ROS2_LYRICAL_NONINTERACTIVE -ne '1') { Read-Host 'Press Enter to close' | Out-Null }
} catch {
  Write-Host ''
  Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
  try { Stop-Transcript | Out-Null } catch { }
  if ($env:ROS2_LYRICAL_NONINTERACTIVE -ne '1') { Read-Host 'Press Enter to close' | Out-Null }
  exit 1
}