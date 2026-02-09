Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION STARTED          "
Write-Host "======================================"

# -------- STEP 1: Angular dist + version update --------
Write-Host "`n[STEP 1] Angular dist & build.properties update"
& ".\angular\angular_release.ps1"

# -------- STEP 2: Incrementals (COMMAND EXECUTION) --------
Write-Host "`n[STEP 2] Incrementals & CodeDiff"

powershell -ExecutionPolicy Bypass `
  -File ".\powershell\Generate-Incrementals.ps1" `
  -RepoPath "C:\Codebases\bnpp_csc_so_ST" `
  -BaseVersion "R25.3.0.1.2" `
  -TargetVersion "R26.1.0.4" `
  -ReleaseFolderPath ".\release_R26.1.0.4" `
  -JiraRef "R26.1.0.4" `
  -AppName "BNPP_CSC_SO"

# -------- STEP 3: Commit Summary --------
Write-Host "`n[STEP 3] Commit Summary"

powershell -ExecutionPolicy Bypass `
  -File ".\powershell\Generate-CommitSummary.ps1" `
  -RepoPath "C:\Codebases\bnpp_csc_so_ST" `
  -BaseVersion "R25.3.0.1.2" `
  -TargetVersion "R26.1.0.4" `
  -ReleaseFolderPath ".\release_R26.1.0.4" `
  -JiraRef "R26.1.0.4" `
  -AppName "BNPP_CSC_SO"

# -------- STEP 4: ZIP + PGP --------
Write-Host "`n[STEP 4] ZIP & PGP Encryption"
Push-Location config
python "..\python\encrypt_release.py"
Pop-Location

# -------- STEP 5: Release Email --------
Write-Host "`n[STEP 5] Release Email"
python ".\python\generate_release_email.py"

Write-Host "======================================"
Write-Host "   RELEASE AUTOMATION COMPLETED      "
Write-Host "======================================"
