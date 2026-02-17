import subprocess
import os
from services.state_manager import update_step_status

LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
BASE_SCRIPT = os.path.join(BASE_DIR, "run_release.ps1")


def safe(value):
    """Ensure subprocess never receives None."""
    return value if value is not None else ""


def run_step(step_name, inputs=None):

    if inputs is None:
        inputs = {}

    update_step_status(step_name, "RUNNING")

    log_file = os.path.join(LOG_DIR, f"{step_name}.log")

    command = []

    # =========================================================
    # ANGULAR
    # =========================================================
    if step_name == "angular":

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", "angular",
            "-ReleaseVersion", safe(inputs.get("ReleaseVersion")),
            "-RemoteReleaseVersion", safe(inputs.get("RemoteReleaseVersion")),
            "-RemoteAppName", safe(inputs.get("RemoteAppName")),
            "-JenkinsUser", safe(inputs.get("JenkinsUser")),
            "-JenkinsToken", safe(inputs.get("JenkinsToken")),
        ]

    # =========================================================
    # INCREMENTALS
    # =========================================================
    elif step_name == "incrementals":

        repo_path = safe(inputs.get("RepoPath"))
        app_name = safe(inputs.get("AppName"))
        base_version = safe(inputs.get("BaseVersion"))
        target_version = safe(inputs.get("TargetVersion"))
        jira_ref = safe(inputs.get("JiraRef"))

        # SAFE Output Folder Handling
        output_folder = inputs.get("OutputFolder")

        if not output_folder:
            output_folder = f".\\release_{target_version}"

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", "incrementals",
            "-RepoPath", repo_path,
            "-AppName", app_name,
            "-BaseVersion", base_version,
            "-TargetVersion", target_version,
            "-OutputFolder", output_folder,
            "-JiraRef", jira_ref,
        ]
        print("DEBUG INPUTS:", inputs)
        print("DEBUG OutputFolder:", inputs.get("OutputFolder"))


    # =========================================================
    # COMMIT SUMMARY
    # =========================================================
    elif step_name == "commit":

        output_folder = inputs.get("OutputFolder")

        if not output_folder:
            target_version = safe(inputs.get("targetRelease"))
            output_folder = f".\\release_{target_version}"

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", os.path.join(BASE_DIR, "powershell", "Generate-CommitSummary.ps1"),
            "-RepoPath", safe(inputs.get("repoPath")),
            "-BaseRelease", safe(inputs.get("baseRelease")),
            "-TargetRelease", safe(inputs.get("targetRelease")),
            "-OutputFolder", output_folder,
            "-JiraRef", safe(inputs.get("jiraRef")),
            "-AppName", safe(inputs.get("appName")),
        ]

    # =========================================================
    # RELEASE REPORT
    # =========================================================
    elif step_name == "report":

        command = [
            "python",
            os.path.join(BASE_DIR, "python", "release-report-generator", "generate_release_doc.py"),
            safe(inputs.get("jsonFile")),
            safe(inputs.get("title")),
            safe(inputs.get("release")),
            safe(inputs.get("subtitle")),
            safe(inputs.get("versionNumber")),
            safe(inputs.get("versionDate")),
        ]

    # =========================================================
    # ZIP + PGP
    # =========================================================
    elif step_name == "zip":

        release_version = safe(inputs.get("releaseVersion"))
        base_dir = safe(inputs.get("baseDir"))

        if not release_version or not base_dir:
            with open(log_file, "w", encoding="utf-8") as log:
                log.write("Missing releaseVersion or baseDir input.\n")
            update_step_status(step_name, "FAILED")
            return

        if not os.path.exists(base_dir):
            with open(log_file, "w", encoding="utf-8") as log:
                log.write(f"Base directory not found: {base_dir}\n")
            update_step_status(step_name, "FAILED")
            return

        command = [
            "python",
            os.path.join(BASE_DIR, "python", "automate_release.py"),
            release_version,
            base_dir,
        ]

    # =========================================================
    # EMAIL GENERATION
    # =========================================================
    elif step_name == "email":

        release_version = safe(inputs.get("releaseVersion"))
        base_folder = safe(inputs.get("baseFolder"))
        application_base_path = safe(inputs.get("applicationBasePath"))
        app_name = safe(inputs.get("appName"))
        sign_off_name = safe(inputs.get("signOffName"))
        output_dir = safe(inputs.get("outputDir"))

        if not all([
            release_version,
            base_folder,
            application_base_path,
            app_name,
            sign_off_name,
            output_dir
        ]):
            with open(log_file, "w", encoding="utf-8") as log:
                log.write("Missing required email inputs.\n")
            update_step_status(step_name, "FAILED")
            return

        command = [
            "python",
            os.path.join(BASE_DIR, "python", "generate_release_email.py"),
            release_version,
            base_folder,
            application_base_path,
            app_name,
            sign_off_name,
            output_dir,
        ]

    # =========================================================
    # DEFAULT
    # =========================================================
    else:

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", step_name
        ]

    # =========================================================
    # EXECUTE + STREAM LOGS
    # =========================================================
    with open(log_file, "w", encoding="utf-8") as log:

        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            for line in process.stdout:
                print(line.strip())
                log.write(line)
                log.flush()

            process.wait()

            if process.returncode == 0:
                update_step_status(step_name, "SUCCESS")
            else:
                update_step_status(step_name, "FAILED")

        except Exception as e:
            log.write(f"\nERROR: {str(e)}\n")
            update_step_status(step_name, "FAILED")
