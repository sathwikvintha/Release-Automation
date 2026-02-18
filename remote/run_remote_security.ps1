param (
    [string]$AppName,
    [string]$ReleaseVersion,
    [string]$ReleaseId,
    [string]$Variant,
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
if (-not $AppName -or -not $ReleaseVersion -or -not $ReleaseId -or -not $Variant) {
    Write-Log "Required parameters missing." "ERROR"
    exit 1
}

$AppName = $AppName.ToUpper()
$Variant = $Variant.ToUpper()
$releaseFs = $ReleaseVersion.Replace(".", "_")

# ================= CONFIG =================
$remoteHost = "oracle-server"
$remoteScript = "/scratch/full/path/run_oscs_sonar_generic.sh"
$remoteReportBase = "/scratch/softwares_2/Reports-ALL"
# ================= LOCAL OUTPUT STRUCTURE =================

$projectRoot = Resolve-Path "$PSScriptRoot\.."

$baseOutput = Join-Path $projectRoot "Report-output"
$finalRoot = Join-Path $baseOutput "${AppName}_${releaseFs}_${Variant}"

New-Item -ItemType Directory -Force -Path $finalRoot | Out-Null

$localReleaseFolder = $finalRoot

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
$remoteRunRoot = "$remoteReportBase/$ReleaseVersion/$AppName"
if (-not $remoteRunRoot) {
    Write-Log "Could not detect remote Reports folder." "ERROR"
    exit 1
}
$latestSonar = "$remoteRunRoot/${ReleaseId}_${AppName}_Sonar_Report"
$latestOSCS = "$remoteRunRoot/${ReleaseId}_${AppName}_OSCS_Report"
$latestMalware = "$remoteRunRoot/${ReleaseId}_${AppName}_Malware_Report"
if (-not $latestSonar -or -not $latestOSCS -or -not $latestMalware) {
    Write-Log "Could not detect latest report folders." "ERROR"
    exit 1
}
$sonarDest = Join-Path $localReleaseFolder "${ReleaseId}_${AppName}_Sonar_Report"
$oscsDest = Join-Path $localReleaseFolder "${ReleaseId}_${AppName}_OSCS_Report"
$malwareDest = Join-Path $localReleaseFolder "${ReleaseId}_${AppName}_Malware_Report"
Write-Log "Copying latest Sonar report..."
scp -r "${remoteHost}:$latestSonar"   $sonarDest

Write-Log "Copying latest OSCS report..."
scp -r "${remoteHost}:$latestOSCS"    $oscsDest

Write-Log "Copying latest Malware report..."
scp -r "${remoteHost}:$latestMalware" $malwareDest

if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to copy latest reports." "ERROR"
    exit 1
}

Write-Log "Reports copied successfully to $localReleaseFolder"
Write-Log "Security reports copied successfully."
Write-Log "========== Remote OSCS + Sonar Execution Completed =========="
