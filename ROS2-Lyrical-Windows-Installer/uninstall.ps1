[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$installRoot = $PSScriptRoot
$marker = Join-Path $installRoot '.ros2_lyrical_install'
if (-not (Test-Path -LiteralPath $marker)) {
  throw "Refusing to uninstall: $installRoot is not a ROS 2 Lyrical installation."
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
  $entries = @($userPath -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ine $installRoot.TrimEnd('\')) })
  [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
}
if ($env:ROS2_LYRICAL_HOME -and ($env:ROS2_LYRICAL_HOME.TrimEnd('\') -ieq $installRoot.TrimEnd('\'))) {
  [Environment]::SetEnvironmentVariable('ROS2_LYRICAL_HOME', $null, 'User')
}

$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\ROS 2 Lyrical'
if (Test-Path -LiteralPath $startMenuDir) { Remove-Item -LiteralPath $startMenuDir -Recurse -Force }
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ROS2Lyrical'
if (Test-Path -LiteralPath $uninstallKey) { Remove-Item -LiteralPath $uninstallKey -Recurse -Force }

Write-Host "ROS 2 Lyrical uninstall information removed. Deleting $installRoot ..."
$escapedRoot = $installRoot.Replace("'", "''")
$cleanup = "Start-Sleep -Seconds 2; Remove-Item -LiteralPath '$escapedRoot' -Recurse -Force"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanup))
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) -WindowStyle Hidden