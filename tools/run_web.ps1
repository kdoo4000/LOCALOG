[CmdletBinding()]
param(
  [string]$Device = 'chrome',
  [int]$WebPort = 0
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'config\local.json'

if (-not (Test-Path -LiteralPath $configPath)) {
  throw "Missing local config: $configPath"
}

$config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath |
  ConvertFrom-Json
$clientId = $config.NAVER_MAP_CLIENT_ID
if ([string]::IsNullOrWhiteSpace($clientId) -or $clientId -eq 'YOUR_NAVER_MAP_CLIENT_ID') {
  throw 'Set NAVER_MAP_CLIENT_ID in config/local.json before running the app.'
}

$flutterArgs = @(
  'run',
  '-d',
  $Device,
  "--dart-define-from-file=$configPath"
)
if ($WebPort -gt 0) {
  $flutterArgs += "--web-port=$WebPort"
}

Push-Location $projectRoot
try {
  & flutter @flutterArgs
} finally {
  Pop-Location
}
