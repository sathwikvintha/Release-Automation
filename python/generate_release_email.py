import os
import re
import textwrap
import logging
import sys
from datetime import datetime

# ============================================================
# ARGUMENT VALIDATION
# ============================================================

if len(sys.argv) != 7:
    print("Usage:")
    print("python generate_release_email.py "
          "<RELEASE_VERSION> "
          "<BASE_FOLDER> "
          "<APPLICATION_BASE_PATH> "
          "<APP_NAME> "
          "<SIGN_OFF_NAME> "
          "<OUTPUT_DIR>")
    sys.exit(1)

RELEASE_VERSION = sys.argv[1].strip()
BASE_FOLDER = os.path.normpath(sys.argv[2].strip())
APPLICATION_BASE_PATH = sys.argv[3].strip()
APP_NAME = sys.argv[4].strip()
SIGN_OFF_NAME = sys.argv[5].strip()
OUTPUT_DIR = os.path.normpath(sys.argv[6].strip())

# ============================================================
# PROJECT PATH RESOLUTION
# ============================================================

BASE_PROJECT_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../")
)

LOG_DIR = os.path.join(BASE_PROJECT_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, "release_email.log")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler()
    ]
)

logging.info("========== Release Email Generator Started ==========")
logging.info(f"Release: {RELEASE_VERSION}")
logging.info(f"Base Folder: {BASE_FOLDER}")
logging.info(f"Application Base Path: {APPLICATION_BASE_PATH}")
logging.info(f"Application: {APP_NAME}")
logging.info(f"Output Dir: {OUTPUT_DIR}")

# ============================================================
# TABLE SETTINGS
# ============================================================

COL1_WIDTH = 40
COL2_WIDTH = 70

SECURITY_NOTE = (
    "The report is available at this location. "
    "Please review the same and as discussed & agreed, "
    "please help to share the priority to address the issues / "
    "vulnerabilities so that the fix can be planned in the "
    "upcoming releases."
)

SECURITY_KEYWORDS = ["Malware", "OSCS", "STaaS"]

# ============================================================
# HELPERS
# ============================================================

def scan_pgp_files(folder):
    logging.info(f"Scanning PGP files in folder: {folder}")

    if not os.path.exists(folder):
        raise FileNotFoundError(f"Release folder not found: {folder}")

    files = sorted(
        f for f in os.listdir(folder)
        if os.path.isfile(os.path.join(folder, f)) and f.lower().endswith(".pgp")
    )

    if not files:
        logging.warning("No PGP files found in release folder.")

    logging.info(f"Found {len(files)} PGP files")
    return files


def derive_left_label(filename, release_version):
    name = filename.replace(release_version + "_", "").replace(".pgp", "")
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    return name.strip()


def needs_security_note(label):
    return any(key.lower() in label.lower() for key in SECURITY_KEYWORDS)


def separator():
    return "+" + "-" * COL1_WIDTH + "+" + "-" * COL2_WIDTH + "+\n"


def format_row(col1, col2):
    wrapped = textwrap.wrap(col2, COL2_WIDTH - 2) or [""]
    lines = [
        f"| {col1.ljust(COL1_WIDTH - 2)}| {wrapped[0].ljust(COL2_WIDTH - 2)}|\n"
    ]
    for extra in wrapped[1:]:
        lines.append(
            f"| {' '.ljust(COL1_WIDTH - 2)}| {extra.ljust(COL2_WIDTH - 2)}|\n"
        )
    return "".join(lines)

# ============================================================
# MAIN
# ============================================================

def generate():

    # Detect whether BASE_FOLDER already points to release folder
    if BASE_FOLDER.endswith(f"release_{RELEASE_VERSION}"):
        release_folder = BASE_FOLDER
    else:
        release_folder = os.path.join(BASE_FOLDER, f"release_{RELEASE_VERSION}")

    pgp_files = scan_pgp_files(release_folder)

    output = []

    # Email Header
    output.append("Hi Team,\n\n")
    output.append(
        f"Please find the artifacts below for release of {RELEASE_VERSION}.\n"
        "Artifacts to be uploaded on SECURE FILE SHARING APAC – BNP PARIBAS Collaboration.\n\n"
    )

    # Table Header
    output.append(separator())
    output.append(format_row("Item", "Details"))
    output.append(separator())

    for file in pgp_files:

        label = derive_left_label(file, RELEASE_VERSION)

        value = (
            f"{APPLICATION_BASE_PATH} > "
            f"{RELEASE_VERSION} > "
            f"{APP_NAME} > "
            f"{file}"
        )

        if needs_security_note(label):
            value += " " + SECURITY_NOTE

        output.append(format_row(label, value))
        output.append(separator())

    # Sign-off
    output.append("\nRegards,\n")
    output.append(SIGN_OFF_NAME + "\n")

    # Ensure output directory exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Add timestamp to avoid overwriting
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    out_file = os.path.join(
        OUTPUT_DIR,
        f"Release_Email_{RELEASE_VERSION}_{timestamp}.txt"
    )

    with open(out_file, "w", encoding="utf-8") as f:
        f.writelines(output)

    logging.info(f"Release email generated successfully: {out_file}")
    print(f"Release email generated successfully at: {out_file}")

# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    try:
        generate()
        logging.info("========== Release Email Generator Completed ==========")
    except Exception as e:
        logging.exception("Release email generation failed")
        sys.exit(1)
