# ================= LOGGING SETUP =================
$LOG_DIR = "..\logs"
$LOG_FILE = Join-Path $LOG_DIR "angular_release.log"

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

Write-Log "========== Angular Release Automation Started =========="

# ================= LOAD CONFIG =================
$configPath = "..\config\angular_release_config.txt"
Write-Log "Loading config from $configPath"

if (-not (Test-Path $configPath)) {
    Write-Log "Angular config file not found" "ERROR"
    exit 1
}

$config = @{}
Get-Content $configPath | ForEach-Object {
    if ($_ -and $_ -notmatch "^#") {
        $k, $v = $_ -split "=", 2
        $config[$k.Trim()] = $v.Trim()
    }
}

$RELEASE_VERSION = $config["RELEASE_VERSION"]
$BRANCH = $config["TARGET_BRANCH"]
$DIST_ZIP = $config["JENKINS_DIST_ZIP"]
$REPO_ROOT = $config["REPO_ROOT"]
$DIST_REL = $config["ANGULAR_DIST_REL"]
$PROP_REL = $config["BUILD_PROP_REL"]

$DIST_MSG = $config["DIST_COMMIT_MSG"] -replace "RELEASE_VERSION", $RELEASE_VERSION
$PROP_MSG = $config["BUILD_PROP_COMMIT_MSG"] -replace "RELEASE_VERSION", $RELEASE_VERSION

$DIST_PATH = Join-Path $REPO_ROOT $DIST_REL
$PROP_PATH = Join-Path $REPO_ROOT $PROP_REL

Write-Log "Release Version: $RELEASE_VERSION"
Write-Log "Target Branch: $BRANCH"

# ================= VALIDATION =================
Write-Log "Validating Jenkins dist zip at $DIST_ZIP"

if (-not (Test-Path $DIST_ZIP)) {
    Write-Log "Jenkins dist.zip not found at $DIST_ZIP" "ERROR"
    exit 1
}

Set-Location $REPO_ROOT
Write-Log "Changed directory to repo root: $REPO_ROOT"

# ================= STEP 1: CHECKOUT TARGET BRANCH =================
Write-Log "Checking out branch $BRANCH"

git checkout $BRANCH
if ($LASTEXITCODE -ne 0) {
    Write-Log "Failed to checkout branch $BRANCH" "ERROR"
    exit 1
}

# ================= STEP 2: REPLACE ANGULAR DIST =================
Write-Log "Updating Angular dist folder"

if (Test-Path $DIST_PATH) {
    Write-Log "Removing existing dist folder: $DIST_PATH"
    Remove-Item $DIST_PATH -Recurse -Force
}

New-Item -ItemType Directory -Path $DIST_PATH | Out-Null
Write-Log "Extracting Jenkins dist zip"

Expand-Archive -Path $DIST_ZIP -DestinationPath $DIST_PATH -Force

git add $DIST_PATH
git commit -m "$DIST_MSG"
Write-Log "Angular dist committed with message: $DIST_MSG"

# ================= STEP 3: UPDATE build.properties =================
Write-Log "Updating build.properties"

$content = Get-Content $PROP_PATH
$content = $content -replace "release.version=.*", "release.version=$RELEASE_VERSION"
$content | Set-Content $PROP_PATH

git add $PROP_PATH
git commit -m "$PROP_MSG"
Write-Log "build.properties committed with message: $PROP_MSG"

# ================= STEP 4: PUSH TO BITBUCKET =================
Write-Log "Pushing changes to Bitbucket"

git push origin $BRANCH
if ($LASTEXITCODE -ne 0) {
    Write-Log "Git push failed" "ERROR"
    exit 1
}

Write-Log "Angular dist + build.properties successfully pushed for $RELEASE_VERSION"
Write-Log "========== Angular Release Automation Completed =========="
