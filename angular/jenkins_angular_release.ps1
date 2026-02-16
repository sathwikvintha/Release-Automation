param(
    [string]$ReleaseVersion,
    [string]$JenkinsUser,
    [string]$JenkinsToken
)

Write-Host "======================================"
Write-Host "   JENKINS ANGULAR BUILD STARTED     "
Write-Host "======================================"

if (-not $ReleaseVersion) {
    Write-Error "ReleaseVersion is required."
    exit 1
}

if (-not $JenkinsUser -or -not $JenkinsToken) {
    Write-Error "Jenkins credentials are required."
    exit 1
}

# ---- Encode Auth ----
$pair = "$JenkinsUser`:$JenkinsToken"
$encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

$Headers = @{
    Authorization = "Basic $encodedAuth"
}

$JenkinsBase = "https://ci-cloud.us.oracle.com/jenkins/finergy"
$BuildJobUrl = "$JenkinsBase/job/BNPP/job/ORM/job/BNPP_CSC_ORM_25.3_ST_JOBS/job/BNPP_CSC_ORM_25.3_ST_Build_Job"
$PushJobUrl  = "$JenkinsBase/job/BNPP/job/ORM/job/BNPP_CSC_ORM_25.3_ST_JOBS/job/BNPP_CSC_ORM_25.3_ST_PushDist"

Write-Host "Fetching Jenkins crumb..."

$crumbResponse = Invoke-RestMethod `
    -Uri "$JenkinsBase/crumbIssuer/api/json" `
    -Headers $Headers

$Headers[$crumbResponse.crumbRequestField] = $crumbResponse.crumb

function Wait-ForJenkinsJob {
    param ([string]$JobUrl)

    Start-Sleep -Seconds 10

    $buildInfo = Invoke-RestMethod `
        -Uri "$JobUrl/lastBuild/api/json" `
        -Headers $Headers

    $buildNumber = $buildInfo.number
    Write-Host "Monitoring Build Number: $buildNumber"

    while ($true) {
        $status = Invoke-RestMethod `
            -Uri "$JobUrl/$buildNumber/api/json" `
            -Headers $Headers

        if ($status.result -ne $null) {
            Write-Host "Build Completed with Status: $($status.result)"
            return $status.result
        }

        Start-Sleep -Seconds 15
    }
}

# Trigger Build
Write-Host "Triggering Angular Build..."
Invoke-RestMethod -Method Post -Uri "$BuildJobUrl/build" -Headers $Headers
$result1 = Wait-ForJenkinsJob -JobUrl $BuildJobUrl

if ($result1 -ne "SUCCESS") {
    Write-Error "Angular Build Failed."
    exit 1
}

# Trigger Push Dist
Write-Host "Triggering Push Dist..."
Invoke-RestMethod -Method Post `
    -Uri "$PushJobUrl/buildWithParameters?RELEASE_VERSION=$ReleaseVersion" `
    -Headers $Headers

$result2 = Wait-ForJenkinsJob -JobUrl $PushJobUrl

if ($result2 -ne "SUCCESS") {
    Write-Error "Push Dist Failed."
    exit 1
}

Write-Host "Jenkins Angular Pipeline Completed Successfully!"
