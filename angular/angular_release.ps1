# ================= LOAD CONFIG =================
$configPath = "..\config\angular_release_config.txt"

if (-not (Test-Path $configPath)) {
    Write-Error "Angular config file not found"
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
$BRANCH          = $config["TARGET_BRANCH"]
$DIST_ZIP        = $config["JENKINS_DIST_ZIP"]
$REPO_ROOT       = $config["REPO_ROOT"]
$DIST_REL        = $config["ANGULAR_DIST_REL"]
$PROP_REL        = $config["BUILD_PROP_REL"]

$DIST_MSG = $config["DIST_COMMIT_MSG"] -replace "RELEASE_VERSION", $RELEASE_VERSION
$PROP_MSG = $config["BUILD_PROP_COMMIT_MSG"] -replace "RELEASE_VERSION", $RELEASE_VERSION

$DIST_PATH = Join-Path $REPO_ROOT $DIST_REL
$PROP_PATH = Join-Path $REPO_ROOT $PROP_REL

# ================= VALIDATION =================
if (-not (Test-Path $DIST_ZIP)) {
    Write-Error "Jenkins dist.zip not found at $DIST_ZIP"
    exit 1
}

Set-Location $REPO_ROOT

# ================= STEP 1: CHECKOUT TARGET BRANCH =================
git checkout $BRANCH
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to checkout branch $BRANCH"
    exit 1
}

# ================= STEP 2: REPLACE ANGULAR DIST =================
Write-Host "Updating Angular dist..."

if (Test-Path $DIST_PATH) {
    Remove-Item $DIST_PATH -Recurse -Force
}

New-Item -ItemType Directory -Path $DIST_PATH | Out-Null
Expand-Archive -Path $DIST_ZIP -DestinationPath $DIST_PATH -Force

git add $DIST_PATH
git commit -m "$DIST_MSG"

# ================= STEP 3: UPDATE build.properties =================
Write-Host "Updating build.properties..."

$content = Get-Content $PROP_PATH
$content = $content -replace "release.version=.*", "release.version=$RELEASE_VERSION"
$content | Set-Content $PROP_PATH

git add $PROP_PATH
git commit -m "$PROP_MSG"

# ================= STEP 4: PUSH TO BITBUCKET =================
git push origin $BRANCH

Write-Host " Angular dist + build.properties committed to $BRANCH for $RELEASE_VERSION"
