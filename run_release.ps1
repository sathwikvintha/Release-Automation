param(
  [string]$Step,
  [string]$RemoteReleaseVersion,
  [string]$RemoteAppName,
  [string]$ReleaseVersion,
  [string]$JenkinsUser,
  [string]$JenkinsToken,
  [string]$BaseVersion = "R25.3.0.1.2",
  [string]$TargetVersion = "R26.1.0.4",
  [string]$RepoPath = "C:\Codebases\bnpp_csc_so_ST",
  [string]$AppName = "BNPP_CSC_SO"
)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION ENTRY POINT     "
Write-Host "======================================"

# Derived release folder
$ReleaseFolder = ".\release_$TargetVersion"
# -----------------------------------------
# STEP CONTROLLER (UI Friendly)
# -----------------------------------------

switch ($Step) {

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

  "incrementals" {

    Write-Host "`n[STEP 2] Incrementals & CodeDiff"

    powershell -ExecutionPolicy Bypass `
      -File ".\powershell\Generate-Incrementals.ps1" `
      -RepoPath $RepoPath `
      -BaseVersion $BaseVersion `
      -TargetVersion $TargetVersion `
      -ReleaseFolderPath $ReleaseFolder `
      -JiraRef $TargetVersion `
      -AppName $AppName

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Incrementals step failed."
      exit 1
    }

    Write-Host "Incrementals step completed successfully."
  }

  "commit" {

    Write-Host "`n[STEP 3] Commit Summary"

    powershell -ExecutionPolicy Bypass `
      Write-Host "Calling Commit Summary Script from: $(Resolve-Path '.\powershell\Generate-CommitSummary.ps1')"
    -File ".\powershell\Generate-CommitSummary.ps1" `
      -RepoPath $RepoPath `
      -BaseRelease $BaseVersion `
      -TargetRelease $TargetVersion `
      -OutputFolder $ReleaseFolder `
      -JiraRef $TargetVersion `
      -AppName $AppName

    if ($LASTEXITCODE -ne 0) {
      Write-Host "Commit Summary step failed."
      exit 1
    }

    Write-Host "Commit Summary completed successfully."
  }

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

  "attach" {

    Write-Host "`n[STEP 3.6] Attaching Release Report"

    $ReportOutputPath = Join-Path $ScriptRoot "Report-output"

    Copy-Item `
      $ReportOutputPath `
      "$ReleaseFolder\Report-output" `
      -Recurse -Force


    if ($LASTEXITCODE -ne 0) {
      Write-Host "Attach Report step failed."
      exit 1
    }

    Write-Host "Report attached successfully."
  }

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

  "zip" {

    Write-Host "`n[STEP 4] ZIP & PGP Encryption"

    Push-Location config
    python "..\python\automate_release.py"
    Pop-Location

    if ($LASTEXITCODE -ne 0) {
      Write-Host "ZIP + PGP step failed."
      exit 1
    }

    Write-Host "ZIP + PGP completed successfully."
  }

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
    Write-Host "Valid steps:"
    Write-Host " angular"
    Write-Host " incrementals"
    Write-Host " commit"
    Write-Host " report"
    Write-Host " attach"
    Write-Host " security"
    Write-Host " staas"
    Write-Host " zip"
    Write-Host " email"
    exit 1
  }
}

Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION COMPLETED          "
Write-Host "======================================"
