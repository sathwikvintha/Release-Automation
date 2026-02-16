let currentLogStep = null;
let logInterval = null;

/* ================= GENERIC RUN ================= */

function runStep(step, payload = {}) {
    fetch(`/run/${step}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
    });
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
}

function submitStaas() {

    fetch("/run/staas", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({

            release: document.getElementById("staasRelease").value,
            app: document.getElementById("staasApp").value,
            username: document.getElementById("staasServerUser").value,
            password: document.getElementById("staasServerPass").value,

            title: document.getElementById("staasTitle").value,
            url: document.getElementById("staasUrl").value,
            version: document.getElementById("staasVersion").value,
            groupId: document.getElementById("staasGroupId").value,
            emails: document.getElementById("staasEmails").value,
            loginType: document.getElementById("staasLoginType").value,
            appUsername: document.getElementById("staasUsername").value,
            appPassword: document.getElementById("staasPassword").value,
            webinspect: document.getElementById("staasWebInspect").value,
            testType: document.getElementById("staasTestType").value,
            auth: document.getElementById("staasAuth").value,
            addUrlsOn: document.getElementById("staasAddUrlsOn").value,
            addUrl: document.getElementById("staasAddUrl").value

        })
    });

    closeModal("staasModal");

    showLogs("staas");  // THIS makes logs open automatically
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