param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,

    [Parameter(Mandatory=$true)]
    [string]$BaseCommit,

    [string]$TargetCommit = "HEAD",

    [Parameter(Mandatory=$true)]
    [string]$JiraRef,

    [Parameter(Mandatory=$true)]
    [string]$ReleaseFolderPath,

    [Parameter(Mandatory=$true)]
    [string]$AppName
)

Set-Location $RepoPath

git cat-file -t $BaseCommit 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Base commit $BaseCommit does not exist in this repo"
    exit 1
}

$diff = git diff --name-status "$BaseCommit..$TargetCommit"

if (-not $diff) {
    Write-Host "No changes found between $BaseCommit and $TargetCommit"
    exit 0
}


$incrementalsFolder = Join-Path $ReleaseFolderPath ($JiraRef + "_Incrementals")

if (-not (Test-Path $incrementalsFolder)) {
    New-Item -ItemType Directory -Path $incrementalsFolder | Out-Null
}

$outputFile = Join-Path $incrementalsFolder ($JiraRef + "_Incrementals.csv")

$SourceExportPath = Join-Path $ReleaseFolderPath ($JiraRef + "_" + $AppName + "_SourceCode")

$CodeDiffPath = Join-Path $ReleaseFolderPath ($JiraRef + "_" + $AppName + "_CodeDiff")


#Incrementals
$result = @()
$counter = 1

foreach ($line in $diff) {
    $parts = $line -split "`t"
    $statusCode = $parts[0]
    $fileName = $parts[-1]

    if ($statusCode -eq "A") {
        $status = "Added"
    }
    elseif ($statusCode -eq "M") {
        $status = "Modified"
    }
    elseif ($statusCode -eq "D") {
        $status = "Deleted"
    }
    elseif ($statusCode.StartsWith("R")) {
        $status = "Renamed"
    }
    else {
        $status = "Changed"
    }

    $result += [PSCustomObject]@{
        "S. NO." = $counter
        "File Name" = $fileName
        "Status" = $status
        "JIRA / Release Reference" = $JiraRef
    }

    $counter++
}

$result | Export-Csv $outputFile -NoTypeInformation

#Extraction of Source Code
if ($SourceExportPath) {

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

            Copy-Item $sourceFile $destFile -Force
        }
    }
}

#CodeDiff
if ($CodeDiffPath) {

    if (-not (Test-Path $CodeDiffPath)) {
        New-Item -ItemType Directory -Path $CodeDiffPath | Out-Null
    }

    $diffFile = Join-Path $CodeDiffPath ($JiraRef + "_" + $AppName + "_CodeDiff.diff")

    git -C $RepoPath diff $BaseCommit $TargetCommit `
        --no-color `
        --patch `
    | Out-File -FilePath $diffFile -Encoding UTF8
}
