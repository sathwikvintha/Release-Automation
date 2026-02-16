let currentLogStep = null;
let logInterval = null;

/* ================= GENERIC RUN ================= */

function runStep(step, payload = {}) {
    fetch(`/run/${step}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
    });

    // Auto-open logs when step starts
    showLogs(step);
}

/* ================= LOG PANEL ================= */

function showLogs(step) {
    currentLogStep = step;
    document.getElementById("logTitle").innerText = step.toUpperCase() + " Logs";
    document.getElementById("logsPanel").style.display = "block";
    fetchLogs();

    if (logInterval) clearInterval(logInterval);
    logInterval = setInterval(fetchLogs, 2000);
}

function fetchLogs() {
    if (!currentLogStep) return;

    fetch(`/logs/${currentLogStep}`)
        .then(res => res.json())
        .then(data => {
            document.getElementById("logsBox").textContent = data.logs;
        });
}

function closeLogs() {
    document.getElementById("logsPanel").style.display = "none";
    currentLogStep = null;
    clearInterval(logInterval);
}

/* ================= STATUS ================= */

function refreshStatus() {
    fetch("/status")
        .then(res => res.json())
        .then(data => {
            for (let step in data) {
                let card = document.getElementById(step);
                if (!card) continue;

                let statusSpan = card.querySelector(".status");

                statusSpan.innerHTML =
                    data[step] === "SUCCESS" ? "🟢" :
                    data[step] === "FAILED" ? "🔴" :
                    data[step] === "RUNNING" ? "🟡" : "⚪";
            }
        });
}
setInterval(refreshStatus, 2000);

/* ================= MODALS ================= */

function openCommitModal() {
    document.getElementById("commitModal").style.display = "flex";
}

function openAngularModal() {
    document.getElementById("angularModal").style.display = "flex";
}

function openReportModal() {
    document.getElementById("reportModal").style.display = "flex";
}

function openSecurityModal() {
    document.getElementById("securityModal").style.display = "flex";
}

/*  Incrementals Modal */
function openIncrementalsModal() {
    document.getElementById("incrementalsModal").style.display = "flex";
}

function closeModal(id) {
    document.getElementById(id).style.display = "none";
}

/* ================= SUBMIT FUNCTIONS ================= */

function submitCommit() {

    runStep("commit", {
        repoPath: document.getElementById("repoPath").value,
        baseRelease: document.getElementById("baseRelease").value,
        targetRelease: document.getElementById("targetRelease").value,
        jiraRef: document.getElementById("jiraRef").value,
        appName: document.getElementById("appName").value
    });

    closeModal("commitModal");
}

function submitReport() {

    runStep("report", {
        jsonFile: document.getElementById("jsonFile").value,
        title: document.getElementById("docTitle").value,
        release: document.getElementById("releaseNumber").value,
        subtitle: document.getElementById("subtitle").value,
        version: document.getElementById("versionNumber").value,
        date: document.getElementById("versionDate").value
    });

    closeModal("reportModal");
}

function submitSecurity() {
    fetch("/run/security", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            RemoteReleaseVersion: document.getElementById("secRelease").value,
            RemoteAppName: document.getElementById("secApp").value,
            username: document.getElementById("secUsername").value,
            password: document.getElementById("secPassword").value
        })
    });

    closeModal("securityModal");
    showLogs("security");
}

/*  Incrementals Submit */
function submitIncrementals() {

    runStep("incrementals", {
        RepoPath: document.getElementById("incRepoPath").value,
        AppName: document.getElementById("incAppName").value,
        BaseVersion: document.getElementById("incBaseRelease").value,
        TargetVersion: document.getElementById("incTargetRelease").value,
        JiraRef: document.getElementById("incJiraRef").value
    });

    closeModal("incrementalsModal");
}

function submitAngular() {

    fetch("/run/angular", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            ReleaseVersion: document.getElementById("angReleaseVersion").value,
            RemoteReleaseVersion: document.getElementById("angRemoteRelease").value,
            RemoteAppName: document.getElementById("angRemoteApp").value,
            JenkinsUser: document.getElementById("angJenkinsUser").value,
            JenkinsToken: document.getElementById("angJenkinsToken").value
        })
    });

    closeModal("angularModal");
    showLogs("angular");
}
