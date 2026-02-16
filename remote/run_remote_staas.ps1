param (
    [string]$Release,
    [string]$App,
    [string]$ServerUser,
    [string]$ServerPass,

    [string]$Title,
    [string]$Url,
    [string]$Version,
    [string]$GroupId,
    [string]$Emails,
    [string]$LoginType,
    [string]$AppUsername,
    [string]$AppPassword,
    [string]$WebInspect,
    [string]$TestType,
    [string]$Auth,
    [string]$AddUrlsOn,
    [string]$AddUrl
)

# ================= LOGGING =================
$LOG_DIR = ".\logs"
$LOG_FILE = Join-Path $LOG_DIR "remote_staas.log"

if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null
}

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Write-Host $logEntry
    Add-Content -Path $LOG_FILE -Value $logEntry
}

Write-Log "========== Remote STaaS Execution Started =========="

# ================= PATHS =================
$remoteHost = "oracle-server"
$remoteScriptDir = "/scratch/softwares_2/Staas_Report_Generator"
$remoteReportDir = "/scratch/softwares_2/Staas_Report_Generator/StaaS_Reports"

# LOCAL STRUCTURE
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$localFolder = Join-Path $projectRoot "Report-output\StaaS_Reports\$Release\$App"

New-Item -ItemType Directory -Force -Path $localFolder | Out-Null

Write-Log "Local folder created: $localFolder"

# ================= SSH COMMAND =================
$sshCommand = @"
cd $remoteScriptDir &&
./staas_start.sh "$Title" "$Url" "$Version" "$GroupId" "$Emails" "$LoginType" "$AppUsername" "$AppPassword" "$WebInspect" "$TestType" "$Auth" "$AddUrlsOn" "$AddUrl"
"@

Write-Log "Executing STaaS scan on server..."

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-tt $ServerUser@$remoteHost `"$sshCommand`""
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.RedirectStandardInput = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi
$process.Start() | Out-Null

# Send password to SSH
$process.StandardInput.WriteLine($ServerPass)
$process.StandardInput.Flush()

while (-not $process.HasExited) {
    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        Write-Host $line
        Add-Content -Path $LOG_FILE -Value $line
    }
    Start-Sleep -Milliseconds 200
}

while (-not $process.StandardError.EndOfStream) {
    $err = $process.StandardError.ReadLine()
    Write-Host $err
    Add-Content -Path $LOG_FILE -Value $err
}

$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    Write-Log "STaaS execution failed."
    exit 1
}

Write-Log "Fetching latest report..."

$latestReport = ssh "${ServerUser}@${remoteHost}" "ls -t ${remoteReportDir} | head -1"

if (-not $latestReport) {
    Write-Log "No report found."
    exit 1
}

Write-Log "Latest report: $latestReport"

scp "${ServerUser}@${remoteHost}:${remoteReportDir}/${latestReport}" $localFolder

Write-Log "Report copied successfully."
Write-Log "========== Remote STaaS Execution Completed =========="
