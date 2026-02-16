import subprocess
import threading

def run_powershell(script_path, args=None):
    if args is None:
        args = []

    command = [
        "powershell",
        "-ExecutionPolicy", "Bypass",
        "-File", script_path
    ] + args

    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    return process
