param (
    [string]$AppName,
    [string]$ReleaseVersion
)

# ================= LOGGING SETUP =================
$LOG_DIR = ".\logs"
$LOG_FILE = Join-Path $LOG_DIR "remote_security.log"

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

Write-Log "========== Remote OSCS + Sonar Execution Started =========="

# ================= CONFIG =================
$remoteHost = "oracle-server"
$remoteScript = "/scratch/full/path/run_oscs_sonar_generic.sh"
$remoteReportBase = "/scratch/softwares_2/Reports-ALL"

$localReleaseFolder = "..\release_R$ReleaseVersion\security-reports"

New-Item -ItemType Directory -Force $localReleaseFolder | Out-Null
Write-Log "Local security report folder ensured at $localReleaseFolder"

Write-Log "Application: $AppName"
Write-Log "Release Version: $ReleaseVersion"

# ---------------------------------------
# Override Prompt
# ---------------------------------------

$override = Read-Host "Do you want to override server paths? (YES/NO)"
Write-Log "Override selection: $override"

$exportCommands = ""

if ($override -eq "YES") {

    $workingDir = Read-Host "Enter WORKING_DIR override (or press Enter to skip)"
    $oscsDir = Read-Host "Enter OSCS_DIR override (or press Enter to skip)"
    $sharedLibs = Read-Host "Enter SHARED_LIBS override (or press Enter to skip)"
    $mavenRepo = Read-Host "Enter MAVEN_REPO override (or press Enter to skip)"
    $sonarKey = Read-Host "Enter SONAR_KEY override (or press Enter to skip)"

    if ($workingDir) { 
        $exportCommands += "export WORKING_DIR_OVERRIDE='$workingDir'; "
        Write-Log "WORKING_DIR override applied"
    }
    if ($oscsDir) { 
        $exportCommands += "export OSCS_DIR_OVERRIDE='$oscsDir'; "
        Write-Log "OSCS_DIR override applied"
    }
    if ($sharedLibs) { 
        $exportCommands += "export SHARED_LIBS_OVERRIDE='$sharedLibs'; "
        Write-Log "SHARED_LIBS override applied"
    }
    if ($mavenRepo) { 
        $exportCommands += "export MAVEN_REPO_OVERRIDE='$mavenRepo'; "
        Write-Log "MAVEN_REPO override applied"
    }
    if ($sonarKey) { 
        $exportCommands += "export SONAR_KEY_OVERRIDE='$sonarKey'; "
        Write-Log "SONAR_KEY override applied"
    }
}

# ---------------------------------------
# Execute Remote Script
# ---------------------------------------

Write-Log "Executing remote security script..."

ssh $remoteHost "$exportCommands $remoteScript $AppName $ReleaseVersion"

if ($LASTEXITCODE -ne 0) {
    Write-Log "Remote execution failed." "ERROR"
    exit 1
}

Write-Log "Remote execution completed successfully."

Write-Log "Waiting for automation completion marker..."

$remoteMarker = "$remoteReportBase/$ReleaseVersion/$AppName/automation_complete.marker"

while ($true) {
    $check = ssh $remoteHost "test -f $remoteMarker && echo DONE"
    if ($check -match "DONE") {
        Write-Log "Completion marker detected."
        break
    }
    Start-Sleep -Seconds 10
}

Write-Log "Copying security reports locally..."

scp -r "${remoteHost}:$remoteReportBase/$ReleaseVersion/$AppName/*" $localReleaseFolder

if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to copy security reports." "ERROR"
    exit 1
}

Write-Log "Security reports copied successfully."
Write-Log "========== Remote OSCS + Sonar Execution Completed =========="
