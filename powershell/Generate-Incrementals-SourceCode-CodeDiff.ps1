param(
    [Parameter(Mandatory = $true)]
    [string]$RepoPath,

    [Parameter(Mandatory = $true)]
    [string]$BaseRelease,

    [Parameter(Mandatory = $true)]
    [string]$TargetRelease,

    [Parameter(Mandatory = $true)]
    [string]$OutputFolder,  

    [Parameter(Mandatory = $true)]
    [string]$JiraRef,

    [Parameter(Mandatory = $true)]
    [string]$AppName
)
# =================================================
# STANDARDIZED RELEASE OUTPUT STRUCTURE
# =================================================

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$BaseOutput = Join-Path $ProjectRoot "Report-output"

# Treat OutputFolder as optional label — clean any path sent by backend
$OptionalLabel = $OutputFolder

# Remove slashes, dots, and "release_" prefix if backend sends path
if (-not [string]::IsNullOrWhiteSpace($OptionalLabel)) {

    $OptionalLabel = Split-Path $OptionalLabel -Leaf
    $OptionalLabel = $OptionalLabel -replace '^release_', ''
    $OptionalLabel = $OptionalLabel -replace '[^a-zA-Z0-9._-]', ''

    if ($OptionalLabel -eq $TargetRelease) {
        $OptionalLabel = ""
    }
}

if ([string]::IsNullOrWhiteSpace($OptionalLabel)) {
    $ReleaseName = $TargetRelease
}
else {
    $ReleaseName = "$TargetRelease`_$OptionalLabel"
}

$ReleaseRoot = Join-Path $BaseOutput "$AppName\$ReleaseName"

# =================================================
# PROMOTED RELEASE FOLDERS (NO 02_Incrementals)
# =================================================

$ParentReleaseDir = Split-Path $ReleaseRoot -Parent
$ReleaseLeaf = Split-Path $ReleaseRoot -Leaf

# Take first 3 characters of AppName (ORM from ORM_26_1_DEV)
$AppShort = $AppName.Substring(0, 3).ToUpper()

$incrementalsFolder = Join-Path $ParentReleaseDir "${ReleaseLeaf}_${AppShort}_Incrementals"
$SourceExportPath = Join-Path $ParentReleaseDir "${ReleaseLeaf}_${AppShort}_Source_Code"
$CodeDiffPath = Join-Path $ParentReleaseDir "${ReleaseLeaf}_${AppShort}_Code_Diff"

New-Item -ItemType Directory -Force -Path $incrementalsFolder | Out-Null
New-Item -ItemType Directory -Force -Path $SourceExportPath   | Out-Null
New-Item -ItemType Directory -Force -Path $CodeDiffPath       | Out-Null

Write-Host "Release Root: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "DEBUG Incrementals OutputFolder: $OutputFolder" -ForegroundColor Green

$outputFile = Join-Path $incrementalsFolder ($JiraRef + "_Incrementals.csv")
# =================================================
# VALIDATION
# =================================================
if (-not (Test-Path $RepoPath)) {
    Write-Error "Repository path does not exist."
    exit 1
}

Set-Location $RepoPath

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not a valid git repository."
    exit 1
}

# =================================================
# LOCATE RELEASE MARKER COMMITS (STANDARDIZED LOGIC)
# =================================================
Write-Host "Locating release markers..." -ForegroundColor Yellow

$BaseCommit = git log --oneline --grep="build.properties -> $BaseRelease" -n 1 |
ForEach-Object { ($_ -split ' ')[0] }

$TargetCommit = git log --oneline --grep="build.properties -> $TargetRelease" -n 1 |
ForEach-Object { ($_ -split ' ')[0] }

if (-not $BaseCommit -or -not $TargetCommit) {
    Write-Error "Base or Target release marker not found."
    exit 1
}

Write-Host "Base Commit   : $BaseCommit"   -ForegroundColor Green
Write-Host "Target Commit : $TargetCommit" -ForegroundColor Green

# =================================================
# GENERATE DIFF
# =================================================
$diff = git diff --name-status "$BaseCommit..$TargetCommit"

if (-not $diff) {
    Write-Host "No changes found between releases."
    exit 0
}

# =================================================
# BUILD INCREMENTALS CSV
# =================================================
$result = @()
$counter = 1

foreach ($line in $diff) {

    $parts = $line -split "`t"
    $statusCode = $parts[0]
    $fileName = $parts[-1]

    switch -Wildcard ($statusCode) {
        "A" { $status = "Added" }
        "M" { $status = "Modified" }
        "D" { $status = "Deleted" }
        "R*" { $status = "Renamed" }
        default { $status = "Changed" }
    }

    $result += [PSCustomObject]@{
        "S. NO."                   = $counter
        "File Name"                = $fileName
        "Status"                   = $status
        "JIRA / Release Reference" = $JiraRef
    }

    $counter++
}

$result | Export-Csv $outputFile -NoTypeInformation

# =================================================
# EXTRACT SOURCE FILES
# =================================================
if (-not (Test-Path $SourceExportPath)) {
    New-Item -ItemType Directory -Path $SourceExportPath | Out-Null
}

foreach ($row in $result) {

    if ($row.Status -in @("Added", "Modified", "Renamed")) {

        $sourceFile = Join-Path $RepoPath $row."File Name"
        $destFile = Join-Path $SourceExportPath $row."File Name"

        $destDir = Split-Path $destFile
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if (Test-Path $sourceFile) {
            Copy-Item $sourceFile $destFile -Force
        }
    }
}

# =================================================
# GENERATE CODE DIFF FILE
# =================================================
if (-not (Test-Path $CodeDiffPath)) {
    New-Item -ItemType Directory -Path $CodeDiffPath | Out-Null
}

$diffFile = Join-Path $CodeDiffPath ($JiraRef + "_" + $AppName + "_CodeDiff.diff")

git diff $BaseCommit $TargetCommit `
    --no-color `
    --patch `
| Out-File -FilePath $diffFile -Encoding UTF8

# =================================================
# DONE
# =================================================
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Incrementals & CodeDiff Generated Successfully"
Write-Output "RELEASE_ROOT=$ReleaseRoot"
Write-Host " CSV  : $outputFile"
Write-Host " DIFF : $diffFile"
Write-Host "==============================================" -ForegroundColor Green
