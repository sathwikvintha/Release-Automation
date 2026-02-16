param (
    [string]$AppName,
    [string]$ReleaseVersion,
    [string]$OverrideMode,
    [string]$WorkingDirOverride,
    [string]$OscsDirOverride,
    [string]$SharedLibsOverride,
    [string]$MavenRepoOverride,
    [string]$SonarKeyOverride
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

# ================= VALIDATION =================
if (-not $AppName -or -not $ReleaseVersion) {
    Write-Log "AppName or ReleaseVersion missing." "ERROR"
    exit 1
}

# ================= CONFIG =================
$remoteHost = "oracle-server"
$remoteScript = "/scratch/full/path/run_oscs_sonar_generic.sh"
$remoteReportBase = "/scratch/softwares_2/Reports-ALL"
# ================= LOCAL OUTPUT STRUCTURE =================

$projectRoot = Resolve-Path "$PSScriptRoot\.."

$baseOutput = Join-Path $projectRoot "Report-output"
$securityBase = Join-Path $baseOutput "Sonar_OSCS_Malware_Reports"

# Create base if not exists
New-Item -ItemType Directory -Force -Path $securityBase | Out-Null

# Create version folder
$versionFolder = Join-Path $securityBase $ReleaseVersion
New-Item -ItemType Directory -Force -Path $versionFolder | Out-Null

# Create application folder inside version
$appFolder = Join-Path $versionFolder $AppName
New-Item -ItemType Directory -Force -Path $appFolder | Out-Null

$localReleaseFolder = $appFolder

Write-Host "DEBUG -> Final Local Path: $localReleaseFolder"
Write-Log "Application: $AppName"
Write-Log "Release Version: $ReleaseVersion"
Write-Host "DEBUG -> ReleaseVersion = [$ReleaseVersion]"
Write-Host "DEBUG -> AppName = [$AppName]"
Write-Log "Local security folder: $localReleaseFolder"

# ================= SSH EXECUTION =================
Write-Log "Executing remote security script..."

$sshCommand = "$exportCommands $remoteScript $AppName $ReleaseVersion"

Write-Log "Starting SSH execution..."

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-tt $remoteHost `"$sshCommand`""
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
$process.Start() | Out-Null

# Stream stdout LIVE
while (-not $process.HasExited) {

    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        Write-Host $line
        Add-Content -Path $LOG_FILE -Value $line
    }

    Start-Sleep -Milliseconds 200
}

# Capture remaining lines
while (-not $process.StandardOutput.EndOfStream) {
    $line = $process.StandardOutput.ReadLine()
    Write-Host $line
    Add-Content -Path $LOG_FILE -Value $line
}

$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    Write-Log "Remote execution failed." "ERROR"
    exit 1
}

# ================= WAIT FOR MARKER =================
Write-Log "Waiting for completion marker..."

$remoteMarker = "$remoteReportBase/$ReleaseVersion/$AppName/automation_complete.marker"

while ($true) {
    $check = ssh $remoteHost "test -f $remoteMarker && echo DONE"
    if ($check -match "DONE") {
        Write-Log "Completion marker detected."
        break
    }
    Start-Sleep -Seconds 10
}

# ================= COPY ONLY LATEST REPORTS =================
Write-Log "Detecting latest report folders on server..."

$latestSonar = ssh $remoteHost "ls -td $remoteReportBase/$ReleaseVersion/$AppName/Sonar_* 2>/dev/null | head -1"
$latestOSCS = ssh $remoteHost "ls -td $remoteReportBase/$ReleaseVersion/$AppName/OSCS_* 2>/dev/null | head -1"
$latestMalware = ssh $remoteHost "ls -td $remoteReportBase/$ReleaseVersion/$AppName/Malware_* 2>/dev/null | head -1"

if (-not $latestSonar -or -not $latestOSCS -or -not $latestMalware) {
    Write-Log "Could not detect latest report folders." "ERROR"
    exit 1
}

# Extract timestamp
$timestamp = ($latestSonar -split "_")[-1]

Write-Log "Latest run timestamp detected: $timestamp"

# Create clean timestamp folder locally
$localTimestampFolder = Join-Path $localReleaseFolder $timestamp
New-Item -ItemType Directory -Force -Path $localTimestampFolder | Out-Null

Write-Log "Copying latest Sonar report..."
scp -r "${remoteHost}:$latestSonar" (Join-Path $localTimestampFolder "Sonar")

Write-Log "Copying latest OSCS report..."
scp -r "${remoteHost}:$latestOSCS" (Join-Path $localTimestampFolder "OSCS")

Write-Log "Copying latest Malware report..."
scp -r "${remoteHost}:$latestMalware" (Join-Path $localTimestampFolder "Malware")

if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to copy latest reports." "ERROR"
    exit 1
}

Write-Log "Reports copied successfully to $localTimestampFolder"


Write-Log "Security reports copied successfully."
Write-Log "========== Remote OSCS + Sonar Execution Completed =========="
