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

    base_release = safe(inputs.get("baseRelease"))
    target_release = safe(inputs.get("targetRelease"))
    output_folder = f".\\release_{target_release}"


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

        target_release = safe(inputs.get("TargetVersion"))
        output_folder = inputs.get("OutputFolder")

        if not output_folder:
            output_folder = f".\\release_{target_release}"

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", "incrementals",
            "-RepoPath", safe(inputs.get("RepoPath")),
            "-AppName", safe(inputs.get("AppName")),
            "-BaseRelease", safe(inputs.get("BaseVersion")),
            "-TargetRelease", target_release,
            "-OutputFolder", output_folder,
            "-JiraRef", safe(inputs.get("JiraRef")),
        ]

    # =========================================================
    # COMMIT SUMMARY
    # =========================================================
    elif step_name == "commit":

        output_folder = inputs.get("OutputFolder")

        if not output_folder:
            output_folder = f".\\release_{target_release}"

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", "commit",
            "-RepoPath", safe(inputs.get("repoPath")),
            "-BaseRelease", safe(inputs.get("baseRelease")),
            "-TargetRelease", safe(inputs.get("targetRelease")),
            "-OutputFolder", output_folder,
            "-JiraRef", safe(inputs.get("jiraRef")),
            "-AppName", safe(inputs.get("appName")),
            "-AppVariant", safe(inputs.get("appVariant")),
        ]


    # =========================================================
    # RELEASE REPORT
    # =========================================================
    elif step_name == "report":

        command = [
            "python",
            os.path.join(BASE_DIR, "python", "release-report-generator", "generate_release_doc.py"),
            "--json", safe(inputs.get("jsonFile")),
            "--title", safe(inputs.get("title")),
            "--release", safe(inputs.get("release")),
            "--subtitle", safe(inputs.get("subtitle")),
            "--version", safe(inputs.get("versionNumber")),
            "--date", safe(inputs.get("versionDate")),
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
    # SECURITY 
    # =========================================================
    elif step_name == "security":

        import paramiko
        from scp import SCPClient

        host = "100.76.144.249"
        username = safe(inputs.get("username"))
        password = safe(inputs.get("password"))
        app = safe(inputs.get("RemoteAppName"))
        release = safe(inputs.get("RemoteReleaseVersion"))

        remote_report_path = f"/scratch/softwares_2/Reports-ALL/{release}/{app}"
        local_report_path = os.path.join(BASE_DIR, "Report-output", "Sonar_OSCS_Malware_Reports")

        os.makedirs(local_report_path, exist_ok=True)

        remote_command = f"/scratch/softwares_2/run_oscs_sonar_generic.sh {app} {release}"

        with open(log_file, "w", encoding="utf-8") as log:
            try:
                log.write("Connecting to server...\n")
                log.flush()

                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(hostname=host, username=username, password=password)

                log.write("Connected successfully.\n")
                log.flush()

                stdin, stdout, stderr = client.exec_command(remote_command, get_pty=True)

                for line in iter(stdout.readline, ""):
                    log.write(line)
                    log.flush()

                log.write("\nDownloading reports...\n")
                log.flush()

                scp = SCPClient(client.get_transport())
                scp.get(remote_report_path, local_path=local_report_path, recursive=True)

                scp.close()
                client.close()

                update_step_status(step_name, "SUCCESS")

            except Exception as e:
                log.write(f"\nERROR: {str(e)}\n")
                update_step_status(step_name, "FAILED")

        return

    # =========================================================
    # STAAS 
    # =========================================================
    elif step_name == "staas":

        import paramiko
        from scp import SCPClient

        host = "100.76.144.249"
        username = safe(inputs.get("username"))
        password = safe(inputs.get("password"))

        remote_report_path = "/scratch/softwares_2/STaaS_Reports"
        local_report_path = os.path.join(BASE_DIR, "Report-output", "STaaS_Reports")

        os.makedirs(local_report_path, exist_ok=True)

        remote_command = "/scratch/softwares_2/run_staas_generic.sh"

        with open(log_file, "w", encoding="utf-8") as log:
            try:
                log.write("Connecting to server...\n")
                log.flush()

                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(hostname=host, username=username, password=password)

                log.write("Connected successfully.\n")
                log.flush()

                stdin, stdout, stderr = client.exec_command(remote_command, get_pty=True)

                for line in iter(stdout.readline, ""):
                    log.write(line)
                    log.flush()

                log.write("\nDownloading STaaS reports...\n")
                log.flush()

                scp = SCPClient(client.get_transport())
                scp.get(remote_report_path, local_path=local_report_path, recursive=True)

                scp.close()
                client.close()

                update_step_status(step_name, "SUCCESS")

            except Exception as e:
                log.write(f"\nERROR: {str(e)}\n")
                update_step_status(step_name, "FAILED")

        return

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
    # EXECUTE (FIXED WORKING DIRECTORY ISSUE)
    # =========================================================
    with open(log_file, "w", encoding="utf-8") as log:

        try:
            process = subprocess.Popen(
                command,
                cwd=BASE_DIR,   
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
