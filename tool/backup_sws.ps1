param(
  [string]$BackupRoot = "$PSScriptRoot\..\backups"
)
$ErrorActionPreference = 'Stop'
foreach ($name in @('SWS_DB_URL','SWS_SUPABASE_URL','SWS_SERVICE_ROLE_KEY')) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { throw "Set environment variable $name before running backup." }
}
if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) { throw 'pg_dump is not installed or not on PATH.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dest = Join-Path $BackupRoot $stamp
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$docsRoot = Join-Path $dest 'documents'
New-Item -ItemType Directory -Force -Path $docsRoot | Out-Null

Write-Host 'Backing up public database schema and data...'
$dbFile = Join-Path $dest "sws_public_$stamp.dump"
& pg_dump $env:SWS_DB_URL --schema=public --no-owner --no-privileges --format=custom --file $dbFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dbFile)) { throw 'pg_dump failed.' }

$base = $env:SWS_SUPABASE_URL.TrimEnd('/')
$headers = @{ apikey = $env:SWS_SERVICE_ROLE_KEY; Authorization = "Bearer $($env:SWS_SERVICE_ROLE_KEY)" }
Write-Host 'Reading document manifest from Supabase...'
$records = Invoke-RestMethod -Method Get -Uri "$base/rest/v1/traveler_documents?select=traveler_id,document_type,original_filename,storage_path,version_no,is_archived,created_at" -Headers $headers
$manifest = @()
foreach ($doc in $records) {
  if ([string]::IsNullOrWhiteSpace($doc.storage_path)) { continue }
  $segments = @('sws-private-documents') + ($doc.storage_path -split '/')
  $encoded = ($segments | ForEach-Object { [uri]::EscapeDataString([string]$_) }) -join '/'
  $category = ([string]$doc.document_type -replace '[\\/:*?"<>|]','_')
  $fileName = ([string]$doc.original_filename -replace '[\\/:*?"<>|]','_')
  $folder = Join-Path $docsRoot $category
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  $target = Join-Path $folder $fileName
  if (Test-Path $target) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $ext = [System.IO.Path]::GetExtension($fileName)
    $target = Join-Path $folder ("{0}_v{1}{2}" -f $stem, $doc.version_no, $ext)
  }
  $downloadUrl = "$base/storage/v1/object/authenticated/$encoded"
  Invoke-WebRequest -Method Get -Uri $downloadUrl -Headers $headers -OutFile $target
  if (-not (Test-Path $target) -or (Get-Item $target).Length -eq 0) { throw "Download failed or empty: $($doc.storage_path)" }
  $manifest += [pscustomobject]@{ traveler_id=$doc.traveler_id; document_type=$doc.document_type; original_filename=$doc.original_filename; storage_path=$doc.storage_path; version_no=$doc.version_no; is_archived=$doc.is_archived; local_file=$target; bytes=(Get-Item $target).Length }
}
$manifest | Export-Csv -NoTypeInformation -Encoding UTF8 -Path (Join-Path $dest 'documents_manifest.csv')
@{ created_at=(Get-Date).ToString('o'); database_dump=$dbFile; document_count=$manifest.Count; note='public schema dump plus document objects; Supabase Auth users and project settings are not included.' } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $dest 'backup_manifest.json')
Write-Host "Backup completed: $dest"
Write-Host "Database dump: $dbFile"
Write-Host "Documents downloaded: $($manifest.Count)"
