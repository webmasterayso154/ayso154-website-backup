param(
  [string]$CmsJsonUrl = "https://script.google.com/macros/s/AKfycbz3o3rRzPb0MRfse8uJ6QrbqbH7JA-XgT8lX4kp5Fc3DdIekIlKbAQGN5-geZGBMFJ08w/exec?format=json"
)

$RepoRoot = $PSScriptRoot
$outputLog = [System.Collections.Generic.List[string]]::new()
$outputLog.Add("⚡ Organizing AYSO 154 Website Backup Repo at: $RepoRoot")

$Folders = @(
  "src/styles",
  "src/partials",
  "src/templates",
  "active",
  "active/github-pages",
  "archive-drafts",
  "assets/logos",
  "assets/docs-2026"
)

foreach ($dir in $Folders) {
  $fullPath = Join-Path $RepoRoot $dir
  if (-not (Test-Path $fullPath)) {
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    $outputLog.Add("  + Created folder: $dir")
  }
}

$MasterCssPath = Join-Path $RepoRoot "src/styles/master-r154.css"
if (-not (Test-Path $MasterCssPath)) {
  @'
.ayso-r154-scope {
  --r154-navy: #002D62;
  --r154-navy-dark: #001A3D;
  --r154-red: #C8102E;
  --r154-gold: #FFD34D;
  --r154-bg-light: #F4F6F9;
  --r154-white: #FFFFFF;
  --r154-border: #E2E8F0;
  --r154-text: #0F172A;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
  color: var(--r154-text) !important;
  line-height: 1.6 !important;
  max-width: 1140px;
  margin: 0 auto;
  padding: 16px;
  box-sizing: border-box;
}
.ayso-r154-scope *, .ayso-r154-scope *::before, .ayso-r154-scope *::after { box-sizing: border-box; }
'@ | Set-Content -Path $MasterCssPath -Encoding UTF8
  $outputLog.Add("  + Created separated stylesheet: src/styles/master-r154.css")
}

$SheetTokens = @{}
if ($CmsJsonUrl -ne "") {
  try {
    $outputLog.Add("🌐 Fetching live tokens from Master Google Sheet Web App...")
    $response = Invoke-RestMethod -Uri $CmsJsonUrl -Method Get -MaximumRedirection 5
    if ($response.tokens) {
      foreach ($prop in $response.tokens.PSObject.Properties) {
        $SheetTokens[$prop.Name] = $prop.Value
      }
      $outputLog.Add("  ✅ Successfully loaded $($SheetTokens.Count) live tokens from Master Sheet.")
    }
  } catch {
    $outputLog.Add("WARNING: Could not fetch live Sheet JSON: $($_.Exception.Message)")
  }
}

$CombinedCss = (Get-ChildItem -Path (Join-Path $RepoRoot "src/styles") -Filter "*.css" | Sort-Object Name | ForEach-Object {
  Get-Content $_.FullName -Raw
}) -join "`n"

$Partials = @{}
Get-ChildItem -Path (Join-Path $RepoRoot "src/partials") -Filter "*.html" -ErrorAction SilentlyContinue | ForEach-Object {
  $Partials["PARTIAL_" + $_.BaseName] = Get-Content $_.FullName -Raw
}

$Templates = Get-ChildItem -Path (Join-Path $RepoRoot "src/templates") -Filter "*.template.html" -ErrorAction SilentlyContinue
foreach ($tpl in $Templates) {
  $htmlBody = Get-Content $tpl.FullName -Raw

  foreach ($key in $Partials.Keys) {
    $htmlBody = $htmlBody.Replace("{{$key}}", $Partials[$key])
  }

  foreach ($key in $SheetTokens.Keys) {
    $htmlBody = $htmlBody.Replace("{{$key}}", [string]$SheetTokens[$key])
  }

  $outFileName = $tpl.Name.Replace(".template.html", ".html")
  $outPath = Join-Path $RepoRoot "active/$outFileName"

  $bundledContent = @"
<!-- AUTO-GENERATED FOR SPORTSCONNECT CMS BY build.ps1 -->
<style>
$CombinedCss
</style>
<div class="ayso-r154-scope">
$htmlBody
</div>
"@

  Set-Content -Path $outPath -Value $bundledContent -Encoding UTF8
  $outputLog.Add("  ✅ Compiled single-file SportsConnect page: active/$outFileName")
}

$outputLog.Add("🎉 Build Complete!")

# Output text to pipeline and copy to clipboard automatically
$finalText = $outputLog -join "`n"
$finalText | Set-Clipboard
Write-Output $finalText