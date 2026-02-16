import threading
from services.executor import run_powershell
from services.state_manager import update_state

def run_full_pipeline(release, app):

    def target():
        update_state("RUNNING")

        process = run_powershell(
            "../run_release.ps1",
            ["-RemoteReleaseVersion", release, "-RemoteAppName", app]
        )

        process.wait()

        if process.returncode == 0:
            update_state("COMPLETED")
        else:
            update_state("FAILED")

    thread = threading.Thread(target=target)
    thread.start()
