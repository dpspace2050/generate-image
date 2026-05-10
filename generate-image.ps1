param(
    [Parameter(Mandatory=$true)]
    [string]$PromptFile,

    [Parameter(Mandatory=$true)]
    [string]$ApiKey,

    [string]$Size = "1024x1024",

    [string]$Name = "",

    [string]$OutputDir = ""
)

# Read prompt from file to preserve original formatting (no PowerShell escaping issues)
$prompt = [System.IO.File]::ReadAllText($PromptFile, [System.Text.Encoding]::UTF8).Trim()

$body = @{
    model           = "gpt-image-2"
    prompt          = $prompt
    n               = 1
    size            = $Size
    response_format = "url"
} | ConvertTo-Json -Depth 3

# Write JSON body with UTF-8 no BOM (avoid "invalid character" error)
$tmpFile = "$env:TEMP\img-body.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tmpFile, $body, $utf8NoBom)

# Call API with 300s timeout to avoid Cloudflare 524
$response = curl.exe -s --max-time 300 -X POST "https://www.tokenlane.org/v1/images/generations" `
    -H "Authorization: Bearer $ApiKey" `
    -H "Content-Type: application/json" `
    -d "@$tmpFile"

Remove-Item $tmpFile -ErrorAction SilentlyContinue

$r = $response | ConvertFrom-Json
if ($r.error) {
    Write-Host "ERROR: $($r.error.message)"
    exit 1
}

# Resolve output path: OutputDir + Name.png
if ($OutputDir -eq "") { $OutputDir = "D:\Neo\Neo\images" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

if ($Name -eq "") { $Name = "img_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
if (-not $Name.EndsWith(".png")) { $Name += ".png" }

$output = Join-Path $OutputDir $Name

$url = $r.data[0].url
Invoke-WebRequest -Uri $url -OutFile $output
Write-Host "OK:$output"
