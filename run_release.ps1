Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION STARTED          "
Write-Host "======================================"

# --------------------------------------------------
# INPUT ONLY FOR REMOTE SECURITY STEP
# --------------------------------------------------

$RemoteReleaseVersion = Read-Host "Enter Release Version for Remote Scan (example: 26.1)"
$RemoteAppName = Read-Host "Enter Application for Remote Scan (ORM/SO/INTAPI/MARKETING)"

# --------------------------------------------------
# STEP 1: Angular dist + version update
# --------------------------------------------------

Write-Host "`n[STEP 1] Angular dist & build.properties update"
& ".\angular\angular_release.ps1"

# --------------------------------------------------
# STEP 2: Incrementals (UNCHANGED)
# --------------------------------------------------

Write-Host "`n[STEP 2] Incrementals & CodeDiff"

powershell -ExecutionPolicy Bypass `
  -File ".\powershell\Generate-Incrementals.ps1" `
  -RepoPath "C:\Codebases\bnpp_csc_so_ST" `
  -BaseVersion "R25.3.0.1.2" `
  -TargetVersion "R26.1.0.4" `
  -ReleaseFolderPath ".\release_R26.1.0.4" `
  -JiraRef "R26.1.0.4" `
  -AppName "BNPP_CSC_SO"

# --------------------------------------------------
# STEP 3: Commit Summary (UNCHANGED)
# --------------------------------------------------

Write-Host "`n[STEP 3] Commit Summary"

powershell -ExecutionPolicy Bypass `
  -File ".\powershell\Generate-CommitSummary.ps1" `
  -RepoPath "C:\Codebases\bnpp_csc_so_ST" `
  -BaseVersion "R25.3.0.1.2" `
  -TargetVersion "R26.1.0.4" `
  -ReleaseFolderPath ".\release_R26.1.0.4" `
  -JiraRef "R26.1.0.4" `
  -AppName "BNPP_CSC_SO"

# --------------------------------------------------
# STEP 3.5: Release Report Generation
# --------------------------------------------------

Write-Host "`n[STEP 3.5] Release Report Generation"

Push-Location ".\python\release-report-generator"
python generate_release_doc.py
Pop-Location

Write-Host "`n[STEP 3.5] Attaching Release Report to Release Folder"

Copy-Item `
  ".\Report-output" `
  ".\release_R26.1.0.4\Report-output" `
  -Recurse -Force

# --------------------------------------------------
# STEP 3.6: Remote OSCS + Sonar (NEW STEP ONLY)
# --------------------------------------------------

Write-Host "`n[STEP 3.6] Remote OSCS + Sonar Scan"

powershell -ExecutionPolicy Bypass `
  -File ".\remote\run_remote_security.ps1" `
  -AppName $RemoteAppName `
  -ReleaseVersion $RemoteReleaseVersion

# --------------------------------------------------
# STEP 4: ZIP + PGP (UNCHANGED)
# --------------------------------------------------

Write-Host "`n[STEP 4] ZIP & PGP Encryption"

Push-Location config
python "..\python\encrypt_release.py"
Pop-Location

# --------------------------------------------------
# STEP 5: Release Email (UNCHANGED)
# --------------------------------------------------

Write-Host "`n[STEP 5] Release Email"
python ".\python\generate_release_email.py"

Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION COMPLETED      "
Write-Host "======================================"
