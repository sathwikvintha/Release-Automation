# =================================================
# LOGGING SETUP (REUSE EXISTING LOGS FOLDER)
# =================================================
$LOG_DIR = "..\logs"
$LOG_FILE = Join-Path $LOG_DIR "deployment_doc_generator.log"

if (-not (Test-Path $LOG_DIR)) {
    Write-Error "Logs directory not found at $LOG_DIR. Expected it to be pre-created."
    exit 1
}

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LOG_FILE -Value $entry
}

Write-Log "========== Deployment Document Generator Started =========="

# =================================================
# HEADER
# =================================================
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Release Deployment Document Generator" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# =================================================
# USER INPUTS
# =================================================
$RepoPath = Read-Host "Enter local repository path"
$BaseRelease = Read-Host "Enter BASE Release (e.g. R25.3.0.1.2)"
$TargetRelease = Read-Host "Enter TARGET Release (e.g. R26.0.0.1.1)"
$OutputFolder = Read-Host "Enter output folder path"
$JiraRef = Read-Host "Enter Jira / Release reference"
$AppName = Read-Host "Enter Application name"

Write-Log "Inputs | Repo=$RepoPath | Base=$BaseRelease | Target=$TargetRelease | App=$AppName | Jira=$JiraRef"

# =================================================
# VALIDATION: REPOSITORY
# =================================================
if (-not (Test-Path $RepoPath)) {
    Write-Log "Repository path does not exist: $RepoPath" "ERROR"
    Write-Error "Repository path does not exist."
    exit 1
}

Set-Location $RepoPath

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Log "Invalid git repository: $RepoPath" "ERROR"
    Write-Error "Not a valid git repository."
    exit 1
}

Write-Log "Validated git repository successfully"

# =================================================
# IDENTIFY RELEASE MARKER COMMITS
# =================================================
Write-Host "Locating release markers..." -ForegroundColor Yellow
Write-Log "Searching for release marker commits"

$BaseCommit = git log --oneline --grep="build.properties -> $BaseRelease" -n 1 |
ForEach-Object { ($_ -split ' ')[0] }

$TargetCommit = git log --oneline --grep="build.properties -> $TargetRelease" -n 1 |
ForEach-Object { ($_ -split ' ')[0] }

if (-not $BaseCommit -or -not $TargetCommit) {
    Write-Log "Release marker not found | Base=$BaseRelease | Target=$TargetRelease" "ERROR"
    Write-Error "Base or Target release marker not found."
    exit 1
}

Write-Host "Base Commit   : $BaseCommit"   -ForegroundColor Green
Write-Host "Target Commit : $TargetCommit" -ForegroundColor Green
Write-Log "Found release markers | BaseCommit=$BaseCommit | TargetCommit=$TargetCommit"

# =================================================
# DEPLOYMENT SECTIONS
# =================================================
$SectionOrder = @(
    "2.1 Web server Changes",
    "2.2 Maven Deployment Changes",
    "2.3 App Server Changes",
    "2.4 DB Changes- Environment Specific Changes",
    "2.5 Queue Configuration Scripts",
    "2.6 Scheduler jobs",
    "2.7 Migration Scripts",
    "2.8 Shell Script changes",
    "2.9 Sql Script change",
    "2.10 Cron Job changes",
    "2.11 Keycloak Configuration changes",
    "2.12 Scheduler Server changes"
)

$SectionKeywords = @{
    "2.1 Web server Changes"                       = @("web", "nginx", "apache")
    "2.2 Maven Deployment Changes"                 = @("maven", "pom.xml")
    "2.3 App Server Changes"                       = @("ear", "war", "weblogic", "app server")
    "2.4 DB Changes- Environment Specific Changes" = @("db", "ddl", "dml", "database")
    "2.5 Queue Configuration Scripts"              = @("queue", "jms", "mq")
    "2.6 Scheduler jobs"                           = @("scheduler", "job")
    "2.7 Migration Scripts"                        = @("migration", "migrate")
    "2.8 Shell Script changes"                     = @(".sh", "shell")
    "2.9 Sql Script change"                        = @(".sql", "sql")
    "2.10 Cron Job changes"                        = @("cron")
    "2.11 Keycloak Configuration changes"          = @("keycloak")
    "2.12 Scheduler Server changes"                = @("scheduler server")
}

# =================================================
# DATA STRUCTURES
# =================================================
$CommitSummaryJson = @()
$DeploymentDetailsJson = @{}
$TxtDeploymentData = @{}

foreach ($section in $SectionOrder) {
    $DeploymentDetailsJson[$section] = @()
    $TxtDeploymentData[$section] = @()
}

# =================================================
# FETCH COMMITS
# =================================================
Write-Host "Extracting commits between releases..." -ForegroundColor Yellow
Write-Log "Extracting commits between $BaseCommit and $TargetCommit"

$CommitLines = git log --ancestry-path "$BaseCommit^..$TargetCommit" `
    --pretty=format:"%h|%an|%ad|%s" `
    --date=format:"%d-%b-%Y"

# =================================================
# BUILD OUTPUT
# =================================================
$TxtOutput = @()
$TxtOutput += "CommitId | Author | CommitDate | Issues | Message"
$TxtOutput += "--------------------------------------------------"

foreach ($line in $CommitLines) {

    $parts = $line -split "\|", 4
    $hash = $parts[0]
    $author = $parts[1]
    $date = $parts[2]
    $message = $parts[3]

    $issues = ([regex]::Matches($message, "[A-Z]+-\d+")).Value -join ", "

    $TxtOutput += "$hash | $author | $date | $issues | $message"

    $CommitSummaryJson += @{
        commitId = $hash
        author   = $author
        date     = $date
        issues   = $issues
        message  = $message
    }

    if ($message -like "build.properties ->*") {
        continue
    }

    $lowerMsg = $message.ToLower()
    foreach ($section in $SectionOrder) {
        foreach ($keyword in $SectionKeywords[$section]) {
            if ($lowerMsg -like "*$keyword*") {
                $DeploymentDetailsJson[$section] += $message
                $TxtDeploymentData[$section] += $message
                break
            }
        }
    }
}

Write-Log "Commit processing and classification completed"

# =================================================
# FINAL JSON OBJECT
# =================================================
$FinalJson = @{
    release           = $TargetRelease
    baseRelease       = $BaseRelease
    targetRelease     = $TargetRelease
    appName           = $AppName
    generatedOn       = (Get-Date -Format "dd-MMM-yyyy")
    commitSummary     = $CommitSummaryJson
    deploymentDetails = $DeploymentDetailsJson
}

# =================================================
# WRITE OUTPUT FILES
# =================================================
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    Write-Log "Created output folder: $OutputFolder"
}

$TxtFile = Join-Path $OutputFolder "$JiraRef`_$AppName`_DeploymentDetails.txt"
$JsonFile = Join-Path $OutputFolder "$JiraRef`_$AppName`_DeploymentDetails.json"

Set-Content -Path $TxtFile  -Value $TxtOutput -Encoding UTF8
$FinalJson | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonFile -Encoding UTF8

Write-Log "Generated output files | TXT=$TxtFile | JSON=$JsonFile"

# =================================================
# DONE
# =================================================
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Release Deployment Details Generated" -ForegroundColor Green
Write-Host " TXT  : $TxtFile"
Write-Host " JSON : $JsonFile"
Write-Host "==============================================" -ForegroundColor Green

Write-Log "========== Deployment Document Generator Completed =========="
