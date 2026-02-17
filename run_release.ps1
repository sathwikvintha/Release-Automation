param(
  [string]$Step,
  [string]$RemoteReleaseVersion,
  [string]$RemoteAppName,
  [string]$ReleaseVersion,
  [string]$JenkinsUser,
  [string]$JenkinsToken,
  [string]$BaseRelease,
  [string]$TargetRelease,
  [string]$RepoPath = "C:\Codebases\bnpp_csc_so_ST",
  [string]$AppName = "BNPP_CSC_SO",
  [string]$OutputFolder,
  [string]$AppVariant,
  [string]$JiraRef
)
Write-Host "DEBUG Received OutputFolder: $OutputFolder" -ForegroundColor Yellow

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION ENTRY POINT     "
Write-Host "======================================"

# =================================================
# SAFE RELEASE FOLDER HANDLING (Backward Compatible)
# =================================================

if (-not $OutputFolder -or $OutputFolder -eq "") {
  $ReleaseFolder = ".\release_$TargetRelease"
}
else {
  $ReleaseFolder = $OutputFolder
}

# Ensure folder exists
if (-not (Test-Path $ReleaseFolder)) {
  New-Item -ItemType Directory -Path $ReleaseFolder -Force | Out-Null
}

Write-Host "Using Release Folder: $ReleaseFolder" -ForegroundColor Cyan

# =================================================
# STEP CONTROLLER
# =================================================

switch ($Step) {

  # =================================================
  # STEP 1 - ANGULAR
  # =================================================
  "angular" {

    Write-Host "`n[STEP 1] Jenkins Angular Build & Push Dist"

    if (-not $ReleaseVersion -or -not $JenkinsUser -or -not $JenkinsToken) {
      Write-Host "ERROR: Missing required Angular inputs."
      exit 1
    }

    powershell -ExecutionPolicy Bypass `
      -File ".\angular\jenkins_angular_release.ps1" `
      -ReleaseVersion $ReleaseVersion `
      -JenkinsUser $JenkinsUser `
      -JenkinsToken $JenkinsToken

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Angular step failed."
      exit 1
    }

    Write-Host "Angular step completed successfully."
  }

  # =================================================
  # STEP 2 - INCREMENTALS
  # =================================================
  "incrementals" {

    Write-Host "`n[STEP 2] Incrementals & CodeDiff"

    powershell -ExecutionPolicy Bypass `
      -File ".\powershell\Generate-Incrementals-SourceCode-CodeDiff.ps1" `
      -RepoPath $RepoPath `
      -BaseRelease $BaseRelease `
      -TargetRelease $TargetRelease `
      -OutputFolder $ReleaseFolder `
      -JiraRef $JiraRef `
      -AppName $AppName

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Incrementals step failed."
      exit 1
    }

    Write-Host "Incrementals step completed successfully."
  }

  # =================================================
  # STEP 3 - COMMIT SUMMARY
  # =================================================
  "commit" {

    Write-Host "`n[STEP 3] Commit Summary"

    powershell -ExecutionPolicy Bypass `
      -File ".\powershell\Generate-CommitSummary.ps1" `
      -RepoPath $RepoPath `
      -BaseRelease $BaseRelease `
      -TargetRelease $TargetRelease `
      -OutputFolder $ReleaseFolder `
      -JiraRef $JiraRef `
      -AppName $AppName `
      -AppVariant $AppVariant

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Commit Summary step failed." 
      exit 1
    }

    Write-Host "Commit Summary completed successfully."
  }

  # =================================================
  # STEP 3.5 - REPORT
  # =================================================
  "report" {

    Write-Host "`n[STEP 3.5] Release Report Generation"

    $ReportPath = Join-Path $ScriptRoot "python\release-report-generator"

    Push-Location $ReportPath
    python generate_release_doc.py
    Pop-Location

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Release Report generation failed."
      exit 1
    }

    Write-Host "Release Report generated successfully."
  }

  # =================================================
  # STEP 3.6 - ATTACH REPORT
  # =================================================
  "attach" {

    Write-Host "`n[STEP 3.6] Attaching Release Report"

    $ReportOutputPath = Join-Path $ScriptRoot "Report-output"

    Copy-Item `
      $ReportOutputPath `
      "$ReleaseFolder\Report-output" `
      -Recurse -Force

    Write-Host "Report attached successfully."
  }

  # =================================================
  # STEP 3.7 - SECURITY
  # =================================================
  "security" {

    Write-Host "`n[STEP 3.7] Remote OSCS + Sonar Scan"

    powershell -ExecutionPolicy Bypass `
      -File ".\remote\run_remote_security.ps1" `
      -AppName $RemoteAppName `
      -ReleaseVersion $RemoteReleaseVersion

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Remote Security step failed."
      exit 1
    }

    Write-Host "Remote Security completed successfully."
  }

  # =================================================
  # STEP 3.8 - STAAS
  # =================================================
  "staas" {

    Write-Host "`n[STEP 3.8] Remote STaaS Report Generation"

    powershell -ExecutionPolicy Bypass `
      -File ".\remote\run_remote_staas.ps1"

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Remote STaaS step failed."
      exit 1
    }

    Write-Host "Remote STaaS completed successfully."
  }

  # =================================================
  # STEP 4 - ZIP
  # =================================================
  "zip" {

    Write-Host "`n[STEP 4] ZIP & PGP Encryption"

    python ".\python\automate_release.py" `
      $TargetVersion `
      $ReleaseFolder

    if ($LASTEXITCODE -ne 0) {
      Write-Host "ZIP + PGP step failed."
      exit 1
    }

    Write-Host "ZIP + PGP completed successfully."
  }

  # =================================================
  # STEP 5 - EMAIL
  # =================================================
  "email" {

    Write-Host "`n[STEP 5] Release Email"

    python ".\python\generate_release_email.py"

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Release Email step failed."
      exit 1
    }

    Write-Host "Release Email sent successfully."
  }

  default {

    Write-Host "Invalid or missing Step parameter."
    exit 1
  }
}

Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION COMPLETED      "
Write-Host "======================================"
