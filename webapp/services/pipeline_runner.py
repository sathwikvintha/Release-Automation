from platform import release
import subprocess
import os
from services.state_manager import update_step_status

LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
BASE_SCRIPT = os.path.join(BASE_DIR, "run_release.ps1")

def run_step(step_name, inputs=None):

    update_step_status(step_name, "RUNNING")
    if step_name.startswith("staas"):
        log_file = os.path.join(LOG_DIR, "staas.log")
    else:
        log_file = os.path.join(LOG_DIR, f"{step_name}.log")

    command = []

        # ==========================
    # ANGULAR (Jenkins Build)
    # ==========================
    if step_name == "angular":

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", "angular",
            "-ReleaseVersion", inputs.get("ReleaseVersion"),
            "-RemoteReleaseVersion", inputs.get("RemoteReleaseVersion"),
            "-RemoteAppName", inputs.get("RemoteAppName"),
            "-JenkinsUser", inputs.get("JenkinsUser"),
            "-JenkinsToken", inputs.get("JenkinsToken"),
        ]

    # ==========================
    # COMMIT SUMMARY
    # ==========================
    elif step_name == "commit":

        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", os.path.join(BASE_DIR, "powershell", "Generate-CommitSummary.ps1"),
            "-RepoPath", inputs.get("repoPath"),
            "-BaseRelease", inputs.get("baseRelease"),
            "-TargetRelease", inputs.get("targetRelease"),
            "-OutputFolder", os.path.join(BASE_DIR, "python", "release-report-generator", "json_files"),
            "-JiraRef", inputs.get("jiraRef"),
            "-AppName", inputs.get("appName")
        ]

    # ==========================
    # RELEASE REPORT
    # ==========================
    elif step_name == "report":

        command = [
            "python",
            os.path.join(BASE_DIR, "python", "release-report-generator", "generate_release_doc.py"),
            inputs.get("jsonFile"),
            inputs.get("title"),
            inputs.get("release"),
            inputs.get("subtitle"),
            inputs.get("versionNumber"),
            inputs.get("versionDate")
        ]

    # ==========================
    # REMOTE SECURITY
    # ==========================
    elif step_name == "security":

        import paramiko
        from scp import SCPClient

        host = "100.76.144.249"
        username = inputs.get("username")
        password = inputs.get("password")
        app = inputs.get("RemoteAppName")
        release = inputs.get("RemoteReleaseVersion")

        remote_report_path = f"/scratch/softwares_2/Reports-ALL/{release}/{app}"
        local_report_path = os.path.join(BASE_DIR, "Report-output", "Sonar_OSCS_Malware_Reports")

        os.makedirs(local_report_path, exist_ok=True)

        command = f"/scratch/softwares_2/run_oscs_sonar_generic.sh {app} {release}"

        with open(log_file, "w", encoding="utf-8") as log:
            try:
                log.write("Connecting to server...\n")
                log.flush()

                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(hostname=host, username=username, password=password)

                log.write("Connected successfully.\n")
                log.flush()

                stdin, stdout, stderr = client.exec_command(command, get_pty=True)

                for line in iter(stdout.readline, ""):
                    log.write(line)
                    log.flush()

                log.write("\nDownloading reports from server...\n")
                log.flush()

                scp = SCPClient(client.get_transport())
                scp.get(remote_report_path, local_path=local_report_path, recursive=True)

                log.write("Reports downloaded successfully.\n")
                log.flush()

                scp.close()
                client.close()

                update_step_status(step_name, "SUCCESS")

            except Exception as e:
                log.write(f"\nERROR: {str(e)}\n")
                log.flush()
                update_step_status(step_name, "FAILED")

        return
    
    # -------------------------
    # REMOTE STaaS (SUBMIT ONLY)
    # -------------------------
    elif step_name == "staas":

        import paramiko

        host = "100.76.144.249"
        username = inputs.get("username")
        password = inputs.get("password")

        remote_script_dir = "/scratch/softwares_2/Staas_Report_Generator"

        with open(log_file, "w", encoding="utf-8") as log:
            log.write("")

        command = (
        f"cd {remote_script_dir} && "
        f"./staas_start.sh "
        f"\"{inputs.get('title')}\" "
        f"\"{inputs.get('url')}\" "
        f"\"{inputs.get('version')}\" "
        f"\"{inputs.get('groupId')}\" "
        f"\"{inputs.get('emails')}\" "
        f"\"{inputs.get('loginType')}\" "
        f"\"{inputs.get('appUsername')}\" "
        f"\"{inputs.get('appPassword')}\" "
        f"\"{inputs.get('webinspect')}\" "
        f"\"{inputs.get('testType')}\" "
        f"\"{inputs.get('auth')}\" "
        f"\"{inputs.get('addUrlsOn')}\" "
        f"\"{inputs.get('addUrl')}\""
    )


        with open(log_file, "w", encoding="utf-8") as log:
            try:
                log.write("Connecting to server...\n")
                log.flush()

                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(hostname=host, username=username, password=password)

                log.write("Connected successfully.\n")
                log.flush()

                stdin, stdout, stderr = client.exec_command(command, get_pty=True)

                log.write("\nSubmitting STaaS scan...\n\n")
                log.flush()

                # STREAM LIVE OUTPUT
                for line in iter(stdout.readline, ""):
                    log.write(line)
                    log.flush()

                client.close()

                update_step_status(step_name, "SUCCESS")

            except Exception as e:
                log.write(f"\nERROR: {str(e)}\n")
                log.flush()
                update_step_status(step_name, "FAILED")

        return


    # -------------------------    
    # STaaS STATUS CHECK
    # -------------------------

    elif step_name == "staas-status":

        import paramiko

        host = "100.76.144.249"
        username = inputs.get("username")
        password = inputs.get("password")
        scan_id = inputs.get("scanId")

        remote_script_path = "/scratch/softwares_2/Staas_Report_Generator/staas_status.sh"
        
        

        with open(log_file, "w", encoding="utf-8") as log:
            log.write("")

        with open(log_file, "w", encoding="utf-8") as log:
            try:
                log.write("Connecting to server...\n")
                log.flush()

                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(hostname=host, username=username, password=password)

                log.write("Connected successfully.\n\n")
                log.flush()

                # -------------------------------
                # STEP 1: Ensure executable permission
                # -------------------------------
                log.write("Ensuring execute permission on staas_status.sh...\n")
                log.flush()

                chmod_command = f"chmod +x {remote_script_path}"
                client.exec_command(chmod_command)

                # -------------------------------
                # STEP 2: Run status script
                # -------------------------------
                log.write("\nChecking Scan Status...\n\n")
                log.flush()

                status_command = (
                "cd /scratch/softwares_2/Staas_Report_Generator && "
                "chmod +x staas_status.sh && "
                f"./staas_status.sh '{scan_id}'"
            )


                stdin, stdout, stderr = client.exec_command(status_command, get_pty=True)

                for line in iter(stdout.readline, ""):
                    log.write(line)
                    log.flush()

                for err in iter(stderr.readline, ""):
                    log.write(err)
                    log.flush()

                client.close()

                update_step_status(step_name, "SUCCESS")

            except Exception as e:
                log.write(f"\nERROR: {str(e)}\n")
                log.flush()
                update_step_status(step_name, "FAILED")

        return
    
    # -------------------------
    # STaaS DOWNLOAD REPORT
    # -------------------------
    elif step_name == "staas-download":

        import paramiko
        from scp import SCPClient

        host = "100.76.144.249"
        username = inputs.get("username")
        password = inputs.get("password")
        scan_id = inputs.get("scanId")
        report_name = inputs.get("reportName")
        file_type = inputs.get("fileType")

        remote_script_dir = "/scratch/softwares_2/Staas_Report_Generator"

        log_file = os.path.join(LOG_DIR, "staas.log")

        with open(log_file, "a", encoding="utf-8") as log:
            try:
                log.write("\n\n==============================\n")
                log.write("Starting STaaS Report Download\n")
                log.write("==============================\n\n")
                log.flush()

                client = paramiko.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(hostname=host, username=username, password=password)

                log.write("Connected successfully.\n\n")
                log.flush()

                command = (
                    f"cd {remote_script_dir} && "
                    f"chmod +x staas_download.sh && "
                    f"./staas_download.sh "
                    f"'{scan_id}' "
                    f"'{report_name}' "
                    f"'{file_type}'"
                )

                stdin, stdout, stderr = client.exec_command(command, get_pty=True)

                # This captures output path echoed by script
                remote_file_path = stdout.read().decode().strip()

                log.write(f"Remote file generated at: {remote_file_path}\n")
                log.flush()

                # LOCAL PROJECT FOLDER
                local_dir = os.path.join(
                    BASE_DIR,
                    "Report-output",
                    "StaaS_Reports"
                )

                os.makedirs(local_dir, exist_ok=True)

                # SCP COPY
                scp = SCPClient(client.get_transport())
                scp.get(remote_file_path, local_path=local_dir)

                log.write("Report downloaded successfully to local project.\n")
                log.flush()

                scp.close()
                client.close()

                update_step_status("staas", "SUCCESS")

            except Exception as e:
                log.write(f"\nERROR: {str(e)}\n")
                log.flush()
                update_step_status("staas", "FAILED")

        return

    # ==========================
    # OTHER STEPS (Angular, etc.)
    # ==========================
    else:
        command = [
            "powershell",
            "-ExecutionPolicy", "Bypass",
            "-File", BASE_SCRIPT,
            "-Step", step_name
        ]

    # ==========================
    # LIVE LOG STREAMING
    # ==========================
    with open(log_file, "w", encoding="utf-8") as log:

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
