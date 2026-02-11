param (
    [string]$AppName,
    [string]$ReleaseVersion
)

$remoteHost = "oracle-server"
$remoteScript = "/scratch/full/path/run_oscs_sonar_generic.sh"
$remoteReportBase = "/scratch/softwares_2/Reports-ALL"

$localReleaseFolder = "..\release_R$ReleaseVersion\security-reports"
New-Item -ItemType Directory -Force $localReleaseFolder | Out-Null

Write-Host "==============================================="
Write-Host " Running Remote OSCS + Sonar"
Write-Host "==============================================="

# ---------------------------------------
# Override Prompt
# ---------------------------------------

$override = Read-Host "Do you want to override server paths? (YES/NO)"

$exportCommands = ""

if ($override -eq "YES") {

    $workingDir = Read-Host "Enter WORKING_DIR override (or press Enter to skip)"
    $oscsDir = Read-Host "Enter OSCS_DIR override (or press Enter to skip)"
    $sharedLibs = Read-Host "Enter SHARED_LIBS override (or press Enter to skip)"
    $mavenRepo = Read-Host "Enter MAVEN_REPO override (or press Enter to skip)"
    $sonarKey = Read-Host "Enter SONAR_KEY override (or press Enter to skip)"

    if ($workingDir) { $exportCommands += "export WORKING_DIR_OVERRIDE='$workingDir'; " }
    if ($oscsDir) { $exportCommands += "export OSCS_DIR_OVERRIDE='$oscsDir'; " }
    if ($sharedLibs) { $exportCommands += "export SHARED_LIBS_OVERRIDE='$sharedLibs'; " }
    if ($mavenRepo) { $exportCommands += "export MAVEN_REPO_OVERRIDE='$mavenRepo'; " }
    if ($sonarKey) { $exportCommands += "export SONAR_KEY_OVERRIDE='$sonarKey'; " }
}

# ---------------------------------------
# Execute Remote Script
# ---------------------------------------

ssh $remoteHost "$exportCommands $remoteScript $AppName $ReleaseVersion"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Remote execution failed."
    exit 1
}

Write-Host "Waiting for automation completion marker..."

$remoteMarker = "$remoteReportBase/$ReleaseVersion/$AppName/automation_complete.marker"

while ($true) {
    $check = ssh $remoteHost "test -f $remoteMarker && echo DONE"
    if ($check -match "DONE") {
        break
    }
    Start-Sleep -Seconds 10
}

Write-Host "Copying reports locally..."

scp -r "${remoteHost}:$remoteReportBase/$ReleaseVersion/$AppName/*" $localReleaseFolder

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to copy reports."
    exit 1
}

Write-Host "Security reports copied successfully."
