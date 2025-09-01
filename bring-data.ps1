param(
    [Parameter(Mandatory)]
    [ValidateSet('csv','json','api')]
    [string]$SourceType,

    # For csv/json: local path to file. For api: ignored.
    
    [string]$Path,

    # For api: full URL. For csv/json: ignored.
    [string]$Url,

    # Output file (extension determines format: .json or .csv)
    [string]$OutFile = ".\data-output.json",

    # Preview first N records on screen
    [int]$Top = 5
)

function Write-Preview($objects, $top) {
    if ($null -eq $objects) { Write-Warning "No data to preview."; return }
    $preview = $objects | Select-Object -First $top
    Write-Host "`nPreview (first $top rows):"
    $preview | Format-Table -AutoSize
}

try {
    switch ($SourceType) {
        'csv' {
            if (-not $Path) { throw "For -SourceType csv, please provide -Path to a CSV file." }
            if (-not (Test-Path $Path)) { throw "CSV not found: $Path" }
            $data = Import-Csv -Path $Path
        }
        'json' {
            if (-not $Path) { throw "For -SourceType json, please provide -Path to a JSON file." }
            if (-not (Test-Path $Path)) { throw "JSON not found: $Path" }
            $jsonRaw = Get-Content -Path $Path -Raw
            $data = $jsonRaw | ConvertFrom-Json
            # Normalize scalars into an array of one, so export is consistent
            if ($data -isnot [System.Collections.IEnumerable]) { $data = @($data) }
        }
        'api' {
            if (-not $Url) { throw "For -SourceType api, please provide -Url." }
            $data = Invoke-RestMethod -Uri $Url -Method GET
            if ($data -isnot [System.Collections.IEnumerable]) { $data = @($data) }
        }
    }

    Write-Preview -objects $data -top $Top

    # Save
    $ext = [System.IO.Path]::GetExtension($OutFile).ToLowerInvariant()
    switch ($ext) {
        '.json' {
            $data | ConvertTo-Json -Depth 100 | Set-Content -Path $OutFile -Encoding UTF8
            Write-Host "`nSaved JSON to $OutFile"
        }
        '.csv' {
            # Flatten if needed; for nested JSON, Export-Csv will show type names; JSON is better for deep data.
            $data | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
            Write-Host "`nSaved CSV to $OutFile"
        }
        default {
            throw "Unsupported output extension: $ext. Use .json or .csv"
        }
    }
}
catch {
    Write-Error $_
    exit 1
}
