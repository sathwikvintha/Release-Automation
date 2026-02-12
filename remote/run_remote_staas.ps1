# ================= LOGGING SETUP =================
$LOG_DIR = ".\logs"
$LOG_FILE = Join-Path $LOG_DIR "remote_staas.log"

if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LOG_FILE -Value $logEntry
}

Write-Log "========== Remote STaaS Execution Started =========="

# ================= CONFIG =================
$remoteHost = "oracle-server"
$remoteScriptDir = "/scratch/softwares_2/Staas_Report_Generator"
$remoteReportDir = "/scratch/softwares_2/Staas_Report_Generator/StaaS_Reports"

$localBaseFolder = ".\Report-output"
$localStaasFolder = "$localBaseFolder\StaaS Report"

# ================= CREATE LOCAL FOLDER =================
if (-not (Test-Path $localStaasFolder)) {
    New-Item -ItemType Directory -Force $localStaasFolder | Out-Null
    Write-Log "Created local folder: $localStaasFolder"
}

# ================= RUN STaaS =================
Write-Log "Connecting to remote host: $remoteHost"
Write-Log "Executing STaaS script on server..."

ssh $remoteHost "cd $remoteScriptDir && ./staas.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Log "STaaS execution failed on remote server." "ERROR"
    exit 1
}

Write-Log "STaaS execution completed. Searching for latest report..."

# ================= FETCH LATEST REPORT =================
$latestReport = ssh $remoteHost "ls -t $remoteReportDir | head -1"

if (-not $latestReport) {
    Write-Log "No STaaS report found in remote directory." "ERROR"
    exit 1
}

Write-Log "Latest report identified: $latestReport"

# ================= COPY REPORT =================
Write-Log "Copying report to local project..."

scp "${remoteHost}:$remoteReportDir/$latestReport" $localStaasFolder

if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to copy STaaS report from server." "ERROR"
    exit 1
}

Write-Log "Report successfully copied to $localStaasFolder"
Write-Log "========== Remote STaaS Execution Completed =========="
