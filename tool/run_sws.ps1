param(
  [ValidateSet('chrome','windows')][string]$Target = 'chrome'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Install Flutter 3.44.3+ and ensure flutter is on PATH.' }
if ([string]::IsNullOrWhiteSpace($env:SWS_SUPABASE_URL)) { throw 'Set SWS_SUPABASE_URL environment variable first.' }
if ([string]::IsNullOrWhiteSpace($env:SWS_SUPABASE_PUBLIC_KEY)) { throw 'Set SWS_SUPABASE_PUBLIC_KEY to the public Publishable/anon key. Never use service_role.' }
Push-Location (Join-Path $PSScriptRoot '..')
try {
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
  flutter run -d $Target --dart-define="SUPABASE_URL=$env:SWS_SUPABASE_URL" --dart-define="SUPABASE_PUBLISHABLE_KEY=$env:SWS_SUPABASE_PUBLIC_KEY"
  if ($LASTEXITCODE -ne 0) { throw 'flutter run failed.' }
} finally { Pop-Location }
