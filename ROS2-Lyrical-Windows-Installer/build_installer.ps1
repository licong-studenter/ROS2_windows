[CmdletBinding()]
param(
  [string]$RosInstall = 'C:\dev\lyrical\install',
  [string]$RuntimeRoot = 'C:\dev\.pixi\envs\default',
  [string]$WorkRoot = 'C:\ros2\installer-build',
  [string]$OutputPath = 'C:\ros2\ROS2-Lyrical-Windows-x64-Installer.exe',
  [int]$CompressionLevel = 5
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$sfxModule = Join-Path $projectRoot 'tools\7zSD.sfx'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
if (-not (Test-Path -LiteralPath $sevenZip)) { $sevenZip = 'C:\dev\.pixi\envs\default\Library\bin\7z.exe' }
if (-not (Test-Path -LiteralPath $sfxModule)) { throw "Missing SFX module: $sfxModule" }
if (-not (Test-Path -LiteralPath $sevenZip)) { throw '7-Zip executable not found.' }
if (-not (Test-Path -LiteralPath (Join-Path $RosInstall 'local_setup.bat'))) { throw "Invalid ROS install tree: $RosInstall" }
if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'python.exe'))) { throw "Invalid runtime tree: $RuntimeRoot" }

$workspace = [IO.Path]::GetFullPath('C:\ros2')
$work = [IO.Path]::GetFullPath($WorkRoot)
$output = [IO.Path]::GetFullPath($OutputPath)
if (-not $work.StartsWith($workspace + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "WorkRoot must be under $workspace" }
if (-not $output.StartsWith($workspace + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "OutputPath must be under $workspace" }
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null
$staging = Join-Path $work 'staging'
New-Item -ItemType Directory -Path $staging -Force | Out-Null

function Invoke-Robocopy([string]$Source, [string]$Destination) {
  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  & "$env:SystemRoot\System32\robocopy.exe" $Source $Destination /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /MT:8 /NFL /NDL /NJH /NJS /NP
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE for $Source" }
}

Write-Host '[1/4] Copying ROS 2 install tree...'
Invoke-Robocopy $RosInstall (Join-Path $staging 'ros')
Write-Host '[2/4] Copying portable runtime...'
Invoke-Robocopy $RuntimeRoot (Join-Path $staging 'runtime')
foreach ($name in @('install.ps1', 'uninstall.ps1', 'ros2.cmd', 'ros2_env.cmd', 'ros2_shell.cmd', 'README.md', 'INSTALLER_VERSION.txt')) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination (Join-Path $staging $name) -Force
}

$configPath = Join-Path $work 'installer-config.txt'
$config = @(
  ';!@Install@!UTF-8!',
  'Title="ROS 2 Lyrical Windows x64"',
  'Progress="yes"',
  'ExecuteFile="powershell.exe"',
  'ExecuteParameters="-NoProfile -ExecutionPolicy Bypass -File install.ps1"',
  ';!@InstallEnd@!'
) -join "`r`n"
[IO.File]::WriteAllText($configPath, $config, (New-Object Text.UTF8Encoding($false)))

Write-Host '[3/4] Compressing payload...'
$archive = Join-Path $work 'payload.7z'
$compressed = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
  Write-Host "Compression attempt $attempt..."
  & $sevenZip a -t7z -mx=$CompressionLevel -mmt=on -y -bso1 -bse1 $archive (Join-Path $staging '*')
  if ($LASTEXITCODE -eq 0) { $compressed = $true; break }
  Write-Warning "7-Zip compression attempt $attempt failed with exit code $LASTEXITCODE"
  if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
  Start-Sleep -Seconds 5
}
if (-not $compressed) { throw '7-Zip compression failed after three attempts' }

Write-Host '[4/4] Creating installer executable...'
$parts = @($sfxModule, $configPath, $archive)
$stream = [IO.File]::Create($output)
try {
  foreach ($part in $parts) {
    $input = [IO.File]::OpenRead($part)
    try {
      $buffer = New-Object byte[] (4MB)
      while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $stream.Write($buffer, 0, $read)
      }
    } finally { $input.Dispose() }
  }
} finally { $stream.Dispose() }

$hash = Get-FileHash -LiteralPath $output -Algorithm SHA256
$hashLine = '{0}  {1}' -f $hash.Hash.ToLowerInvariant(), [IO.Path]::GetFileName($output)
Set-Content -LiteralPath ($output + '.sha256') -Value $hashLine -Encoding ascii
Write-Host "Created: $output"
Write-Host ("Size: {0:N2} GB" -f ((Get-Item -LiteralPath $output).Length / 1GB))
Write-Host "SHA256: $($hash.Hash)"